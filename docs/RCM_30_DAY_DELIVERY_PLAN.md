# RCM 30-Day Delivery Plan

Status: active client-delivery plan
Scope: first paid cardiology RCM Revenue Leak Audit
Price: 5000 founder audit
Constraint: no PHI in GitHub, CI, prompts, screenshots, or unapproved artifacts

## Goal

Deliver the first paid owner-facing RCM Revenue Leak Audit in 30 days or less.

The first client has agreed in principle to a 5000 audit. The job now is not to
perfect software. The job is to produce a credible, useful report that shows
where money is leaking and what the owner should do next.

## Offer

Name:

```text
90-Day Cardiology RCM Revenue Leak Audit
```

Founder price:

```text
5000 total
2500 upfront
2500 on delivery
```

Deliverables:

- Executive Revenue Leak Summary.
- Denial and Prior Authorization Failure Report.
- Payment Posting and EOB Intake Lag Report.
- Write-Off and Adjustment Review.
- Outsourced Biller Activity Scorecard.
- Clearinghouse vs Ethizo Status Exceptions.
- Top 20 Claims To Work Now.
- Owner Action Plan.

## Working Principle

Manual work is acceptable for the first audit.

The report is the product. FTE is the repeatability layer that will make future
audits faster and more scalable.

Do not delay the first audit for:

- dashboard work,
- automated IDP perfection,
- SaaS auth,
- broad schema redesign,
- 835 generation,
- or full clearinghouse integration.

## Roles

Keith:

- Client relationship.
- Practice data access.
- Business judgment.
- Final approval on findings before owner delivery.

Codex:

- Repo artifacts.
- Data-shape mapping docs.
- Synthetic fixtures.
- SQL/reporting implementation when export shapes are known.
- Tests and guardrails.

Claude:

- Product critique.
- Report clarity review.
- Offer and positioning review.
- Edge-case and workflow critique.

## Timeline

### Days 1-2: Close and collect

Outcomes:

- Confirm audit scope and 5000 founder price.
- Send data request checklist.
- Schedule export session.
- Confirm HIPAA-safe handling path before receiving PHI.

Actions:

- Send short written engagement summary.
- Request 30-90 days of exports.
- Prefer headers/sample files without PHI first.
- If real data is unavoidable, keep it out of GitHub and agent prompts.

### Days 3-5: Export inventory

Outcomes:

- All available report names listed.
- Column headers mapped.
- Missing data sources identified.

Actions:

- Create `docs/RCM_EXPORT_FIELD_MAP.md` from headers only.
- Identify join keys across reports.
- Confirm whether raw ERA/835 files are available.
- Confirm clearinghouse name and export capabilities.
- Confirm whether write-off approval is recorded.
- Confirm whether prior auth data links to claims, appointments, CPTs, or
  patient/account records.

### Days 6-9: First analysis pass

Outcomes:

- First 5-10 findings identified.
- Data quality issues documented.
- Owner preview memo drafted.

Focus findings:

- Payments received/deposited but not posted.
- Payments posted late.
- Denials with no documented follow-up.
- Prior-auth denial patterns.
- Write-offs without visible owner approval.
- Clearinghouse rejections with no timely correction.
- High-dollar A/R with stale action dates.

### Days 10-12: Preview memo

Outcomes:

- Owner sees early value quickly.
- Scope is confirmed before full report work.

Deliver:

- One-page preview.
- 3-5 strongest examples.
- Amounts at issue.
- What evidence supports each finding.
- What still needs clarification from the practice or biller.

### Days 13-20: Full report build

Outcomes:

- Complete draft report.
- Findings are categorized by severity and actionability.
- Top 20 claims/action list is ready.

Report sections:

- Executive summary.
- Cash control.
- Denial management.
- Prior authorization.
- Write-offs and adjustments.
- Biller activity.
- Payer performance.
- Top claims/actions.
- Data limitations.

### Days 21-23: Review loop

Outcomes:

- Claude reviews clarity, business value, and owner-readability.
- Codex handles any repo/reporting artifacts needed.
- Keith validates business sensitivity and client context.

Rules:

- No PHI to Claude or Codex unless an approved secure workflow exists.
- Use synthetic or redacted examples in prompts.
- Keep findings factual and evidence-backed.

### Days 24-27: Owner presentation

Outcomes:

- Present final audit.
- Ask for ongoing monthly oversight.
- Ask for referral/testimonial if appropriate.

Ongoing offer options:

- 3000/month: monthly owner RCM oversight report.
- 5000/month: monthly report plus denial/write-off review meeting.
- 7500/month: monthly report plus priority recovery worklist and biller
  accountability meeting.

### Days 28-30: Package and repeat

Outcomes:

- First case study structure created.
- Repeatable audit checklist improved.
- Next two referral targets identified.

Actions:

- Strip PHI and create anonymized finding categories.
- Update export checklist with lessons learned.
- Decide first automation target based on the most time-consuming manual step.

## First Report Severity Model

High:

- Cash received/deposited but not posted.
- High-dollar denial with no action and active appeal window.
- Write-off without visible owner approval.
- Prior-auth failure causing high-dollar preventable denial.
- Clearinghouse rejection untouched beyond 7 business days.

Medium:

- Payment posted late beyond agreed threshold.
- Denial worked late but still recoverable.
- Missing/weak documentation for adjustment.
- A/R item stale beyond expected follow-up cycle.
- Repeated payer issue without escalation.

Low:

- Data quality gap.
- Missing report field.
- Ambiguous action history.
- Process improvement with unclear immediate dollars.

## First Audit Success Criteria

The first audit succeeds if it produces at least one of the following:

- Recoverable dollars the owner did not know about.
- Preventable denial pattern the owner did not understand.
- Evidence that outsourced biller follow-up is lagging.
- Payment posting or deposit mismatch.
- Questionable write-offs requiring owner review.
- A ranked action list that the owner believes is worth paying for monthly.

## Immediate Script

```text
I recommend we start with a 90-day RCM Revenue Leak Audit.

The deliverable is an owner-facing report covering payments, denials,
prior-auth failures, write-offs/adjustments, clearinghouse exceptions, biller
activity, and the top claims to work first.

For this first audit, the founder price is 5000: 2500 to start and 2500 on
delivery.

If you are ready, I will send the data request checklist and schedule the export
session.
```

## Do Not Do Yet

- Do not build a dashboard.
- Do not add new database tables before seeing export headers.
- Do not ingest real PHI into the repo.
- Do not send real PHI to any model prompt.
- Do not optimize for SaaS before the first report proves value.
- Do not make 835 generation the primary deliverable.
