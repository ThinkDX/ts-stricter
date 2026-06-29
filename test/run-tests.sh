#!/usr/bin/env bash
#
# Local test harness for ts-stricter.
#
# Exercises the extracted scripts (scripts/lib.sh, run-check.sh, compare.sh)
# against the fixture projects under test/fixtures/ — no GitHub, no network
# beyond a one-time `npm install` of TypeScript.
#
#   ./test/run-tests.sh
#
# Exits non-zero if any assertion fails.

set -uo pipefail

TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TEST_DIR/.." && pwd)"
SCRIPTS="$REPO_DIR/scripts"
FIXTURES="$TEST_DIR/fixtures"

PASS=0
FAIL=0

green() { printf '\033[32m%s\033[0m' "$1"; }
red()   { printf '\033[31m%s\033[0m' "$1"; }

ok()  { PASS=$((PASS + 1)); printf '  %s %s\n' "$(green '✓')" "$1"; }
bad() { FAIL=$((FAIL + 1)); printf '  %s %s\n' "$(red '✗')" "$1"; }

# assert_eq <description> <expected> <actual>
assert_eq() {
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 (expected '$2', got '$3')"; fi
}

# Run a script with a scratch GITHUB_OUTPUT file. Inline assignment exports
# GITHUB_OUTPUT to the (external) script. Any other env the script needs must
# already be exported by the caller. Results:
#   $RUN_RC      exit code
#   out <key>    value emitted for <key>
RUN_OUT=""
RUN_RC=0
run_script() {
  RUN_OUT="$(mktemp)"
  GITHUB_OUTPUT="$RUN_OUT" "$@"
  RUN_RC=$?
}
out() { grep -E "^$1=" "$RUN_OUT" | head -n1 | cut -d= -f2-; }

# ---------------------------------------------------------------------------
# Setup: one shared TypeScript install used by every fixture.
# ---------------------------------------------------------------------------
if [ ! -x "$TEST_DIR/node_modules/.bin/tsc" ]; then
  echo "Installing TypeScript for the test harness..."
  (cd "$TEST_DIR" && npm install --no-audit --no-fund --silent)
fi
export TSC_CMD="$TEST_DIR/node_modules/.bin/tsc"
echo "Using $($TSC_CMD --version)"
echo

# ===========================================================================
echo "▸ count: single package, strict OFF (should be clean)"
export STRICT_OVERRIDE=false IS_WORKSPACE=false
pushd "$FIXTURES/single" >/dev/null; run_script "$SCRIPTS/run-check.sh"; popd >/dev/null
assert_eq "single, strict off → 0 errors" "0" "$(out error_count)"

echo "▸ count: single package, strict ON"
export STRICT_OVERRIDE=true
pushd "$FIXTURES/single" >/dev/null; run_script "$SCRIPTS/run-check.sh"; popd >/dev/null
assert_eq "single, strict on → 2 errors" "2" "$(out error_count)"

echo "▸ count: workspace, multiple tsconfigs, strict ON"
export STRICT_OVERRIDE=true IS_WORKSPACE=true WORKSPACE_PACKAGES="packages/a, packages/b"
pushd "$FIXTURES/workspace" >/dev/null; run_script "$SCRIPTS/run-check.sh"; popd >/dev/null
assert_eq "workspace → package_errors json" '{"packages/a":2,"packages/b":1}' "$(out package_errors)"
assert_eq "workspace → total error_count" "3" "$(out error_count)"
unset STRICT_OVERRIDE IS_WORKSPACE WORKSPACE_PACKAGES

# ===========================================================================
echo "▸ compare: single, no change"
export HEAD_ERRORS=5 BASE_ERRORS=5; run_script "$SCRIPTS/compare.sh"
assert_eq "no change → rc 0" "0" "$RUN_RC"
assert_eq "no change → increased=false" "false" "$(out increased)"
assert_eq "no change → difference=0" "0" "$(out difference)"

echo "▸ compare: single, errors increased (should fail)"
export HEAD_ERRORS=7 BASE_ERRORS=5; run_script "$SCRIPTS/compare.sh"
assert_eq "increase → rc 1" "1" "$RUN_RC"
assert_eq "increase → increased=true" "true" "$(out increased)"
assert_eq "increase → difference=2" "2" "$(out difference)"

echo "▸ compare: single, errors reduced (should pass)"
export HEAD_ERRORS=3 BASE_ERRORS=5; run_script "$SCRIPTS/compare.sh"
assert_eq "reduced → rc 0" "0" "$RUN_RC"
assert_eq "reduced → increased=false" "false" "$(out increased)"
assert_eq "reduced → difference=-2" "-2" "$(out difference)"

echo "▸ compare: single, increase but fail-on-increase=false"
export HEAD_ERRORS=7 BASE_ERRORS=5 FAIL_ON_INCREASE=false; run_script "$SCRIPTS/compare.sh"
assert_eq "soft increase → rc 0" "0" "$RUN_RC"
assert_eq "soft increase → increased=true" "true" "$(out increased)"
unset HEAD_ERRORS BASE_ERRORS FAIL_ON_INCREASE

# ===========================================================================
export IS_WORKSPACE=true
echo "▸ compare: workspace, slashed package names, one package regresses"
export HEAD_PACKAGE_ERRORS='{"packages/a":3,"packages/b":1}'
export BASE_PACKAGE_ERRORS='{"packages/a":2,"packages/b":1}'
run_script "$SCRIPTS/compare.sh"
assert_eq "ws regress → rc 1" "1" "$RUN_RC"
assert_eq "ws regress → increased=true" "true" "$(out increased)"
assert_eq "ws regress → difference=1" "1" "$(out difference)"
assert_eq "ws regress → package_differences" '{"packages/a":1,"packages/b":0}' "$(out package_differences)"

echo "▸ compare: workspace, net reduction across packages"
export HEAD_PACKAGE_ERRORS='{"packages/a":0,"packages/b":1}'
export BASE_PACKAGE_ERRORS='{"packages/a":2,"packages/b":1}'
run_script "$SCRIPTS/compare.sh"
assert_eq "ws reduce → rc 0" "0" "$RUN_RC"
assert_eq "ws reduce → increased=false" "false" "$(out increased)"
assert_eq "ws reduce → difference=-2" "-2" "$(out difference)"

echo "▸ compare: workspace, a brand-new package with errors regresses"
export HEAD_PACKAGE_ERRORS='{"packages/a":2,"packages/c":4}'
export BASE_PACKAGE_ERRORS='{"packages/a":2}'
run_script "$SCRIPTS/compare.sh"
assert_eq "ws new pkg → rc 1" "1" "$RUN_RC"
assert_eq "ws new pkg → difference=4" "4" "$(out difference)"
unset IS_WORKSPACE HEAD_PACKAGE_ERRORS BASE_PACKAGE_ERRORS

# ===========================================================================
echo
if [ "$FAIL" -eq 0 ]; then
  printf '%s\n' "$(green "All $PASS checks passed.")"
  exit 0
else
  printf '%s\n' "$(red "$FAIL failed, $PASS passed.")"
  exit 1
fi
