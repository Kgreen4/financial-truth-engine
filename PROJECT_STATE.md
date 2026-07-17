# Financial Truth Engine — Project State

Operational handoff. Concise by design.

## Repository
- **Repo:** `Kgreen4/financial-truth-engine`
- **main HEAD:** `cc9155b` or newer (Task 024S final MVP state refresh; RCM-SETUP-001 follows)
- FTE now lives at the **repository root** — formerly the `financial-truth-engine/` subdirectory of `n2n-portal`, promoted to root on import.
- **Do not use `Kgreen4/n2n-portal` for FTE anymore.** That repo is the separate **client / exodus** project and is not part of FTE.

## Expected root layout
- `migrations/` — schema migrations (001–014; 014 = `fte_action_effects` reference table)
- `reconciler/` — `fte_reconcile.sql`, `fte_explain_claim.sql`, `fte_mock_extract_observations.sql`, `fte_claim_report.sql`, `fte_practice_report.sql`
- `tests/` — validation suites + `RUNBOOK.md` + `run_all_validations.sql` + `validate_mvp_runner.sh` (shell)
- `scripts/ci/` — `apply_migrations.sh`, `run_validations.sh` (CI-callable; also runnable locally)
- `scripts/guards/` — `check_forbidden_refs.sh`, `check_no_secrets_or_phi.sh`, `check_action_effects_consistency.sh`
- `scripts/mvp/` — `run_mvp.sh` (one-command MVP demo → Financial Truth Report)
- `.github/workflows/ci.yml` — CI workflow (push + pull_request)
- `docs/agent_reviews/` — shared review queue for Claude/Codex/Keith collaboration (`claude/`, `codex/`, `resolved/`)
- `docs/adr/` — architecture decision records (ADR-001: CI and agent guardrails)
- `AGENTS.md` — standing agent operating contract; `CLAUDE.md` — pointer to `AGENTS.md`
- `README.md`, `README_SCHEMA.md`, `NEXT_STEPS.md`

