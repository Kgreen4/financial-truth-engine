-- =============================================================================
-- Financial Truth Engine — MVP Report Validation (Task 023B, polished 024A)
-- tests/validate_mvp_report.sql
--
-- 17 PASS checks proving the human-readable Financial Truth Report
-- (fte_practice_report / fte_claim_report) renders the full MVP value story from
-- the synthetic MVP batch: balanced claims, a short-pay exception needing review,
-- a non-recoverable denial, a recoverable denial with an OPEN appeal deadline, an
-- EXPIRED appeal deadline, the 022B/022C denial-knowledge traces (worded for a
-- business reader, per Task 024A), the practice-level executive summary line,
-- and that the report is read-only (reconciled positions match expected values).
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
-- Emits RAISE NOTICE 'PASS [n/17] ...'; any failure RAISEs EXCEPTION.
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
    RAISE EXCEPTION 'FAIL [1/17] report title missing';
  END IF;
  RAISE NOTICE 'PASS [1/17] report title present';

  -- CHECK 2: balanced claim appears with balanced status.
  IF strpos(v_report, 'Claim CLM-MVP-001') = 0
     OR strpos(v_report, 'Status: balanced') = 0 THEN
    RAISE EXCEPTION 'FAIL [2/17] balanced claim CLM-MVP-001 / balanced status not shown';
  END IF;
  RAISE NOTICE 'PASS [2/17] balanced claim appears';

  -- CHECK 3: short-pay / review exception appears (CLM-MVP-002 + NEEDS REVIEW).
  IF strpos(v_report, 'Claim CLM-MVP-002') = 0
     OR strpos(v_report, 'NEEDS REVIEW') = 0
     OR strpos(v_report, 'unbalanced_financial_position') = 0 THEN
    RAISE EXCEPTION 'FAIL [3/17] short-pay review exception not shown';
  END IF;
  RAISE NOTICE 'PASS [3/17] short-pay / review exception appears';

  -- CHECK 4: recoverable denial claim appears.
  IF strpos(v_report, 'Claim CLM-MVP-004') = 0 THEN
    RAISE EXCEPTION 'FAIL [4/17] recoverable denial claim CLM-MVP-004 not shown';
  END IF;
  RAISE NOTICE 'PASS [4/17] recoverable denial claim appears';

  -- CHECK 5: recoverable amount appears (via the single-claim report too).
  IF strpos(v_claim4, 'Recoverable: $100.00') = 0
     OR strpos(v_report, 'Recoverable: $100.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [5/17] recoverable amount $100.00 not shown';
  END IF;
  RAISE NOTICE 'PASS [5/17] recoverable amount appears (claim + practice report)';

  -- CHECK 6: appeal deadline + open status appears.
  IF strpos(v_report, 'Appeal deadline:') = 0
     OR strpos(v_report, '(open)') = 0 THEN
    RAISE EXCEPTION 'FAIL [6/17] appeal deadline / open status not shown';
  END IF;
  RAISE NOTICE 'PASS [6/17] appeal deadline + status appears';

  -- CHECK 7: recoverability_trace summary appears, worded for a business reader
  -- (Task 024A) while preserving the match_status/confidence-score audit values.
  IF strpos(v_report, 'Recoverability trace:') = 0
     OR strpos(v_report, 'matched (confidence score') = 0 THEN
    RAISE EXCEPTION 'FAIL [7/17] recoverability_trace summary not shown';
  END IF;
  RAISE NOTICE 'PASS [7/17] recoverability trace summary appears (business-readable wording)';

  -- CHECK 8: appeal_window_trace summary appears, with confidence-score wording.
  IF strpos(v_report, 'Appeal-window trace:') = 0
     OR strpos(v_report, 'Appeal-window trace: matched (confidence score') = 0 THEN
    RAISE EXCEPTION 'FAIL [8/17] appeal_window_trace summary not shown';
  END IF;
  RAISE NOTICE 'PASS [8/17] appeal-window trace summary appears (business-readable wording)';

  -- CHECK 9: practice review summary appears (exactly one claim needs review).
  IF strpos(v_report, 'Needs review: 1') = 0 THEN
    RAISE EXCEPTION 'FAIL [9/17] practice "Needs review: 1" summary not shown';
  END IF;
  RAISE NOTICE 'PASS [9/17] practice review summary appears';

  -- CHECK 10: practice totals appear (open balance + recoverable denied amount),
  -- using the Task 024A clarified labels.
  IF strpos(v_report, 'Total open balance: $180.00') = 0
     OR strpos(v_report, 'Total recoverable denied amount: $200.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [10/17] practice totals (clarified labels) not shown';
  END IF;
  RAISE NOTICE 'PASS [10/17] practice totals appear with clarified labels';

  -- CHECK 11: non-recoverable denial appears.
  IF strpos(v_report, 'Claim CLM-MVP-003') = 0
     OR strpos(v_report, 'Non-recoverable: $100.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [11/17] non-recoverable denial not shown';
  END IF;
  RAISE NOTICE 'PASS [11/17] non-recoverable denial appears';

  -- CHECK 12: expired appeal deadline appears.
  IF strpos(v_report, '(expired)') = 0 THEN
    RAISE EXCEPTION 'FAIL [12/17] expired appeal deadline not shown';
  END IF;
  RAISE NOTICE 'PASS [12/17] expired appeal deadline appears';

  -- CHECK 13: denial-knowledge governance surfaces in the trace summary, using
  -- the Task 024A business-readable "rule: category=... action=..." phrasing.
  IF strpos(v_report, 'rule: category=contractual_adjustment') = 0
     OR strpos(v_report, 'action=file_appeal') = 0 THEN
    RAISE EXCEPTION 'FAIL [13/17] rule governance not surfaced in trace summary';
  END IF;
  RAISE NOTICE 'PASS [13/17] rule governance surfaces in trace summary';

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
    RAISE EXCEPTION 'FAIL [14/17] positions not as expected: 004(%,denied %,rec %,open %) 002(%,open %) 003(rec %)',
      v_st, v_denied, v_rec, v_open, v_st2, v_open2, v_rec3;
  END IF;
  RAISE NOTICE 'PASS [14/17] accounting invariance: reconciled positions match expected values';

  -- CHECK 15 (Task 024A): "Balanced" summary label clarified to "Financially
  -- balanced" with the correct count (4 of 5 MVP claims are balanced).
  IF strpos(v_report, 'Financially balanced: 4') = 0 THEN
    RAISE EXCEPTION 'FAIL [15/17] clarified "Financially balanced: 4" label not shown';
  END IF;
  RAISE NOTICE 'PASS [15/17] clarified "Financially balanced" label appears';

  -- CHECK 16 (Task 024A): executive/demo conclusion near the top of the practice
  -- report mentions the review exception count, the recoverable denial
  -- opportunity, and the open appeal deadline count.
  IF strpos(v_report,
      'Executive summary: 1 claim(s) needing review, $200.00 in potentially recoverable denied amounts, 1 appeal deadline(s) still open.'
    ) = 0 THEN
    RAISE EXCEPTION 'FAIL [16/17] executive summary line not shown as expected';
  END IF;
  RAISE NOTICE 'PASS [16/17] executive summary line appears with expected counts/amount';

  -- CHECK 17 (Task 024A): both trace sections use the "confidence score"
  -- business-readable phrasing (not the raw match_score=N form), while still
  -- carrying the numeric score value forward.
  IF strpos(v_report, 'confidence score 10') = 0 THEN
    RAISE EXCEPTION 'FAIL [17/17] "confidence score" business-readable wording not shown';
  END IF;
  RAISE NOTICE 'PASS [17/17] "confidence score" wording appears in trace sections';

END $$;

rollback;
