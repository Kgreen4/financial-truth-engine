-- =============================================================================
-- Financial Truth Engine — Claim Explanation Function Validation
-- tests/validate_explain_claim.sql
--
-- 42 PASS checks verifying fte_explain_claim (Task 006D; extended in 014E2 for
-- the E2 / denial / recoverable ledger fields; extended in 017D for the
-- denial-lifecycle reporting fields; extended in 018D for appeal_outcome;
-- extended in 019B for appeal window / deadline reporting).
--
-- CHECK 33  AWOPEN appeal_window_days surfaces from matching denial knowledge
-- CHECK 34  AWOPEN appeal_deadline = denial_posted.event_date + window
-- CHECK 35  AWOPEN appeal_deadline_status = open
-- CHECK 36  AWEXP appeal_deadline_status = expired
-- CHECK 37  AWNOMATCH -> unknown (no matching denial-knowledge row at all)
-- CHECK 38  AWNULLWIN -> unknown (matching row has appeal_window_days NULL)
-- CHECK 39  AWMULTI -> earliest non-null deadline selected across two denials
-- CHECK 40  prior appeal_outcome field still preserved (AOU still 'upheld')
-- CHECK 41  prior lifecycle explain fields still preserved (LIFE unchanged)
-- CHECK 42  appeal window fields are reporting-only: accounting unchanged
--
-- CHECK 27  AOU upheld appeal outcome surfaced
-- CHECK 28  AOD denied appeal outcome surfaced
-- CHECK 29  AOP partial appeal outcome surfaced
-- CHECK 30  no recorded outcome -> appeal_outcome null (key present)
-- CHECK 31  prior lifecycle explain fields still present
-- CHECK 32  outcome is reporting-only: accounting fields unchanged
--
-- CHECK 15  no-denial claim: denied/recoverable/nonrecoverable are null
-- CHECK 16  explanation surfaces allowed/patient_responsibility/denied/recoverable keys
-- CHECK 17  REC claim denied_amount surfaced
-- CHECK 18  REC recoverable_amount + derived nonrecoverable_denied_amount
-- CHECK 19  MIXED claim denied/recoverable/nonrecoverable split
-- CHECK 20  recoverable overlay leaves open_balance/status unchanged
-- CHECK 21  LIFE gross_denied_amount from denial_posted history (100.00)
-- CHECK 22  LIFE denied_amount is net after recovery/write-off (0.00)
-- CHECK 23  LIFE recovered_amount / written_off_amount surfaced
-- CHECK 24  LIFE remaining_recoverable_amount non-negative (recoverable - recovered)
-- CHECK 25  LIFE appeal_filed marker + lifecycle_event_counts
-- CHECK 26  LIFE lifecycle reporting-only; prior output keys preserved
--
-- CHECK  1  fte_explain_claim exists in pg_proc
-- CHECK  2  returns jsonb without exception for CLM-P3A-0001
-- CHECK  3  CLM-P3A-0001 claim_number = 'CLM-P3A-0001'
-- CHECK  4  CLM-P3A-0001 reconciliation_status = 'balanced'
-- CHECK  5  CLM-P3A-0001 open_balance_amount = '0.00'
-- CHECK  6  CLM-P3A-0001 summary contains 'balanced'
-- CHECK  7  CLM-P3A-0001 events array length = 3
-- CHECK  8  CLM-P3A-0001 evidence array length = 2
-- CHECK  9  CLM-P3A-0003 reconciliation_status = 'unbalanced'
-- CHECK 10  CLM-P3A-0003 open_balance_amount = '180.00'
-- CHECK 11  CLM-P3A-0003 summary contains '180.00'
-- CHECK 12  CLM-P3A-0003 review_queue length = 1 and reason = 'unbalanced_financial_position'
-- CHECK 13  CLM-P3A-0001 payment_applied event has evidence_count = 2
-- CHECK 14  all non-null raw_text_snippet values in both outputs have length <= 500
--
-- Test vehicle: fixtures/synthetic_phase3a_extraction_fixture.sql
--   Practice: a3000000-0000-4000-8000-0000000000fe
--   Claims:   CLM-P3A-0001 (c3a00000-0000-4000-8000-000000000001) — balanced
--             CLM-P3A-0003 (c3a00000-0000-4000-8000-000000000003) — unbalanced
--
-- Prerequisites:
--   1. migrations 001–013 applied
--   2. reconciler/fte_reconcile.sql registered (CREATE OR REPLACE)
--   3. reconciler/fte_explain_claim.sql registered (CREATE OR REPLACE)
--   4. fixtures/synthetic_phase3a_extraction_fixture.sql loaded (committed)
--
-- Supabase SQL Editor note:
--   This suite assumes the Phase 3A fixture has already been loaded and
--   reconciler/fte_explain_claim.sql has already been registered. When running in
--   the Supabase SQL Editor, paste and execute this file starting from the BEGIN
--   block.
--
-- psql convenience (from repo root):
--   \i fixtures/synthetic_phase3a_extraction_fixture.sql
--   \i reconciler/fte_explain_claim.sql
--
-- Run via:
--   psql "$DATABASE_URL" -f tests/validate_explain_claim.sql
--
-- No credentials or connection strings are stored here.
-- All fixtures are synthetic. No PHI. No production data.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Task 014E2 self-contained denial + recoverable fixture (rolled back at end).
-- Exercises the new explanation ledger fields with real values, independent of
-- the (no-denial) Phase 3A fixture. Synthetic practice; CO-45 / CO-97 are
-- synthetic CARC placeholders.
-- ---------------------------------------------------------------------------
INSERT INTO fte_practices (id, name, external_ref) VALUES
  ('e5000000-0000-4000-8000-0000000000fe', 'Explain Ledger Fields Test Practice', 'SYN-EXP-PRACTICE');

INSERT INTO fte_evidence
  (id, practice_id, evidence_type, fixture_id, source_uri, page_number, metadata)
VALUES
  ('e5e00000-0000-4000-8000-00000000000a','e5000000-0000-4000-8000-0000000000fe',
   'ocr_text','SYN_EXP_PAGE_TEXT','private://fte/de-identified/SYN_EXP/page_001',1,'{}'::jsonb);

