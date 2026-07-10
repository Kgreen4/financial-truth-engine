-- =============================================================================
-- Financial Truth Engine — Appeal Outcome Reconciler Validation
-- tests/validate_reconciler_appeal_outcome.sql
--
-- Covers Task 018C (appeal-outcome reporting derivation): the reconciler reads
-- active record_appeal_outcome resolutions (migration 013) and, in Phase 5g,
-- derives the appeal disposition REPORTING-ONLY:
--   * a valid outcome (upheld/denied/partial) on a claim that has a prior
--     appeal_filed event is accepted with NO event / accounting / status effect
--     (the value is read from fte_review_resolutions by explain, Task 018D)
--   * an outcome with no prior appeal_filed routes to review non-destructively
--     (fte_review_queue, reason 'conflicting_observations', descriptor in details)
--   * conflicting active outcomes route to review the same way
--   * no auto-recovery, no auto-write-off, no status change
--
-- Self-contained: creates its own synthetic fixture INSIDE the transaction, calls
-- fte_reconcile_practice, asserts, then ROLLs BACK — nothing persists. All
-- identifiers/amounts synthetic. No PHI, no production data.
--
-- Depends on migrations 001..013 and reconciler/fte_reconcile.sql.
-- Emits RAISE NOTICE 'PASS [n/6] ...'; any failure RAISEs EXCEPTION and rolls back.
-- =============================================================================

begin;

-- ---- Synthetic fixture -------------------------------------------------------
INSERT INTO fte_practices (id, name, external_ref) VALUES
  ('e8000000-0000-4000-8000-0000000000fe', 'Appeal Outcome Test Practice', 'SYN-AO-PRACTICE');

INSERT INTO fte_evidence (id, practice_id, evidence_type, fixture_id, raw_text) VALUES
  ('e8e00000-0000-4000-8000-00000000000a', 'e8000000-0000-4000-8000-0000000000fe',
   'page', 'SYN-AO', '[SYNTHETIC] appeal outcome page');

INSERT INTO fte_claims (id, practice_id, internal_claim_id, claim_number, payer_name, status) VALUES
  ('e8c00000-0000-4000-8000-000000000001','e8000000-0000-4000-8000-0000000000fe','SYN-AO-UP','SYN-AO-UP','Synthetic Payer','open'),
  ('e8c00000-0000-4000-8000-000000000002','e8000000-0000-4000-8000-0000000000fe','SYN-AO-DN','SYN-AO-DN','Synthetic Payer','open'),
  ('e8c00000-0000-4000-8000-000000000003','e8000000-0000-4000-8000-0000000000fe','SYN-AO-PA','SYN-AO-PA','Synthetic Payer','open'),
  ('e8c00000-0000-4000-8000-000000000004','e8000000-0000-4000-8000-0000000000fe','SYN-AO-NOAPP','SYN-AO-NOAPP','Synthetic Payer','open'),
  ('e8c00000-0000-4000-8000-000000000005','e8000000-0000-4000-8000-0000000000fe','SYN-AO-CONFL','SYN-AO-CONFL','Synthetic Payer','open');

-- Each claim: billed 100 + denial 100 -> denied 100, open_balance 0, balanced.
-- Column-explicit INSERT ... SELECT (positional-drift-safe).
INSERT INTO fte_observations
  (practice_id, evidence_id, payer_name, confidence_score, page_number,
   is_summary_row, is_superseded, metadata,
   id, observation_type, amount, amount_type, claim_identifier)
SELECT
  'e8000000-0000-4000-8000-0000000000fe'::uuid,
  'e8e00000-0000-4000-8000-00000000000a'::uuid,
  'Synthetic Payer', 0.9000, 1,
  false, false, '{}'::jsonb,
  v.id, v.observation_type, v.amount, v.amount_type, v.claim_identifier
FROM (VALUES
  ('e8b00000-0000-4000-8000-000000000001'::uuid, 'billed_amount'::text, 100.00::numeric, 'billed'::text, 'SYN-AO-UP'::text),
  ('e8b00000-0000-4000-8000-000000000002', 'denial', 100.00, 'denied', 'SYN-AO-UP'),
  ('e8b00000-0000-4000-8000-000000000003', 'billed_amount', 100.00, 'billed', 'SYN-AO-DN'),
  ('e8b00000-0000-4000-8000-000000000004', 'denial', 100.00, 'denied', 'SYN-AO-DN'),
  ('e8b00000-0000-4000-8000-000000000005', 'billed_amount', 100.00, 'billed', 'SYN-AO-PA'),
  ('e8b00000-0000-4000-8000-000000000006', 'denial', 100.00, 'denied', 'SYN-AO-PA'),
  ('e8b00000-0000-4000-8000-000000000007', 'billed_amount', 100.00, 'billed', 'SYN-AO-NOAPP'),
  ('e8b00000-0000-4000-8000-000000000008', 'denial', 100.00, 'denied', 'SYN-AO-NOAPP'),
  ('e8b00000-0000-4000-8000-000000000009', 'billed_amount', 100.00, 'billed', 'SYN-AO-CONFL'),
  ('e8b00000-0000-4000-8000-00000000000a', 'denial', 100.00, 'denied', 'SYN-AO-CONFL')
) AS v(id, observation_type, amount, amount_type, claim_identifier);

