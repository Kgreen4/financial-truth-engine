#!/usr/bin/env bash
# scripts/guards/check_forbidden_refs.sh
#
# Static guard: forbidden legacy references and forbidden repo/path touch
# assumptions. Fails closed (nonzero exit) on any hit; prints exact matches.
#
# What this checks and why:
#
# 1. Legacy `eob_*` table usage in ACTIVE SQL. AGENTS.md Hard Rule #3 forbids
#    treating legacy eob_ tables as truth. Historical/explanatory prose
#    mentioning "eob_" is fine and expected (e.g. migrations/001 explains why
#    it does NOT reference eob_*) -- this check only flags patterns that look
#    like real usage (FROM/JOIN/INTO/UPDATE/REFERENCES/DELETE FROM eob_...),
#    not comments describing the exclusion.
#
# 2. Forbidden repo/path touch assumptions in the executable CI surface only
#    (.github/workflows, scripts/): no reference to the sibling client/legacy
#    projects (`n2n-portal`, the legacy GitLab path) or to a local
#    Windows/Dropbox path. This repo's CI must be self-contained and must
#    never assume access to another repo or a specific developer machine.
#    Docs (README/AGENTS/PROJECT_STATE) may mention these names historically
#    and are intentionally excluded from this check.
#
# Usage: scripts/guards/check_forbidden_refs.sh

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

FAIL=0

echo "== Check 1: legacy eob_ table usage in active SQL/Python =="
EOB_PATTERN='(references|from|join|into|update|delete[[:space:]]+from)[[:space:]]+eob_'
EOB_HITS="$(grep -rniE "$EOB_PATTERN" \
  migrations fixtures reconciler tests extractor 2>/dev/null || true)"
if [ -n "$EOB_HITS" ]; then
  echo "FAIL: found executable-looking legacy eob_ table reference(s):"
  echo "$EOB_HITS"
  FAIL=1
else
  echo "OK: no executable eob_ table references found."
fi

echo "== Check 2: forbidden repo/path assumptions in CI surface =="
FORBIDDEN_REF_PATTERN='n2n-portal|kgreen41-eob|/Users/kgree/|C:\\Users\\kgree|C:/Users/kgree'
SELF_PATH="scripts/guards/check_forbidden_refs.sh"
CI_SURFACE_HITS=""
if [ -d .github/workflows ]; then
  CI_SURFACE_HITS="$CI_SURFACE_HITS$(grep -rniE "$FORBIDDEN_REF_PATTERN" .github/workflows 2>/dev/null || true)"
fi
if [ -d scripts ]; then
  CI_SURFACE_HITS="$CI_SURFACE_HITS$(grep -rniE "$FORBIDDEN_REF_PATTERN" scripts --exclude="$(basename "$SELF_PATH")" 2>/dev/null || true)"
fi
if [ -n "$CI_SURFACE_HITS" ]; then
  echo "FAIL: CI surface references a forbidden repo/path assumption:"
  echo "$CI_SURFACE_HITS"
  FAIL=1
else
  echo "OK: no forbidden repo/path assumptions in .github/workflows or scripts/."
fi

if [ "$FAIL" -ne 0 ]; then
  echo "check_forbidden_refs.sh: FAILED"
  exit 1
fi
echo "check_forbidden_refs.sh: PASSED"
exit 0
