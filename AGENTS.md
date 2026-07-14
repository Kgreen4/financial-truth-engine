# AGENTS.md — Financial Truth Engine

**Scope:** `financial-truth-engine/` only.
**Status:** Active separate initiative. The legacy EOB extraction project is frozen / reference-only.

This file is the standing contract for any future Codex / Claude Code / agent run that
touches this folder. Read it before doing anything.

---

## Hard Rules

1. **This effort is separate from the current EOB extraction project.**
   The legacy document-first EOB pipeline (GitLab `kgreen41-eob/cardio-metrics-saas`,
   and the `eob_*` / `eob_line_items` / `eob_payments` tables) is frozen. The Financial
   Truth Engine (FTE) is a clean, ledger-centered rebuild.

2. **Work only under `financial-truth-engine/` unless explicitly instructed otherwise.**
   Do not modify files outside this folder. Do not modify existing EOB extraction code,
   edge functions, migrations, or frontend.

3. **Do not reference or migrate old extracted EOB rows as truth.**
   No `INSERT ... SELECT` from `eob_*` tables. No foreign keys to legacy tables. The
   `fte_` schema must stand alone. Old extracted line items, payment rows, reconciliation
   patches, and one-off manual fixes are NOT financial truth and must not be carried forward.

4. **Never commit PHI or sensitive source material.** This repository is public.
   Do not commit:
   - raw EOB / ERA PDFs
   - production database exports
   - screenshots of live EOBs
   - patient names
   - member IDs
   - real claim numbers
   Use **synthetic or redacted fixtures only**. Real PDFs live in private, PHI-safe storage
   and are referenced by internal fixture ID only.

5. **AI observations are not financial truth.**
   Extraction produces *observations* (visible facts with confidence + evidence references),
   never final financial answers. Observations must never directly mutate
   `fte_financial_positions`.

6. **Claim events and financial positions must be deterministic and auditable.**
   `fte_financial_positions` are derived/materialized from `fte_claim_events` by
   deterministic reconciliation — not entered as source truth, not computed by AI.

7. **All financial conclusions must link back to evidence and/or observations.**
   Every `fte_claim_event` must be traceable through `fte_event_evidence` to at least one
   `fte_evidence` and/or `fte_observation` row. No evidence link → it goes to
   `fte_review_queue`, not into the ledger as fact.

8. **Make uncertainty explicit.** Conflicting, low-confidence, late/retry, duplicate,
   summary-row, and unbalanced cases are routed to `fte_review_queue`. They are never
   silently overwritten or patched.

---

## Stack

- **Database:** PostgreSQL (deployed on Supabase in practice; CI runs against
  vanilla `postgres` — see `docs/adr/ADR-001-ci-and-agent-guardrails.md`).
  No Supabase-only feature (`auth.*`, `storage.*`, `net.*`, `vault.*`, or any
  `anon`/`authenticated`/`service_role` grant) is depended on by executable
  SQL in this repo.
- **Schema/logic:** SQL migrations (`migrations/*.sql`, sequential,
  one-time DDL) and PL/pgSQL functions (`reconciler/fte_reconcile.sql`,
  `reconciler/fte_explain_claim.sql`, `reconciler/fte_mock_extract_observations.sql`
  — all `CREATE OR REPLACE`, safe to rerun).
  There is no ORM, no application backend framework, and no Node/Bun/TypeScript
  layer in this repo.
- **Validation:** hand-written SQL validation suites (`tests/*.sql`), each a
  `ROLLBACK`-wrapped `DO $$ ... $$` block emitting `RAISE NOTICE 'PASS [n/N] ...'`
  or `RAISE EXCEPTION 'FAIL [n/N] ...'`. Run together via
  `tests/run_all_validations.sql`.
- **Extraction:** a Python script + provider-adapter layer
  (`extractor/fte_extract_observations.py`, `extractor/providers/`), stdlib +
  `psycopg2` for the DB-writing entrypoint only. Unit tests
  (`extractor/tests/`, plain `unittest`, zero external deps, zero network,
  zero live API calls) exercise `preflight.py`, `schema_validator.py`, and the
  OpenAI adapter against a mocked client.
- **CI:** GitHub Actions (`.github/workflows/ci.yml`), plus the scripts under
  `scripts/ci/` and `scripts/guards/` that CI calls (and that also run
  identically on a developer machine).

Do not introduce Node/Bun/Zod/Plaid/SQLite tooling, Ruflo, or any
swarm/multi-agent orchestration framework into this repo — none of it matches
this stack, and adopting it would import complexity this repo does not need
(see ADR-001).

---

## Canonical commands

All commands assume `DATABASE_URL` is set to a disposable-test or CI Postgres
connection string. Never print `DATABASE_URL` to chat or logs; confirm it is
set by name only.