-- Reviewer resolutions:
--   UP/DN/PA : file_appeal + a single record_appeal_outcome (valid)
--   NOAPP    : record_appeal_outcome only, NO file_appeal (anomaly)
--   CONFL    : file_appeal + two conflicting outcomes (anomaly)
INSERT INTO fte_review_resolutions
  (practice_id, claim_id, action, target_type, appeal_outcome, resolved_by, resolved_at)
VALUES
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000001','file_appeal','claim',NULL,'test_runner','2026-07-05 09:00:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000001','record_appeal_outcome','claim','upheld','test_runner','2026-07-05 09:01:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000002','file_appeal','claim',NULL,'test_runner','2026-07-05 09:00:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000002','record_appeal_outcome','claim','denied','test_runner','2026-07-05 09:01:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000003','file_appeal','claim',NULL,'test_runner','2026-07-05 09:00:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000003','record_appeal_outcome','claim','partial','test_runner','2026-07-05 09:01:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000004','record_appeal_outcome','claim','upheld','test_runner','2026-07-05 09:01:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000005','file_appeal','claim',NULL,'test_runner','2026-07-05 09:00:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000005','record_appeal_outcome','claim','upheld','test_runner','2026-07-05 09:01:00+00'),
  ('e8000000-0000-4000-8000-0000000000fe','e8c00000-0000-4000-8000-000000000005','record_appeal_outcome','claim','denied','test_runner','2026-07-05 09:02:00+00');

SELECT fte_reconcile_practice('e8000000-0000-4000-8000-0000000000fe');


-- Helper expressions used below:
--   appeal_filed present  : an appeal_filed event exists for the claim
--   ao_anomaly(claim,kind) : a conflicting_observations review row for the claim
--                            whose details.action = 'record_appeal_outcome' and
--                            details.anomaly = kind
DO $$
DECLARE
  v_prac uuid := 'e8000000-0000-4000-8000-0000000000fe';
  v_up   uuid := 'e8c00000-0000-4000-8000-000000000001';
  v_dn   uuid := 'e8c00000-0000-4000-8000-000000000002';
  v_pa   uuid := 'e8c00000-0000-4000-8000-000000000003';
  v_no   uuid := 'e8c00000-0000-4000-8000-000000000004';
  v_cf   uuid := 'e8c00000-0000-4000-8000-000000000005';
  v_val  text;
  v_appeal int;
  v_anom int;
  v_denied numeric; v_ob numeric; v_rec numeric; v_wo numeric;
