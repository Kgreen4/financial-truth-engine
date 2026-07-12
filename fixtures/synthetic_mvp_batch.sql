-- =============================================================================
-- Financial Truth Engine — Synthetic MVP Batch Fixture
-- fixtures/synthetic_mvp_batch.sql
--
-- Practice ID : a4000000-0000-4000-8000-0000000000fe  (MVP demonstration batch)
-- Covers      : the full FTE value story in one loadable practice —
--   CLM-MVP-001  billed 250 / adj 100 / paid 150            -> balanced ($0.00)
--   CLM-MVP-002  billed 350 / adj 70  / paid 100            -> unbalanced ($180.00), review queue
--   CLM-MVP-003  billed 100 + denial 100 CARC MVP-NON       -> denied 100, recoverable 0 (balanced)
--   CLM-MVP-004  billed 100 + denial 100 CARC MVP-REC       -> denied 100, recoverable 100,
--                (denial service_date = today-10d, window 45)   OPEN appeal deadline + both traces
--   CLM-MVP-005  billed 100 + denial 100 CARC MVP-REC       -> denied 100, recoverable 100,
--                (denial service_date = today-1000d, window 45) EXPIRED appeal deadline
--
-- Denial knowledge (Task 022B/022C traces) is PRACTICE-SCOPED (practice_id set,
-- not global) and uses MVP-only CARC codes, so committing this fixture can NEVER
-- affect any other practice or validation suite:
--   MVP-REC  recoverable=true,  appeal_window_days=45, governance populated
--   MVP-NON  recoverable=false, appeal_window_days=NULL
--
-- This is the demonstration input for fte_claim_report / fte_practice_report
-- (Task 023B) and the scripts/mvp runner (Task 023C).
--
-- Safety:
--   All raw_text values are prefixed [SYNTHETIC]. No PHI, no real patient data,
--   no real member IDs, no production exports. CARC codes are synthetic MVP-*
--   placeholders. source_uri uses private://fte/... ; content_hash sha256:SYNTHETIC_...
--   No legacy EOB tables or connection strings. No live AI.
--
-- Idempotent: cleanup block at top + INSERT ... ON CONFLICT DO NOTHING throughout.
-- Relative dates (CURRENT_DATE - N) keep appeal_deadline_status deterministic:
--   recent denial -> open; years-past denial -> expired.
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- Idempotent cleanup (dependency order); includes practice-scoped denial knowledge.
-- ---------------------------------------------------------------------------
delete from fte_event_evidence      where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_review_queue        where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_analysis_runs       where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_financial_positions where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_claim_events        where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_claims              where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_observations        where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_denial_knowledge    where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_evidence            where practice_id = 'a4000000-0000-4000-8000-0000000000fe'
                                      and parent_evidence_id is not null;
delete from fte_evidence            where practice_id = 'a4000000-0000-4000-8000-0000000000fe';
delete from fte_practices           where id = 'a4000000-0000-4000-8000-0000000000fe';

-- ---------------------------------------------------------------------------
-- Practice
-- ---------------------------------------------------------------------------
insert into fte_practices (id, name, external_ref) values
  ('a4000000-0000-4000-8000-0000000000fe', 'Synthetic MVP Practice', 'synthetic_mvp_batch')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Practice-scoped denial knowledge (MVP-only CARC codes; safe to commit)
-- ---------------------------------------------------------------------------
insert into fte_denial_knowledge
  (id, practice_id, carc_code, rarc_code, payer_name, recoverable, appeal_window_days,
   category, subcategory, default_action, default_owner, evidence_requirements)
values
  ('d4d00000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-0000000000fe',
   'MVP-REC', null, null, true, 45,
   'contractual_adjustment', 'allowed-rate-underpay', 'file_appeal', 'billing_team',
   'remittance advice + contracted rate sheet'),
  ('d4d00000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-0000000000fe',
   'MVP-NON', null, null, false, null,
   'bundled', null, 'write_off', 'coding_team', null)
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Evidence — 1 document parent + 5 page children (one per claim)
-- ---------------------------------------------------------------------------
insert into fte_evidence
  (id, practice_id, parent_evidence_id, evidence_type, fixture_id, source_uri,
   content_hash, page_number, raw_text, metadata)