INSERT INTO fte_denial_knowledge (id, practice_id, carc_code, rarc_code, payer_name, recoverable) VALUES
  ('e5d00000-0000-4000-8000-000000000001', NULL, 'CO-45', NULL, NULL, true),
  ('e5d00000-0000-4000-8000-000000000002', NULL, 'CO-97', NULL, NULL, false);

-- Task 019B: appeal-window knowledge rows. Independent CARC codes (AW-*) keep
-- this overlay decoupled from the CO-45/CO-97 recoverable-overlay rows above --
-- per-task instruction, appeal-window matching must not share or couple to the
-- recoverable overlay's resolution. AW-NULLCARC matches on scope but carries a
-- NULL appeal_window_days (tests the "matched row, no window" unknown case).
-- No row exists for 'AW-NOMATCH-CARC' (tests the "no matching row at all" case).
INSERT INTO fte_denial_knowledge (id, practice_id, carc_code, rarc_code, payer_name, recoverable, appeal_window_days) VALUES
  ('e5d00000-0000-4000-8000-000000000003', NULL, 'AW-30', NULL, NULL, false, 30),
  ('e5d00000-0000-4000-8000-000000000004', NULL, 'AW-45', NULL, NULL, false, 45),
  ('e5d00000-0000-4000-8000-000000000005', NULL, 'AW-NULLCARC', NULL, NULL, false, NULL);

INSERT INTO fte_claims (id, practice_id, internal_claim_id, claim_number, payer_name, status) VALUES
  ('e5c00000-0000-4000-8000-00000000000a','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-REC','SYN-EXP-REC','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-00000000000b','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-MIXED','SYN-EXP-MIXED','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-00000000000c','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-LIFE','SYN-EXP-LIFE','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-00000000000d','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AOU','SYN-EXP-AOU','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-00000000000e','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AOD','SYN-EXP-AOD','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-00000000000f','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AOP','SYN-EXP-AOP','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-000000000010','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AWOPEN','SYN-EXP-AWOPEN','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-000000000011','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AWEXP','SYN-EXP-AWEXP','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-000000000012','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AWNOMATCH','SYN-EXP-AWNOMATCH','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-000000000013','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AWNULLWIN','SYN-EXP-AWNULLWIN','Synthetic Payer','open'),
  ('e5c00000-0000-4000-8000-000000000014','e5000000-0000-4000-8000-0000000000fe','SYN-EXP-AWMULTI','SYN-EXP-AWMULTI','Synthetic Payer','open');

-- Column-explicit INSERT ... SELECT: invariant columns (practice_id,
-- evidence_id, payer_name, confidence_score, page_number, flags, metadata) are
-- set ONCE as constants; per-row tuples carry only the varying fields, so
-- practice_id/evidence_id can't be positionally miswritten.
INSERT INTO fte_observations
  (practice_id, evidence_id, payer_name, confidence_score, page_number,
   is_summary_row, is_superseded, metadata,
   id, observation_type, amount, amount_type, claim_identifier,
   check_eft_identifier, carc_code, rarc_code, raw_value, normalized_value)
SELECT
  'e5000000-0000-4000-8000-0000000000fe'::uuid,
  'e5e00000-0000-4000-8000-00000000000a'::uuid,
  'Synthetic Payer', 0.9000, 1,
  false, false, '{}'::jsonb,
  v.id, v.observation_type, v.amount, v.amount_type, v.claim_identifier,
  v.check_eft_identifier, v.carc_code, v.rarc_code, v.raw_value, v.normalized_value
