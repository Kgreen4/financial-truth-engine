# Financial Truth Engine — Project State

Operational handoff. Concise by design.

## Repository
- **Repo:** `Kgreen4/financial-truth-engine`
- **main HEAD:** `52bd329` (Task 019B merged)
- FTE now lives at the **repository root** — formerly the `financial-truth-engine/` subdirectory of `n2n-portal`, promoted to root on import.
- **Do not use `Kgreen4/n2n-portal` for FTE anymore.** That repo is the separate **client / exodus** project and is not part of FTE.

## Expected root layout
- `migrations/` — schema migrations (001–013)
- `reconciler/` — `fte_reconcile.sql`, `fte_explain_claim.sql`, `fte_mock_extract_observations.sql`
- `tests/` — validation suites + `RUNBOOK.md` + `run_all_validations.sql`
- `README.md`, `README_SCHEMA.md`, `NEXT_STEPS.md`

## Progress
- **Completed through Task 019B** (merged via PR #8).
- **Current validation baseline:** 329 PASS across twenty-four suites.
- **Next:** awaiting next written task spec. Likely candidates from deferred design list:
  - Observation/extraction-driven recovery
  - Reviewer-supplied appeal deadline override (deferred from 019A)
  - Denial knowledge trace/governance
  - Appeal outcome automation (deferred)
  - Deadline-driven review-queue automation (deferred from 019A)

## Key completed milestones
- **014B** — core denial accounting (`denial_posted`, `denied_amount`).
- **014D** — recoverable-amount overlay (reporting-only).
- **014E2** — claim-explanation ledger fields.
- **015A** — fixture observation-insert hardening.
- **016A** — project-status refresh.
- **017A** — denial-lifecycle design.
- **017B** — denial-lifecycle schema (migration 012).
- **017C** — denial-lifecycle reconciler (appeal / recovery / write-off).
- **017D** — denial-lifecycle explain/reporting fields (reporting-only).
- **017S** — project state handoff doc.
- **017T** — repo hygiene (`.gitignore`).
- **018A** — appeal-outcome design (reporting/workflow-only; no accounting effects).
- **018B** — appeal-outcome schema (migration 013; `record_appeal_outcome` action, `appeal_outcome` column).
- **018C** — appeal-outcome reconciler/reporting derivation (Phase 5g; anomaly routing for outcome-without-appeal and conflicting outcomes).
- **018D** — appeal-outcome explain surfacing (`appeal_outcome` key in `fte_explain_claim`).
- **018S** — project state handoff doc, refreshed through 018D.
- **019A** — appeal window/deadline enrichment design (reporting-only; no migration needed, `fte_denial_knowledge.appeal_window_days` already existed).
- **019B** — appeal window/deadline explain surfacing (`appeal_window_days`, `appeal_deadline`, `appeal_deadline_status` keys in `fte_explain_claim`). No migration. No reconciler/accounting change.

## Accounting model notes
- **Money-moving lifecycle levers:** `record_recovery` and `approve_write_off` only. These reclassify from the gross denied pool.
- **Reporting-only lifecycle actions:** `file_appeal` (marker), `record_appeal_outcome` (disposition). Neither changes `denied_amount`, `open_balance`, or any monetary position.
- `denied_amount` = gross denied − recovered − written_off (net).
- `open_balance` is computed on gross denied (unchanged by lifecycle reclassifications).
- `recovered + written_off ≤ gross_denied` (shared pool cap).

## Appeal window / deadline notes (Task 019B)
- **Reporting-only.** `appeal_window_days`, `appeal_deadline`, `appeal_deadline_status` are read-only projections in `fte_explain_claim` — no accounting, status, or review-routing effect.
- **Deadline anchor:** `denial_posted.event_date`. No reviewer-supplied override exists yet (deferred).
- **Resolution:** independent specificity-scored join against `fte_denial_knowledge.appeal_window_days` (practice/payer/carc/rarc), decoupled from the `recoverable_amount` overlay. Unanimous top-score match required; conflicts and NULL-window matches fail closed to `unknown`.
- **Multi-denial claims:** the earliest non-null computed deadline across all of the claim's `denial_posted` events is surfaced at the claim level.
- **No migration required** — `fte_denial_knowledge.appeal_window_days` already existed in migration 001, previously unused.

## Safety rails
- No PHI, no credentials, no project refs, no real identifiers, no `raw_text`, no evidence quotes.
- Synthetic fixtures only; **disposable-test** database only.
- **No Docker.** Use direct `psql` (`C:\Program Files\PostgreSQL\17\bin\psql.exe` if not on PATH).
- Feature branches; push explicitly; validate before review; no merge before validation.

## Open blockers
- None.
