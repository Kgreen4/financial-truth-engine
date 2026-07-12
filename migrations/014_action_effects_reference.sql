-- =============================================================================
-- Financial Truth Engine (FTE) — Reviewer Action-Effects Reference Table
-- Migration: 014_action_effects_reference.sql
-- Depends on: 013_appeal_outcome_constraints.sql
-- Created: 2026-07-12
--
-- WHAT THIS MIGRATION ADDS (reference data only; NO reconciler/explain/accounting change)
-- -----------------------------------------------------------------------------
-- A single hand-authored reference table, fte_action_effects, that documents —
-- declaratively, in one place — what each fte_review_resolutions.action value
-- actually does inside the deterministic reconciler (reconciler/fte_reconcile.sql).
--
-- Today that knowledge is implicit: it lives only as ad hoc `action = 'X'` /
-- `action IN (...)` predicates scattered across ~13 reconciler phases, summarized
-- (with no mechanical link back to the code) by hand-maintained contrast tables in
-- reconciler/README.md §5.14 / §5.16 and prose invariants in README_SCHEMA.md.
-- This table is the declarative single source of truth those prose tables were
-- trying to be. It is designed per the Task 021A design artifact
-- (reviewer_action_effects_design.md).
--
-- ROLE IN THIS SLICE: documentation-plus-future-CI-guard ONLY. No runtime code
-- reads this table. The reconciler is NOT changed and does NOT consult it. The
-- table ASSERTS what the code already does; a future task (021C) will add a CI
-- guard + validation suite that checks the table against the reconciler source.
-- Runtime consultation (the reconciler dynamically joining against this table) is
-- explicitly deferred to a separate, higher-risk future task (021A §11).
--
-- GRAIN: one row per (action, phase, effect_type). A single action may have
-- MULTIPLE rows when it produces distinct effects in distinct phases — most
-- notably dismiss_short_pay, which suppresses the Phase 7 review-queue row AND
-- (uniquely, not shared with confirm_short_pay / mark_position_resolved) the
-- Phase 8 short_pay_detected event, so it carries two rows.
--
-- CATEGORIES (021A §6): accounting_effect, observation_suppression,
-- queue_suppression, queue_and_event_suppression, status_only, event_emission,
-- reporting_only, durable_note, reserved_unimplemented.
--
--   * durable_note        — fully constrained/tested actions with ZERO
--                           reconciler-phase reference by design (audit-trail
--                           notes read directly by fte_explain_claim). phase='none'.
--   * reserved_unimplemented — actions in the CHECK vocabulary that have no
--                           constraint migration and no reconciler wiring
--                           (confirm_position_balanced was deliberately deferred by
--                           Task 005C to keep 'balanced' event-derived). phase='none'.
--
-- phase is stored with the sentinel 'none' (not NULL) for durable_note and
-- reserved_unimplemented rows, so the (action, phase, effect_type) uniqueness key
-- stays meaningful for every seeded row (021A §6). The column is nullable to match
-- the 021A schema sketch, but every seeded row carries a non-null phase.
--
-- shared_predicate_group tags rows whose action string appears inside a shared
-- multi-action IN-list in the reconciler (rather than a lone equality check), so a
-- future CI guard knows which physical list to search:
--   * phase0_5_suppression_list  = ('reject_observation','mark_duplicate')
--   * phase5f_lifecycle_gate      = ('file_appeal','record_recovery','approve_write_off')
--   * phase7_queue_suppression_list = ('dismiss_short_pay','confirm_short_pay','mark_position_resolved')
--
-- Every row was hand-transcribed from the current reconciler/fte_reconcile.sql
-- phase code and migrations 002-013 — NOT AI-inferred.
--
-- NOT CHANGED / NOT ADDED (per Task 021B scope):
--   * No change to reconciler/fte_reconcile.sql, fte_explain_claim.sql, or any
--     accounting behavior. No new event_type/status/queue reason. No change to
--     fte_review_resolutions or any existing table. No FK to fte_review_resolutions
--     (this is static reference data, not runtime claim data). No CI/guard change.
--
-- RLS: enabled (validate_schema.sql Check 1 requires RLS on every fte_ table).
-- This table holds only non-sensitive, non-tenant reference metadata, so the
-- SELECT policy is global-read (using true). There is intentionally NO tenant
-- write policy — like global fte_denial_knowledge rows, this table is seeded and
-- maintained exclusively by migrations (service_role / postgres, both BYPASSRLS).
--
-- Idempotent: create table if not exists; insert ... on conflict do nothing —
-- safe to re-run against an already-migrated disposable database.
-- =============================================================================

