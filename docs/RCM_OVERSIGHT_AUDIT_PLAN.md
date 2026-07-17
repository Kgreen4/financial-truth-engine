# RCM Oversight Audit Plan

Status: planning artifact
Scope: Financial Truth Engine only
No PHI: this plan describes export shapes and synthetic test strategy only.

## Purpose

The Financial Truth Engine should become an owner-facing revenue cycle
oversight layer, not just an EOB-to-835 conversion tool.

The practice management system records what was posted. The clearinghouse
records claim and payer transaction activity. The outsourced biller records
some workflow actions. FTE should independently reconcile those sources into a
plain-English view of whether revenue cycle work is protecting the practice's
money.

Core owner question:

```text
Are our claims, payments, denials, prior authorizations, write-offs, and biller
actions financially correct, timely, and recoverable?
```

## Product Positioning

Do not lead with "we generate 835 files." That may be useful as a fallback
when a practice has paper EOBs and no structured ERA path, but it is not the
main business.

Lead with:

```text
Independent RCM truth and accountability for practice owners.
```

FTE should answer:

- Which payments were received but not posted?
- Which payments were posted late or posted incorrectly?
- Which denials were preventable?
- Which denials were worked, appealed, ignored, or written off?
- Which prior authorization failures are causing revenue loss?
- Which write-offs lack documented owner approval?
- Which payer patterns are causing underpayment, delay, or avoidable rework?
- How is the outsourced biller performing by claim, payer, denial category, and
  action lag?

## Current Practice Context

Known facts from discovery:

- Practice specialty: cardiology.
- Practice management/EHR system: Ethizo.
- Billing model: outsourced biller.
- Payments are posted inside the PM system.
- Ethizo can export claim, payment, denial, write-off, A/R, and user activity
  reports.
- The practice can access the clearinghouse directly.
- Checks are deposited by the practice.
- Owners have authority over appeals, adjustments, and write-offs, but write-off
  approval workflow is not yet confirmed.
- Prior authorizations appear to be tracked in the system, but exportability and
  quality need verification.
- Owners do not fully review denial/write-off/biller performance. They mostly
  know what they are told.

## What May Already Be Solved Elsewhere

Ethizo, the clearinghouse, or payer portals may already handle:

- Claim submission.
- ERA/835 intake and payment posting.
- Claim status and rejection reporting.
- Basic denial code capture.
- A/R aging.
- Prior authorization fields or workflow.
- User activity logs.

FTE should not duplicate these as primary systems of record unless a source is
missing or inaccessible. FTE should ingest their outputs as evidence and produce
cross-source truth.

## FTE's Non-Duplicative Role

FTE should compare and reconcile:

```text
Mail/check/EOB evidence
  vs bank/deposit record
  vs clearinghouse activity
  vs Ethizo posted payments/adjustments/denials/write-offs
  vs prior authorization records
  vs biller user activity
```

The output is not another posting feed. The output is an owner-grade audit:

- Cash received but not posted.
- Payment posted to wrong claim or wrong payer context.
- ERA/EOB denial present but no documented follow-up.
- Claim rejected by clearinghouse but not corrected promptly.
- Prior auth missing, expired, wrong CPT, wrong site, or wrong date span.
- Denial appeal deadline missed or approaching.
- Write-off without adequate approval or documentation.
- Repeated payer underpayment/short-pay pattern.
- Biller action lag and unresolved work queues.

## First Offering

Name:

```text
90-Day RCM Revenue Leak and Biller Accountability Audit
```

Audience:

- Practice owner.
- Practice administrator.
- Optional: outsourced biller, but the primary buyer is the owner.

Promise:

```text
We independently verify where the revenue cycle is leaking money and whether
the billing process is working claims correctly.
```

Initial delivery format:

- Managed-service audit.
- Static report first.
- Dashboard later.
- No public upload workflow.
- No real PHI in repo, CI, prompts, screenshots, or artifacts.

## Export Package Needed

Request 30 days first, then 90 days once the shape is proven.

Required exports:

