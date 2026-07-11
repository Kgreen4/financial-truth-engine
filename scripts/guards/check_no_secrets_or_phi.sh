#!/usr/bin/env bash
# scripts/guards/check_no_secrets_or_phi.sh
#
# Static guard: obvious secrets, project refs, raw_text/evidence-quote
# leakage, and obvious PHI/real-identifier fixture patterns. Fails closed
# (nonzero exit) on any hit; prints exact matches. This is a heuristic
# safety net, not a substitute for review -- it catches obvious mistakes,
# not every possible leak.
#
# Usage: scripts/guards/check_no_secrets_or_phi.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0
SCAN_PATHS="migrations fixtures reconciler tests extractor .github scripts docs README.md README_SCHEMA.md PROJECT_STATE.md NEXT_STEPS.md AGENTS.md"
EXISTING_SCAN_PATHS=""
for p in $SCAN_PATHS; do
  [ -e "$p" ] && EXISTING_SCAN_PATHS="$EXISTING_SCAN_PATHS $p"
done

echo "== Check 1: obvious secret / API key patterns =="
SECRET_PATTERN='sk-[A-Za-z0-9]{20,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}'
SECRET_HITS="$(grep -rniE "$SECRET_PATTERN" $EXISTING_SCAN_PATHS \
  --exclude="check_no_secrets_or_phi.sh" 2>/dev/null || true)"
if [ -n "$SECRET_HITS" ]; then
  echo "FAIL: found an OpenAI-style or JWT-shaped secret literal:"
  echo "$SECRET_HITS"
  FAIL=1
else
  echo "OK: no OpenAI-style or JWT-shaped secret literals found."
fi

echo "== Check 2: raw Postgres connection strings with embedded credentials =="
# Excludes localhost/127.0.0.1 targets: a fixed local CI-container credential
# (e.g. the GitHub Actions ephemeral `postgres` service in .github/workflows/ci.yml)
# is not a secret -- it never resolves outside that single CI job's network
# namespace. Any embedded credential pointed at a REAL host is still flagged.
CONN_PATTERN='postgres(ql)?://[^:/[:space:]]+:[^@/[:space:]]+@'
CONN_HITS="$(grep -rniE "$CONN_PATTERN" $EXISTING_SCAN_PATHS 2>/dev/null \
  | grep -viE '@(localhost|127\.0\.0\.1)([:/]|$)' || true)"
if [ -n "$CONN_HITS" ]; then
  echo "FAIL: found a raw Postgres connection string with embedded credentials:"
  echo "$CONN_HITS"
  FAIL=1
else
  echo "OK: no embedded-credential connection strings found."
fi

echo "== Check 3: live Supabase project reference URLs =="
PROJECT_REF_PATTERN='https?://[a-z0-9]{15,}\.supabase\.co'
PROJECT_REF_HITS="$(grep -rniE "$PROJECT_REF_PATTERN" $EXISTING_SCAN_PATHS 2>/dev/null || true)"
if [ -n "$PROJECT_REF_HITS" ]; then
  echo "FAIL: found a live-looking Supabase project reference URL:"
  echo "$PROJECT_REF_HITS"
  FAIL=1
else
  echo "OK: no Supabase project reference URLs found."
fi

echo "== Check 4: raw_text / evidence-quote leakage in fixtures =="
# Every fte_evidence.raw_text value inserted by fixtures must be prefixed
# [SYNTHETIC] (existing repo invariant, already runtime-asserted by
# tests/validate_extraction_pipeline.sql check 18). Precise per-value static
# matching is unreliable here (fixtures declare columns once and supply
# values across multi-line, positionally-ordered VALUES tuples, so a value
# literal is not textually adjacent to the word "raw_text"). This check uses
# a coarser but zero-false-positive file-level signal instead: any fixture
# file that declares a `raw_text` column must contain the literal marker
# `[SYNTHETIC]` somewhere in the same file. A fixture that adds a raw_text
# column and supplies zero [SYNTHETIC]-prefixed values anywhere is flagged.
if [ -d fixtures ]; then
  CHECK4_FAIL=0
  for f in fixtures/*.sql; do
    if grep -q "raw_text" "$f" && ! grep -q '\[SYNTHETIC\]' "$f"; then
      echo "FAIL: $f declares a raw_text column but contains no [SYNTHETIC] marker."
      FAIL=1
      CHECK4_FAIL=1
    fi
  done
  if [ "$CHECK4_FAIL" -eq 0 ]; then
    echo "OK: every fixture declaring raw_text also contains the [SYNTHETIC] marker."
  fi
fi

echo "== Check 5: obvious PHI-shaped identifiers (SSN pattern) =="
SSN_PATTERN='[0-9]{3}-[0-9]{2}-[0-9]{4}'
SSN_HITS="$(grep -rnE "$SSN_PATTERN" $EXISTING_SCAN_PATHS 2>/dev/null || true)"
if [ -n "$SSN_HITS" ]; then
  echo "FAIL: found an SSN-shaped literal:"
  echo "$SSN_HITS"
  FAIL=1
else
  echo "OK: no SSN-shaped literals found."
fi

if [ "$FAIL" -ne 0 ]; then
  echo "check_no_secrets_or_phi.sh: FAILED"
  exit 1
fi
echo "check_no_secrets_or_phi.sh: PASSED"
exit 0
