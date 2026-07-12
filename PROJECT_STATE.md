# Financial Truth Engine — Project State

Operational handoff. Concise by design.

## Repository
- **Repo:** `Kgreen4/financial-truth-engine`
- **main HEAD:** `2911d94` (Task 021D merged)
- FTE now lives at the **repository root** — formerly the `financial-truth-engine/` subdirectory of `n2n-portal`, promoted to root on import.
- **Do not use `Kgreen4/n2n-portal` for FTE anymore.** That repo is the separate **client / exodus** project and is not part of FTE.

## Expected root layout
- `migrations/` — schema migrations (001–014; 014 = `fte_action_effects` reference table)
- `reconciler/` — `fte_reconcile.sql`, `fte_explain_claim.sql`, `fte_mock_extract_observations.sql`
- `tests/` — validation suites + `RUNBOOK.md` + `run_all_validations.sql`
- `scripts/ci/` — `apply_migrations.sh`, `run_validations.sh` (CI-callable; also runnable locally)
- `scripts/guards/` — `check_forbidden_refs.sh`, `check_no_secrets_or_phi.sh`, `check_action_effects_consistency.sh`
- `.github/workflows/ci.yml` — CI workflow (push + pull_request)
- `docs/adr/` — architecture decision records (ADR-001: CI and agent guardrails)
- `AGENTS.md` — standing agent operating contract; `CLAUDE.md` — pointer to `AGENTS.md`
- `README.md`, `README_SCHEMA.md`, `NEXT_STEPS.md`

## Progress
- **Completed through Task 021D** (merged via PR #14).
- **Current validation baseline:** 339 PASS across twenty-five suites (329 + 10 from `validate_action_effects.sql`, added in 021C). CI floor is now `MIN_PASS_COUNT: 339`.
- **Next:** awaiting next written task spec. Likely candidates from deferred design list:
  - Observation/extraction-driven recovery
  - Reviewer-supplied appeal deadline override (deferred from 019A)
  - Denial knowledge trace/governance
  - Appeal outcome automation (deferred)
  - Deadline-driven review-queue automation (deferred from 019A)
  - Runtime consultation of `fte_action_effects` by the reconciler (deferred from 021A — higher-risk control-flow change, requires its own design + approval)

## CI (Task 020A; guard added + floor raised in 021C)
- **Active on `push` and `pull_request`** — `.github/workflows/ci.yml`.
- **Jobs:**
  - `Guardrails / static checks` — `scripts/guards/check_forbidden_refs.sh`, `scripts/guards/check_no_secrets_or_phi.sh`, `scripts/guards/check_action_effects_consistency.sh` (021C), extractor Python unit tests (`extractor/tests/`, 49 tests, stdlib-only).
  - `Migrations + validation suites` — applies migrations 001–014 in order against a fresh **vanilla `postgres:16`** GitHub Actions service container, registers the reconciler functions, runs `tests/run_all_validations.sql`, and asserts zero SQL errors and a PASS count `>= 339` (`MIN_PASS_COUNT`, raised from 329 in 021C; fails if the count drops below baseline).
- **Database strategy:** vanilla Postgres, not Supabase — this schema has no real Supabase dependency (only `pgcrypto`, which ships with the official `postgres` image; `auth.uid()` appears only in a comment, never called; zero `anon`/`authenticated`/`service_role` grants anywhere). Full enumeration in `docs/adr/ADR-001-ci-and-agent-guardrails.md`.
- **No live AI/API secrets in CI.** No `OPENAI_API_KEY`, no Supabase service-role key, no repository secrets required.
- Verified green on genuine fresh-database runs (not just locally): baseline `339 PASS, 0 errors, exit 0`.

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
- **020S** — project state handoff doc, refreshed through 020A.
- **021A** — reviewer action-effects table design (declarative catalog of reviewer-action semantics; documentation/CI-guard-only, runtime consultation deferred).
- **021B** — `fte_action_effects` reference table (migration 014; 25 hand-authored rows covering all 19 actions; multi-effect actions carry multiple rows). No reconciler/explain/accounting change; no runtime consumer.
- **021C** — action-effects consistency guard + validation suite (`scripts/guards/check_action_effects_consistency.sh` table-vs-reconciler; `tests/validate_action_effects.sql` table-vs-vocabulary, +10 checks → 339; CI floor raised 329 → 339). No reconciler/explain/accounting change.
- **021D** — reviewer-action documentation consolidation (`reconciler/README.md` §5.14/§5.16 and `README_SCHEMA.md` now point at `fte_action_effects` as the single source of truth). Docs-only.

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

## Reviewer action-effects reference (Task 021 arc)
- **`fte_action_effects`** (migration 014) is the authoritative, declarative catalog of reviewer-action semantics: for each of the 19 `fte_review_resolutions.action` values, which reconciler phase(s) it affects and how. Grain `(action, phase, effect_type)`; multi-effect actions (e.g. `dismiss_short_pay` = Phase 7 queue + Phase 8 event suppression) carry multiple rows. 25 rows total.
- **Documentation/CI-only.** No runtime consumer — the reconciler does **not** read `fte_action_effects`. Runtime consultation (reconciler consulting the table to decide behavior) is deliberately **deferred** (021A design) as a higher-risk control-flow change.
- **Hand-authored, never AI-inferred.** Rows are human-transcribed from `fte_reconcile.sql` and migrations 002–013.
- **CI-enforced against drift:** `check_action_effects_consistency.sh` asserts code-bearing actions appear (and durable-note/reserved actions do not) in `fte_reconcile.sql`, incl. the Phase 7/8 membership distinctions; `validate_action_effects.sql` asserts vocabulary coverage, row counts, categories, uniqueness, and no FK.
- The prose contrast tables previously in `reconciler/README.md` §5.14/§5.16 now point at this table (021D); `README_SCHEMA.md` Invariant 18 documents it.

## Safety rails
- No PHI, no credentials, no project refs, no real identifiers, no `raw_text`, no evidence quotes.
- Synthetic fixtures only; **disposable-test** database only.
- **No Docker** for local human/agent use. (CI's `postgres:16` GitHub Actions service container is the one sanctioned exception — it runs entirely inside the CI runner, not locally.)
- Use direct `psql` (`C:\Program Files\PostgreSQL\17\bin\psql.exe` if not on PATH).
- Feature branches; push explicitly; validate before review; no merge before validation.
- CI guard scripts (`scripts/guards/*`) provide a mechanical backstop for secrets/project-ref/legacy-`eob_`/PHI-shaped-fixture checks — they supplement, not replace, review.

## Open blockers
- None.