- Charges/claims.
- Payments.
- Adjustments.
- Denials.
- Write-offs.
- A/R aging.
- Claim status.
- User activity/audit log.
- Prior authorization report, if available.
- Clearinghouse claim status/rejection report.
- Clearinghouse ERA/835 report or raw ERA files, if available.
- Deposit/check log from the practice.
- EOB/check intake log, if available.

Preferred export format:

- CSV or XLSX.
- One report per file.
- Include column headers.
- Include export date and date range in the file name or separate manifest.
- De-identify before sharing outside a HIPAA-safe workflow.

Minimum fields to inspect in each export:

Claims:

- Internal claim id.
- Claim number.
- Payer claim number.
- Patient identifier hash or synthetic placeholder.
- Provider/rendering provider.
- Payer.
- Service date.
- CPT/modifier.
- Billed amount.
- Claim status.
- Submission date.

Payments:

- Payment id or posting id.
- Claim id or claim number.
- Check/EFT number.
- Payment date.
- Posted date.
- Payer.
- Paid amount.
- Posted by user.

Adjustments/write-offs:

- Claim id or claim number.
- Adjustment type.
- Adjustment reason.
- Amount.
- Created date.
- Posted by user.
- Approval/reference note, if available.

Denials:

- Claim id or claim number.
- Denial date.
- CARC/RARC or denial reason.
- Denied amount.
- Payer.
- Current status.
- Last action date.
- Assigned user or biller.

A/R aging:

- Claim id or claim number.
- Payer.
- Balance.
- Aging bucket.
- Last billed date.
- Last action date.

User activity:

- User.
- Timestamp.
- Action type.
- Claim id or account id.
- Before/after status if available.
- Notes if available.

Prior authorization:

- Claim or appointment/procedure link.
- Payer.
- CPT/service.
- Auth required flag.
- Auth number.
- Approved date range.
- Approved site/provider if available.
- Auth status.
- Created/updated user.

Clearinghouse:

- Claim id / payer claim id.
- Submission date.
- Accepted/rejected status.
- Rejection reason.
- Payer status.
- ERA/payment reference if available.

Deposit/check log:

- Deposit date.
- Check/EFT number.
- Payer.
- Amount.
- Bank/deposit batch reference.

## First Report Sections

Executive summary:

- Total charges reviewed.
- Total payments reviewed.
- Total denied amount.
- Potential recoverable amount.
- Unposted or late-posted payment amount.
- Write-offs requiring owner review.
- Claims requiring immediate action.

Cash control:

- Checks/EFTs received but not posted.
- Deposits without matching posted payments.
- Posted payments without matching payment evidence.
- Posting lag by payer and biller.

Denial management:

- Denials by reason/category.
- Preventable vs payer-driven denials.
- Denials with no documented action.
- Denials past or near appeal deadline.
- Appeal outcomes where available.

Prior authorization:

- Auth-related denial amount.
- Missing/expired/mismatched auth patterns.
- CPT/site/date-span mismatches.
- Auth failure rate by payer/provider/service.

Biller performance:

- Average denial action lag.
- Claims untouched after denial.
- Rejections not corrected promptly.
- Payment posting lag.
- Write-offs by user and reason.
- Recoverable dollars worked vs ignored.

Payer performance:

- Denial rate by payer.
- Underpayment/short-pay patterns.
- Rejection and delay patterns.
- Recoverable amount by payer.

Owner action list:

- Top claims to work now.
- Write-offs to approve/reverse/review.
- Payer issues to escalate.
- Internal workflow fixes.

## Synthetic Fixture Plan

Before using real PHI, create synthetic fixtures that mimic Ethizo and
clearinghouse exports.

First synthetic scenarios:

1. Check received and deposited, but no matching payment posted in Ethizo.
2. Payment posted in Ethizo seven days after deposit.
3. Clearinghouse rejection with no user activity for 14 days.
4. Denial with open appeal window and no documented biller action.
5. Prior-auth denial where auth record is missing.
6. Prior-auth denial where auth exists but CPT/date range mismatches.
7. Write-off posted by biller with no owner approval evidence.
8. ERA/EOB denial exists but Ethizo status remains misleadingly open or worked.
9. Payer short-pay where paid amount is below expected allowed amount.
10. Denial later reversed/recovered, proving lifecycle handling.

