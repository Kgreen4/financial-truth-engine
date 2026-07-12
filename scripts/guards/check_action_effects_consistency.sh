#!/usr/bin/env bash
# scripts/guards/check_action_effects_consistency.sh
#
# Drift-detection guard: asserts the hand-authored fte_action_effects reference
# (seeded by migrations/014_action_effects_reference.sql) stays consistent with
# the actual reviewer-action usage in reconciler/fte_reconcile.sql.
#
# WHY A STATIC GUARD (no database): this runs in CI's guardrails job, which has
# no Postgres service. So it reads the table's DECLARED rows straight from the
# migration seed (the current authoritative source of the table's content) and
# cross-checks them against the reconciler source text. The companion SQL suite
# tests/validate_action_effects.sql covers the table's in-database internal
# consistency (row counts, categories, no duplicates, no FK).
#
# MAINTENANCE NOTE: this guard parses migrations/014_action_effects_reference.sql
# as the seed source of truth. Any FUTURE migration that changes fte_action_effects
# (adds/removes actions, changes a category, adds effect rows) MUST also update
# this guard (SEED_MIGRATION below, and the KNOWN_ACTIONS list) so the static
# cross-check keeps matching the live table.
#
# Design intent (Task 021A/021C): match by phase-header RANGES and action-string
# presence -- NOT by brittle hardcoded line numbers.
#
# Checks:
#   1. Code-bearing actions (category not durable_note/reserved_unimplemented)
#      must appear as a quoted 'action' literal in fte_reconcile.sql.
#   2. durable_note and reserved_unimplemented actions must NOT appear as a quoted
#      literal in fte_reconcile.sql (they have zero reconciler-phase effect by
#      design; an appearance means someone wired one up without updating the table).
#   3. All 19 known action values are present in the migration seed.
#   4. Phase 7 queue-suppression block references dismiss_short_pay, confirm_short_pay,
#      and mark_position_resolved.
#   5. Phase 8 event-suppression block references dismiss_short_pay but NOT
#      confirm_short_pay and NOT mark_position_resolved.
#   6. Shared IN-list integrity: the Phase 0.5 observation-suppression list and the
#      Phase 5f lifecycle gate list each contain their expected members.
#
# Exits nonzero on any failure; prints an explicit FAILED/PASSED line.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

SEED_MIGRATION="migrations/014_action_effects_reference.sql"
RECONCILER="reconciler/fte_reconcile.sql"

FAIL=0

# The 19-value fte_review_resolutions.action vocabulary (migrations 002+012+013).
KNOWN_ACTIONS="
confirm_observation reject_observation mark_duplicate resolve_contradiction attach_corrected_value
confirm_payment_event reject_payment_event assert_check_identity
confirm_short_pay dismiss_short_pay mark_position_resolved mark_position_needs_correction request_more_evidence confirm_position_balanced override_position_status
file_appeal record_recovery approve_write_off
record_appeal_outcome
"

# Sanity: required source files exist.
for f in "$SEED_MIGRATION" "$RECONCILER"; do
  if [ ! -f "$f" ]; then
    echo "FAIL: required source file not found: $f"
    echo "check_action_effects_consistency.sh: FAILED"
    exit 1
  fi
done

# Count occurrences of a quoted action literal in the reconciler.
recon_count() {
  # $1 = action string. Matches the single-quoted literal 'action'.
  grep -oF "'$1'" "$RECONCILER" 2>/dev/null | wc -l | tr -d '[:space:]'
}

echo "== Check 1+2: seed categories vs reconciler action-string usage =="
# Parse the seed VALUES rows: each tuple starts on a line matching  ('action','category',...
# awk -F"'" then yields field 2 = action, field 4 = category. Inline comment lines
# in the VALUES block start with '  --' and do not match the leading "  ('" anchor.
SEED_PAIRS="$(grep -E "^  \('" "$SEED_MIGRATION" | awk -F"'" '{print $2 "|" $4}' | sort -u)"

if [ -z "$SEED_PAIRS" ]; then
  echo "FAIL: parsed zero (action,category) rows from $SEED_MIGRATION — seed format changed?"
  FAIL=1
fi

while IFS='|' read -r action category; do
  [ -z "$action" ] && continue
  cnt="$(recon_count "$action")"
  case "$category" in
    durable_note|reserved_unimplemented)
      if [ "$cnt" -ne 0 ]; then
        echo "FAIL: '$action' is category '$category' (no reconciler effect expected) but appears $cnt time(s) as a literal in $RECONCILER"
        FAIL=1
      fi
      ;;
    *)
      if [ "$cnt" -lt 1 ]; then
        echo "FAIL: '$action' is code-bearing category '$category' but does NOT appear as a literal in $RECONCILER"
        FAIL=1
      fi
      ;;
  esac
done <<< "$SEED_PAIRS"
if [ "$FAIL" -eq 0 ]; then
  echo "OK: every seed action's category is consistent with its presence/absence in the reconciler."
fi

