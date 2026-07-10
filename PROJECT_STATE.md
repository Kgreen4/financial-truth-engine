# Financial Truth Engine — Project State

Operational handoff. Concise by design.

## Repository
- **Repo:** `Kgreen4/financial-truth-engine`
- **main HEAD:** `b740016` (Task 018D merged)
- FTE now lives at the **repository root** — formerly the `financial-truth-engine/` subdirectory of `n2n-portal`, promoted to root on import.
- **Do not use `Kgreen4/n2n-portal` for FTE anymore.** That repo is the separate **client / exodus** project and is not part of FTE.

## Expected root layout
- `migrations/` — schema migrations (001–013)
- `reconciler/` — `fte_reconcile.sql`, `fte_explain_claim.sql`, `fte_mock_extract_observations.sql`
- `tests/` — validation suites + `RUNBOOK.md` + `run_all_validations.sql`
- `README.md`, `README_SCHEMA.md`, `NEXT_STEPS.md`

## Progress
- **Completed through Task 018D** (merged via PR #6).
- **Current validation baseline:** 319 PASS across twenty-four suites.
- **Next:** awaiting next written task spec. Likely candidates from deferred design list:
  - Observation/extraction-driven recovery
  - Appeal window/deadline enrichment from denial knowledge
  - Denial knowledge trace/governance
  - Appeal outcome automation (deferred)

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

## Accounting model notes
- **Money-moving lifecycle levers:** `record_recovery` and `approve_write_off` only. These reclassify from the gross denied pool.
- **Reporting-only lifecycle actions:** `file_appeal` (marker), `record_appeal_outcome` (disposition). Neither changes `denied_amount`, `open_balance`, or any monetary position.
- `denied_amount` = gross denied − recovered − written_off (net).
- `open_balance` is computed on gross denied (unchanged by lifecycle reclassifications).
- `recovered + written_off ≤ gross_denied` (shared pool cap).

## Safety rails
- No PHI, no credentials, no project refs, no real identifiers, no `raw_text`, no evidence quotes.
- Synthetic fixtures only; **disposable-test** database only.
- **No Docker.** Use direct `psql` (`C:\Program Files\PostgreSQL\17\bin\psql.exe` if not on PATH).
- Feature branches; push explicitly; validate before review; no merge before validation.

## Open blockers
- None.
