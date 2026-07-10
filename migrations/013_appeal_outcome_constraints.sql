-- =============================================================================
-- Financial Truth Engine (FTE) — Appeal Outcome Schema Support
-- Migration: 013_appeal_outcome_constraints.sql
-- Depends on: 012_denial_lifecycle_constraints.sql
-- Created: 2026-07-05
--
-- WHAT THIS MIGRATION ADDS (schema-only; NO reconciler/explain/accounting change)
-- -----------------------------------------------------------------------------
-- Minimal, reviewer-driven, reporting-only support for appeal OUTCOME states
-- (Task 018A design). The appeal loop already has a filing marker (file_appeal
-- -> appeal_filed); this adds the outcome the reviewer records after an appeal
-- resolves. It is captured as a typed reviewer resolution — NOT a new claim
-- event and NOT a position field — so it has no accounting effect.
--
-- 1. One new reviewer action in the fte_review_resolutions action vocabulary:
--      record_appeal_outcome — reviewer records the disposition of a filed appeal
--    The base vocabulary CHECK (auto-named fte_review_resolutions_action_check)
--    is dropped and re-added with the full 19-value list (18 existing + 1).
--    All 18 existing actions remain valid and behavior-compatible.
--
-- 2. appeal_outcome text (nullable) — the reviewer-supplied outcome.
--
-- 3. Shape constraints:
--      * appeal_outcome, when set, must be one of 'upheld' / 'denied' / 'partial'
--      * record_appeal_outcome requires appeal_outcome to be set
--      * all OTHER actions must leave appeal_outcome NULL
--    record_appeal_outcome does NOT require lifecycle_amount (outcome is a
--    workflow disposition, not a monetary reclassification).
--
-- NOT CHANGED / NOT ADDED (per Task 018B scope):
--   * No new event_type (enum unchanged). No new fte_financial_positions column.
--   * No new claim/position status. No new table. No accounting behavior.
--   * RLS unchanged (fte_review_resolutions already has RLS + policy).
--
-- Idempotent: DROP ... IF EXISTS precedes each ADD; ADD COLUMN IF NOT EXISTS —
-- safe to re-run against an already-migrated disposable database.
-- =============================================================================

begin;

-- -----------------------------------------------------------------------------
-- 1. Extend the action vocabulary CHECK (18 existing + record_appeal_outcome = 19).
-- -----------------------------------------------------------------------------
alter table fte_review_resolutions
  drop constraint if exists fte_review_resolutions_action_check;

alter table fte_review_resolutions
  add constraint fte_review_resolutions_action_check
    check (action in (
      -- Observation-level (5)
      'confirm_observation',
      'reject_observation',
      'mark_duplicate',
      'resolve_contradiction',
      'attach_corrected_value',
      -- Payment / event-level (3)
      'confirm_payment_event',
      'reject_payment_event',
      'assert_check_identity',
      -- Position-level (7)
      'confirm_short_pay',
      'dismiss_short_pay',
      'mark_position_resolved',
      'mark_position_needs_correction',
      'request_more_evidence',
      'confirm_position_balanced',
      'override_position_status',
      -- Denial lifecycle (3) — Task 017B
      'file_appeal',
      'record_recovery',
      'approve_write_off',
      -- Appeal outcome (1) — Task 018B
      'record_appeal_outcome'
    ));

-- -----------------------------------------------------------------------------
-- 2. appeal_outcome — nullable reviewer-supplied appeal disposition.
-- -----------------------------------------------------------------------------
alter table fte_review_resolutions
  add column if not exists appeal_outcome text;

comment on column fte_review_resolutions.appeal_outcome is
  'Reviewer-recorded disposition of a filed appeal for record_appeal_outcome: '
  'one of upheld / denied / partial. NULL for every other action. Reporting/'
  'workflow only — carries no accounting effect (recovery and write-off remain '
  'the sole money-moving lifecycle actions).';

-- -----------------------------------------------------------------------------
-- 3. Shape constraints (mirror the migration-004/012 "action <> 'X' OR ..." style).
-- -----------------------------------------------------------------------------

-- 3a. Allowed value set (applies whenever appeal_outcome is set).
alter table fte_review_resolutions
  drop constraint if exists fte_review_resolutions_appeal_outcome_valid;
alter table fte_review_resolutions
  add constraint fte_review_resolutions_appeal_outcome_valid
    check (
      appeal_outcome IS NULL
      OR appeal_outcome IN ('upheld', 'denied', 'partial')
    );

-- 3b. record_appeal_outcome requires a (valid, per 3a) appeal_outcome.
alter table fte_review_resolutions
  drop constraint if exists fte_review_resolutions_appeal_outcome_needs_value;
alter table fte_review_resolutions
  add constraint fte_review_resolutions_appeal_outcome_needs_value
    check (
      action <> 'record_appeal_outcome'
      OR appeal_outcome IS NOT NULL
    );

-- 3c. Only record_appeal_outcome may populate appeal_outcome.
alter table fte_review_resolutions
  drop constraint if exists fte_review_resolutions_non_appeal_outcome_no_value;
alter table fte_review_resolutions
  add constraint fte_review_resolutions_non_appeal_outcome_no_value
    check (
      action = 'record_appeal_outcome'
      OR appeal_outcome IS NULL
    );

-- =============================================================================
-- End of migration 013.
-- =============================================================================

commit;
