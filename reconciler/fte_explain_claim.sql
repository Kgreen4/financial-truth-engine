-- =============================================================================
-- Financial Truth Engine — Claim Explanation Function
-- reconciler/fte_explain_claim.sql
--
-- Function: fte_explain_claim(p_practice_id uuid, p_claim_id uuid) RETURNS jsonb
--
-- Read-only. Deterministic. No AI calls. Does not call fte_reconcile_practice.
-- Caller must run fte_reconcile_practice first to materialize positions.
--
-- Returns structured JSON for one claim's reconciled financial position:
--   claim identity, financial position, summary sentence, events array,
--   distinct evidence array, review queue array.
--
-- Monetary fields are returned as fixed two-decimal strings ("150.00"), never
-- raw JSON numerics — use to_char(value, 'FM999999999999990.00').
--
-- Missing position handling:
--   If the claim exists for the practice but has no fte_financial_positions row,
--   returns partial JSON with null monetary fields and an advisory summary.
--   Does not raise an exception.
--
-- Prerequisites: migrations 001–012 applied; fte_reconcile_practice registered.
-- Run as a database role with ordinary read access to the FTE tables in the target environment.
-- =============================================================================

CREATE OR REPLACE FUNCTION fte_explain_claim(
  p_practice_id uuid,
  p_claim_id    uuid
) RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_claim       record;
  v_pos         record;
  v_life        record;
  v_events      jsonb;
  v_evidence    jsonb;
  v_review      jsonb;
  v_summary     text;
  v_appeal_outcome text;
  v_appeal_window_days     integer;
  v_appeal_deadline        date;
  v_appeal_deadline_status text;
