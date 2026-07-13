-- =============================================================================
-- Financial Truth Engine — MVP Report Validation (Task 023B)
-- tests/validate_mvp_report.sql
--
-- 14 PASS checks proving the human-readable Financial Truth Report
-- (fte_practice_report / fte_claim_report) renders the full MVP value story from
-- the synthetic MVP batch: balanced claims, a short-pay exception needing review,
-- a non-recoverable denial, a recoverable denial with an OPEN appeal deadline, an
-- EXPIRED appeal deadline, and the 022B/022C denial-knowledge traces — plus that
-- the report is read-only (reconciled positions match expected values).
--
-- The report functions WRAP fte_explain_claim and read materialized tables; they
-- derive no new financial values and change nothing.
--
-- Prerequisites:
--   1. migrations 001–014 applied
--   2. reconciler/fte_reconcile.sql, fte_explain_claim.sql, fte_claim_report.sql,
--      fte_practice_report.sql registered (CREATE OR REPLACE)
--   3. fixtures/synthetic_mvp_batch.sql loaded (committed)
--
-- Self-contained: reconciles inside the transaction and ROLLs BACK — nothing
-- persists. Synthetic only. No PHI, no production data, no AI.
-- Emits RAISE NOTICE 'PASS [n/14] ...'; any failure RAISEs EXCEPTION.
-- =============================================================================

begin;

DO $$
DECLARE
  v_practice uuid := 'a4000000-0000-4000-8000-0000000000fe';
  v_c004     uuid := 'c4a00000-0000-4000-8000-000000000004';
  v_report   text;   -- full practice report
  v_claim4   text;   -- single-claim report (recoverable denial)
  -- position invariance vars
  v_st text; v_denied numeric; v_rec numeric; v_open numeric;
  v_st2 text; v_open2 numeric;
  v_rec3 numeric;