begin;

create extension if not exists pgcrypto;  -- gen_random_uuid()

-- -----------------------------------------------------------------------------
-- Table
-- -----------------------------------------------------------------------------
create table if not exists fte_action_effects (
  id                     uuid primary key default gen_random_uuid(),

  -- Which reviewer action this row describes. CHECK mirrors the 19-value
  -- fte_review_resolutions.action vocabulary (migrations 002 + 012 + 013). Kept
  -- as an independent CHECK (not a FK) because fte_review_resolutions holds
  -- per-claim runtime rows, not the action catalog; this is reference data.
  action                 text not null
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
                             -- Denial lifecycle (3)
                             'file_appeal',
                             'record_recovery',
                             'approve_write_off',
                             -- Appeal outcome (1)
                             'record_appeal_outcome'
                           )),

  -- Effect taxonomy (021A §6).
  category               text not null
                           check (category in (
                             'accounting_effect',
                             'observation_suppression',
                             'queue_suppression',
                             'queue_and_event_suppression',
                             'status_only',
                             'event_emission',
                             'reporting_only',
                             'durable_note',
                             'reserved_unimplemented'
                           )),

  -- Reconciler phase this row's effect applies in, e.g. '3', '5c', '5f', '7', '8'.
  -- Sentinel 'none' for durable_note / reserved_unimplemented rows (no phase).
  -- Nullable to match the 021A sketch, but every seeded row carries a non-null value.
  phase                  text,

  -- Short controlled label for what happens: overrides_amount,
  -- suppresses_observation, suppresses_queue_reason, suppresses_event_type,
  -- promotes_status, emits_event, routes_to_review_queue, or none.
  effect_type            text not null,

  -- Which shared multi-action IN-list (if any) this row's action string lives in.
  shared_predicate_group text,

  requires_notes         boolean not null default false,
  requires_amount        boolean not null default false,

  description            text not null
                           check (btrim(description) <> ''),
  source_migration       text not null
                           check (btrim(source_migration) <> ''),

  created_at             timestamptz not null default now(),

  -- Allows multiple rows per action (distinct phase/effect_type) but prevents
  -- duplicate effect rows.
  constraint fte_action_effects_action_phase_effect_uniq
    unique (action, phase, effect_type)
);

comment on table fte_action_effects is
  'Hand-authored declarative reference for reviewer-action semantics: for each '
  'fte_review_resolutions.action, which reconciler phase(s) it affects and how. '
  'Documentation / future-CI-guard only (Task 021B) — no runtime code reads it and '
  'the reconciler does not consult it. Grain: (action, phase, effect_type); an '
  'action with multiple distinct effects (e.g. dismiss_short_pay) has multiple rows.';

comment on column fte_action_effects.phase is
  'Reconciler phase the effect applies in; sentinel ''none'' for durable_note and '
  'reserved_unimplemented actions that no phase references.';

comment on column fte_action_effects.shared_predicate_group is
  'Identifies the shared multi-action IN-list the action string belongs to '
  '(phase0_5_suppression_list / phase5f_lifecycle_gate / phase7_queue_suppression_list), '
  'so a future CI guard searches the correct list rather than assuming a lone equality.';

-- -----------------------------------------------------------------------------
-- RLS: global-read reference metadata; writes via migrations only.
-- -----------------------------------------------------------------------------
alter table fte_action_effects enable row level security;

drop policy if exists fte_action_effects_select on fte_action_effects;
create policy fte_action_effects_select on fte_action_effects
  for select using (true);

-- -----------------------------------------------------------------------------
-- Seed — all 19 actions; multi-effect actions carry multiple rows.
-- Hand-transcribed from reconciler/fte_reconcile.sql and migrations 002-013.
-- -----------------------------------------------------------------------------
insert into fte_action_effects
  (action, category, phase, effect_type, shared_predicate_group,
   requires_notes, requires_amount, description, source_migration)