```bash
# Apply all migrations + register reconciler functions (idempotent to rerun
# reconciler files; migrations are one-time DDL — do not rerun against an
# already-migrated database).
scripts/ci/apply_migrations.sh

# Run the full validation suite and assert PASS-count / zero-error outcome.
scripts/ci/run_validations.sh

# Guard checks (no database required).
scripts/guards/check_forbidden_refs.sh
scripts/guards/check_no_secrets_or_phi.sh

# Extractor unit tests (no database, no network, no live API key required).
python -m unittest discover -s extractor/tests -t extractor
```

For the manual, human-in-the-loop Supabase SQL Editor workflow, see
`tests/RUNBOOK.md` — it remains the authoritative reference for that path.

---

## Context management

Use `docs/CONTEXT_HYGIENE.md` for context handoff practice. Prefer a clean
handoff + fresh session over `/compact` when a session's context becomes
noisy or repetitive. Do not commit live handoff notes unless explicitly
requested — they live under `../fte_local_artifacts/session_handoffs/` and
are ephemeral by design. `PROJECT_STATE.md` (including its bounded "Known
traps / do not repeat" section) remains the durable project truth.

---

## Definition of Done

A task is done only when all of the following are true:

- The written task spec's scope was followed exactly — no unrequested
  refactors, no drive-by cleanups, no scope creep into adjacent files.
- All SQL changes were validated against a disposable-test database (or, for
  CI-related changes, verified to run cleanly via the CI scripts) — not just
  read for correctness.
- `tests/run_all_validations.sql` passes with a PASS count at or above the
  documented baseline; any intentional count change is called out explicitly
  in the task report.
- No accounting/reconciler/explain behavior changed unless the task spec
  explicitly authorized it.
- No PHI, credentials, project refs, `raw_text`, evidence quotes, or real
  identifiers were introduced (guard scripts help catch this, but are not a
  substitute for reading the diff).
- `n2n-portal` was not touched.
- The task report states: changed files, validation result, commit SHA, push
  status, and explicit confirmations of the constraints above.
- Nothing was merged without Keith's review and explicit approval.

---

## Work tiers

1. **Design-only tasks** (e.g. 019A, 018A): produce a written design artifact.
   No code, no migration, no test changes, no branch required unless useful
   for inspection. Never merged as code — the *next* task implements the
   design.
2. **Implementation + validation tasks** (e.g. 017C, 019B, 020A): branch,
   implement exactly what the spec authorizes, validate against a
   disposable-test database (or CI scripts), commit, push. No PR opened
   unless the spec says to — Keith opens/merges PRs himself in the normal
   flow.
3. **Documentation-only tasks** (e.g. 017S, 018S, 019S): update the named
   doc file(s) only. No code, no migration, no DB commands required.
4. **Cleanup tasks** (e.g. branch deletion after merge): mechanical, low-risk,
   still reported (SHA, branch status, confirmations) — never silent.

A task never skips its own tier's constraints because a later tier would be
more convenient. If a design task discovers the "real" fix needs code, it
stops and recommends a follow-on implementation task instead of writing code.

---

## Stop-and-ask rules

Stop and report back — do not proceed or guess — when:

- A task spec is ambiguous about scope, target files, or expected behavior.
- Making a change would require touching a file outside the spec's declared
  scope.
- A test harness only prints failure text but exits zero (informative red is
  required; **never manufacture a false green**).
- A guardrail file (`AGENTS.md`, `CLAUDE.md`, `.github/workflows/*`,
  `scripts/guards/*`, `docs/adr/*`) would need to change as a side effect of
  unrelated work — flag it, do not edit it inline, without a separate
  explicitly-approved task naming that file.
- A live AI/API call, a new secret, or a Supabase project reference would be
  required to complete the task as specified.
- `n2n-portal` or any legacy `eob_*` table/reference would need to be touched
  or migrated from.
- The task would introduce autonomous/self-patching behavior (schema
  auto-patching, AI-confidence-based auto-reconciliation, an agent editing
  its own guardrails) — this requires its own ADR and explicit approval, full
  stop otherwise.

---

## Architecture Principle

```text
Evidence -> Observations -> Claim Ledger -> Reconciliation -> Intelligence
```

The PDF is evidence, not truth. AI outputs observations only. Deterministic reconciliation
creates financial truth. Analytics and recommendations reason from the ledger.

---

## Why This Is Separate (Design Intent)

The legacy EOB project asked AI to decide final financial truth directly from a PDF, then
accumulated incremental prompt patches and manual DB corrections to fix the resulting
reconciliation gaps. That is fragile: a single mis-extracted line (e.g. a CO-45 contractual
adjustment landing in `paid_amount`, or a late page-63 retry contradicting an earlier read)
silently corrupted the financial result.

The FTE inverts this. Evidence is immutable. AI only records what it sees, with confidence.
Reconciliation is deterministic and auditable, and every dollar in a financial position is
traceable to evidence. Contradictions surface in a review queue instead of corrupting truth.

Keep it that way.
