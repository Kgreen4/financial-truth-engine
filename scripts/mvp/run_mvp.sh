#!/usr/bin/env bash
# scripts/mvp/run_mvp.sh
#
# One-command Financial Truth Engine MVP demo. Applies the synthetic MVP batch,
# reconciles it deterministically, and renders a human-readable "Financial Truth
# Report" to a markdown/plain-text file. No AI, no PHI, synthetic data only.
#
# Usage:
#   FTE_DB_TARGET_LABEL=disposable-test DATABASE_URL=postgres://... \
#     scripts/mvp/run_mvp.sh [output_file]
#
#   Default output_file: mvp_output/financial_truth_report.md
#
# Safety:
#   * Requires FTE_DB_TARGET_LABEL=disposable-test (refuses to run otherwise) so
#     it can never be pointed at a real/production database.
#   * Requires DATABASE_URL but NEVER prints it.
#
# Setup behavior:
#   * If the FTE schema is absent, runs scripts/ci/apply_migrations.sh (migrations
#     + all reconciler/report functions).
#   * If the schema is already present, it does NOT re-apply migrations (that would
#     duplicate one-time DDL); it only re-registers the CREATE OR REPLACE functions
#     this demo needs, which is always safe.

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

PSQL_BIN="${PSQL_BIN:-psql}"
MVP_PRACTICE='a4000000-0000-4000-8000-0000000000fe'
OUTPUT_FILE="${1:-mvp_output/financial_truth_report.md}"

# --- Safety gates -----------------------------------------------------------
if [ "${FTE_DB_TARGET_LABEL:-}" != "disposable-test" ]; then
  echo "REFUSING TO RUN: FTE_DB_TARGET_LABEL must equal 'disposable-test' (got '${FTE_DB_TARGET_LABEL:-<unset>}')." >&2
  echo "This runner only operates against a disposable test database." >&2
  exit 2
fi
if [ -z "${DATABASE_URL:-}" ]; then
  echo "REFUSING TO RUN: DATABASE_URL is not set." >&2
  exit 2
fi

echo "Financial Truth Engine — MVP runner"
echo "Target: disposable-test (DATABASE_URL set; not printed)"

# --- Setup: schema + functions ---------------------------------------------
SCHEMA_PRESENT="$("$PSQL_BIN" -tA "$DATABASE_URL" -c "SELECT to_regclass('public.fte_practices') IS NOT NULL;" 2>/dev/null | tr -d '[:space:]')"

if [ "$SCHEMA_PRESENT" != "t" ]; then
  echo "Schema not found — applying migrations and registering functions…"
  bash scripts/ci/apply_migrations.sh
else
  echo "Schema present — re-registering report/reconciler functions (safe CREATE OR REPLACE)…"
  for f in reconciler/fte_reconcile.sql reconciler/fte_explain_claim.sql \
           reconciler/fte_claim_report.sql reconciler/fte_practice_report.sql; do
    "$PSQL_BIN" -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$f" >/dev/null
  done
fi

# --- Load synthetic MVP batch (idempotent) ---------------------------------
echo "Loading synthetic MVP batch…"
"$PSQL_BIN" -v ON_ERROR_STOP=1 "$DATABASE_URL" -f fixtures/synthetic_mvp_batch.sql >/dev/null

# --- Reconcile --------------------------------------------------------------
echo "Reconciling practice…"
"$PSQL_BIN" -v ON_ERROR_STOP=1 "$DATABASE_URL" \
  -c "SET client_min_messages = warning; SELECT fte_reconcile_practice('${MVP_PRACTICE}'::uuid);" >/dev/null

# --- Render report to the output file --------------------------------------
mkdir -p "$(dirname "$OUTPUT_FILE")"
"$PSQL_BIN" -v ON_ERROR_STOP=1 -tA "$DATABASE_URL" \
  -c "SELECT fte_practice_report('${MVP_PRACTICE}'::uuid);" > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
  echo "ERROR: report output was empty ($OUTPUT_FILE)." >&2
  exit 1
fi

# --- Print path + short summary --------------------------------------------
echo "MVP report written to: $OUTPUT_FILE"
# Echo the practice summary line (Claims: … | Balanced: … | …) if present.
grep -m1 '^Claims:' "$OUTPUT_FILE" || true
echo "Financial Truth MVP complete."
