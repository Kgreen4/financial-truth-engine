-- =============================================================================
-- Financial Truth Engine — Human-Readable Practice Report (MVP, Task 023B)
-- reconciler/fte_practice_report.sql
--
-- Function: fte_practice_report(p_practice_id uuid) RETURNS text
--
-- Renders a whole practice as a plain-text/markdown "Financial Truth Report":
-- a title, a practice summary (counts + totals + upcoming appeal deadlines), and
-- each claim's fte_claim_report block. Read-only, deterministic, no AI. It only
-- reads materialized positions / review queue / explain output — it derives no
-- new financial values and changes nothing.
--
-- Prerequisites: fte_claim_report + fte_explain_claim registered; caller must run
-- fte_reconcile_practice first. Register AFTER fte_claim_report.sql.
-- =============================================================================

CREATE OR REPLACE FUNCTION fte_practice_report(
  p_practice_id uuid
) RETURNS text
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_name              text;
  r                   text;
  v_claims            bigint;
  v_balanced          bigint;
  v_needs_review      bigint;
  v_denied            bigint;
  v_open_total        numeric;
  v_recoverable_total numeric;
  rec                 record;
  v_ex                jsonb;
BEGIN
  SELECT name INTO v_name FROM fte_practices WHERE id = p_practice_id;
  IF NOT FOUND THEN
    RETURN format('Practice %s not found.', p_practice_id);
  END IF;

  SELECT count(*) INTO v_claims
    FROM fte_claims WHERE practice_id = p_practice_id;
  SELECT count(*) INTO v_balanced
    FROM fte_financial_positions
    WHERE practice_id = p_practice_id AND reconciliation_status = 'balanced';
  SELECT count(DISTINCT claim_id) INTO v_needs_review
    FROM fte_review_queue
    WHERE practice_id = p_practice_id AND claim_id IS NOT NULL;
  SELECT count(*) INTO v_denied
    FROM fte_financial_positions
    WHERE practice_id = p_practice_id AND denied_amount IS NOT NULL AND denied_amount > 0;
  SELECT COALESCE(SUM(open_balance_amount), 0) INTO v_open_total
    FROM fte_financial_positions WHERE practice_id = p_practice_id;
  SELECT COALESCE(SUM(recoverable_amount), 0) INTO v_recoverable_total
    FROM fte_financial_positions WHERE practice_id = p_practice_id;

  r := format('=== Financial Truth Report — %s ===', v_name) || E'\n';
  r := r || format('Claims: %s | Balanced: %s | Needs review: %s | Denied: %s',
        v_claims, v_balanced, v_needs_review, v_denied) || E'\n';
  r := r || format('Total open balance: $%s | Total recoverable: $%s',
        to_char(v_open_total, 'FM999999999999990.00'),
        to_char(v_recoverable_total, 'FM999999999999990.00')) || E'\n';

  -- Upcoming/known appeal deadlines (appeal_deadline is explain-derived, not stored).
  r := r || 'Appeal deadlines:' || E'\n';
  FOR rec IN
    SELECT id, claim_number FROM fte_claims
    WHERE practice_id = p_practice_id ORDER BY claim_number
  LOOP
    v_ex := fte_explain_claim(p_practice_id, rec.id);
    IF v_ex->>'appeal_deadline' IS NOT NULL THEN
      r := r || format('  %s — %s (%s)',
            rec.claim_number, v_ex->>'appeal_deadline', v_ex->>'appeal_deadline_status') || E'\n';
    END IF;
  END LOOP;

  r := r || E'\n--- Per-claim detail ---\n';
  FOR rec IN
    SELECT id, claim_number FROM fte_claims
    WHERE practice_id = p_practice_id ORDER BY claim_number
  LOOP
    r := r || fte_claim_report(p_practice_id, rec.id) || E'\n';
  END LOOP;

  RETURN r;
END;
$$;