values
  ('e4a00000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-0000000000fe',
   null, 'document', 'synthetic_mvp_batch',
   'private://fte/mvp/remittance-mvp-batch.pdf', 'sha256:SYNTHETIC_MVP_DOC', null, null, '{}'),

  ('e4a00000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-0000000000fe',
   'e4a00000-0000-4000-8000-000000000001', 'page', 'synthetic_mvp_batch',
   'private://fte/mvp/remittance-mvp-batch.pdf#page=1', 'sha256:SYNTHETIC_MVP_P1', 1,
   '[SYNTHETIC] MVP Remittance p1 | Claim: CLM-MVP-001 | Billed 250.00 | Adj 100.00 | Paid 150.00 (balanced)', '{}'),

  ('e4a00000-0000-4000-8000-000000000003', 'a4000000-0000-4000-8000-0000000000fe',
   'e4a00000-0000-4000-8000-000000000001', 'page', 'synthetic_mvp_batch',
   'private://fte/mvp/remittance-mvp-batch.pdf#page=2', 'sha256:SYNTHETIC_MVP_P2', 2,
   '[SYNTHETIC] MVP Remittance p2 | Claim: CLM-MVP-002 | Billed 350.00 | Adj 70.00 | Paid 100.00 (short pay)', '{}'),

  ('e4a00000-0000-4000-8000-000000000004', 'a4000000-0000-4000-8000-0000000000fe',
   'e4a00000-0000-4000-8000-000000000001', 'page', 'synthetic_mvp_batch',
   'private://fte/mvp/remittance-mvp-batch.pdf#page=3', 'sha256:SYNTHETIC_MVP_P3', 3,
   '[SYNTHETIC] MVP Remittance p3 | Claim: CLM-MVP-003 | Billed 100.00 | Denial 100.00 CARC MVP-NON (non-recoverable)', '{}'),

  ('e4a00000-0000-4000-8000-000000000005', 'a4000000-0000-4000-8000-0000000000fe',
   'e4a00000-0000-4000-8000-000000000001', 'page', 'synthetic_mvp_batch',
   'private://fte/mvp/remittance-mvp-batch.pdf#page=4', 'sha256:SYNTHETIC_MVP_P4', 4,
   '[SYNTHETIC] MVP Remittance p4 | Claim: CLM-MVP-004 | Billed 100.00 | Denial 100.00 CARC MVP-REC (recoverable, open appeal)', '{}'),

  ('e4a00000-0000-4000-8000-000000000006', 'a4000000-0000-4000-8000-0000000000fe',
   'e4a00000-0000-4000-8000-000000000001', 'page', 'synthetic_mvp_batch',
   'private://fte/mvp/remittance-mvp-batch.pdf#page=5', 'sha256:SYNTHETIC_MVP_P5', 5,
   '[SYNTHETIC] MVP Remittance p5 | Claim: CLM-MVP-005 | Billed 100.00 | Denial 100.00 CARC MVP-REC (recoverable, expired appeal)', '{}'),

  -- check_payment stub — enables the Phase 5c two-link for payment_applied events
  -- (payments must reference a check; check_eft_identifier on the payment
  -- observations below matches metadata->>'check_number' here).
  ('e4a00000-0000-4000-8000-000000000007', 'a4000000-0000-4000-8000-0000000000fe',
   null, 'check_payment', 'synthetic_mvp_batch',
   'private://fte/mvp/check-stub-SYN-MVP-CHK', 'sha256:SYNTHETIC_MVP_CHK', null, null,
   '{"check_number":"SYN-MVP-CHK","check_amount":"250.00","payer_name":"Synthetic MVP Payer","payment_date":"2026-05-16"}')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Claims — 5 rows (claim_number must equal observation.claim_identifier)
-- ---------------------------------------------------------------------------
insert into fte_claims
  (id, practice_id, internal_claim_id, claim_number, payer_claim_number,
   patient_identifier_hash, service_date_start, service_date_end, payer_name, status)
