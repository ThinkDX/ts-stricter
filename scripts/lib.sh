#!/usr/bin/env bash
#
# Shared helpers for ts-stricter.
#
# This file is meant to be *sourced*, not executed. It contains the core
# TypeScript-error-counting logic so it can be unit-tested directly (see
# test/run-tests.sh) instead of being trapped inside action YAML.
#
# Configuration is read from the environment so the same code works both
# inside a GitHub composite action and from the local test runner:
#
#   TSCONFIG          Path to tsconfig, relative to the package directory.
#                     Default: "tsconfig.json".
#   STRICT_OVERRIDE   "true" to force `--strict` on the compiler regardless
#                     of what the tsconfig says. Default: "true".
#   TSC_CMD           Override the compiler binary invocation (mainly for
#                     tests). Default: "npx tsc".

set -euo pipefail

# Parse a tsc error count out of compiler output.
#
# tsc prints a trailing summary line in a few shapes:
#   "Found 1 error in foo.ts:3"
#   "Found 12 errors in 4 files."
#   "Found 12 errors in the same file, starting at: foo.ts:3"
# A clean run prints no such line, in which case the count is 0.
ts_stricter::parse_count() {
  local output="$1"
  local count
  count=$(printf '%s\n' "$output" \
    | grep -Eo 'Found ([0-9]+) error' \
    | grep -Eo '[0-9]+' \
    | head -n1 || true)
  printf '%s\n' "${count:-0}"
}

# Run tsc in a single directory and echo the integer error count.
#
# $1 - directory to run in (default ".").
#
# The tsconfig existence check and the compiler run happen in the *same*
# directory, so a relative TSCONFIG always resolves consistently (this was a
# bug in the original inline workspace implementation).
ts_stricter::count_errors_in_dir() {
  local dir="${1:-.}"
  local tsconfig="${TSCONFIG:-tsconfig.json}"
  local strict_override="${STRICT_OVERRIDE:-true}"
  local tsc_cmd="${TSC_CMD:-npx tsc}"

  (
    cd "$dir" || exit 1

    local cmd="$tsc_cmd --pretty --noEmit"
    if [ "$strict_override" = "true" ]; then
      cmd="$cmd --strict"
    fi
    if [ -f "$tsconfig" ]; then
      cmd="$cmd --project $tsconfig"
    fi

    # tsc exits non-zero when it finds errors; that is expected, so never let
    # it abort the script. We only care about the parsed count.
    local output
    output=$(eval "$cmd" 2>&1 || true)
    ts_stricter::parse_count "$output"
  )
}

# Trim leading/trailing whitespace from a string.
ts_stricter::trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}