BEGIN

  -- =========================================================================
  -- Step 1: Load claim identity.
  -- Returns NULL if the claim does not exist for this practice.
  -- =========================================================================
  SELECT c.id, c.claim_number, c.payer_name
  INTO   v_claim
  FROM   fte_claims c
  WHERE  c.practice_id = p_practice_id
    AND  c.id          = p_claim_id;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  -- =========================================================================
  -- Step 2: Load financial position (may not exist yet).
  -- =========================================================================
  SELECT fp.reconciliation_status,
         fp.billed_amount,
         fp.allowed_amount,
         fp.contractual_adjustment_amount,
         fp.paid_amount,
         fp.patient_responsibility_amount,
         fp.denied_amount,
         fp.recoverable_amount,
         fp.recovered_amount,
         fp.written_off_amount,
         fp.open_balance_amount
  INTO   v_pos
  FROM   fte_financial_positions fp
  WHERE  fp.practice_id = p_practice_id
    AND  fp.claim_id    = p_claim_id;

  -- =========================================================================
  -- Step 2b (Task 017D): denial-lifecycle aggregates from claim_events history.
  -- gross_denied is summed from denial_posted event amounts (NOT net position
  -- math), so it reflects the total denial before any recovery/write-off
  -- reclassification. Counts drive the appeal marker and lifecycle summary.
  -- Aggregate query: always returns one row; gross_denied is NULL when there
  -- are no denial_posted events for the claim.
  -- =========================================================================
  SELECT
    SUM(ce.amount) FILTER (WHERE ce.event_type = 'denial_posted')      AS gross_denied,
    COUNT(*)       FILTER (WHERE ce.event_type = 'appeal_filed')       AS appeal_ct,
    COUNT(*)       FILTER (WHERE ce.event_type = 'recovery_received')  AS recovery_ct,
    COUNT(*)       FILTER (WHERE ce.event_type = 'write_off_approved') AS writeoff_ct
  INTO   v_life
  FROM   fte_claim_events ce
  WHERE  ce.practice_id = p_practice_id
    AND  ce.claim_id    = p_claim_id;

  -- =========================================================================
  -- Step 2c (Task 018D): active appeal outcome, read from reviewer resolutions.
  -- Reporting-only. Surfaces the single active record_appeal_outcome disposition
  -- (upheld / denied / partial). NULL when none is recorded; also NULL when
  -- conflicting active outcomes exist (Task 018C routes that to review — explain
  -- does not invent a value). Reads fte_review_resolutions directly; it makes no
  -- accounting change and does not alter position or status.
  -- =========================================================================
  SELECT CASE WHEN COUNT(DISTINCT rr.appeal_outcome) = 1
              THEN MIN(rr.appeal_outcome) ELSE NULL END
  INTO   v_appeal_outcome
  FROM   fte_review_resolutions rr
  WHERE  rr.practice_id   = p_practice_id
    AND  rr.claim_id      = p_claim_id
    AND  rr.action        = 'record_appeal_outcome'
    AND  rr.is_superseded = false;

  -- =========================================================================
  -- Step 2d (Task 019B): appeal window / deadline, derived from denial_posted
  -- event history and fte_denial_knowledge.appeal_window_days. Reporting-only;
  -- INDEPENDENT of the Phase 6b recoverable overlay (own specificity-scored
  -- match against fte_denial_knowledge, not coupled to recoverable_amount).
  --
  -- For each denial_posted event with a non-null event_date, find the
  -- highest-specificity fte_denial_knowledge row(s) (practice(+8) + payer(+4)
  -- + carc(+2) + rarc(+1); NULL fields on the knowledge row are wildcards) that
  -- also have appeal_window_days IS NOT NULL. A knowledge row that matches on
  -- scope but carries a NULL appeal_window_days is excluded from this join
  -- entirely -- it never counts as this event's match, so such an event falls
  -- through to unknown exactly like an event with zero matching rows. Requires
  -- unanimous agreement (single distinct appeal_window_days) among the
  -- top-scored rows for that event; a same-specificity conflict fails closed
  -- (event excluded, no guessing). event_date + resolved window = candidate
  -- deadline. Across all of the claim's denial_posted events, the EARLIEST
  -- non-null candidate deadline is surfaced at the claim level (v1: multi-denial
  -- claims resolve to their tightest/soonest window).
  --
  -- Result is NULL (both fields) when: no denial_posted events, no event has a
  -- non-null event_date, or no event resolves to a non-null candidate deadline.
  -- =========================================================================
  WITH claim_denials AS (
    SELECT ce.id AS event_id, ce.event_date, ce.carc_code, ce.rarc_code, ce.payer_name
    FROM   fte_claim_events ce
    WHERE  ce.practice_id = p_practice_id
      AND  ce.claim_id    = p_claim_id
      AND  ce.event_type  = 'denial_posted'
      AND  ce.event_date IS NOT NULL
  ),
  scored AS (
    SELECT cd.event_id, cd.event_date, dk.appeal_window_days,
           (CASE WHEN dk.practice_id IS NOT NULL THEN 8 ELSE 0 END
          + CASE WHEN dk.payer_name  IS NOT NULL THEN 4 ELSE 0 END
          + CASE WHEN dk.carc_code   IS NOT NULL THEN 2 ELSE 0 END
          + CASE WHEN dk.rarc_code   IS NOT NULL THEN 1 ELSE 0 END) AS score
    FROM   claim_denials cd
    JOIN   fte_denial_knowledge dk
      ON  (dk.practice_id = p_practice_id OR dk.practice_id IS NULL)
      AND (dk.payer_name  = cd.payer_name OR dk.payer_name  IS NULL)
      AND (dk.carc_code   = cd.carc_code  OR dk.carc_code   IS NULL)
      AND (dk.rarc_code   = cd.rarc_code  OR dk.rarc_code   IS NULL)
      AND dk.appeal_window_days IS NOT NULL
  ),
  top_scored AS (
    SELECT event_id, event_date, appeal_window_days,
           RANK() OVER (PARTITION BY event_id ORDER BY score DESC) AS rnk
    FROM   scored
  ),
  resolved AS (
    SELECT event_id, event_date,
           CASE WHEN COUNT(DISTINCT appeal_window_days) = 1
                THEN MIN(appeal_window_days) ELSE NULL END AS resolved_window
    FROM   top_scored
    WHERE  rnk = 1
    GROUP BY event_id, event_date
  ),
  deadlines AS (
    SELECT resolved_window, (event_date + resolved_window)::date AS deadline
    FROM   resolved
    WHERE  resolved_window IS NOT NULL
  )
  SELECT resolved_window, deadline
  INTO   v_appeal_window_days, v_appeal_deadline
  FROM   deadlines
  ORDER BY deadline ASC
  LIMIT  1;

  v_appeal_deadline_status := CASE
    WHEN v_appeal_deadline IS NULL      THEN 'unknown'
    WHEN v_appeal_deadline >= CURRENT_DATE THEN 'open'
    ELSE 'expired'
  END;

  -- =========================================================================
  -- Step 3: Build events array.
  -- One object per fte_claim_events row, ordered by created_at then event_type.
  -- evidence_count = count of all fte_event_evidence rows linked to the event.
  -- =========================================================================
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'event_type',            ce.event_type,
        'amount',                to_char(ce.amount, 'FM999999999999990.00'),
        'amount_type',           ce.amount_type,
        'event_date',            ce.event_date,
        'reconciliation_status', ce.reconciliation_status,
        'evidence_count',        (
          SELECT COUNT(*)
          FROM   fte_event_evidence ee
          WHERE  ee.claim_event_id = ce.id
            AND  ee.practice_id   = p_practice_id
        )
      )
      ORDER BY ce.created_at, ce.event_type
    ),
    '[]'::jsonb
  )
  INTO v_events
  FROM fte_claim_events ce
  WHERE ce.practice_id = p_practice_id
    AND ce.claim_id    = p_claim_id;

  -- =========================================================================
  -- Step 4: Build distinct evidence array.
  -- Distinct evidence rows reachable from this claim's events via
  -- fte_event_evidence. Ordered by page_number ASC NULLS LAST, then
  -- evidence_type, then evidence_id for determinism.
  -- raw_text_snippet = left(raw_text, 500); null raw_text stays null.
  -- =========================================================================
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'evidence_type',    ev.evidence_type,
        'page_number',      ev.page_number,
        'source_uri',       ev.source_uri,
        'raw_text_snippet', CASE WHEN ev.raw_text IS NOT NULL
                              THEN left(ev.raw_text, 500)
                              ELSE NULL
                            END
      )
      ORDER BY ev.page_number ASC NULLS LAST, ev.evidence_type, ev.id
    ),
    '[]'::jsonb
  )
  INTO v_evidence
  FROM (
    SELECT DISTINCT ev.id, ev.evidence_type, ev.page_number,
                    ev.source_uri, ev.raw_text
    FROM   fte_event_evidence ee
    JOIN   fte_claim_events   ce ON ce.id          = ee.claim_event_id
    JOIN   fte_evidence       ev ON ev.id          = ee.evidence_id
    WHERE  ce.practice_id = p_practice_id
      AND  ce.claim_id    = p_claim_id
      AND  ee.practice_id = p_practice_id
  ) ev;

  -- =========================================================================
  -- Step 5: Build review queue array.
  -- All fte_review_queue rows for the claim, ordered by created_at.
  -- Uses column `reason` (not review_reason).
  -- =========================================================================
  SELECT COALESCE(
    jsonb_agg(
      jsonb_build_object(
        'reason',     rq.reason,
        'status',     rq.status,
        'details',    rq.details,
        'created_at', rq.created_at
      )
      ORDER BY rq.created_at
    ),
    '[]'::jsonb
  )
  INTO v_review
  FROM fte_review_queue rq
  WHERE rq.practice_id = p_practice_id
    AND rq.claim_id    = p_claim_id;

  -- =========================================================================
  -- Step 6: Compose summary sentence.
  -- =========================================================================
  IF v_pos IS NULL OR v_pos.reconciliation_status IS NULL THEN
    v_summary := format(
      'Claim %s has no materialized financial position. Run reconciliation before explanation.',
      v_claim.claim_number
    );
  ELSE
    v_summary := format(
      'Claim %s is %s. Billed %s minus contractual adjustments %s minus payments %s leaves an open balance of %s.',
      v_claim.claim_number,
      v_pos.reconciliation_status,
      COALESCE(to_char(v_pos.billed_amount,                    'FM999999999999990.00'), 'null'),
      COALESCE(to_char(v_pos.contractual_adjustment_amount,    'FM999999999999990.00'), 'null'),
      COALESCE(to_char(v_pos.paid_amount,                      'FM999999999999990.00'), 'null'),
      COALESCE(to_char(v_pos.open_balance_amount,              'FM999999999999990.00'), 'null')
    );
  END IF;

  -- =========================================================================
  -- Step 7: Return JSON.
  -- =========================================================================
  RETURN jsonb_build_object(
    'practice_id',                    p_practice_id,
    'claim_id',                       p_claim_id,
    'claim_number',                   v_claim.claim_number,
    'payer_name',                     v_claim.payer_name,
    'reconciliation_status',          CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE v_pos.reconciliation_status END,
    'billed_amount',                  CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.billed_amount, 'FM999999999999990.00') END,
    'allowed_amount',                 CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.allowed_amount, 'FM999999999999990.00') END,
    'contractual_adjustment_amount',  CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.contractual_adjustment_amount, 'FM999999999999990.00') END,
    'paid_amount',                    CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.paid_amount, 'FM999999999999990.00') END,
    'patient_responsibility_amount',  CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.patient_responsibility_amount, 'FM999999999999990.00') END,
    'denied_amount',                  CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.denied_amount, 'FM999999999999990.00') END,
    'recoverable_amount',             CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.recoverable_amount, 'FM999999999999990.00') END,
    -- nonrecoverable_denied_amount (Task 014E2): denied minus recoverable, floored
    -- at 0; NULL when there are no denials. Derived for reporting only — it does
    -- not affect open_balance / short_pay / reconciliation_status.
    'nonrecoverable_denied_amount',   CASE WHEN v_pos IS NULL OR v_pos.denied_amount IS NULL THEN NULL
                                           ELSE to_char(GREATEST(0, v_pos.denied_amount
                                                        - COALESCE(v_pos.recoverable_amount, 0)),
                                                        'FM999999999999990.00') END,
    -- --- Denial lifecycle reporting (Task 017D) — additive, reporting-only ---
    -- denied_amount above is NET after 017C (gross - recovered - written_off).
    -- gross_denied_amount is derived from denial_posted event history so callers
    -- can see the pre-reclassification total alongside the net figure.
    'gross_denied_amount',            CASE WHEN v_life.gross_denied IS NULL THEN NULL
                                           ELSE to_char(v_life.gross_denied, 'FM999999999999990.00') END,
    'recovered_amount',               CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.recovered_amount, 'FM999999999999990.00') END,
    'written_off_amount',             CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.written_off_amount, 'FM999999999999990.00') END,
    -- remaining_recoverable_amount: recoverable overlay (gross-based; unchanged
    -- by 017C) minus what has already been recovered, floored at 0. recovered is
    -- subtracted exactly once (recoverable is NOT net after 017C). NULL when the
    -- claim has no denials (recoverable_amount NULL).
    'remaining_recoverable_amount',   CASE WHEN v_pos IS NULL OR v_pos.recoverable_amount IS NULL THEN NULL
                                           ELSE to_char(GREATEST(0, v_pos.recoverable_amount
                                                        - COALESCE(v_pos.recovered_amount, 0)),
                                                        'FM999999999999990.00') END,
    -- appeal_filed: reporting marker only (an appeal_filed event exists); it
    -- implies NO accounting change.
    'appeal_filed',                   COALESCE(v_life.appeal_ct, 0) > 0,
    -- appeal_outcome (Task 018D): the single active record_appeal_outcome
    -- disposition (upheld/denied/partial); JSON null when none is recorded or
    -- when conflicting active outcomes exist (018C routes conflicts to review).
    -- Reporting-only — implies NO accounting change.
    'appeal_outcome',                 v_appeal_outcome,
    -- appeal window / deadline (Task 019B): derived from denial_posted event
    -- history + fte_denial_knowledge.appeal_window_days. Reporting-only,
    -- independent of the recoverable overlay. NULL / 'unknown' when no
    -- denial_posted event, no event_date, or no matching non-null window.
    'appeal_window_days',             v_appeal_window_days,
    'appeal_deadline',                to_char(v_appeal_deadline, 'YYYY-MM-DD'),
    'appeal_deadline_status',         v_appeal_deadline_status,
    'lifecycle_event_counts',         jsonb_build_object(
                                        'appeal_filed',       COALESCE(v_life.appeal_ct, 0),
                                        'recovery_received',  COALESCE(v_life.recovery_ct, 0),
                                        'write_off_approved', COALESCE(v_life.writeoff_ct, 0)
                                      ),
    'open_balance_amount',            CASE WHEN v_pos IS NULL THEN NULL
                                           ELSE to_char(v_pos.open_balance_amount, 'FM999999999999990.00') END,
    'summary',                        v_summary,
    'events',                         v_events,
    'evidence',                       v_evidence,
    'review_queue',                   v_review
  );

END;
$$;
