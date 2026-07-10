# Financial Truth Engine — Project State

Operational handoff. Concise by design.

## Repository
- **Repo:** `Kgreen4/financial-truth-engine`
- **Clean import commit (through 017C):** `8b76a22677dc6d529e50e2deec86b2d26846486c`
- FTE now lives at the **repository root** — formerly the `financial-truth-engine/` subdirectory of `n2n-portal`, promoted to root on import.
- **Do not use `Kgreen4/n2n-portal` for FTE anymore.** That repo is the separate **client / exodus** project and is not part of FTE.

## Expected root layout
- `migrations/` — schema migrations (001–012)
- `reconciler/` — `fte_reconcile.sql`, `fte_explain_claim.sql`, `fte_mock_extract_observations.sql`
- `tests/` — validation suites + `RUNBOOK.md` + `run_all_validations.sql`
- `README.md`, `README_SCHEMA.md`, `NEXT_STEPS.md`

## Progress
- **Completed through Task 017D** (merged via PR #1).
- **Current validation baseline:** 304 PASS.
- **Next:** `.gitignore` hygiene (add `.env*`, `__pycache__/`, `.pytest_cache/`) before any local env files are created here; then the next denial-lifecycle slice per `NEXT_STEPS.md` / the 017A deferred list.

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

## Safety rails
- No PHI, no credentials, no project refs, no real identifiers, no `raw_text`, no evidence quotes.
- Synthetic fixtures only; **disposable-test** database only.
- **No Docker.** Use direct `psql` (`C:\Program Files\PostgreSQL\17\bin\psql.exe` if not on PATH).
- Feature branches; push explicitly; validate before review; no merge before validation.

## Open blockers
- None.