echo "== Check 3: all 19 known actions present in the seed =="
SEED_ACTIONS="$(printf '%s\n' "$SEED_PAIRS" | awk -F'|' '{print $1}' | sort -u)"
for a in $KNOWN_ACTIONS; do
  if ! printf '%s\n' "$SEED_ACTIONS" | grep -qx "$a"; then
    echo "FAIL: known action '$a' is missing from $SEED_MIGRATION seed rows"
    FAIL=1
  fi
done
# And no unexpected action in the seed.
while read -r a; do
  [ -z "$a" ] && continue
  if ! printf '%s ' $KNOWN_ACTIONS | grep -qw "$a"; then
    echo "FAIL: seed contains unknown action '$a' not in the 19-value vocabulary"
    FAIL=1
  fi
done <<< "$SEED_ACTIONS"
if [ "$FAIL" -eq 0 ]; then
  echo "OK: seed covers exactly the 19 known actions."
fi

# Extract a phase block by its unique header text, up to the next given header.
# Uses awk range on distinctive header substrings (not line numbers).
phase_block() {
  # $1 = start header substring, $2 = end header substring
  awk -v s="$1" -v e="$2" '
    index($0, s) { f=1 }
    index($0, e) { f=0 }
    f { print }
  ' "$RECONCILER"
}

echo "== Check 4: Phase 7 queue-suppression references all three position actions =="
P7="$(phase_block "-- PHASE 7: Route every unbalanced" "-- PHASE 8: Emit short_pay_detected")"
for a in dismiss_short_pay confirm_short_pay mark_position_resolved; do
  if ! printf '%s' "$P7" | grep -qF "'$a'"; then
    echo "FAIL: Phase 7 block does not reference '$a' (expected in the queue-suppression IN-list)"
    FAIL=1
  fi
done
if printf '%s' "$P7" | grep -qF "'dismiss_short_pay'" \
   && printf '%s' "$P7" | grep -qF "'confirm_short_pay'" \
   && printf '%s' "$P7" | grep -qF "'mark_position_resolved'"; then
  echo "OK: Phase 7 references dismiss_short_pay, confirm_short_pay, mark_position_resolved."
fi

echo "== Check 5: Phase 8 suppresses ONLY dismiss_short_pay =="
P8="$(phase_block "-- PHASE 8: Emit short_pay_detected" "-- PHASE 9: Record analysis run")"
if [ -z "$P8" ]; then
  echo "FAIL: could not extract Phase 8 block (header text changed?)"
  FAIL=1
fi
if ! printf '%s' "$P8" | grep -qF "'dismiss_short_pay'"; then
  echo "FAIL: Phase 8 block does not reference 'dismiss_short_pay' (event suppression expected)"
  FAIL=1
fi
for a in confirm_short_pay mark_position_resolved; do
  if printf '%s' "$P8" | grep -qF "'$a'"; then
    echo "FAIL: Phase 8 block references '$a' — it must NOT (only dismiss_short_pay suppresses short_pay_detected)"
    FAIL=1
  fi
done
if printf '%s' "$P8" | grep -qF "'dismiss_short_pay'" \
   && ! printf '%s' "$P8" | grep -qF "'confirm_short_pay'" \
   && ! printf '%s' "$P8" | grep -qF "'mark_position_resolved'"; then
  echo "OK: Phase 8 references dismiss_short_pay only (confirm_short_pay/mark_position_resolved absent)."
fi

echo "== Check 6: shared IN-list integrity (Phase 0.5 obs-suppression, Phase 5f lifecycle gate) =="
# Phase 0.5 observation-suppression list: a single line containing IN ( and both members.
if ! grep -E "action IN \(" "$RECONCILER" | grep -qF "'reject_observation'" \
   || ! grep -E "action IN \(" "$RECONCILER" | grep -F "'reject_observation'" | grep -qF "'mark_duplicate'"; then
  echo "FAIL: Phase 0.5 observation-suppression IN-list not found intact ('reject_observation' + 'mark_duplicate')"
  FAIL=1
fi
# Phase 5f lifecycle gate: one line containing IN ( with all three lifecycle actions.
LIFECYCLE_LINE="$(grep -E "action IN \(" "$RECONCILER" | grep -F "'file_appeal'")"
if [ -z "$LIFECYCLE_LINE" ] \
   || ! printf '%s' "$LIFECYCLE_LINE" | grep -qF "'record_recovery'" \
   || ! printf '%s' "$LIFECYCLE_LINE" | grep -qF "'approve_write_off'"; then
  echo "FAIL: Phase 5f lifecycle gate IN-list not found intact ('file_appeal' + 'record_recovery' + 'approve_write_off')"
  FAIL=1
fi
if [ "$FAIL" -eq 0 ]; then
  echo "OK: shared IN-lists intact."
fi

if [ "$FAIL" -ne 0 ]; then
  echo "check_action_effects_consistency.sh: FAILED"
  exit 1
fi
echo "check_action_effects_consistency.sh: PASSED"
exit 0
