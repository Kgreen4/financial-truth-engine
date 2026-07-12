-- =============================================================================
-- Financial Truth Engine — Action-Effects Reference Table Validation
-- tests/validate_action_effects.sql
--
-- Asserts the INTERNAL consistency of the fte_action_effects reference table
-- (seeded by migrations/014_action_effects_reference.sql, Task 021B): vocabulary
-- coverage, row counts, categories, uniqueness, nonempty fields, and that the
-- table carries no runtime/accounting dependency (no foreign key).
--
-- This complements scripts/guards/check_action_effects_consistency.sh, which
-- checks the table's declared effects against reconciler/fte_reconcile.sql text
-- (that guard runs in the DB-less guardrails CI job). Here we check the table
-- itself, in-database.
--
-- Read-only: SELECTs against fte_action_effects only. Wrapped in BEGIN/ROLLBACK
-- out of convention; nothing is written. No PHI, no production data.
--
-- Depends on migration 014 (fte_action_effects). Emits RAISE NOTICE 'PASS [n/10] ...';
-- any failure RAISEs EXCEPTION and aborts.
-- =============================================================================

begin;

DO $$
DECLARE
  v_count       bigint;
  v_missing     text;
  v_bad         text;
BEGIN

  -- CHECK 1: all 19 vocabulary actions present (each has at least one row).
  SELECT string_agg(a, ', ' ORDER BY a) INTO v_missing
  FROM unnest(array[
    'confirm_observation','reject_observation','mark_duplicate','resolve_contradiction','attach_corrected_value',
    'confirm_payment_event','reject_payment_event','assert_check_identity',
    'confirm_short_pay','dismiss_short_pay','mark_position_resolved','mark_position_needs_correction',
    'request_more_evidence','confirm_position_balanced','override_position_status',
    'file_appeal','record_recovery','approve_write_off',
    'record_appeal_outcome'
  ]) AS a
  WHERE a NOT IN (SELECT DISTINCT action FROM fte_action_effects);
  IF v_missing IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL [1/10] fte_action_effects missing rows for action(s): %', v_missing;
  END IF;
  RAISE NOTICE 'PASS [1/10] all 19 vocabulary actions have at least one row';

  -- CHECK 2: exactly 25 rows present (the hand-authored 021B seed).
  SELECT count(*) INTO v_count FROM fte_action_effects;
  IF v_count <> 25 THEN
    RAISE EXCEPTION 'FAIL [2/10] expected exactly 25 rows, got %', v_count;
  END IF;
  RAISE NOTICE 'PASS [2/10] exactly 25 rows present';

  -- CHECK 3: no unknown action values (every row is one of the 19).
  SELECT string_agg(DISTINCT action, ', ' ORDER BY action) INTO v_bad
  FROM fte_action_effects
  WHERE action NOT IN (
    'confirm_observation','reject_observation','mark_duplicate','resolve_contradiction','attach_corrected_value',
    'confirm_payment_event','reject_payment_event','assert_check_identity',
    'confirm_short_pay','dismiss_short_pay','mark_position_resolved','mark_position_needs_correction',
    'request_more_evidence','confirm_position_balanced','override_position_status',
    'file_appeal','record_recovery','approve_write_off',
    'record_appeal_outcome'
  );
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL [3/10] fte_action_effects contains unknown action(s): %', v_bad;
  END IF;
  RAISE NOTICE 'PASS [3/10] no unknown action values';

  -- CHECK 4: no duplicate (action, phase, effect_type) tuples.
  SELECT count(*) INTO v_count FROM (
    SELECT action, phase, effect_type
    FROM fte_action_effects
    GROUP BY action, phase, effect_type
    HAVING count(*) > 1
  ) dups;
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL [4/10] % duplicate (action, phase, effect_type) tuple(s) found', v_count;
  END IF;
  RAISE NOTICE 'PASS [4/10] no duplicate (action, phase, effect_type) rows';

  -- CHECK 5: the 3 durable-note actions are all categorized durable_note.
  SELECT string_agg(action || '=' || category, ', ' ORDER BY action) INTO v_bad
  FROM fte_action_effects
  WHERE action IN ('assert_check_identity','request_more_evidence','mark_position_needs_correction')
    AND category <> 'durable_note';
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL [5/10] durable-note action(s) miscategorized: %', v_bad;
  END IF;
  RAISE NOTICE 'PASS [5/10] durable-note actions categorized durable_note';

  -- CHECK 6: the 3 reserved actions are all categorized reserved_unimplemented.
  SELECT string_agg(action || '=' || category, ', ' ORDER BY action) INTO v_bad
  FROM fte_action_effects
  WHERE action IN ('resolve_contradiction','confirm_position_balanced','override_position_status')
    AND category <> 'reserved_unimplemented';
  IF v_bad IS NOT NULL THEN
    RAISE EXCEPTION 'FAIL [6/10] reserved action(s) miscategorized: %', v_bad;
  END IF;
  RAISE NOTICE 'PASS [6/10] reserved actions categorized reserved_unimplemented';

  -- CHECK 7: dismiss_short_pay has exactly 2 effect rows (Phase 7 + Phase 8).
  SELECT count(*) INTO v_count FROM fte_action_effects WHERE action = 'dismiss_short_pay';
  IF v_count <> 2 THEN
    RAISE EXCEPTION 'FAIL [7/10] dismiss_short_pay expected 2 rows, got %', v_count;
  END IF;
  RAISE NOTICE 'PASS [7/10] dismiss_short_pay has exactly 2 effect rows';

  -- CHECK 8: attach_corrected_value has exactly 6 effect rows (Phases 3/4/4b/5c/5d/5e).
  SELECT count(*) INTO v_count FROM fte_action_effects WHERE action = 'attach_corrected_value';
  IF v_count <> 6 THEN
    RAISE EXCEPTION 'FAIL [8/10] attach_corrected_value expected 6 rows, got %', v_count;
  END IF;
  RAISE NOTICE 'PASS [8/10] attach_corrected_value has exactly 6 effect rows';

  -- CHECK 9: all description and source_migration values are nonempty.
  SELECT count(*) INTO v_count FROM fte_action_effects
  WHERE btrim(coalesce(description,'')) = '' OR btrim(coalesce(source_migration,'')) = '';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL [9/10] % row(s) have empty description or source_migration', v_count;
  END IF;
  RAISE NOTICE 'PASS [9/10] all description/source_migration values nonempty';

  -- CHECK 10: fte_action_effects has NO foreign-key constraint — it is static
  -- reference data, not runtime/accounting-linked claim data.
  SELECT count(*) INTO v_count
  FROM pg_constraint con
  JOIN pg_class c ON c.oid = con.conrelid
  WHERE c.relname = 'fte_action_effects' AND con.contype = 'f';
  IF v_count <> 0 THEN
    RAISE EXCEPTION 'FAIL [10/10] fte_action_effects has % foreign-key constraint(s); it must be dependency-free static reference data', v_count;
  END IF;
  RAISE NOTICE 'PASS [10/10] fte_action_effects has no foreign-key dependency (static reference table)';

END $$;

rollback;
