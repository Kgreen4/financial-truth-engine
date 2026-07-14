-- =============================================================================
-- Financial Truth Engine — MVP Report Validation (Task 023B, polished 024A/024B)
-- tests/validate_mvp_report.sql
--
-- 19 PASS checks proving the human-readable Financial Truth Report
-- (fte_practice_report / fte_claim_report) renders the full MVP value story from
-- the synthetic MVP batch: balanced claims, a short-pay exception needing review,
-- a non-recoverable denial, a recoverable denial with an OPEN appeal deadline, an
-- EXPIRED appeal deadline, the 022B/022C denial-knowledge traces in plain
-- business language (024A, finalized 024B), the practice-level executive
-- summary line, and that the report is read-only (reconciled positions match
-- expected values).
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
-- Emits RAISE NOTICE 'PASS [n/19] ...'; any failure RAISEs EXCEPTION.
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
    RAISE EXCEPTION 'FAIL [1/19] report title missing';
  END IF;
  RAISE NOTICE 'PASS [1/19] report title present';

  -- CHECK 2: balanced claim appears with balanced status.
  IF strpos(v_report, 'Claim CLM-MVP-001') = 0
     OR strpos(v_report, 'Status: balanced') = 0 THEN
    RAISE EXCEPTION 'FAIL [2/19] balanced claim CLM-MVP-001 / balanced status not shown';
  END IF;
  RAISE NOTICE 'PASS [2/19] balanced claim appears';

  -- CHECK 3: short-pay / review exception appears (CLM-MVP-002 + NEEDS REVIEW).
  IF strpos(v_report, 'Claim CLM-MVP-002') = 0
     OR strpos(v_report, 'NEEDS REVIEW') = 0
     OR strpos(v_report, 'unbalanced_financial_position') = 0 THEN
    RAISE EXCEPTION 'FAIL [3/19] short-pay review exception not shown';
  END IF;
  RAISE NOTICE 'PASS [3/19] short-pay / review exception appears';

  -- CHECK 4: recoverable denial claim appears.
  IF strpos(v_report, 'Claim CLM-MVP-004') = 0 THEN
    RAISE EXCEPTION 'FAIL [4/19] recoverable denial claim CLM-MVP-004 not shown';
  END IF;
  RAISE NOTICE 'PASS [4/19] recoverable denial claim appears';

  -- CHECK 5: recoverable amount appears (via the single-claim report too).
  IF strpos(v_claim4, 'Recoverable: $100.00') = 0
     OR strpos(v_report, 'Recoverable: $100.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [5/19] recoverable amount $100.00 not shown';
  END IF;
  RAISE NOTICE 'PASS [5/19] recoverable amount appears (claim + practice report)';

  -- CHECK 6: appeal deadline + open status appears.
  IF strpos(v_report, 'Appeal deadline:') = 0
     OR strpos(v_report, '(open)') = 0 THEN
    RAISE EXCEPTION 'FAIL [6/19] appeal deadline / open status not shown';
  END IF;
  RAISE NOTICE 'PASS [6/19] appeal deadline + status appears';

  -- CHECK 7 (finalized 024B): recoverability_trace summary appears in plain
  -- business language ("matched with high confidence (N/10)"), preserving the
  -- match_status/score audit values.
  IF strpos(v_report, 'Recoverability trace:') = 0
     OR strpos(v_report, 'matched with high confidence (10/10)') = 0 THEN
    RAISE EXCEPTION 'FAIL [7/19] recoverability_trace summary not shown';
  END IF;
  RAISE NOTICE 'PASS [7/19] recoverability trace summary appears (finalized business wording)';

  -- CHECK 8 (finalized 024B): appeal_window_trace summary appears with the
  -- same plain-language confidence phrasing.
  IF strpos(v_report, 'Appeal-window trace:') = 0
     OR strpos(v_report, 'Appeal-window trace: matched with high confidence (10/10)') = 0 THEN
    RAISE EXCEPTION 'FAIL [8/19] appeal_window_trace summary not shown';
  END IF;
  RAISE NOTICE 'PASS [8/19] appeal-window trace summary appears (finalized business wording)';

  -- CHECK 9: practice review summary appears (exactly one claim needs review).
  IF strpos(v_report, 'Needs review: 1') = 0 THEN
    RAISE EXCEPTION 'FAIL [9/19] practice "Needs review: 1" summary not shown';
  END IF;
  RAISE NOTICE 'PASS [9/19] practice review summary appears';

  -- CHECK 10: practice totals appear (open balance + recoverable denied amount),
  -- using the Task 024A clarified labels.
  IF strpos(v_report, 'Total open balance: $180.00') = 0
     OR strpos(v_report, 'Total recoverable denied amount: $200.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [10/19] practice totals (clarified labels) not shown';
  END IF;
  RAISE NOTICE 'PASS [10/19] practice totals appear with clarified labels';

  -- CHECK 11: non-recoverable denial appears.
  IF strpos(v_report, 'Claim CLM-MVP-003') = 0
     OR strpos(v_report, 'Non-recoverable: $100.00') = 0 THEN
    RAISE EXCEPTION 'FAIL [11/19] non-recoverable denial not shown';
  END IF;
  RAISE NOTICE 'PASS [11/19] non-recoverable denial appears';

  -- CHECK 12: expired appeal deadline appears.
  IF strpos(v_report, '(expired)') = 0 THEN
    RAISE EXCEPTION 'FAIL [12/19] expired appeal deadline not shown';
  END IF;
  RAISE NOTICE 'PASS [12/19] expired appeal deadline appears';

  -- CHECK 13 (finalized 024B): denial-knowledge governance surfaces in plain
  -- business language ("category: ..., recommended action: ...", underscores
  -- rendered as spaces) instead of the old "category=... action=..." syntax.
  IF strpos(v_report, 'category: contractual adjustment') = 0
     OR strpos(v_report, 'recommended action: file appeal') = 0 THEN
    RAISE EXCEPTION 'FAIL [13/19] rule governance not surfaced in trace summary';
  END IF;
  RAISE NOTICE 'PASS [13/19] rule governance surfaces in plain business wording';

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
    RAISE EXCEPTION 'FAIL [14/19] positions not as expected: 004(%,denied %,rec %,open %) 002(%,open %) 003(rec %)',
      v_st, v_denied, v_rec, v_open, v_st2, v_open2, v_rec3;
  END IF;
  RAISE NOTICE 'PASS [14/19] accounting invariance: reconciled positions match expected values';

  -- CHECK 15 (Task 024A): "Balanced" summary label clarified to "Financially
  -- balanced" with the correct count (4 of 5 MVP claims are balanced).
  IF strpos(v_report, 'Financially balanced: 4') = 0 THEN
    RAISE EXCEPTION 'FAIL [15/19] clarified "Financially balanced: 4" label not shown';
  END IF;
  RAISE NOTICE 'PASS [15/19] clarified "Financially balanced" label appears';

  -- CHECK 16 (Task 024A): executive/demo conclusion near the top of the practice
  -- report mentions the review exception count, the recoverable denial
  -- opportunity, and the open appeal deadline count.
  IF strpos(v_report,
      'Executive summary: 1 claim(s) needing review, $200.00 in potentially recoverable denied amounts, 1 appeal deadline(s) still open.'
    ) = 0 THEN
    RAISE EXCEPTION 'FAIL [16/19] executive summary line not shown as expected';
  END IF;
  RAISE NOTICE 'PASS [16/19] executive summary line appears with expected counts/amount';

  -- CHECK 17 (finalized 024B): denial-code + payer-scope wording is plain
  -- language ("on denial code X and any payer"), preserving the CARC/payer
  -- audit values without raw bracket/equals syntax.
  IF strpos(v_report, 'on denial code MVP-REC and any payer') = 0 THEN
    RAISE EXCEPTION 'FAIL [17/19] plain-language denial-code/payer scope wording not shown';
  END IF;
  RAISE NOTICE 'PASS [17/19] plain-language denial-code/payer scope wording appears';

  -- CHECK 18 (finalized 024B): the recoverable-total consistency footer is a
  -- plain sentence instead of a raw "(...: true)" assertion.
  IF strpos(v_report, 'This matches the recorded recoverable amount.') = 0 THEN
    RAISE EXCEPTION 'FAIL [18/19] plain-language consistency footer not shown';
  END IF;
  RAISE NOTICE 'PASS [18/19] plain-language consistency footer appears';

  -- CHECK 19 (finalized 024B): all prior debug/internal syntax is fully gone —
  -- no raw "scope=[", no old "(confidence score N)" form, and no old
  -- "rule: category=...action=...owner=..." bracket/equals phrasing anywhere
  -- in the report.
  IF strpos(v_report, 'scope=[') > 0
     OR strpos(v_report, '(confidence score') > 0
     OR strpos(v_report, 'rule: category=') > 0 THEN
    RAISE EXCEPTION 'FAIL [19/19] leftover debug/internal wording still present in report';
  END IF;
  RAISE NOTICE 'PASS [19/19] no leftover debug/internal wording in report';

END $$;

rollback;
