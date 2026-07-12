#!/usr/bin/env bash
# scripts/ci/apply_migrations.sh
#
# Applies migrations/*.sql in order, then registers the reconciler functions
# (CREATE OR REPLACE — safe to rerun). Runnable locally or in CI; both just
# need DATABASE_URL pointed at a disposable/CI Postgres instance.
#
# No Supabase-specific setup required: migration 001 creates the only
# extension this schema needs (pgcrypto), which ships with vanilla Postgres.
#
# Usage:
#   DATABASE_URL=postgres://... scripts/ci/apply_migrations.sh

set -euo pipefail

: "${DATABASE_URL:?DATABASE_URL must be set (postgres connection string)}"
PSQL_BIN="${PSQL_BIN:-psql}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "== Applying migrations (in order) =="
for f in migrations/*.sql; do
  echo "-- $f"
  "$PSQL_BIN" -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$f"
done

echo "== Registering reconciler functions =="
for f in reconciler/fte_reconcile.sql reconciler/fte_explain_claim.sql reconciler/fte_mock_extract_observations.sql; do
  echo "-- $f"
  "$PSQL_BIN" -v ON_ERROR_STOP=1 "$DATABASE_URL" -f "$f"
done

echo "== Migrations + reconciler registration complete =="