values
  ('c4a00000-0000-4000-8000-000000000001', 'a4000000-0000-4000-8000-0000000000fe',
   'FTE-MVP-0001', 'CLM-MVP-001', 'SYN-MVP-PCN-0001', 'synthhash:mvp-a',
   '2026-05-15', '2026-05-15', 'Synthetic MVP Payer', 'open'),
  ('c4a00000-0000-4000-8000-000000000002', 'a4000000-0000-4000-8000-0000000000fe',
   'FTE-MVP-0002', 'CLM-MVP-002', 'SYN-MVP-PCN-0002', 'synthhash:mvp-b',
   '2026-05-15', '2026-05-15', 'Synthetic MVP Payer', 'open'),
  ('c4a00000-0000-4000-8000-000000000003', 'a4000000-0000-4000-8000-0000000000fe',
   'FTE-MVP-0003', 'CLM-MVP-003', 'SYN-MVP-PCN-0003', 'synthhash:mvp-c',
   '2026-05-15', '2026-05-15', 'Synthetic MVP Payer', 'open'),
  ('c4a00000-0000-4000-8000-000000000004', 'a4000000-0000-4000-8000-0000000000fe',
   'FTE-MVP-0004', 'CLM-MVP-004', 'SYN-MVP-PCN-0004', 'synthhash:mvp-d',
   '2026-05-15', '2026-05-15', 'Synthetic MVP Payer', 'open'),
  ('c4a00000-0000-4000-8000-000000000005', 'a4000000-0000-4000-8000-0000000000fe',
   'FTE-MVP-0005', 'CLM-MVP-005', 'SYN-MVP-PCN-0005', 'synthhash:mvp-e',
   '2026-05-15', '2026-05-15', 'Synthetic MVP Payer', 'open')
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Observations
--   001: billed/adj/paid -> balanced
--   002: billed/adj/paid -> unbalanced (short pay)
--   003: billed + denial (MVP-NON)  -> denied, non-recoverable
--   004: billed + denial (MVP-REC, service_date today-10d)   -> recoverable, open appeal
--   005: billed + denial (MVP-REC, service_date today-1000d)  -> recoverable, expired appeal
-- ---------------------------------------------------------------------------
insert into fte_observations
  (id, practice_id, evidence_id, observation_type, amount, amount_type,
   claim_identifier, payer_name, service_date, carc_code, check_eft_identifier,
   confidence_score, raw_value, normalized_value, page_number,
   is_summary_row, is_superseded, metadata)
values
  -- CLM-MVP-001 balanced (payment references check SYN-MVP-CHK)
  ('0b4a0000-0000-4000-8000-000000000001','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000002',
   'billed_amount', 250.00, 'billed', 'CLM-MVP-001', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:250.00','250.00',1,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-000000000002','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000002',
   'contractual_adjustment', 100.00, 'contractual_adjustment', 'CLM-MVP-001', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:100.00','100.00',1,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-000000000003','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000002',
   'payment', 150.00, 'paid', 'CLM-MVP-001', 'Synthetic MVP Payer', '2026-05-15', null, 'SYN-MVP-CHK', 0.97, 'SYN:150.00','150.00',1,false,false,'{}'),

  -- CLM-MVP-002 short pay (open 180; payment references check SYN-MVP-CHK)
  ('0b4a0000-0000-4000-8000-000000000004','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000003',
   'billed_amount', 350.00, 'billed', 'CLM-MVP-002', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:350.00','350.00',2,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-000000000005','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000003',
   'contractual_adjustment', 70.00, 'contractual_adjustment', 'CLM-MVP-002', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:70.00','70.00',2,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-000000000006','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000003',
   'payment', 100.00, 'paid', 'CLM-MVP-002', 'Synthetic MVP Payer', '2026-05-15', null, 'SYN-MVP-CHK', 0.97, 'SYN:100.00','100.00',2,false,false,'{}'),

  -- CLM-MVP-003 non-recoverable denial (billed 100 + denial 100 MVP-NON)
  ('0b4a0000-0000-4000-8000-000000000007','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000004',
   'billed_amount', 100.00, 'billed', 'CLM-MVP-003', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:100.00','100.00',3,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-000000000008','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000004',
   'denial', 100.00, 'denied', 'CLM-MVP-003', 'Synthetic MVP Payer', '2026-05-15', 'MVP-NON', null, 0.97, 'SYN:DENIAL:100.00','100.00',3,false,false,'{}'),

  -- CLM-MVP-004 recoverable denial, OPEN appeal (denial service_date today-10d, window 45)
  ('0b4a0000-0000-4000-8000-000000000009','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000005',
   'billed_amount', 100.00, 'billed', 'CLM-MVP-004', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:100.00','100.00',4,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-00000000000a','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000005',
   'denial', 100.00, 'denied', 'CLM-MVP-004', 'Synthetic MVP Payer', (CURRENT_DATE - INTERVAL '10 days')::date, 'MVP-REC', null, 0.97, 'SYN:DENIAL:100.00','100.00',4,false,false,'{}'),

  -- CLM-MVP-005 recoverable denial, EXPIRED appeal (denial service_date today-1000d, window 45)
  ('0b4a0000-0000-4000-8000-00000000000b','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000006',
   'billed_amount', 100.00, 'billed', 'CLM-MVP-005', 'Synthetic MVP Payer', '2026-05-15', null, null, 0.97, 'SYN:100.00','100.00',5,false,false,'{}'),
  ('0b4a0000-0000-4000-8000-00000000000c','a4000000-0000-4000-8000-0000000000fe','e4a00000-0000-4000-8000-000000000006',
   'denial', 100.00, 'denied', 'CLM-MVP-005', 'Synthetic MVP Payer', (CURRENT_DATE - INTERVAL '1000 days')::date, 'MVP-REC', null, 0.97, 'SYN:DENIAL:100.00','100.00',5,false,false,'{}')
on conflict do nothing;

commit;