FROM (VALUES
  -- id, observation_type, amount, amount_type, claim_identifier, check_eft_identifier, carc_code, rarc_code, raw_value, normalized_value
  -- REC: billed 100, denial 100 CO-45 (recoverable) -> denied 100, recoverable 100, nonrecoverable 0.
  ('e5b00000-0000-4000-8000-000000000001'::uuid, 'billed_amount'::text, 100.00::numeric, 'billed'::text, 'SYN-EXP-REC'::text, NULL::text, NULL::text, NULL::text, '100.00'::text, '100.00'::text),
  ('e5b00000-0000-4000-8000-000000000002', 'denial', 100.00, 'denied', 'SYN-EXP-REC', NULL, 'CO-45', NULL, '100.00', '100.00'),
  -- MIXED: billed 100, denial 60 CO-45 (rec) + denial 40 CO-97 (non-rec) -> denied 100, recoverable 60, nonrecoverable 40.
  ('e5b00000-0000-4000-8000-000000000003', 'billed_amount', 100.00, 'billed', 'SYN-EXP-MIXED', NULL, NULL, NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-000000000004', 'denial', 60.00, 'denied', 'SYN-EXP-MIXED', NULL, 'CO-45', NULL, '60.00', '60.00'),
  ('e5b00000-0000-4000-8000-000000000005', 'denial', 40.00, 'denied', 'SYN-EXP-MIXED', NULL, 'CO-97', NULL, '40.00', '40.00'),
  -- LIFE (Task 017D): billed 100, denial 100 CO-45 (recoverable). The lifecycle
  -- resolutions below recover 60 + write off 40 -> net denied 0, gross_denied 100,
  -- recovered 60, written_off 40, remaining_recoverable 40 (recoverable 100 - 60).
  ('e5b00000-0000-4000-8000-000000000006', 'billed_amount', 100.00, 'billed', 'SYN-EXP-LIFE', NULL, NULL, NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-000000000007', 'denial', 100.00, 'denied', 'SYN-EXP-LIFE', NULL, 'CO-45', NULL, '100.00', '100.00'),
  -- AOU/AOD/AOP (Task 018D): billed 100 + denial 100 each; appeal filed and an
  -- outcome recorded (upheld / denied / partial respectively). Reporting-only:
  -- accounting stays denied 100 / open_balance 0.
  ('e5b00000-0000-4000-8000-000000000008', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AOU', NULL, NULL, NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-000000000009', 'denial', 100.00, 'denied', 'SYN-EXP-AOU', NULL, 'CO-45', NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-00000000000a', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AOD', NULL, NULL, NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-00000000000b', 'denial', 100.00, 'denied', 'SYN-EXP-AOD', NULL, 'CO-45', NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-00000000000c', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AOP', NULL, NULL, NULL, '100.00', '100.00'),
  ('e5b00000-0000-4000-8000-00000000000d', 'denial', 100.00, 'denied', 'SYN-EXP-AOP', NULL, 'CO-45', NULL, '100.00', '100.00')
) AS v(id, observation_type, amount, amount_type, claim_identifier, check_eft_identifier, carc_code, rarc_code, raw_value, normalized_value);

-- Task 019B: appeal-window/deadline observations. Separate INSERT (own column
-- list including service_date, which Phase 5e copies onto denial_posted.event_date)
-- so the shared VALUES block above is untouched. CURRENT_DATE-relative offsets
-- keep the open/expired assertions stable indefinitely regardless of run date.
INSERT INTO fte_observations
  (practice_id, evidence_id, payer_name, confidence_score, page_number,
   is_summary_row, is_superseded, metadata,
   id, observation_type, amount, amount_type, claim_identifier,
   carc_code, service_date)
SELECT
  'e5000000-0000-4000-8000-0000000000fe'::uuid,
  'e5e00000-0000-4000-8000-00000000000a'::uuid,
  'Synthetic Payer', 0.9000, 1,
  false, false, '{}'::jsonb,
  v.id, v.observation_type, v.amount, v.amount_type, v.claim_identifier,
  v.carc_code, v.service_date
FROM (VALUES
  -- AWOPEN: billed 100, denial 100 (AW-30, 30-day window). service_date =
  -- today-10d -> deadline = today+20d -> status open.
  ('e5b00000-0000-4000-8000-00000000000e'::uuid, 'billed_amount'::text, 100.00::numeric, 'billed'::text, 'SYN-EXP-AWOPEN'::text, NULL::text, NULL::date),
  ('e5b00000-0000-4000-8000-00000000000f', 'denial', 100.00, 'denied', 'SYN-EXP-AWOPEN', 'AW-30', (CURRENT_DATE - INTERVAL '10 days')::date),
  -- AWEXP: billed 100, denial 100 (AW-30, 30-day window). service_date =
  -- today-1000d -> deadline = today-970d -> status expired.
  ('e5b00000-0000-4000-8000-000000000010', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AWEXP', NULL, NULL),
  ('e5b00000-0000-4000-8000-000000000011', 'denial', 100.00, 'denied', 'SYN-EXP-AWEXP', 'AW-30', (CURRENT_DATE - INTERVAL '1000 days')::date),
  -- AWNOMATCH: billed 100, denial 100 with a CARC that has NO fte_denial_knowledge
  -- row at all -> unknown.
  ('e5b00000-0000-4000-8000-000000000012', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AWNOMATCH', NULL, NULL),
  ('e5b00000-0000-4000-8000-000000000013', 'denial', 100.00, 'denied', 'SYN-EXP-AWNOMATCH', 'AW-NOMATCH-CARC', (CURRENT_DATE - INTERVAL '10 days')::date),
  -- AWNULLWIN: billed 100, denial 100 with CARC AW-NULLCARC, which matches on
  -- scope but has appeal_window_days IS NULL -> unknown (not a 0-day window).
  ('e5b00000-0000-4000-8000-000000000014', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AWNULLWIN', NULL, NULL),
  ('e5b00000-0000-4000-8000-000000000015', 'denial', 100.00, 'denied', 'SYN-EXP-AWNULLWIN', 'AW-NULLCARC', (CURRENT_DATE - INTERVAL '10 days')::date),
  -- AWMULTI: two denials. AW-30 event (service_date today-5d -> deadline today+25d)
  -- and AW-45 event (service_date today-40d -> deadline today+5d). The earlier
  -- deadline (today+5d, window 45) must be the one surfaced at claim level.
  ('e5b00000-0000-4000-8000-000000000016', 'billed_amount', 100.00, 'billed', 'SYN-EXP-AWMULTI', NULL, NULL),
  ('e5b00000-0000-4000-8000-000000000017', 'denial', 60.00, 'denied', 'SYN-EXP-AWMULTI', 'AW-30', (CURRENT_DATE - INTERVAL '5 days')::date),
  ('e5b00000-0000-4000-8000-000000000018', 'denial', 40.00, 'denied', 'SYN-EXP-AWMULTI', 'AW-45', (CURRENT_DATE - INTERVAL '40 days')::date)
) AS v(id, observation_type, amount, amount_type, claim_identifier, carc_code, service_date);

-- Appeal-outcome resolutions (Task 018D): each AO claim files an appeal and
-- records one outcome. SYN-EXP-LIFE keeps its appeal WITHOUT an outcome (null case).
INSERT INTO fte_review_resolutions
  (practice_id, claim_id, action, target_type, appeal_outcome, resolved_by, resolved_at)
VALUES
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000d','file_appeal','claim',NULL,'test_runner','2026-07-05 08:00:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000d','record_appeal_outcome','claim','upheld','test_runner','2026-07-05 08:01:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000e','file_appeal','claim',NULL,'test_runner','2026-07-05 08:00:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000e','record_appeal_outcome','claim','denied','test_runner','2026-07-05 08:01:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000f','file_appeal','claim',NULL,'test_runner','2026-07-05 08:00:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000f','record_appeal_outcome','claim','partial','test_runner','2026-07-05 08:01:00+00');

-- Lifecycle resolutions for SYN-EXP-LIFE (Task 017D): appeal (reporting-only) +
-- recovery 60 + write-off 40 consume the 100 denied pool exactly. Explicit
-- distinct resolved_at makes the cumulative-cap processing order deterministic.
INSERT INTO fte_review_resolutions
  (practice_id, claim_id, action, target_type, lifecycle_amount, resolved_by, resolved_at)
VALUES
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000c','file_appeal','claim',NULL,'test_runner','2026-07-05 09:00:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000c','record_recovery','claim',60.00,'test_runner','2026-07-05 09:01:00+00'),
  ('e5000000-0000-4000-8000-0000000000fe','e5c00000-0000-4000-8000-00000000000c','approve_write_off','claim',40.00,'test_runner','2026-07-05 09:02:00+00');

DO $$
DECLARE
  v_practice_id  uuid := 'a3000000-0000-4000-8000-0000000000fe';
  v_claim_0001   uuid := 'c3a00000-0000-4000-8000-000000000001';
  v_claim_0003   uuid := 'c3a00000-0000-4000-8000-000000000003';

  v_result_0001  jsonb;
  v_result_0003  jsonb;

  v_count        bigint;
  v_text         text;
  v_bool         boolean;
BEGIN

  -- =========================================================================
  -- CHECK 1: fte_explain_claim exists in pg_proc
  -- =========================================================================
  SELECT COUNT(*) INTO v_count
  FROM   pg_proc p
  JOIN   pg_namespace n ON n.oid = p.pronamespace
  WHERE  p.proname = 'fte_explain_claim'
    AND  n.nspname = 'public';

  IF v_count = 0 THEN
    RAISE EXCEPTION 'FAIL [1/42] fte_explain_claim not found in pg_proc';
  END IF;
  RAISE NOTICE 'PASS [1/42] fte_explain_claim exists in pg_proc';


  -- =========================================================================
  -- Setup: materialize positions by running the reconciler.
  -- =========================================================================
  PERFORM fte_reconcile_practice(v_practice_id);


  -- =========================================================================
  -- CHECK 2: returns jsonb without exception for CLM-P3A-0001
  -- =========================================================================
  BEGIN
    v_result_0001 := fte_explain_claim(v_practice_id, v_claim_0001);
    IF v_result_0001 IS NULL THEN
      RAISE EXCEPTION 'FAIL [2/42] fte_explain_claim returned NULL for CLM-P3A-0001';
    END IF;
  EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION 'FAIL [2/42] fte_explain_claim raised exception for CLM-P3A-0001: %', SQLERRM;
  END;
  RAISE NOTICE 'PASS [2/42] fte_explain_claim returns jsonb for CLM-P3A-0001';


  -- =========================================================================
  -- CHECK 3: CLM-P3A-0001 claim_number = 'CLM-P3A-0001'
  -- =========================================================================
  IF v_result_0001->>'claim_number' <> 'CLM-P3A-0001' THEN
    RAISE EXCEPTION 'FAIL [3/42] expected claim_number=CLM-P3A-0001, got %',
      v_result_0001->>'claim_number';
  END IF;
  RAISE NOTICE 'PASS [3/42] CLM-P3A-0001 claim_number correct';


  -- =========================================================================
  -- CHECK 4: CLM-P3A-0001 reconciliation_status = 'balanced'
  -- =========================================================================
  IF v_result_0001->>'reconciliation_status' <> 'balanced' THEN
    RAISE EXCEPTION 'FAIL [4/42] expected reconciliation_status=balanced, got %',
      v_result_0001->>'reconciliation_status';
  END IF;
  RAISE NOTICE 'PASS [4/42] CLM-P3A-0001 reconciliation_status = balanced';


  -- =========================================================================
  -- CHECK 5: CLM-P3A-0001 open_balance_amount = '0.00'
  -- =========================================================================
  IF v_result_0001->>'open_balance_amount' <> '0.00' THEN
    RAISE EXCEPTION 'FAIL [5/42] expected open_balance_amount=0.00, got %',
      v_result_0001->>'open_balance_amount';
  END IF;
  RAISE NOTICE 'PASS [5/42] CLM-P3A-0001 open_balance_amount = 0.00';


  -- =========================================================================
  -- CHECK 6: CLM-P3A-0001 summary contains 'balanced'
  -- =========================================================================
  v_text := v_result_0001->>'summary';
  IF v_text NOT LIKE '%balanced%' THEN
    RAISE EXCEPTION 'FAIL [6/42] summary does not contain ''balanced'': %', v_text;
  END IF;
  RAISE NOTICE 'PASS [6/42] CLM-P3A-0001 summary contains ''balanced''';


  -- =========================================================================
  -- CHECK 7: CLM-P3A-0001 events array length = 3
  -- (claim_adjudicated + contractual_adjustment_applied + payment_applied)
  -- =========================================================================
  v_count := jsonb_array_length(v_result_0001->'events');
  IF v_count <> 3 THEN
    RAISE EXCEPTION 'FAIL [7/42] expected events length=3, got %', v_count;
  END IF;
  RAISE NOTICE 'PASS [7/42] CLM-P3A-0001 events array length = 3';


  -- =========================================================================
  -- CHECK 8: CLM-P3A-0001 evidence array length = 2
  -- (page evidence from observation + check_payment stub from two-link)
  -- =========================================================================
  v_count := jsonb_array_length(v_result_0001->'evidence');
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'FAIL [8/42] expected evidence length=2, got %', v_count;
  END IF;
  RAISE NOTICE 'PASS [8/42] CLM-P3A-0001 evidence array length = 2';


  -- =========================================================================
  -- Fetch CLM-P3A-0003 result
  -- =========================================================================
  v_result_0003 := fte_explain_claim(v_practice_id, v_claim_0003);
  IF v_result_0003 IS NULL THEN
    RAISE EXCEPTION 'FAIL fte_explain_claim returned NULL for CLM-P3A-0003';
  END IF;


  -- =========================================================================
  -- CHECK 9: CLM-P3A-0003 reconciliation_status = 'unbalanced'
  -- =========================================================================
  IF v_result_0003->>'reconciliation_status' <> 'unbalanced' THEN
    RAISE EXCEPTION 'FAIL [9/42] expected reconciliation_status=unbalanced, got %',
      v_result_0003->>'reconciliation_status';
  END IF;
  RAISE NOTICE 'PASS [9/42] CLM-P3A-0003 reconciliation_status = unbalanced';


  -- =========================================================================
  -- CHECK 10: CLM-P3A-0003 open_balance_amount = '180.00'
  -- =========================================================================
  IF v_result_0003->>'open_balance_amount' <> '180.00' THEN
    RAISE EXCEPTION 'FAIL [10/42] expected open_balance_amount=180.00, got %',
      v_result_0003->>'open_balance_amount';
  END IF;
  RAISE NOTICE 'PASS [10/42] CLM-P3A-0003 open_balance_amount = 180.00';


  -- =========================================================================
  -- CHECK 11: CLM-P3A-0003 summary contains '180.00'
  -- =========================================================================
  v_text := v_result_0003->>'summary';
  IF v_text NOT LIKE '%180.00%' THEN
    RAISE EXCEPTION 'FAIL [11/42] summary does not contain ''180.00'': %', v_text;
  END IF;
  RAISE NOTICE 'PASS [11/42] CLM-P3A-0003 summary contains ''180.00''';


  -- =========================================================================
  -- CHECK 12: CLM-P3A-0003 review_queue length = 1 and
  --           reason = 'unbalanced_financial_position'
  -- =========================================================================
  v_count := jsonb_array_length(v_result_0003->'review_queue');
  IF v_count <> 1 THEN
    RAISE EXCEPTION 'FAIL [12/42] expected review_queue length=1, got %', v_count;
  END IF;
  v_text := v_result_0003->'review_queue'->0->>'reason';
  IF v_text <> 'unbalanced_financial_position' THEN
    RAISE EXCEPTION 'FAIL [12/42] expected reason=unbalanced_financial_position, got %', v_text;
  END IF;
  RAISE NOTICE 'PASS [12/42] CLM-P3A-0003 review_queue length=1 and reason correct';


  -- =========================================================================
  -- CHECK 13: CLM-P3A-0001 payment_applied event has evidence_count = 2
  -- (page observation link + check_payment stub link)
  -- =========================================================================
  SELECT (e->>'evidence_count')::bigint INTO v_count
  FROM   jsonb_array_elements(v_result_0001->'events') AS e
  WHERE  e->>'event_type' = 'payment_applied'
  LIMIT 1;

  IF v_count IS NULL THEN
    RAISE EXCEPTION 'FAIL [13/42] payment_applied event not found in CLM-P3A-0001 events';
  END IF;
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'FAIL [13/42] expected payment_applied evidence_count=2, got %', v_count;
  END IF;
  RAISE NOTICE 'PASS [13/42] CLM-P3A-0001 payment_applied evidence_count = 2';


  -- =========================================================================
  -- CHECK 14: all non-null raw_text_snippet values in both outputs have length <= 500
  -- =========================================================================
  SELECT COUNT(*) INTO v_count
  FROM (
    SELECT e->>'raw_text_snippet' AS snippet
    FROM   jsonb_array_elements(v_result_0001->'evidence') AS e
    UNION ALL
    SELECT e->>'raw_text_snippet' AS snippet
    FROM   jsonb_array_elements(v_result_0003->'evidence') AS e
  ) snippets
  WHERE snippet IS NOT NULL
    AND length(snippet) > 500;

  IF v_count > 0 THEN
    RAISE EXCEPTION 'FAIL [14/42] % raw_text_snippet value(s) exceed 500 chars', v_count;
  END IF;
  RAISE NOTICE 'PASS [14/42] all non-null raw_text_snippet values have length <= 500';

END;
$$;


-- ===========================================================================
-- Task 014E2: new ledger-field surfacing (denied / recoverable / etc.).
-- Reconciles the self-contained SYN-EXP practice and asserts the extended
-- explanation output. No persistent 006L/009C reconcile.
-- ===========================================================================
DO $$
DECLARE
  v_exp_practice uuid := 'e5000000-0000-4000-8000-0000000000fe';
  v_rec          jsonb;
  v_mixed        jsonb;
  v_p3a          jsonb;
BEGIN
  PERFORM fte_reconcile_practice(v_exp_practice);

  v_rec   := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000a');
  v_mixed := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000b');
  v_p3a   := fte_explain_claim('a3000000-0000-4000-8000-0000000000fe', 'c3a00000-0000-4000-8000-000000000001');

  -- CHECK 15: no-denial claim surfaces denied/recoverable/nonrecoverable as JSON null.
  IF NOT (v_p3a->>'denied_amount' IS NULL
          AND v_p3a->>'recoverable_amount' IS NULL
          AND v_p3a->>'nonrecoverable_denied_amount' IS NULL) THEN
    RAISE EXCEPTION 'FAIL [15/42] no-denial claim expected null denial fields, got denied=% recoverable=% nonrec=%',
      v_p3a->>'denied_amount', v_p3a->>'recoverable_amount', v_p3a->>'nonrecoverable_denied_amount';
  END IF;
  RAISE NOTICE 'PASS [15/42] no-denial claim: denied/recoverable/nonrecoverable are null';

  -- CHECK 16: E2/denial ledger keys are present (surfaced) in the explanation.
  IF NOT (v_p3a ? 'allowed_amount' AND v_p3a ? 'patient_responsibility_amount'
          AND v_p3a ? 'denied_amount' AND v_p3a ? 'recoverable_amount'
          AND v_p3a ? 'nonrecoverable_denied_amount') THEN
    RAISE EXCEPTION 'FAIL [16/42] explanation missing one or more new ledger keys';
  END IF;
  RAISE NOTICE 'PASS [16/42] explanation surfaces allowed/patient_responsibility/denied/recoverable keys';

  -- CHECK 17: REC claim surfaces denied_amount.
  IF v_rec->>'denied_amount' <> '100.00' THEN
    RAISE EXCEPTION 'FAIL [17/42] REC denied_amount expected 100.00, got %', v_rec->>'denied_amount';
  END IF;
  RAISE NOTICE 'PASS [17/42] REC denied_amount surfaced';

  -- CHECK 18: REC recoverable_amount + derived nonrecoverable_denied_amount.
  IF NOT (v_rec->>'recoverable_amount' = '100.00' AND v_rec->>'nonrecoverable_denied_amount' = '0.00') THEN
    RAISE EXCEPTION 'FAIL [18/42] REC recoverable=100.00/nonrecoverable=0.00 expected, got rec=% nonrec=%',
      v_rec->>'recoverable_amount', v_rec->>'nonrecoverable_denied_amount';
  END IF;
  RAISE NOTICE 'PASS [18/42] REC recoverable + derived nonrecoverable correct';

  -- CHECK 19: MIXED claim aggregates recoverable subset; nonrecoverable is the remainder.
  IF NOT (v_mixed->>'denied_amount' = '100.00'
          AND v_mixed->>'recoverable_amount' = '60.00'
          AND v_mixed->>'nonrecoverable_denied_amount' = '40.00') THEN
    RAISE EXCEPTION 'FAIL [19/42] MIXED expected denied=100.00 recoverable=60.00 nonrec=40.00, got %/%/%',
      v_mixed->>'denied_amount', v_mixed->>'recoverable_amount', v_mixed->>'nonrecoverable_denied_amount';
  END IF;
  RAISE NOTICE 'PASS [19/42] MIXED denied/recoverable/nonrecoverable split correct';

  -- CHECK 20: recoverable overlay does not change accounting (open_balance / status).
  IF NOT (v_rec->>'open_balance_amount' = '0.00' AND v_rec->>'reconciliation_status' = 'balanced') THEN
    RAISE EXCEPTION 'FAIL [20/42] REC accounting changed by overlay: open=% status=%',
      v_rec->>'open_balance_amount', v_rec->>'reconciliation_status';
  END IF;
  RAISE NOTICE 'PASS [20/42] recoverable overlay leaves open_balance/status unchanged';

END;
$$;


-- ===========================================================================
-- Task 017D: denial-lifecycle explain surfacing (SYN-EXP-LIFE).
-- billed 100, denial 100 CO-45, then appeal + recovery 60 + write-off 40.
-- Expected: gross_denied 100, denied (net) 0, recovered 60, written_off 40,
-- remaining_recoverable 40, appeal marker true, counts 1/1/1, open_balance 0.
-- ===========================================================================
DO $$
DECLARE
  v_exp_practice uuid := 'e5000000-0000-4000-8000-0000000000fe';
  v_life         jsonb;
  v_counts       jsonb;
BEGIN
  PERFORM fte_reconcile_practice(v_exp_practice);
  v_life := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000c');

  IF v_life IS NULL THEN
    RAISE EXCEPTION 'FAIL [21/42] fte_explain_claim returned NULL for SYN-EXP-LIFE';
  END IF;

  -- CHECK 21: gross_denied_amount derived from denial_posted event history.
  IF v_life->>'gross_denied_amount' <> '100.00' THEN
    RAISE EXCEPTION 'FAIL [21/42] gross_denied_amount expected 100.00, got %', v_life->>'gross_denied_amount';
  END IF;
  RAISE NOTICE 'PASS [21/42] gross_denied_amount surfaced from denial_posted history (100.00)';

  -- CHECK 22: denied_amount is NET after recovery + write-off (documents net semantics).
  IF v_life->>'denied_amount' <> '0.00' THEN
    RAISE EXCEPTION 'FAIL [22/42] net denied_amount expected 0.00, got %', v_life->>'denied_amount';
  END IF;
  RAISE NOTICE 'PASS [22/42] denied_amount is net after recovery/write-off (0.00) alongside gross 100.00';

  -- CHECK 23: recovered_amount / written_off_amount surfaced from the position.
  IF NOT (v_life->>'recovered_amount' = '60.00' AND v_life->>'written_off_amount' = '40.00') THEN
    RAISE EXCEPTION 'FAIL [23/42] expected recovered=60.00 written_off=40.00, got %/%',
      v_life->>'recovered_amount', v_life->>'written_off_amount';
  END IF;
  RAISE NOTICE 'PASS [23/42] recovered_amount=60.00 and written_off_amount=40.00 surfaced';

  -- CHECK 24: remaining_recoverable_amount = recoverable(100) - recovered(60), non-negative.
  IF v_life->>'remaining_recoverable_amount' <> '40.00' THEN
    RAISE EXCEPTION 'FAIL [24/42] remaining_recoverable_amount expected 40.00, got %',
      v_life->>'remaining_recoverable_amount';
  END IF;
  RAISE NOTICE 'PASS [24/42] remaining_recoverable_amount=40.00 (recoverable 100 - recovered 60), non-negative';

  -- CHECK 25: appeal marker true; lifecycle_event_counts = appeal/recovery/write_off 1/1/1.
  v_counts := v_life->'lifecycle_event_counts';
  IF NOT ((v_life->>'appeal_filed')::boolean
          AND (v_counts->>'appeal_filed')::int = 1
          AND (v_counts->>'recovery_received')::int = 1
          AND (v_counts->>'write_off_approved')::int = 1) THEN
    RAISE EXCEPTION 'FAIL [25/42] appeal/lifecycle counts wrong: appeal_filed=% counts=%',
      v_life->>'appeal_filed', v_counts;
  END IF;
  RAISE NOTICE 'PASS [25/42] appeal_filed marker true; lifecycle_event_counts appeal/recovery/write_off = 1/1/1';

  -- CHECK 26: lifecycle is reporting-only (open_balance/status unchanged) AND all
  -- pre-017D output keys are preserved (backward compatibility).
  IF NOT (v_life->>'open_balance_amount' = '0.00' AND v_life->>'reconciliation_status' = 'balanced') THEN
    RAISE EXCEPTION 'FAIL [26/42] lifecycle changed accounting: open=% status=%',
      v_life->>'open_balance_amount', v_life->>'reconciliation_status';
  END IF;
  IF NOT (v_life ? 'billed_amount' AND v_life ? 'allowed_amount'
          AND v_life ? 'contractual_adjustment_amount' AND v_life ? 'paid_amount'
          AND v_life ? 'patient_responsibility_amount' AND v_life ? 'denied_amount'
          AND v_life ? 'recoverable_amount' AND v_life ? 'nonrecoverable_denied_amount'
          AND v_life ? 'open_balance_amount' AND v_life ? 'summary'
          AND v_life ? 'events' AND v_life ? 'evidence' AND v_life ? 'review_queue') THEN
    RAISE EXCEPTION 'FAIL [26/42] a pre-017D output key is missing (backward compatibility broken)';
  END IF;
  RAISE NOTICE 'PASS [26/42] lifecycle reporting-only: open_balance/status unchanged; all prior keys preserved';

END;
$$;


-- ===========================================================================
-- Task 018D: appeal-outcome explain surfacing.
-- AOU/AOD/AOP: appeal filed + outcome recorded (upheld/denied/partial).
-- LIFE: appeal filed, NO outcome -> appeal_outcome null.
-- Reporting-only: accounting fields unchanged by outcomes.
-- ===========================================================================
DO $$
DECLARE
  v_exp_practice uuid := 'e5000000-0000-4000-8000-0000000000fe';
  v_aou  jsonb;
  v_aod  jsonb;
  v_aop  jsonb;
  v_life jsonb;
BEGIN
  -- Positions already materialized by the earlier PERFORM fte_reconcile_practice
  -- call for this practice; a fresh call keeps this block self-sufficient.
  PERFORM fte_reconcile_practice(v_exp_practice);

  v_aou  := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000d');
  v_aod  := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000e');
  v_aop  := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000f');
  v_life := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000c');

  -- CHECK 27: upheld outcome surfaced.
  IF v_aou->>'appeal_outcome' <> 'upheld' THEN
    RAISE EXCEPTION 'FAIL [27/42] AOU appeal_outcome expected upheld, got %', v_aou->>'appeal_outcome';
  END IF;
  RAISE NOTICE 'PASS [27/42] upheld appeal outcome surfaced';

  -- CHECK 28: denied outcome surfaced.
  IF v_aod->>'appeal_outcome' <> 'denied' THEN
    RAISE EXCEPTION 'FAIL [28/42] AOD appeal_outcome expected denied, got %', v_aod->>'appeal_outcome';
  END IF;
  RAISE NOTICE 'PASS [28/42] denied appeal outcome surfaced';

  -- CHECK 29: partial outcome surfaced.
  IF v_aop->>'appeal_outcome' <> 'partial' THEN
    RAISE EXCEPTION 'FAIL [29/42] AOP appeal_outcome expected partial, got %', v_aop->>'appeal_outcome';
  END IF;
  RAISE NOTICE 'PASS [29/42] partial appeal outcome surfaced';

  -- CHECK 30: no recorded outcome -> appeal_outcome is JSON null (key present).
  IF NOT (v_life ? 'appeal_outcome') OR v_life->>'appeal_outcome' IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL [30/42] LIFE appeal_outcome expected null (key present), got %', v_life->>'appeal_outcome';
  END IF;
  RAISE NOTICE 'PASS [30/42] claim without a recorded outcome returns appeal_outcome null';

  -- CHECK 31: prior lifecycle explain fields still present (017D keys).
  IF NOT (v_aou ? 'gross_denied_amount' AND v_aou ? 'recovered_amount'
          AND v_aou ? 'written_off_amount' AND v_aou ? 'remaining_recoverable_amount'
          AND v_aou ? 'appeal_filed' AND v_aou ? 'lifecycle_event_counts') THEN
    RAISE EXCEPTION 'FAIL [31/42] a prior lifecycle explain key is missing on AOU';
  END IF;
  IF NOT ((v_aou->>'appeal_filed')::boolean) THEN
    RAISE EXCEPTION 'FAIL [31/42] AOU appeal_filed marker expected true';
  END IF;
  RAISE NOTICE 'PASS [31/42] prior lifecycle explain fields still present (appeal_filed true on AOU)';

  -- CHECK 32: reporting-only — accounting fields unchanged by the outcome
  -- (denied 100, open_balance 0, no recovery/write-off, status balanced).
  IF NOT (v_aou->>'denied_amount' = '100.00'
          AND v_aou->>'open_balance_amount' = '0.00'
          AND v_aou->>'recovered_amount' IS NULL
          AND v_aou->>'written_off_amount' IS NULL
          AND v_aou->>'reconciliation_status' = 'balanced') THEN
    RAISE EXCEPTION 'FAIL [32/42] AOU accounting changed by outcome: denied=% open=% rec=% wo=% status=%',
      v_aou->>'denied_amount', v_aou->>'open_balance_amount',
      v_aou->>'recovered_amount', v_aou->>'written_off_amount', v_aou->>'reconciliation_status';
  END IF;
  RAISE NOTICE 'PASS [32/42] appeal outcome is reporting-only: accounting fields unchanged';

END;
$$;


-- ===========================================================================
-- Task 019B: appeal window / deadline explain surfacing.
-- AWOPEN/AWEXP: single denial, resolved window, open vs expired.
-- AWNOMATCH/AWNULLWIN: two distinct "no usable window" shapes -> unknown.
-- AWMULTI: two denials with different windows -> earliest deadline wins.
-- Also proves prior appeal_outcome / lifecycle keys and accounting are
-- untouched by this reporting-only overlay.
-- ===========================================================================
DO $$
DECLARE
  v_exp_practice uuid := 'e5000000-0000-4000-8000-0000000000fe';
  v_awopen     jsonb;
  v_awexp      jsonb;
  v_awnomatch  jsonb;
  v_awnullwin  jsonb;
  v_awmulti    jsonb;
  v_aou        jsonb;
  v_life       jsonb;
BEGIN
  PERFORM fte_reconcile_practice(v_exp_practice);

  v_awopen    := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-000000000010');
  v_awexp     := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-000000000011');
  v_awnomatch := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-000000000012');
  v_awnullwin := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-000000000013');
  v_awmulti   := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-000000000014');
  v_aou       := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000d');
  v_life      := fte_explain_claim(v_exp_practice, 'e5c00000-0000-4000-8000-00000000000c');

  -- CHECK 33: AWOPEN appeal_window_days surfaces from the matching AW-30 row.
  IF (v_awopen->>'appeal_window_days')::int <> 30 THEN
    RAISE EXCEPTION 'FAIL [33/42] AWOPEN appeal_window_days expected 30, got %', v_awopen->>'appeal_window_days';
  END IF;
  RAISE NOTICE 'PASS [33/42] AWOPEN appeal_window_days surfaces from matching denial knowledge (30)';

  -- CHECK 34: AWOPEN appeal_deadline = denial_posted.event_date + window
  --           (service_date today-10d + 30 = today+20d).
  IF v_awopen->>'appeal_deadline' <> to_char(CURRENT_DATE + INTERVAL '20 days', 'YYYY-MM-DD') THEN
    RAISE EXCEPTION 'FAIL [34/42] AWOPEN appeal_deadline expected %, got %',
      to_char(CURRENT_DATE + INTERVAL '20 days', 'YYYY-MM-DD'), v_awopen->>'appeal_deadline';
  END IF;
  RAISE NOTICE 'PASS [34/42] AWOPEN appeal_deadline = denial_posted.event_date + appeal_window_days';

  -- CHECK 35: AWOPEN appeal_deadline_status = open (deadline in the future).
  IF v_awopen->>'appeal_deadline_status' <> 'open' THEN
    RAISE EXCEPTION 'FAIL [35/42] AWOPEN appeal_deadline_status expected open, got %', v_awopen->>'appeal_deadline_status';
  END IF;
  RAISE NOTICE 'PASS [35/42] AWOPEN appeal_deadline_status = open';

  -- CHECK 36: AWEXP appeal_deadline_status = expired (service_date today-1000d
  -- + 30 = today-970d, well in the past).
  IF v_awexp->>'appeal_deadline_status' <> 'expired' THEN
    RAISE EXCEPTION 'FAIL [36/42] AWEXP appeal_deadline_status expected expired, got %', v_awexp->>'appeal_deadline_status';
  END IF;
  RAISE NOTICE 'PASS [36/42] AWEXP appeal_deadline_status = expired';

  -- CHECK 37: AWNOMATCH -> unknown; no fte_denial_knowledge row exists at all
  -- for CARC 'AW-NOMATCH-CARC'.
  IF NOT (v_awnomatch->>'appeal_window_days' IS NULL
          AND v_awnomatch->>'appeal_deadline' IS NULL
          AND v_awnomatch->>'appeal_deadline_status' = 'unknown') THEN
    RAISE EXCEPTION 'FAIL [37/42] AWNOMATCH expected null/null/unknown, got %/%/%',
      v_awnomatch->>'appeal_window_days', v_awnomatch->>'appeal_deadline', v_awnomatch->>'appeal_deadline_status';
  END IF;
  RAISE NOTICE 'PASS [37/42] AWNOMATCH -> unknown (no matching denial-knowledge row at all)';

  -- CHECK 38: AWNULLWIN -> unknown; the matching AW-NULLCARC row has
  -- appeal_window_days IS NULL, so it is excluded from the match entirely
  -- (not treated as a 0-day window).
  IF NOT (v_awnullwin->>'appeal_window_days' IS NULL
          AND v_awnullwin->>'appeal_deadline' IS NULL
          AND v_awnullwin->>'appeal_deadline_status' = 'unknown') THEN
    RAISE EXCEPTION 'FAIL [38/42] AWNULLWIN expected null/null/unknown, got %/%/%',
      v_awnullwin->>'appeal_window_days', v_awnullwin->>'appeal_deadline', v_awnullwin->>'appeal_deadline_status';
  END IF;
  RAISE NOTICE 'PASS [38/42] AWNULLWIN -> unknown (matching row has appeal_window_days NULL)';

  -- CHECK 39: AWMULTI selects the earliest non-null deadline across two
  -- denials: AW-30 (today-5d+30=today+25d) vs AW-45 (today-40d+45=today+5d).
  -- today+5d is earlier, so window=45 and that deadline must be surfaced.
  IF NOT ((v_awmulti->>'appeal_window_days')::int = 45
          AND v_awmulti->>'appeal_deadline' = to_char(CURRENT_DATE + INTERVAL '5 days', 'YYYY-MM-DD')
          AND v_awmulti->>'appeal_deadline_status' = 'open') THEN
    RAISE EXCEPTION 'FAIL [39/42] AWMULTI expected window=45 deadline=% status=open, got window=% deadline=% status=%',
      to_char(CURRENT_DATE + INTERVAL '5 days', 'YYYY-MM-DD'),
      v_awmulti->>'appeal_window_days', v_awmulti->>'appeal_deadline', v_awmulti->>'appeal_deadline_status';
  END IF;
  RAISE NOTICE 'PASS [39/42] AWMULTI earliest non-null deadline selected across two denials (window=45)';

  -- CHECK 40: prior appeal_outcome field (Task 018D) still preserved on AOU.
  IF v_aou->>'appeal_outcome' <> 'upheld' THEN
    RAISE EXCEPTION 'FAIL [40/42] AOU appeal_outcome expected upheld (still preserved), got %', v_aou->>'appeal_outcome';
  END IF;
  RAISE NOTICE 'PASS [40/42] prior appeal_outcome field still preserved (AOU still upheld)';

  -- CHECK 41: prior lifecycle explain fields (Task 017D) still preserved on LIFE.
  IF NOT (v_life->>'gross_denied_amount' = '100.00'
          AND v_life->>'denied_amount' = '0.00'
          AND v_life->>'recovered_amount' = '60.00'
          AND v_life->>'written_off_amount' = '40.00'
          AND v_life->>'remaining_recoverable_amount' = '40.00'
          AND (v_life->>'appeal_filed')::boolean) THEN
    RAISE EXCEPTION 'FAIL [41/42] a prior lifecycle explain value changed on LIFE';
  END IF;
  RAISE NOTICE 'PASS [41/42] prior lifecycle explain fields still preserved (LIFE unchanged)';

  -- CHECK 42: appeal window fields are reporting-only — accounting (denied /
  -- open_balance / status) on AWOPEN and AWEXP matches the plain
  -- billed=100/denial=100 shape, unaffected by window resolution or status.
  IF NOT (v_awopen->>'denied_amount' = '100.00' AND v_awopen->>'open_balance_amount' = '0.00'
          AND v_awopen->>'reconciliation_status' = 'balanced') THEN
    RAISE EXCEPTION 'FAIL [42/42] AWOPEN accounting changed: denied=% open=% status=%',
      v_awopen->>'denied_amount', v_awopen->>'open_balance_amount', v_awopen->>'reconciliation_status';
  END IF;
  IF NOT (v_awexp->>'denied_amount' = '100.00' AND v_awexp->>'open_balance_amount' = '0.00'
          AND v_awexp->>'reconciliation_status' = 'balanced') THEN
    RAISE EXCEPTION 'FAIL [42/42] AWEXP accounting changed: denied=% open=% status=%',
      v_awexp->>'denied_amount', v_awexp->>'open_balance_amount', v_awexp->>'reconciliation_status';
  END IF;
  RAISE NOTICE 'PASS [42/42] appeal window fields are reporting-only: accounting unchanged';

END;
$$;

ROLLBACK;
