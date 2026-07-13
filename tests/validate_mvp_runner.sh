#!/usr/bin/env bash
# tests/validate_mvp_runner.sh
#
# Lightweight SHELL validation for the one-command MVP runner (scripts/mvp/run_mvp.sh).
# Runs the runner against the disposable-test database and asserts the produced
# Financial Truth Report contains the expected sections.
#
# This is a shell check (its PASS lines are echoed here, NOT emitted as SQL
# `NOTICE: PASS [n/N]` lines), so it does NOT contribute to the SQL PASS count
# asserted by scripts/ci/run_validations.sh — the 379 SQL floor is unaffected.
#
# Requires (same as the runner): FTE_DB_TARGET_LABEL=disposable-test and DATABASE_URL
# (never printed). Exits nonzero on any failure.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

OUT="$(mktemp -t fte_mvp_report.XXXXXX.md)"
trap 'rm -f "$OUT"' EXIT

FAIL=0
N=0
TOTAL=10

pass() { N=$((N+1)); echo "PASS [${N}/${TOTAL}] $1"; }
failc() { N=$((N+1)); echo "FAIL [${N}/${TOTAL}] $1" >&2; FAIL=1; }

# 1. runner exits 0
if bash scripts/mvp/run_mvp.sh "$OUT" >/dev/null 2>&1; then
  pass "runner exits 0"
else
  failc "runner did not exit 0"
fi

# 2. output file created and non-empty
if [ -s "$OUT" ]; then
  pass "output file created (non-empty)"
else
  failc "output file missing or empty"
fi

R="$(cat "$OUT" 2>/dev/null || true)"
check() { # $1 = needle, $2 = description
  if printf '%s' "$R" | grep -qF -- "$1"; then pass "$2"; else failc "$2 (missing: $1)"; fi
}

# 3–10. report content
check '=== Financial Truth Report'   "report title present"
check 'Claim CLM-MVP-001'            "balanced claim present"
check 'NEEDS REVIEW'                 "review exception / needs review present"
check 'Recoverable: $100.00'         "recoverable denial amount present"
check 'Appeal deadline:'             "appeal deadline/status present"
check 'Recoverability trace:'        "recoverability trace summary present"
check 'Appeal-window trace:'         "appeal-window trace summary present"
check 'Total open balance:'          "practice totals present"

if [ "$FAIL" -ne 0 ]; then
  echo "validate_mvp_runner.sh: FAILED"
  exit 1
fi
echo "validate_mvp_runner.sh: PASSED (${N}/${TOTAL})"
exit 0
