#!/usr/bin/env bash
# scripts/ci/run_validations.sh
#
# Runs tests/run_all_validations.sql and asserts the run actually succeeded.
#
# WHY THIS SCRIPT EXISTS (do not just check psql's own exit code):
#   tests/run_all_validations.sql is deliberately written WITHOUT
#   `ON_ERROR_STOP`, so that if one suite's DO block raises an EXCEPTION
#   (a FAIL), psql prints the error and keeps running the remaining `\i`
#   suites — see tests/RUNBOOK.md. That is correct behavior for a human
#   scanning full output for every failure in one pass, but it means plain
#   `psql -f tests/run_all_validations.sql; echo $?` returns 0 even when a
#   check failed. Confirmed locally: a RAISE EXCEPTION inside this harness
#   prints `psql:<file>:<line>: ERROR:  ...` and exits 0 without
#   ON_ERROR_STOP. This script does NOT change that harness behavior (so the
#   "run everything, see every failure" property is preserved for local use)
#   -- instead it captures the full log and applies its own pass/fail
#   assertions on top, exactly as instructed by Task 020A: exact assertion
#   count parsing, not a broad FAIL|ERROR grep (which would also match
#   benign in-suite text like "fails closed").
#
# Assertions:
#   1. No literal psql-emitted error line (`psql:<file>:<line>: ERROR:`).
#   2. PASS count parsed from `NOTICE:  PASS [n/N]` lines is >= MIN_PASS_COUNT.
#   3. psql's own exit code was 0 (guards against connection/fatal failures,
#      which DO make psql exit non-zero even without ON_ERROR_STOP).
#
# Usage:
#   DATABASE_URL=postgres://... scripts/ci/run_validations.sh
#   MIN_PASS_COUNT=329 DATABASE_URL=postgres://... scripts/ci/run_validations.sh

set -uo pipefail

: "${DATABASE_URL:?DATABASE_URL must be set (postgres connection string)}"
PSQL_BIN="${PSQL_BIN:-psql}"
MIN_PASS_COUNT="${MIN_PASS_COUNT:-329}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

"$PSQL_BIN" "$DATABASE_URL" -f tests/run_all_validations.sql > "$LOG_FILE" 2>&1
PSQL_EXIT=$?

echo "----- validation run log -----"
cat "$LOG_FILE"
echo "-------------------------------"

PASS_COUNT="$(grep -c 'NOTICE:  PASS \[' "$LOG_FILE" || true)"
ERROR_COUNT="$(grep -cE '^psql:.*: ERROR:' "$LOG_FILE" || true)"

echo "psql exit code : $PSQL_EXIT"
echo "PASS count     : $PASS_COUNT (minimum required: $MIN_PASS_COUNT)"
echo "ERROR lines    : $ERROR_COUNT"

STATUS=0

if [ "$PSQL_EXIT" -ne 0 ]; then
  echo "FAIL: psql exited with code $PSQL_EXIT (connection or fatal error)."
  STATUS=1
fi

if [ "$ERROR_COUNT" -gt 0 ]; then
  echo "FAIL: $ERROR_COUNT SQL error line(s) detected — at least one validation check failed."
  STATUS=1
fi

if [ "$PASS_COUNT" -lt "$MIN_PASS_COUNT" ]; then
  echo "FAIL: PASS count $PASS_COUNT is below the required minimum of $MIN_PASS_COUNT."
  STATUS=1
fi

if [ "$STATUS" -eq 0 ]; then
  echo "OK: $PASS_COUNT PASS checks, 0 errors."
fi

exit "$STATUS"
