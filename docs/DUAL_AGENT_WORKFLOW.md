# Dual-Agent Workflow

Status: operating protocol
Scope: coordinating Codex, Claude Code, and Keith on FTE/RCM work

## Purpose

Codex and Claude Code should not free-chat or autonomously loop. They should
coordinate through durable artifacts, explicit handoffs, and Keith's approval.

The goal is to use each model where it is strongest while avoiding duplicated
work, conflicting edits, PHI exposure, and strategy drift.

## Roles

Keith:

- Owns client relationship and business judgment.
- Approves paid-client scope.
- Approves any use of real practice data.
- Decides product, pricing, and final client-facing language.

Codex:

- Reads and edits the repo.
- Creates task docs, SQL, scripts, tests, fixtures, and CI changes.
- Preserves guardrails and context hygiene.
- Does implementation work only within approved scope.

Claude Code:

- Reviews product strategy and report clarity.
- Critiques offer, workflow, and client-facing language.
- Reviews specs before implementation when helpful.
- Reviews outputs after implementation.

## Default Flow

1. Keith defines the business goal.
2. Claude critiques the offer, workflow, or report concept.
3. Keith forwards Claude's useful feedback to Codex.
4. Codex turns approved feedback into repo artifacts or implementation.
5. Keith sends Codex output back to Claude for review when needed.
6. Keith approves final client-facing artifacts.

## File Access Reality

Codex in the desktop app can read and edit the local workspace that Keith has
opened. Claude in a separate chat usually cannot read Keith's local filesystem.

Use GitHub as the bridge when Claude needs to review repo artifacts:

- Codex writes files locally.
- Keith reviews/approves the local diff.
- Codex commits/pushes only when Keith asks.
- Claude reads the pushed branch or file from GitHub and returns review
  findings.
- Keith approves which findings Codex should implement.

If Claude is running as Claude Code locally inside the same checkout, it may be
able to read local files directly. Treat that as a separate local tool session,
not as a persistent shared memory between chat sessions.

Repository reference:

```text
Kgreen4/financial-truth-engine
```

Confirm whether Claude has access to the GitHub repo before relying on this
flow, especially if the repo is private.

## Shared Review Queue

For suggestions that should persist across agents, use repo files instead of
chat memory.

Suggested locations:

- `docs/agent_reviews/claude/` for Claude review notes.
- `docs/agent_reviews/codex/` for Codex review notes.
- `docs/agent_reviews/resolved/` for notes Keith has approved and acted on.

Review note naming:

```text
YYYY-MM-DD-short-topic.md
```

Review note format:

```text
# Review Note: [topic]

From: [Claude / Codex]
For: [Keith / Claude / Codex]
Date: YYYY-MM-DD
Status: proposed

## Context
[What was reviewed.]

## Findings
- [Finding.]

## Recommended Action
- [Action.]

## Approval Needed
[What Keith must approve before implementation.]
```

Do not put PHI, credentials, real patient identifiers, real claim numbers, or
client-sensitive screenshots in review notes.

## Handoff Template

Use this when moving work between agents.

```text
HANDOFF: [task name]
FROM: [Keith / Codex / Claude]
TO: [Keith / Codex / Claude]

CONTEXT:
[1-3 sentences on current state]

FILES TO READ:
- [file path]

FILES CHANGED:
- [file path or "none"]

WHAT WAS DECIDED:
- [decision]

OPEN QUESTIONS:
- [question]

REQUESTED OUTPUT:
[exactly what the receiving agent should produce]

DO NOT TOUCH:
- no PHI
- no credentials
- no n2n-portal
- no schema changes unless explicitly approved
- no client-facing claims not approved by Keith
```

## Safety Rules

- Do not paste PHI into either model.
- Do not paste real patient names, member IDs, DOBs, SSNs, claim numbers, or
  screenshots containing PHI.
- Use headers, synthetic rows, or de-identified/redacted samples for model work.
- Real exports stay outside the public repo unless a separate HIPAA-safe process
  is approved.
- Schema changes require a specific task and approval.
- Client-facing reports require Keith's final review.
- Codex does not make pricing decisions.
- Claude does not implement repo changes.

## First RCM Workflow

Task:

```text
First paid 90-Day Cardiology RCM Revenue Leak Audit
```

Files to anchor the work:

- `docs/RCM_OVERSIGHT_AUDIT_PLAN.md`
- `docs/RCM_30_DAY_DELIVERY_PLAN.md`
- `docs/RCM_EXPORT_REQUEST_CHECKLIST.md`
- `docs/CONTEXT_HYGIENE.md`
- `AGENTS.md`
- `PROJECT_STATE.md`

Claude's first review request:

```text
Review docs/RCM_30_DAY_DELIVERY_PLAN.md and
docs/RCM_EXPORT_REQUEST_CHECKLIST.md for offer clarity, missing RCM reports,
and whether the first paid audit can be delivered in under 30 days. Do not edit
files. Return findings only.
```

Codex's first implementation request after export headers arrive:

```text
Create docs/RCM_EXPORT_FIELD_MAP.md from the provided de-identified headers.
Do not create migrations yet. Identify join keys, missing fields, and which
first findings can be generated from the available reports.
```

## When To Stop And Ask

Stop before proceeding if:

- real PHI would need to be pasted into a prompt,
- the next step requires credentials,
- a schema migration is needed but not explicitly approved,
- Claude and Codex disagree on client-facing conclusions,
- an output could accuse a biller or staff member without evidence,
- or a report finding cannot be traced to source data.

## Good Division Of Labor

Claude is best used for:

- "Is this offer clear enough to sell?"
- "Would this report make an owner care?"
- "What RCM edge cases are missing?"
- "Is this conclusion too strong?"

Codex is best used for:

- "Create the field map."
- "Build the synthetic fixture."
- "Write the SQL validation."
- "Render the report."
- "Run guards/tests."

Keith is best used for:

- "Will the client understand this?"
- "Can we get this data?"
- "Is this sensitive?"
- "Should we charge for this?"

## Operating Bias

For the first paid audit, prefer:

- manual analysis over delayed automation,
- static report over dashboard,
- export headers before schema,
- synthetic fixtures before PHI,
- owner clarity over technical completeness,
- and paid proof before product perfection.
