# ADR-001: CI and Agent Operating Guardrails

**Status:** Accepted
**Date:** 2026-07-11
**Task:** 020A

---

## Decision

Add an executable CI layer (GitHub Actions) that applies migrations and runs
the full validation suite on every push/PR, plus a repo-native agent
operating contract (`AGENTS.md`). CI enforces two things mechanically:
zero SQL errors, and a PASS count that never drops below the current
baseline (329). No autonomous agent behavior is introduced. This is a
guardrail layer, not an automation layer.

---

## Context

Through Task 019B this repository accumulated 329 hand-run validation checks
across twenty-four suites, all executed manually against a disposable
Supabase/Postgres database by whoever ran the task. Nothing mechanically
verifies that:

- migrations still apply cleanly in order on a fresh database,
- the full validation suite still passes after a change,
- the PASS count hasn't silently regressed,
- no legacy `eob_*` reference, secret, project ref, or PHI-shaped fixture
  value has been introduced.

Every guarantee up to this point has depended on the human or agent running
the task correctly following `tests/RUNBOOK.md` by hand. That does not scale
and does not catch a mistake before it merges.

## Why Ruflo / a swarm framework was not adopted

This stack is Postgres/Supabase + PL/pgSQL + SQL migrations + SQL validation
suites + a Python extractor script (stdlib + `psycopg2`, unit-tested with
plain `unittest`). It has no Node/Bun/TypeScript surface, no Zod schemas, no
multi-agent orchestration need. Adopting Ruflo, a generic Node/Bun/Zod
AGENTS template, or any swarm-coordination framework would import a stack and
an operating model this repo does not have and does not need, purely to
satisfy a fashionable pattern. The existing task-by-task, spec-approved,
single-agent workflow already works and is auditable. This ADR does not
change that workflow — it adds a mechanical check under it.

## Why CI comes before autonomy

The standing hard rules in `AGENTS.md` already say AI observations are not
financial truth and financial positions must stay deterministic and
auditable. Those rules protect the ledger from bad *data*. They do not yet
protect the *repository* from a bad *change* — a migration that silently
breaks on a clean database, a regression that drops the PASS count, a
constraint change that quietly weakens an invariant. CI closes that gap
mechanically, without requiring a human to remember to run
`tests/run_all_validations.sql` correctly every time.

Introducing any autonomous or self-patching agent capability (schema
auto-patching, AI-confidence-driven auto-reconciliation, agents editing
their own guardrail files) before this mechanical safety net exists would be
backwards: it would give a less-supervised actor more room to make an
unverified change stick. CI must exist first. Autonomy, if it is ever added,
is a separate future decision requiring its own ADR and Keith's explicit
approval — not a byproduct of adding CI.

---

## Database strategy: vanilla Postgres (Option A)

Enumerated Supabase-specific dependencies across `migrations/*.sql`,
`fixtures/*.sql`, `reconciler/*.sql`, and `tests/*.sql`:

