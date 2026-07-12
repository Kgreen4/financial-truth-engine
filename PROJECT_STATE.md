# Financial Truth Engine — Project State

Operational handoff. Concise by design.

## Repository
- **Repo:** `Kgreen4/financial-truth-engine`
- **main HEAD:** `8d7a9aa4` (Task 020A merged)
- FTE now lives at the **repository root** — formerly the `financial-truth-engine/` subdirectory of `n2n-portal`, promoted to root on import.
- **Do not use `Kgreen4/n2n-portal` for FTE anymore.** That repo is the separate **client / exodus** project and is not part of FTE.

## Expected root layout
- `migrations/` — schema migrations (001–013)
- `reconciler/` — `fte_reconcile.sql`, `fte_explain_claim.sql`, `fte_mock_extract_observations.sql`
- `tests/` — validation suites + `RUNBOOK.md` + `run_all_validations.sql`
- `scripts/ci/` — `apply_migrations.sh`, `run_validations.sh` (CI-callable; also runnable locally)
- `scripts/guards/` — `check_forbidden_refs.sh`, `check_no_secrets_or_phi.sh`
- `.github/workflows/ci.yml` — CI workflow (push + pull_request)
- `docs/adr/` — architecture decision records (ADR-001: CI and agent guardrails)
- `AGENTS.md` — standing agent operating contract; `CLAUDE.md` — pointer to `AGENTS.md`
- `README.md`, `README_SCHEMA.md`, `NEXT_STEPS.md`

## Progress
- **Completed through Task 020A** (merged via PR #10).
- **Current validation baseline:** 329 PASS across twenty-four suites (unchanged by 020A — guardrails/CI only, no accounting/reconciler/explain/migration behavior changed).
- **Next:** awaiting next written task spec. Likely candidates from deferred design list:
  - Observation/extraction-driven recovery
  - Reviewer-supplied appeal deadline override (deferred from 019A)
  - Denial knowledge trace/governance
  - Appeal outcome automation (deferred)
  - Deadline-driven review-queue automation (deferred from 019A)
  - 020C — reviewer-action effects table CI guard (placeholder noted in ADR-001, no spec written yet)

## CI (Task 020A)
- **Active on `push` and `pull_request`** — `.github/workflows/ci.yml`.
- **Jobs:**
  - `Guardrails / static checks` — `scripts/guards/check_forbidden_refs.sh`, `scripts/guards/check_no_secrets_or_phi.sh`, extractor Python unit tests (`extractor/tests/`, 49 tests, stdlib-only).
  - `Migrations + validation suites` — applies migrations 001–013 in order against a fresh **vanilla `postgres:16`** GitHub Actions service container, registers the reconciler functions, runs `tests/run_all_validations.sql`, and asserts zero SQL errors and a PASS count `>= 329` (fails if the count drops below baseline).
- **Database strategy:** vanilla Postgres, not Supabase — this schema has no real Supabase dependency (only `pgcrypto`, which ships with the official `postgres` image; `auth.uid()` appears only in a comment, never called; zero `anon`/`authenticated`/`service_role` grants anywhere). Full enumeration in `docs/adr/ADR-001-ci-and-agent-guardrails.md`.
- **No live AI/API secrets in CI.** No `OPENAI_API_KEY`, no Supabase service-role key, no repository secrets required.
- Verified green on a genuine fresh-database run (not just locally): PR #10, run `29175256423` and subsequent runs — `329 PASS, 0 errors, exit 0`.

## Agent operating contract (Task 020A)
- `AGENTS.md` expanded with: Stack, Canonical Commands, Definition of Done, Work Tiers, Stop-and-Ask Rules — in addition to the pre-existing Hard Rules (unchanged, preserved verbatim).
- `CLAUDE.md` is a short pointer to `AGENTS.md` (single source of truth, avoids drift between two contract files).
- `docs/adr/ADR-001-ci-and-agent-guardrails.md` records the decision, including explicit rationale for **not** adopting Ruflo or any generic Node/Bun/Zod swarm-agent template (this repo's stack is Postgres/PL/pgSQL/SQL + a stdlib-only Python extractor — no Node/TS surface exists), and why CI had to exist before any autonomy is considered.
- **No autonomous schema-patching agents. No AI-confidence-based auto-reconciliation.** Both explicitly rejected in ADR-001 as out of scope; CI is a guardrail layer, not an automation layer.
- **Human-owned guardrail files** (`AGENTS.md`, `CLAUDE.md`, `.github/workflows/ci.yml`, `scripts/guards/*`, `docs/adr/*`): agents must not modify these as a side effect of unrelated work, and must not auto-update their own guardrails without a separate explicitly-approved task naming the file.

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
- **019S** — project state handoff doc, refreshed through 019B.
- **020A** — CI (GitHub Actions) + agent operating guardrails (`AGENTS.md` expansion, `CLAUDE.md`, ADR-001, guard scripts). No migration. No reconciler/explain/accounting change. Baseline (329) verified green on a fresh database in CI.

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
- **No Docker** for local human/agent use. (CI's `postgres:16` GitHub Actions service container is the one sanctioned exception — it runs entirely inside the CI runner, not locally.)
- Use direct `psql` (`C:\Program Files\PostgreSQL\17\bin\psql.exe` if not on PATH).
- Feature branches; push explicitly; validate before review; no merge before validation.
- CI guard scripts (`scripts/guards/*`) provide a mechanical backstop for secrets/project-ref/legacy-`eob_`/PHI-shaped-fixture checks — they supplement, not replace, review.

## Open blockers
- None.
