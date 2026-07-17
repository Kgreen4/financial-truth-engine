# RCM Export Request Checklist

Status: client-facing request checklist draft
Scope: first paid cardiology RCM Revenue Leak Audit

## Instructions

Please export the following reports for the last 90 days if available. If 90
days is difficult, start with 60 days. CSV or Excel is preferred.

If possible, send column headers or de-identified samples first so the audit
workflow can be mapped before any PHI is handled.

Do not email unencrypted PHI unless the practice has approved that workflow.

## Practice Management / Ethizo Exports

### 1. Claims / Charges

Purpose:

- Establish the universe of claims and billed amounts.

Helpful fields:

- Claim id.
- Claim number.
- Payer claim number.
- Patient/account identifier.
- Rendering provider.
- Payer.
- Date of service.
- CPT / modifiers.
- Billed amount.
- Claim status.
- Submission date.
- Created date.

### 2. Payments Posted

Purpose:

- Compare posted payments to deposits, EOBs, ERA/835, and clearinghouse records.

Helpful fields:

- Payment id or posting id.
- Claim id / claim number.
- Check/EFT number.
- Payer.
- Payment amount.
- Payment date.
- Posted date.
- Posted by user.
- Batch id if available.

### 3. Adjustments and Write-Offs

Purpose:

- Separate contractual adjustments from discretionary write-offs and identify
  items needing owner review.

Helpful fields:

- Claim id / claim number.
- Adjustment id.
- Adjustment type.
- Adjustment reason code.
- Amount.
- Created date.
- Posted date.
- Posted by user.
- Notes.
- Approval field or owner approval reference, if available.

### 4. Denials

Purpose:

- Identify denied dollars, preventable denial patterns, and unworked denials.

Helpful fields:

- Claim id / claim number.
- Denial date.
- Denial reason.
- CARC/RARC if available.
- Denied amount.
- Payer.
- Current status.
- Last action date.
- Assigned user.
- Notes.

### 5. A/R Aging

Purpose:

- Identify stale balances and claims needing follow-up.

Helpful fields:

- Claim id / claim number.
- Payer.
- Balance.
- Aging bucket.
- Date of service.
- Last billed date.
- Last payment date.
- Last action date.
- Responsible user or assigned team.

### 6. User Activity / Audit Log

Purpose:

- Measure biller activity, action lag, posting activity, adjustments, and
  write-off behavior.

Helpful fields:

- User.
- Timestamp.
- Action type.
- Claim id / account id.
- Previous status.
- New status.
- Amount changed, if applicable.
- Notes or activity description.

### 7. Prior Authorization Log

Purpose:

- Connect prior-auth failures to denied or unpaid claims.

Helpful fields:

- Claim id, appointment id, or account id.
- Patient/account identifier.
- Payer.
- CPT/service.
- Auth required.
- Auth number.
- Auth status.
- Approved date range.
- Approved site/provider, if available.
- Created date.
- Updated date.
- Created/updated by user.

## Clearinghouse Exports

### 8. Claim Status / Rejection Report

Purpose:

- Compare clearinghouse status to Ethizo status and biller follow-up.

Helpful fields:

- Claim id / claim number.
- Payer claim number.
- Submission date.
- Accepted/rejected status.
- Rejection reason.
- Payer status.
- Status date.
- Correction/resubmission date, if available.

### 9. ERA / 835 Summary Or Raw 835 Files

Purpose:

- Compare payer payment/remittance activity to Ethizo posting.

Helpful fields:

- Payer.
- Check/EFT number.
- Payment date.
- Payment amount.
- Claim id / payer claim number.
- Paid amount by claim.
- Adjustment reason codes.
- Denial reason codes.
- Patient responsibility.

## Practice / Banking Records

### 10. Deposit Log

Purpose:

- Confirm cash received and deposited against posted payments.

Helpful fields:

- Deposit date.
- Deposit amount.
- Check/EFT number.
- Payer.
- Bank batch/reference.
- Notes.

### 11. Incoming Check / EOB Log

Purpose:

- Identify EOB/check intake lag and unposted items.

Helpful fields:

- Received date.
- Payer.
- Check/EFT number.
- Amount.
- Scanned date.
- Sent to biller date.
- Posted date if tracked.
- Notes.

## If A Report Is Not Available

If one report cannot be exported, note:

- report name,
- reason unavailable,
- where the information lives instead,
- who can access it,
- and whether screenshots or a limited manual sample are possible.

## First-Pass Priority

If time is limited, pull these first:

1. Payments posted.
2. Denials.
3. A/R aging.
4. Adjustments/write-offs.
5. User activity.
6. Clearinghouse claim status/rejections.
7. Deposit/check log.
8. Prior authorization log.