BEGIN
  PERFORM fte_reconcile_practice(v_practice);
  v_report := fte_practice_report(v_practice);
  v_claim4 := fte_claim_report(v_practice, v_c004);

  -- CHECK 1: report title present.
  IF strpos(v_report, '=== Financial Truth Report — Synthetic MVP Practice ===') = 0 THEN
    RAISE EXCEPTION 'FAIL [1/14] report title missing';
  END IF;
  RAISE NOTICE 'PASS [1/14] report title present';

  -- CHECK 2: balanced claim appears with balanced status.
  IF strpos(v_report, 'Claim CLM-MVP-001') = 0
     OR strpos(v_report, 'Status: balanced') = 0 THEN
    RAISE EXCEPTION 'FAIL [2/14] balanced claim CLM-MVP-001 / balanced status not shown';
  END IF;
  RAISE NOTICE 'PASS [2/14] balanced claim appears';

  -- CHECK 3: short-pay / review exception appears (CLM-MVP-002 + NEEDS REVIEW).
  IF strpos(v_report, 'Claim CLM-MVP-002') = 0
     OR strpos(v_report, 'NEEDS REVIEW') = 0
     OR strpos(v_report, 'unbalanced_financial_position') = 0 THEN
    RAISE EXCEPTION 'FAIL [3/14] short-pay review exception not shown';
  END IF;
  RAISE NOTICE 'PASS [3/14] short-pay / review exception appears';

  -- CHECK 4: recoverable denial claim appears.
  IF strpos(v_report, 'Claim CLM-MVP-004') = 0 THEN
    RAISE EXCEPTION 'FAIL [4/14] recoverable denial claim CLM-MVP-004 not shown';
  END IF;
  RAISE NOTICE 'PASS [4/14] recoverable denial claim appears';

  -- CHECK 5: recoverable amount appears (via the single-claim report too).
  IF strpos(v_claim4, 'Recoverable: $100.00') = 0
     OR strpos(v_report, 'Recoverable: $100.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [5/14] recoverable amount $100.00 not shown';
  END IF;
  RAISE NOTICE 'PASS [5/14] recoverable amount appears (claim + practice report)';

  -- CHECK 6: appeal deadline + open status appears.
  IF strpos(v_report, 'Appeal deadline:') = 0
     OR strpos(v_report, '(open)') = 0 THEN
    RAISE EXCEPTION 'FAIL [6/14] appeal deadline / open status not shown';
  END IF;
  RAISE NOTICE 'PASS [6/14] appeal deadline + status appears';

  -- CHECK 7: recoverability_trace summary appears (matched).
  IF strpos(v_report, 'Recoverability trace:') = 0
     OR strpos(v_report, 'match_status=matched') = 0 THEN
    RAISE EXCEPTION 'FAIL [7/14] recoverability_trace summary not shown';
  END IF;
  RAISE NOTICE 'PASS [7/14] recoverability trace summary appears';

  -- CHECK 8: appeal_window_trace summary appears.
  IF strpos(v_report, 'Appeal-window trace:') = 0 THEN
    RAISE EXCEPTION 'FAIL [8/14] appeal_window_trace summary not shown';
  END IF;
  RAISE NOTICE 'PASS [8/14] appeal-window trace summary appears';

  -- CHECK 9: practice review summary appears (exactly one claim needs review).
  IF strpos(v_report, 'Needs review: 1') = 0 THEN
    RAISE EXCEPTION 'FAIL [9/14] practice "Needs review: 1" summary not shown';
  END IF;
  RAISE NOTICE 'PASS [9/14] practice review summary appears';

  -- CHECK 10: practice totals appear (open balance + recoverable).
  IF strpos(v_report, 'Total open balance: $180.00') = 0
     OR strpos(v_report, 'Total recoverable: $200.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [10/14] practice totals not shown';
  END IF;
  RAISE NOTICE 'PASS [10/14] practice totals appear';

  -- CHECK 11: non-recoverable denial appears.
  IF strpos(v_report, 'Claim CLM-MVP-003') = 0
     OR strpos(v_report, 'Non-recoverable: $100.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [11/14] non-recoverable denial not shown';
  END IF;
  RAISE NOTICE 'PASS [11/14] non-recoverable denial appears';

  -- CHECK 12: expired appeal deadline appears.
  IF strpos(v_report, '(expired)') = 0 THEN
    RAISE EXCEPTION 'FAIL [12/14] expired appeal deadline not shown';
  END IF;
  RAISE NOTICE 'PASS [12/14] expired appeal deadline appears';

  -- CHECK 13: denial-knowledge governance surfaces in the trace summary.
  IF strpos(v_report, 'governance=[category=contractual_adjustment') = 0
     OR strpos(v_report, 'action=file_appeal') = 0 THEN
    RAISE EXCEPTION 'FAIL [13/14] rule governance not surfaced in trace summary';
  END IF;
  RAISE NOTICE 'PASS [13/14] rule governance surfaces in trace summary';

  -- CHECK 14: accounting invariance — reconciled positions match expected values
  -- (the report only reads them; it changes nothing).
  SELECT reconciliation_status, denied_amount, recoverable_amount, open_balance_amount
    INTO v_st, v_denied, v_rec, v_open
    FROM fte_financial_positions WHERE practice_id=v_practice AND claim_id=v_c004;
  SELECT reconciliation_status, open_balance_amount
    INTO v_st2, v_open2
    FROM fte_financial_positions fp JOIN fte_claims c ON c.id=fp.claim_id
    WHERE fp.practice_id=v_practice AND c.claim_number='CLM-MVP-002';
  SELECT recoverable_amount INTO v_rec3
    FROM fte_financial_positions fp JOIN fte_claims c ON c.id=fp.claim_id
    WHERE fp.practice_id=v_practice AND c.claim_number='CLM-MVP-003';
  IF NOT (v_st='balanced' AND v_denied=100.00 AND v_rec=100.00 AND v_open=0.00
          AND v_st2='unbalanced' AND v_open2=180.00
          AND v_rec3=0.00) THEN
    RAISE EXCEPTION 'FAIL [14/14] positions not as expected: 004(%,denied %,rec %,open %) 002(%,open %) 003(rec %)',
      v_st, v_denied, v_rec, v_open, v_st2, v_open2, v_rec3;
  END IF;
  RAISE NOTICE 'PASS [14/14] accounting invariance: reconciled positions match expected values';

END $$;

rollback;
