# Context Hygiene — Financial Truth Engine

**Scope:** `financial-truth-engine/` only. Applies to any Claude Code, Codex, ChatGPT,
or other agent session working in this repo.

## Why this exists

A long-running agent session accumulates dead ends, rejected approaches, and
messy debugging alongside the useful signal. As that pile grows it crowds out
the signal — the agent spends attention on noise and answer quality quietly
degrades. This is **context rot**.

`/compact` is not a fix for this: it summarizes the old conversation and
carries it forward, baggage included. The dead ends and bad assumptions
survive, just in shorter form.

The fix is a **clean handoff**: write down only what the next session needs
(goal, current state, what changed, what failed, what's next), then start
fresh from that note instead of from the full noisy history. The most
valuable part of a handoff is the **failed-attempts list** — it is what stops
a fresh session from looping back into a path already ruled out.

## Durable vs. ephemeral state

This repo already separates these two concerns; this doc formalizes it and
adds the one missing piece (a durable, bounded "known traps" list).

**Durable project truth — committed, long-lived:**
- `PROJECT_STATE.md` — main SHA, CI baseline, current capabilities, next work,
  and a small bounded **"Known traps / do not repeat"** section (see below).
- `README.md` — capabilities and current validation summary.
- `AGENTS.md` / `CLAUDE.md` — the standing agent operating contract.

**Ephemeral session state — never committed, short-lived:**
- Local scratch handoff notes under `../fte_local_artifacts/session_handoffs/`
  (sibling directory to this repo, matching the existing convention used for
  design-only artifacts such as `019A`, `022A`, `023A`).
- Used only when deliberately clearing or restarting a session mid-task —
  not written every session, and not a substitute for `PROJECT_STATE.md`.

**Do not commit live handoff files by default.** They may contain local paths,
in-progress decision noise, or context that is stale within days. If a
handoff turns out to contain something durable and generally useful, promote
that specific fact into `PROJECT_STATE.md` instead of committing the handoff
itself.

## Known traps / do not repeat (PROJECT_STATE.md)

`PROJECT_STATE.md` carries a small, **bounded** `## Known traps / do not
repeat` section (see that file). Rules for it:

- Durable, repo-or-environment-level gotchas only — things a *future* session
  would otherwise waste time rediscovering (e.g. tooling/environment
  friction). Not a log of every mistake made in every task.
- Do not restate rules that already live in `AGENTS.md`/`CLAUDE.md` (e.g.
  "don't touch n2n-portal") — that would let the two files drift out of sync.
- Keep it short: roughly 10 entries max. Compress or remove stale entries
  during routine state refreshes rather than letting the list only grow.

## Clean-handoff triggers

Write a six-section handoff (see template below) and prefer a fresh
session over `/compact` when any of these happen:

- A PR merges.
- A task arc closes (a checkpoint is reached; e.g. an "…S" state-refresh task).
- The CI baseline (PASS count) or `main` SHA changes.
- Work pivots from design to implementation, or vice versa.
- The session hits repeated tooling/environment friction (e.g. the same
  command fails 2+ times for environmental reasons).
- The user says "pause," "handoff," "new session," or "context rot."

## Stop rule

After **two repeated failures** on the same approach (same command, same
fix, same root cause), stop. Do not keep retrying variations in place. Write
a handoff capturing what was tried and why it failed, then restart clean from
that note rather than continuing to loop in a degraded context.

## The six-section handoff template

```markdown
# FTE Session Handoff

## 1. Goal
What we are trying to accomplish next, in one or two lines.

## 2. Current State
- Repo:
- Current main SHA:
- CI status:
- Validation baseline:
- Current branch:
- Migration status:
- Forbidden areas / safety rails:
- Task status:

## 3. Active Files
Files touched or expected to be touched next.

## 4. Changes Made
Short, factual summary of what changed this session.

## 5. Failed Attempts / Do Not Repeat
What was tried that did not work, and why — so the next session never
retries a ruled-out path.

## 6. Next Steps
The specific next actions, in order.
```

Write this file to `../fte_local_artifacts/session_handoffs/<date>-<task>.md`
(e.g. `../fte_local_artifacts/session_handoffs/2026-07-14-025a.md`). Do not
commit it. The next session reads it, then continues from "Next Steps."

## What this doc does not change

- `PROJECT_STATE.md` remains the single durable source of project truth —
  this doc does not duplicate or replace it.
- No task ever adds to the "Known traps" section, or writes a handoff, as a
  silent side effect of unrelated work — either happens as its own named
  task/step, or is explicitly called out in that task's report.