| Dependency | Found? | Detail |
|---|---|---|
| `auth.uid()` / `auth` schema | **No** (comment only) | `migrations/001` defines `fte_accessible_practice_ids()` as a deny-by-default RLS stub; the one `auth.uid()` reference is inside a comment showing how a *future* real deployment might wire it — it is never called. |
| `anon` / `authenticated` / `service_role` / `supabase_admin` roles | **No** | Zero `GRANT ... TO` statements anywhere in the repo. RLS policies reference no specific role; comments explain that Supabase's `service_role` (BYPASSRLS) is how migrations/fixtures/validations run in a real Supabase deployment, but nothing in executable SQL requires that role to exist. |
| RLS policies | **Yes, but vanilla** | `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and `CREATE POLICY` are standard PostgreSQL, not Supabase-specific. They work identically against a plain `postgres` image. |
| Supabase-only extensions | **No** | The only extension required is `pgcrypto` (`migrations/001`, for `gen_random_uuid()`), which ships in the official `postgres` Docker image's contrib set. |
| `storage.*`, `net.*`, `vault.*` schemas | **No** | Zero references anywhere in the repo. |

**Conclusion: this schema has no real Supabase dependency.** Confirmed
locally: `apply_migrations.sh` + `run_all_validations.sql` run clean against
a vanilla `postgres` connection with no Supabase project involved.

**Decision: Option A — vanilla Postgres**, via GitHub Actions' `postgres`
service container (official `postgres` image). No Supabase project, no
Supabase CLI, no `supabase/postgres` image, and no `ci/bootstrap.sql` shim
are needed — migration 001 already creates the one extension the schema
requires. This is the simplest path that actually runs and it is what CI
uses.

---

## What CI covers

- **Guardrails job:** `scripts/guards/check_forbidden_refs.sh`,
  `scripts/guards/check_no_secrets_or_phi.sh`, and the extractor's existing
  Python unit test suite (`extractor/tests/`, 49 tests, stdlib-only, zero
  network, zero secrets — added as a near-zero-cost extra step in this job,
  beyond the Task 020A minimum, because it was already free to run and
  catches extractor regressions with no CI cost).
- **Database job:** applies `migrations/001`–`013` in order against a fresh
  `postgres` service container, registers the three reconciler functions,
  then runs `tests/run_all_validations.sql` and asserts:
  - psql itself did not exit with a fatal/connection error,
  - zero `psql:<file>:<line>: ERROR:` lines appear in the output,
  - the parsed `PASS [n/N]` count is `>= 329` (the current baseline).
- Runs on every `push` and `pull_request`.

## What CI does not cover

- No live OpenAI/API calls of any kind — the extractor's provider adapters
  are exercised only via their existing mocked-client unit tests.
- No Supabase-hosted database, no disposable-test Supabase project, no
  production data of any kind.
- No UI, no Edge Functions (none exist yet).
- No enforcement of documentation freshness (`PROJECT_STATE.md`,
  `README.md`, etc.) — that remains a human/task-spec responsibility.
- No autonomous remediation. CI reports red; it does not attempt to fix
  anything.

---

## Human-owned guardrail files

The following files are **human-owned guardrails**. An agent must not modify
them as a side effect of unrelated work, and must not weaken, disable, or
route around them without a separate, explicitly-approved written task spec
naming the file:

- `AGENTS.md`
- `CLAUDE.md`
- `.github/workflows/ci.yml`
- `scripts/guards/check_forbidden_refs.sh`
- `scripts/guards/check_no_secrets_or_phi.sh`
- `docs/adr/*` (ADRs are amended by new ADRs, not silently edited)

**Agents must not auto-update their own guardrails outside explicit written
approval.** If a guardrail appears wrong or needs to change, the correct
response is to stop and report it, not to edit it inline.

---

## No live AI/API secrets in CI

`.github/workflows/ci.yml` requires no repository secrets. It does not
reference `OPENAI_API_KEY`, any Supabase service-role key, or any other
live-call-capable credential. The `postgres` service container uses a fixed
local, non-sensitive password (`postgres`) scoped to the ephemeral CI
runner only — this is standard practice for CI database containers and is
not a production credential.

---

## Future placeholder: Task 020C — reviewer-action effects table

A follow-on task (**020C**, not started, no spec written yet) should extend
CI's guardrail coverage with a machine-checkable **reviewer-action effects
table**: a single source of truth enumerating, for every
`fte_review_resolutions.action` value, exactly which reconciler
phase(s) it affects (if any) and which it explicitly does not — mirroring
the contrast tables already hand-maintained in `reconciler/README.md` §5.14
and `README_SCHEMA.md`. That table could then be asserted against the
reconciler source (e.g. grepping for each action string in
`reconciler/fte_reconcile.sql` and confirming it only appears in the phases
the table says it should) as an additional CI guard. This is intentionally
out of scope for 020A.