These should produce owner-facing findings without relying on real identifiers.

## Data Model Direction

Existing FTE tables remain useful:

- `fte_evidence`: export files, EOB pages, ERA files, deposit logs, auth reports.
- `fte_observations`: visible facts from exports/documents.
- `fte_claims`: claim identity.
- `fte_claim_events`: posted payments, denials, rejections, appeals, recoveries,
  write-offs.
- `fte_financial_positions`: derived claim truth.
- `fte_review_queue`: ambiguity and missing evidence.
- `fte_review_resolutions`: owner/biller decisions.
- `fte_analysis_runs`: audit metadata.

Likely future additions or extensions:

- Source-system import staging tables for Ethizo and clearinghouse exports.
- Deposit/payment intake model.
- Prior authorization model.
- User activity / biller action event model.
- Owner approval evidence for write-offs.
- Payer contract/expected allowed amount rules.
- RCM finding table, so report findings are persisted and auditable.

Do not add these tables until the first export column shapes are known.

## Implementation Roadmap

Phase 1: Export discovery

- Collect sample headers only, preferably de-identified.
- Map Ethizo and clearinghouse report columns.
- Confirm whether raw 835/ERA files are accessible.
- Confirm whether prior-auth exports are usable.
- Confirm whether write-off approval is recorded anywhere.

Phase 2: Synthetic export fixtures

- Build synthetic CSV/SQL fixtures matching the export shapes.
- Add a read-only import/staging path.
- Validate cash, denial, auth, and biller-action findings on synthetic data.

Phase 3: RCM oversight report

- Render a 90-day owner-facing report.
- Keep it static/plain text first, similar to the MVP Financial Truth Report.
- Include top-dollar and deadline-driven action lists.

Phase 4: De-identified pilot

- Use de-identified exports only after compliance approval.
- No real PHI in GitHub, CI artifacts, prompts, screenshots, or local report
  artifacts outside the approved workflow.

Phase 5: Managed-service pilot

- Add HIPAA/BAA-backed storage, access controls, audit logs, retention policy,
  incident response, and vendor inventory before real PHI.

Phase 6: SaaS/dashboard

- Build dashboard only after the report proves value.
- Add tenant auth, RLS tests, role-based access, alerts, and monitoring.

## Immediate Next Tasks

Task RCM-001: export inventory

- Get sample headers for each Ethizo and clearinghouse export.
- No PHI needed.
- Create `docs/RCM_EXPORT_FIELD_MAP.md`.

Task RCM-002: synthetic export fixture design

- Define synthetic rows for cash posting, denial management, prior auth failure,
  write-off governance, and user activity.
- No database migrations yet unless the export shapes require staging tables.

Task RCM-003: owner-facing report design

- Draft the 90-day RCM Revenue Leak Report with sections and finding severity.

Task RCM-004: data model proposal

- Decide which concepts belong as claim events, evidence, observations, or new
  RCM-specific tables.

## Open Questions

- Which clearinghouse is used?
- Can raw 835 files be downloaded directly?
- Which Ethizo reports include write-offs, and do they distinguish contractual
  adjustments from discretionary write-offs?
- Does Ethizo expose user activity with claim-level identifiers?
- Does the prior-authorization report link to claims, appointments, CPTs, or
  only patient/account records?
- Do owners approve write-offs inside Ethizo, outside Ethizo, or not at all?
- Can deposit/check records be exported from banking or accounting software?
- Which denial categories are currently highest-dollar or highest-volume?

## Success Criteria

The first usable product is successful when it can show an owner:

- money received but not posted,
- denials not worked,
- prior-auth failures causing revenue loss,
- questionable write-offs,
- biller action lag,
- payer patterns,
- and the top claims/actions that can recover cash now.

That is the business value. EOB conversion is only one evidence intake path.