values
  -- ---- Accounting-effect: attach_corrected_value overrides the extracted amount
  --      in each phase that builds an amount-bearing event (COALESCE of the active
  --      corrected_value over the observed amount). Requires corrected_value (not
  --      lifecycle_amount), so requires_amount stays false.
  ('attach_corrected_value','accounting_effect','3','overrides_amount',NULL,
     false,false,
     'Overrides the billed/claim_adjudicated amount with the active corrected_value (Phase 3).','004'),
  ('attach_corrected_value','accounting_effect','4','overrides_amount',NULL,
     false,false,
     'Overrides the stored contractual_adjustment amount with the active corrected_value (Phase 4).','004'),
  ('attach_corrected_value','accounting_effect','4b','overrides_amount',NULL,
     false,false,
     'Overrides billed/allowed inputs to the derived contractual adjustment (Phase 4b).','004'),
  ('attach_corrected_value','accounting_effect','5c','overrides_amount',NULL,
     false,false,
     'Overrides the payment_applied amount with the active corrected_value (Phase 5c).','004'),
  ('attach_corrected_value','accounting_effect','5d','overrides_amount',NULL,
     false,false,
     'Overrides the patient_responsibility_assigned amount with the active corrected_value (Phase 5d).','004'),
  ('attach_corrected_value','accounting_effect','5e','overrides_amount',NULL,
     false,false,
     'Overrides the denial_posted amount with the active corrected_value (Phase 5e).','004'),

  -- ---- Accounting-effect: reject_payment_event suppresses the payment_applied
  --      event entirely (open_balance recalculates to full billed). Loaded via
  --      _fte_rejected_payment_event_claims (built from action='reject_payment_event').
  ('reject_payment_event','accounting_effect','5c','suppresses_event_type',NULL,
     true,false,
     'Suppresses payment_applied emission for the claim; observation stays trusted, open_balance recalculates to full billed (Phase 5c).','010'),

  -- ---- Accounting-effect (lifecycle pool): record_recovery / approve_write_off
  --      emit their event and consume from the per-claim cumulative gross-denied
  --      pool (recovered + written_off <= gross_denied), reducing NET denied_amount.
  --      Both share the Phase 5f gate IN-list. Require lifecycle_amount.
  ('record_recovery','accounting_effect','5f','emits_event','phase5f_lifecycle_gate',
     false,true,
     'Emits recovery_received and consumes from the per-claim gross-denied pool, reducing net denied_amount (Phase 5f).','012'),
  ('approve_write_off','accounting_effect','5f','emits_event','phase5f_lifecycle_gate',
     false,true,
     'Emits write_off_approved and consumes from the same per-claim gross-denied pool, reducing net denied_amount (Phase 5f).','012'),

  -- ---- Observation-suppression: reject_observation / mark_duplicate are loaded
  --      into _fte_suppressed_observations via the Phase 0.5 IN-list and excluded
  --      from Phase 1 classification entirely (no events/queue derived).
  ('reject_observation','observation_suppression','0.5','suppresses_observation','phase0_5_suppression_list',
     false,false,
     'Excludes the observation from Phase 1 classification entirely (loaded via the Phase 0.5 suppression IN-list).','002'),
  ('mark_duplicate','observation_suppression','0.5','suppresses_observation','phase0_5_suppression_list',
     false,false,
     'Excludes the duplicate observation from Phase 1 classification entirely (loaded via the Phase 0.5 suppression IN-list); canonical recorded via target_observation_id.','003'),

  -- ---- Queue-suppression only: confirm_observation (Phase 2 queue row for a
  --      non-trusted observation); confirm_short_pay / mark_position_resolved
  --      (Phase 7 unbalanced-position queue row, via the shared Phase 7 IN-list).
  --      None of these suppress the Phase 8 short_pay_detected event.
  ('confirm_observation','queue_suppression','2','suppresses_queue_reason',NULL,
     false,false,
     'Suppresses the Phase 2 review-queue row for a correctly-flagged non-trusted observation; no ledger/accounting effect.','002'),
  ('confirm_short_pay','queue_suppression','7','suppresses_queue_reason','phase7_queue_suppression_list',
     false,false,
     'Suppresses the Phase 7 unbalanced-position review-queue row; Phase 8 short_pay_detected still emits; position math unchanged.','006'),
  ('mark_position_resolved','queue_suppression','7','suppresses_queue_reason','phase7_queue_suppression_list',
     true,false,
     'Suppresses the Phase 7 unbalanced-position review-queue row (unbalanced only); Phase 8 short_pay_detected preserved; requires notes.','009'),

  -- ---- Queue AND event suppression: dismiss_short_pay — TWO rows. Shares the
  --      Phase 7 queue-suppression IN-list AND is the sole subject of the Phase 8
  --      short_pay_detected suppression (which confirm_short_pay / mark_position_resolved
  --      do NOT share). Position math is preserved in both phases.
  ('dismiss_short_pay','queue_and_event_suppression','7','suppresses_queue_reason','phase7_queue_suppression_list',
     false,false,
     'Suppresses the Phase 7 unbalanced-position review-queue row (shared IN-list); position math preserved.','005'),
  ('dismiss_short_pay','queue_and_event_suppression','8','suppresses_event_type',NULL,
     false,false,
     'Uniquely suppresses the Phase 8 short_pay_detected event (lone action check, not shared with confirm_short_pay / mark_position_resolved).','005'),

  -- ---- Status-only: confirm_payment_event promotes an ambiguous late/retry
  --      payment_applied event to reconciled (Phase 5); no amount/queue change.
  ('confirm_payment_event','status_only','5','promotes_status',NULL,
     false,false,
     'Promotes an ambiguous late/retry payment_applied event to reconciliation_status=reconciled (Phase 5); no amount or queue change.','010'),

  -- ---- Event-emission (non-monetary): file_appeal emits appeal_filed with a NULL
  --      amount. Shares the Phase 5f gate IN-list but takes the no-pool-consumption
  --      branch. Requires lifecycle_amount to be NULL.
  ('file_appeal','event_emission','5f','emits_event','phase5f_lifecycle_gate',
     false,false,
     'Emits a non-monetary appeal_filed event (Phase 5f); no pool consumption, no accounting effect.','012'),

  -- ---- Reporting-only: record_appeal_outcome emits no event and changes no
  --      accounting; Phase 5g only routes anomalies (outcome-without-appeal,
  --      conflicting-outcomes) to the review queue. Valid outcome read by explain.
  ('record_appeal_outcome','reporting_only','5g','routes_to_review_queue',NULL,
     false,false,
     'Reporting-only: Phase 5g routes outcome-without-appeal and conflicting-outcome anomalies to the review queue; valid single outcome read directly by fte_explain_claim; no event/accounting effect.','013'),

  -- ---- Durable-note: fully constrained/tested, but NO reconciler phase references
  --      the action string. Loaded in Phase 0.5 (counted) and read directly by
  --      humans / fte_explain_claim. phase='none'.
  ('assert_check_identity','durable_note','none','none',NULL,
     true,false,
     'Durable audit note: stores the canonical check/EFT identifier for a payment observation; no reconciler phase acts on it; requires notes + corrected_identifier.','011'),
  ('request_more_evidence','durable_note','none','none',NULL,
     true,false,
     'Durable workflow note that a claim needs more external evidence; no reconciler phase acts on it; requires notes.','007'),
  ('mark_position_needs_correction','durable_note','none','none',NULL,
     true,false,
     'Durable workflow note that a position has an extraction/attribution error to correct; no reconciler phase acts on it; requires notes.','008'),

  -- ---- Reserved / unimplemented: valid CHECK vocabulary, but no constraint
  --      migration and no reconciler wiring. confirm_position_balanced was
  --      deliberately deferred (Task 005C) to keep 'balanced' event-derived.
  --      phase='none'.
  ('resolve_contradiction','reserved_unimplemented','none','none',NULL,
     false,false,
     'Reserved vocabulary: no constraint migration and no reconciler wiring; intentionally dormant.','002'),
  ('confirm_position_balanced','reserved_unimplemented','none','none',NULL,
     false,false,
     'Reserved vocabulary: deliberately deferred (Task 005C) so that balanced stays purely event-derived; no reconciler wiring.','002'),
  ('override_position_status','reserved_unimplemented','none','none',NULL,
     false,false,
     'Reserved vocabulary: no constraint migration and no reconciler wiring; intentionally dormant.','002')
on conflict (action, phase, effect_type) do nothing;

-- =============================================================================
-- End of migration 014.
-- =============================================================================

commit;
