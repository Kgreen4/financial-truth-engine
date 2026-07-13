-- =============================================================================
-- Financial Truth Engine — Human-Readable Claim Report (MVP, Task 023B)
-- reconciler/fte_claim_report.sql
--
-- Function: fte_claim_report(p_practice_id uuid, p_claim_id uuid) RETURNS text
--
-- Renders a single claim as a plain-text/markdown block for humans. It WRAPS
-- fte_explain_claim (and the review queue it already returns) — it derives no
-- new financial values and changes nothing. Read-only, deterministic, no AI.
--
-- Surfaces: identity, status, billed/adjustments/paid/open, denied/recoverable/
-- non-recoverable, appeal window/deadline/status, a "NEEDS REVIEW" line from the
-- review queue, and a short denial-knowledge trace summary (022B recoverability +
-- 022C appeal-window), worded for a business reader while preserving the audit
-- values: match_status, match_score (as "confidence score"), matched_scope, and
-- rule_governance (category/action/owner). denial_knowledge_id is intentionally
-- NOT printed (it is a secondary, opaque reference); the stable scope + score +
-- governance are the human explanation.
--
-- Prerequisites: fte_explain_claim registered (which needs the reconciler run
-- first to materialize positions). Register AFTER fte_explain_claim.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION fte_claim_report(
  p_practice_id uuid,
  p_claim_id    uuid
) RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v        jsonb;
  r        text;
  v_reasons text;
  v_d      jsonb;   -- one recoverability denial entry
  v_de     jsonb;   -- appeal-window driving_event
BEGIN
  v := fte_explain_claim(p_practice_id, p_claim_id);
  IF v IS NULL THEN
    RETURN format('Claim %s: not found for this practice.', p_claim_id);
  END IF;

  r := format('Claim %s (%s)', v->>'claim_number', COALESCE(v->>'payer_name', 'unknown payer')) || E'\n';
  r := r || format('  Status: %s', COALESCE(v->>'reconciliation_status', '(no position)')) || E'\n';
  r := r || format('  Billed: $%s | Adjustments: $%s | Paid: $%s | Open balance: $%s',
        COALESCE(v->>'billed_amount', '0.00'),
        COALESCE(v->>'contractual_adjustment_amount', '0.00'),
        COALESCE(v->>'paid_amount', '0.00'),
        COALESCE(v->>'open_balance_amount', '0.00')) || E'\n';

  IF v->>'denied_amount' IS NOT NULL THEN
    r := r || format('  Denied: $%s | Recoverable: $%s | Non-recoverable: $%s',
          v->>'denied_amount',
          COALESCE(v->>'recoverable_amount', '0.00'),
          COALESCE(v->>'nonrecoverable_denied_amount', '0.00')) || E'\n';
  END IF;

  IF v->>'appeal_deadline' IS NOT NULL THEN
    r := r || format('  Appeal deadline: %s (%s), window %s days',
          v->>'appeal_deadline', v->>'appeal_deadline_status',
          COALESCE(v->>'appeal_window_days', '?')) || E'\n';
  END IF;

  -- Needs-review line from the review queue explain already carries.
  IF jsonb_array_length(COALESCE(v->'review_queue', '[]'::jsonb)) > 0 THEN
    SELECT string_agg(x->>'reason', ', ')
      INTO v_reasons
      FROM jsonb_array_elements(v->'review_queue') x;
    r := r || format('  NEEDS REVIEW: %s', v_reasons) || E'\n';
  END IF;

  -- Recoverability trace (022B): one line per denial event.
  IF jsonb_typeof(v->'recoverability_trace') = 'object'
     AND jsonb_array_length(COALESCE(v->'recoverability_trace'->'denials', '[]'::jsonb)) > 0 THEN
    r := r || '  Recoverability trace:' || E'\n';
    FOR v_d IN SELECT * FROM jsonb_array_elements(v->'recoverability_trace'->'denials') LOOP
      r := r || format('    - Denied $%s: %s (confidence score %s)',
            v_d->>'denied_amount', v_d->>'match_status',
            COALESCE(v_d->>'match_score', 'n/a'));
      IF jsonb_typeof(v_d->'matched_scope') = 'object' THEN
        r := r || format(' on scope=[carc=%s payer=%s]',
              COALESCE(v_d->'matched_scope'->>'carc', '*'),
              COALESCE(v_d->'matched_scope'->>'payer', '*'));
      END IF;
      IF jsonb_typeof(v_d->'rule_governance') = 'object' THEN
        r := r || format(' → rule: category=%s action=%s owner=%s',
              COALESCE(v_d->'rule_governance'->>'category', '-'),
              COALESCE(v_d->'rule_governance'->>'default_action', '-'),
              COALESCE(v_d->'rule_governance'->>'default_owner', '-'));
      END IF;
      r := r || E'\n';
    END LOOP;
    r := r || format('    (recoverable total consistent with stored position: %s)',
          COALESCE(v->'recoverability_trace'->>'consistent', '?')) || E'\n';
  END IF;

  -- Appeal-window trace (022C): the rule that drove the surfaced deadline.
  IF v->'appeal_window_trace'->>'status' = 'matched' THEN
    v_de := v->'appeal_window_trace'->'driving_event';
    r := r || format('  Appeal-window trace: %s (confidence score %s)',
          v_de->>'match_status', COALESCE(v_de->>'match_score', 'n/a'));
    IF jsonb_typeof(v_de->'matched_scope') = 'object' THEN
      r := r || format(' on scope=[carc=%s]', COALESCE(v_de->'matched_scope'->>'carc', '*'));
    END IF;
    IF jsonb_typeof(v_de->'rule_governance') = 'object' THEN
      r := r || format(' → rule: category=%s action=%s',
            COALESCE(v_de->'rule_governance'->>'category', '-'),
            COALESCE(v_de->'rule_governance'->>'default_action', '-'));
    END IF;
    r := r || E'\n';
  END IF;

  RETURN r;
END;
$$;