## Progress
- **Completed through Task 024B** (MVP report wording finalized; merged via PR #26). Docs/state refreshed in this 024S pass.
- **MVP v0.1 is demo-ready.** The Financial Truth Report is fully business-readable — no remaining debug/internal syntax — while every audit value (match status, confidence score, denial code/payer scope, governance category/action/owner) is preserved.
- **The MVP is demonstrable with one command:** `scripts/mvp/run_mvp.sh` loads the synthetic MVP batch, reconciles, and writes a human-readable **Financial Truth Report** (balanced claims, a short-pay review exception, a recoverable denial with an open appeal deadline, an expired one, and denial-knowledge trace summaries). Proven in CI on a fresh database. CI (023E) also publishes the generated report as a GitHub Actions artifact (`financial-truth-mvp-report`), so it can be reviewed without a local disposable-test `DATABASE_URL`.
- **024A/024B polished the report for demo readability** (no engine/accounting change): an **Executive summary** line (review-exception count, recoverable-denial opportunity, open-appeal-deadline count); clarified summary labels **"Financially balanced"** and **"Total recoverable denied amount"** (024A); and, finalized in 024B, fully business-readable trace phrasing — **"matched with high confidence (10/10)"** in place of the raw `(confidence score N)` form, **"on denial code X and any payer"** in place of raw `scope=[carc=... payer=...]` syntax, **"category: ..., recommended action: ..., owner: ..."** in place of `rule: category=... action=... owner=...`, and **"This matches the recorded recoverable amount."** in place of the raw true/false consistency footer. All underlying audit values (`match_status`, `match_score`, `matched_scope`, `rule_governance`) are preserved unchanged — only surrounding wording changed.
- **Current validation baseline:** 384 SQL PASS across twenty-six suites (365 + 19 MVP-report checks in `validate_mvp_report.sql` — 14 from 023B, +3 in 024A, +2 in 024B) **plus** the shell MVP-runner smoke test (`tests/validate_mvp_runner.sh`, 10/10 — shell-only, does not affect the SQL count). CI floor is now `MIN_PASS_COUNT: 384`. CI remains green; the MVP report artifact still uploads on every run.
- **Active client-delivery work (RCM-SETUP-001): First Paid RCM Revenue Leak Audit.** A cardiology practice client has agreed to the founder audit offer (no client name, no PHI in repo). Invoice has been sent; export checklist has been sent; awaiting Ethizo / clearinghouse / deposit-log export headers or de-identified samples. Current RCM docs: `docs/RCM_OVERSIGHT_AUDIT_PLAN.md`, `docs/RCM_30_DAY_DELIVERY_PLAN.md`, `docs/RCM_EXPORT_REQUEST_CHECKLIST.md`, and empty header-only template `docs/RCM_EXPORT_FIELD_MAP.md`.
- **Dual-agent operating model:** Claude reviews pushed GitHub artifacts and product/report clarity; Codex implements locally in the repo; Keith approves scope, client-facing conclusions, and any findings before implementation or delivery. Shared review folders live under `docs/agent_reviews/` (`claude/`, `codex/`, `resolved/`) with `.gitkeep` markers and README guidance.
- **Next: demo review, packaging, and audience feedback** on the finalized MVP report — not new engine internals. Deferred design-list candidates remain (post-MVP):
  - Observation/extraction-driven recovery
  - Reviewer-supplied appeal deadline override (deferred from 019A)
  - Persisted reconcile-time denial-knowledge provenance (deferred 022X — reconciler + migration; would make the `recoverability_trace.consistent` flag fully authoritative)
  - Appeal outcome automation (deferred)
  - Deadline-driven review-queue automation (deferred from 019A)
  - Runtime consultation of `fte_action_effects` by the reconciler (deferred from 021A — higher-risk control-flow change, requires its own design + approval)

## CI (Task 020A; guard added + floor raised in 021C)
- **Active on `push` and `pull_request`** — `.github/workflows/ci.yml`.
- **Jobs:**
  - `Guardrails / static checks` — `scripts/guards/check_forbidden_refs.sh`, `scripts/guards/check_no_secrets_or_phi.sh`, `scripts/guards/check_action_effects_consistency.sh` (021C), extractor Python unit tests (`extractor/tests/`, 49 tests, stdlib-only).
  - `Migrations + validation suites` — applies migrations 001–014 in order against a fresh **vanilla `postgres:16`** GitHub Actions service container, registers the reconciler + report functions, runs `tests/run_all_validations.sql`, and asserts zero SQL errors and a PASS count `>= 384` (`MIN_PASS_COUNT`, raised 329→339 in 021C, 339→351 in 022B, 351→365 in 022C, 365→379 in 023B, 379→382 in 024A, 382→384 in 024B; fails if the count drops below baseline). A final step runs the **MVP runner smoke test** (`tests/validate_mvp_runner.sh`, 023C) — shell-only, so it does not change `MIN_PASS_COUNT`. A further step (023E) generates the MVP report to a stable path and uploads it as the `financial-truth-mvp-report` CI artifact.
- **Database strategy:** vanilla Postgres, not Supabase — this schema has no real Supabase dependency (only `pgcrypto`, which ships with the official `postgres` image; `auth.uid()` appears only in a comment, never called; zero `anon`/`authenticated`/`service_role` grants anywhere). Full enumeration in `docs/adr/ADR-001-ci-and-agent-guardrails.md`.
- **No live AI/API secrets in CI.** No `OPENAI_API_KEY`, no Supabase service-role key, no repository secrets required.
- Verified green on genuine fresh-database runs (not just locally): baseline `384 PASS, 0 errors, exit 0`, plus `validate_mvp_runner.sh: PASSED (10/10)`, plus the MVP report artifact still uploads.

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
- **021S** — project state handoff doc, refreshed through the 021 arc.
- **022A** — denial-knowledge trace & governance design (explain-only re-derived traces; persisted provenance deferred as 022X).
- **022B** — `recoverability_trace` in `fte_explain_claim` (per-denial re-derived Phase 6b match + stored-vs-re-derived `consistent` flag; +12 checks → 351; CI floor 339 → 351). Explain-only; no migration/reconciler/accounting change.
- **022C** — `appeal_window_trace` in `fte_explain_claim` (driving-denial descriptor for the surfaced window/deadline; independent of `recoverability_trace`; +14 checks → 365; CI floor 351 → 365). Explain-only; no migration/reconciler/accounting change.
- **022D/S** — denial-knowledge-trace documentation (`README_SCHEMA.md` Invariant 19) + state refresh. Docs-only.
- **023A** — MVP vertical-slice design (identified the human-readable report as the genuine gap; steps ingest/reconcile/review/explain/trace already worked).
- **023B** — MVP report renderer: `fixtures/synthetic_mvp_batch.sql`, `fte_claim_report`, `fte_practice_report`, `tests/validate_mvp_report.sql` (+14 checks → 379; CI floor 365 → 379). No migration; no `fte_reconcile.sql`/`fte_explain_claim.sql`/accounting change (reports only render existing data).
- **023C** — one-command MVP runner/export (`scripts/mvp/run_mvp.sh`) + shell smoke test (`tests/validate_mvp_runner.sh`, wired into CI). SQL floor unchanged at 379 (shell-only validation). No SQL logic change.
- **023D/S** — MVP runner documentation (`README.md` Quick Start) + `mvp_output/` gitignore + a state refresh. Docs-only.
- **023E** — publish the MVP report as a CI artifact (`financial-truth-mvp-report`, `.github/workflows/ci.yml` only) so it can be reviewed without a local disposable-test `DATABASE_URL`. SQL floor unchanged at 379. No SQL/migration/reconciler/explain/accounting change.
- **024A** — MVP report wording polish: Executive summary line; clarified "Financially balanced" / "Total recoverable denied amount" labels; business-readable trace phrasing ("confidence score", "→ rule: category=... action=... owner=..."), preserving every audit value. `+3` checks in `validate_mvp_report.sql` (14 → 17; CI floor 379 → 382). No migration; no `fte_reconcile.sql`/`fte_explain_claim.sql`/accounting change.
- **024S** — state refresh (docs/state only) covering 023E + 024A.
- **025A** — context hygiene practice: `docs/CONTEXT_HYGIENE.md` (durable/ephemeral split, clean-handoff triggers, stop-after-2-failures rule, six-section handoff template), `AGENTS.md` pointer, and a bounded "Known traps / do not repeat" section in this file. Docs-only.
- **024B** — MVP report wording finalized: "matched with high confidence (10/10)" replaces the raw `(confidence score N)` form; "on denial code X and any payer" replaces raw `scope=[carc=... payer=...]` syntax; "category: ..., recommended action: ..., owner: ..." replaces `rule: category=... action=... owner=...`; "This matches the recorded recoverable amount." replaces the raw true/false consistency footer. `+2` checks in `validate_mvp_report.sql` (17 → 19, including a regression guard against old raw syntax reappearing; CI floor 382 → 384). No migration; no `fte_reconcile.sql`/`fte_explain_claim.sql`/accounting change. **MVP v0.1 is demo-ready.**
- **024S** — this state refresh (docs/state only) covering the final 024B report-wording polish, baseline 382 → 384.

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

## Denial-knowledge traces (Task 022 arc)
- **`fte_explain_claim`** surfaces two independent, **reporting/explain-only** governance objects showing *which* `fte_denial_knowledge` rule drove a derived value: `recoverability_trace` (022B) and `appeal_window_trace` (022C).
- Both **re-derive the current `fte_denial_knowledge` match inline at explain time** (identical specificity `practice+8 / payer+4 / carc+2 / rarc+1`, unanimous top-score or fail-closed). Nothing is persisted; `fte_reconcile.sql` is unchanged; no runtime consumer.
- **Primary audit explanation:** `matched_scope` + `match_score` + `rule_governance` (the rule's category/subcategory/default_action/default_owner/evidence_requirements). **`denial_knowledge_id` is secondary/opaque** (synthetic, volatile across re-seeds).
- The two traces are **independent and may select different rules for the same denial** — the appeal-window match additionally filters `appeal_window_days IS NOT NULL`.
- `recoverability_trace` echoes stored vs re-derived `recoverable_amount` with a `consistent` flag (surfaces drift if knowledge is edited after reconcile). **Persisted reconcile-time provenance remains deferred (022X).**
- **No accounting/status/review-routing/event-emission behavior changed.** Documented in `README_SCHEMA.md` Invariant 19.

## MVP demo (Task 023 arc, finalized in 024A/024B — MVP v0.1 demo-ready)
- **One command:** `FTE_DB_TARGET_LABEL=disposable-test DATABASE_URL=… scripts/mvp/run_mvp.sh [output_file]` (default output `mvp_output/financial_truth_report.md`, git-ignored).
- Loads `fixtures/synthetic_mvp_batch.sql` (practice `a4…fe`, 5 claims; denial knowledge is **practice-scoped** with MVP-only CARC codes, so it never contaminates other practices), reconciles, and renders `fte_practice_report` → a markdown/plain-text **Financial Truth Report**.
- The report shows balanced claims, a short-pay **NEEDS REVIEW** exception, a **recoverable** denial with an **open** appeal deadline, an **expired** one, and the recoverability + appeal-window **trace summaries** (governing rule via `matched_scope`/`match_score`/`rule_governance`).
- **024A/024B polish (demo readability, no engine change):** an **Executive summary** line near the top (review-exception count, recoverable-denial opportunity, open-appeal-deadline count); clarified summary labels **"Financially balanced"** and **"Total recoverable denied amount"** (024A); trace lines fully reworded for a business reader (024B, finalized) — **"matched with high confidence (10/10) on denial code X and any payer → category: ..., recommended action: ..., owner: ..."**, and **"This matches the recorded recoverable amount."** in place of the raw true/false footer — while every audit value (`match_status`, `match_score`, `matched_scope`, `rule_governance`) is preserved unchanged. No raw debug syntax (`scope=[...]`, `(confidence score N)`, `rule: category=...`) remains anywhere in the report.
- **No local DB required to review it:** CI (023E) uploads the generated report as the `financial-truth-mvp-report` GitHub Actions artifact on every run.
- `fte_claim_report` / `fte_practice_report` are `CREATE OR REPLACE` functions registered by `apply_migrations.sh` — **read-only**; they render existing materialized data and change no accounting/status/event behavior.
- Safety: refuses unless `FTE_DB_TARGET_LABEL=disposable-test`; requires `DATABASE_URL` but never prints it; synthetic-only, no AI.

## Safety rails
- No PHI, no credentials, no project refs, no real identifiers, no `raw_text`, no evidence quotes.
- Synthetic fixtures only; **disposable-test** database only.
- **No Docker** for local human/agent use. (CI's `postgres:16` GitHub Actions service container is the one sanctioned exception — it runs entirely inside the CI runner, not locally.)
- Use direct `psql` (`C:\Program Files\PostgreSQL\17\bin\psql.exe` if not on PATH).
- Feature branches; push explicitly; validate before review; no merge before validation.
- CI guard scripts (`scripts/guards/*`) provide a mechanical backstop for secrets/project-ref/legacy-`eob_`/PHI-shaped-fixture checks — they supplement, not replace, review.

## Known traps / do not repeat (Task 025A)
Bounded list of genuinely discovered environment/tooling gotchas — not a
restatement of rules already in `AGENTS.md`/`CLAUDE.md`, and not a log of
every task-level mistake (those stay in ephemeral session handoffs, see
`docs/CONTEXT_HYGIENE.md`). Compress or remove entries once no longer
relevant; keep this list short (~10 entries max).
- Local Bash-tool sessions do not reliably inherit `setx`'d Windows env vars
  (`DATABASE_URL`, `FTE_DB_TARGET_LABEL`) without a full app/session relaunch
  — do not assume a newly-set var is visible without re-checking it first.
- Do not search shell history, profiles, dotfiles, or any credential
  locations to discover how `DATABASE_URL` was previously configured.
- If local `DATABASE_URL` setup blocks MVP report review, use the CI
  artifact path instead (023E: `financial-truth-mvp-report` uploads on every
  `main`/PR run) rather than spending further time on local env plumbing.
- Docker is not available for local human/agent use; CI's `postgres:16`
  service container is the sanctioned exception (runs only inside the CI
  runner).
- The git remote name for this checkout is `origin`, not `github` — verify
  with `git remote -v` before assuming a remote name from another worktree's
  convention.
- SQL PASS floor is currently 384 (twenty-six suites); the MVP runner shell
  smoke test (`tests/validate_mvp_runner.sh`, 10/10) is a separate,
  shell-only check that does not contribute to the SQL PASS count.
- Generated MVP reports belong under `mvp_output/` and are git-ignored — do
  not commit them.

## Open blockers
- None.