BEGIN
  -- helper counts as inline subqueries per check.

  -- CHECK 1: valid upheld after appeal — outcome value set, appeal_filed present,
  --          and NO appeal-outcome anomaly.
  SELECT appeal_outcome INTO v_val FROM fte_review_resolutions
   WHERE practice_id=v_prac AND claim_id=v_up AND action='record_appeal_outcome' AND is_superseded=false;
  SELECT count(*) INTO v_appeal FROM fte_claim_events
   WHERE practice_id=v_prac AND claim_id=v_up AND event_type='appeal_filed';
  SELECT count(*) INTO v_anom FROM fte_review_queue
   WHERE practice_id=v_prac AND claim_id=v_up AND reason='conflicting_observations'
     AND details->>'action'='record_appeal_outcome';
  ASSERT v_val='upheld' AND v_appeal=1 AND v_anom=0,
    format('FAIL [1/6] upheld: value=%s appeal_filed=%s anomaly=%s', v_val, v_appeal, v_anom);
  RAISE NOTICE 'PASS [1/6] valid upheld outcome after appeal — accepted, appeal_filed present, no anomaly';

  -- CHECK 2: valid denied after appeal.
  SELECT appeal_outcome INTO v_val FROM fte_review_resolutions
   WHERE practice_id=v_prac AND claim_id=v_dn AND action='record_appeal_outcome' AND is_superseded=false;
  SELECT count(*) INTO v_appeal FROM fte_claim_events
   WHERE practice_id=v_prac AND claim_id=v_dn AND event_type='appeal_filed';
  SELECT count(*) INTO v_anom FROM fte_review_queue
   WHERE practice_id=v_prac AND claim_id=v_dn AND reason='conflicting_observations'
     AND details->>'action'='record_appeal_outcome';
  ASSERT v_val='denied' AND v_appeal=1 AND v_anom=0,
    format('FAIL [2/6] denied: value=%s appeal_filed=%s anomaly=%s', v_val, v_appeal, v_anom);
  RAISE NOTICE 'PASS [2/6] valid denied outcome after appeal — accepted, appeal_filed present, no anomaly';

  -- CHECK 3: valid partial after appeal.
  SELECT appeal_outcome INTO v_val FROM fte_review_resolutions
   WHERE practice_id=v_prac AND claim_id=v_pa AND action='record_appeal_outcome' AND is_superseded=false;
  SELECT count(*) INTO v_appeal FROM fte_claim_events
   WHERE practice_id=v_prac AND claim_id=v_pa AND event_type='appeal_filed';
  SELECT count(*) INTO v_anom FROM fte_review_queue
   WHERE practice_id=v_prac AND claim_id=v_pa AND reason='conflicting_observations'
     AND details->>'action'='record_appeal_outcome';
  ASSERT v_val='partial' AND v_appeal=1 AND v_anom=0,
    format('FAIL [3/6] partial: value=%s appeal_filed=%s anomaly=%s', v_val, v_appeal, v_anom);
  RAISE NOTICE 'PASS [3/6] valid partial outcome after appeal — accepted, appeal_filed present, no anomaly';

  -- CHECK 4: outcome without appeal_filed routes to review non-destructively.
  SELECT count(*) INTO v_appeal FROM fte_claim_events
   WHERE practice_id=v_prac AND claim_id=v_no AND event_type='appeal_filed';
  SELECT count(*) INTO v_anom FROM fte_review_queue
   WHERE practice_id=v_prac AND claim_id=v_no AND reason='conflicting_observations'
     AND details->>'anomaly'='appeal_outcome_without_appeal';
  ASSERT v_appeal=0 AND v_anom=1,
    format('FAIL [4/6] outcome-without-appeal: appeal_filed=%s anomaly=%s', v_appeal, v_anom);
  RAISE NOTICE 'PASS [4/6] outcome without appeal_filed routes to review (appeal_outcome_without_appeal)';

  -- CHECK 5: conflicting active outcomes route to review non-destructively.
  SELECT count(*) INTO v_appeal FROM fte_claim_events
   WHERE practice_id=v_prac AND claim_id=v_cf AND event_type='appeal_filed';
  SELECT count(*) INTO v_anom FROM fte_review_queue
   WHERE practice_id=v_prac AND claim_id=v_cf AND reason='conflicting_observations'
     AND details->>'anomaly'='conflicting_appeal_outcome';
  ASSERT v_appeal=1 AND v_anom=1,
    format('FAIL [5/6] conflicting: appeal_filed=%s anomaly=%s', v_appeal, v_anom);
  RAISE NOTICE 'PASS [5/6] conflicting active outcomes route to review (conflicting_appeal_outcome)';

  -- CHECK 6: accounting invariance — a claim with an appeal outcome has the same
  --          monetary state as if no outcome existed (no auto-recovery/write-off,
  --          no status change). Verified on the valid upheld claim AND on both
  --          anomaly claims.
  SELECT denied_amount, open_balance_amount, recovered_amount, written_off_amount
    INTO v_denied, v_ob, v_rec, v_wo
  FROM fte_financial_positions fp WHERE fp.practice_id=v_prac AND fp.claim_id=v_up;
  ASSERT v_denied=100.00 AND v_ob=0.00 AND v_rec IS NULL AND v_wo IS NULL,
    format('FAIL [6/6] UP accounting changed: denied=%s open=%s rec=%s wo=%s', v_denied, v_ob, v_rec, v_wo);

  SELECT denied_amount, open_balance_amount, recovered_amount, written_off_amount
    INTO v_denied, v_ob, v_rec, v_wo
  FROM fte_financial_positions fp WHERE fp.practice_id=v_prac AND fp.claim_id=v_cf;
  ASSERT v_denied=100.00 AND v_ob=0.00 AND v_rec IS NULL AND v_wo IS NULL,
    format('FAIL [6/6] CONFL accounting changed: denied=%s open=%s rec=%s wo=%s', v_denied, v_ob, v_rec, v_wo);

  RAISE NOTICE 'PASS [6/6] accounting invariant — open_balance/denied/recovered/written_off unchanged by appeal outcome';
END $$;

-- Discard all fixture + derived data. Nothing persists.
rollback;
