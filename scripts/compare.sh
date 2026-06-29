#!/usr/bin/env bash
#
# Compare HEAD vs BASE TypeScript error counts and fail when errors increase.
#
# Reads (env):
#   IS_WORKSPACE          - "true" to compare per-package JSON maps
#   FAIL_ON_INCREASE      - "true" (default) to exit 1 on any increase
#   GITHUB_OUTPUT         - optional; results appended as key=value
#
#   Single package:
#     HEAD_ERRORS, BASE_ERRORS              - integers
#   Workspace:
#     HEAD_PACKAGE_ERRORS, BASE_PACKAGE_ERRORS - JSON {dir: count}
#
# Writes:  difference=<int>  increased=<true|false>
#          package_differences=<json>   (workspace only)
#
# Exit code: 1 when errors increased and FAIL_ON_INCREASE=true, else 0.

set -euo pipefail

fail_on_increase="${FAIL_ON_INCREASE:-true}"
is_workspace="${IS_WORKSPACE:-false}"

emit() {
  local line="$1"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s\n' "$line" >> "$GITHUB_OUTPUT"
  fi
}

if [ "$is_workspace" = "true" ]; then
  # Note: `${VAR:-{}}` does NOT default to "{}" — bash parses it as
  # `${VAR:-{}` followed by a literal "}", corrupting valid JSON. Default
  # explicitly instead.
  head_json="${HEAD_PACKAGE_ERRORS:-}"; [ -z "$head_json" ] && head_json='{}'
  base_json="${BASE_PACKAGE_ERRORS:-}"; [ -z "$base_json" ] && base_json='{}'

  # Per-package diff over the union of package names. Missing on either side
  # is treated as 0. Using jq with the keys as data (not interpolated into the
  # filter) keeps directory names containing "/" working correctly.
  diffs_json="$(jq -cn \
    --argjson head "$head_json" \
    --argjson base "$base_json" \
    '[$head, $base] | add | keys
       | map({ (.): (($head[.] // 0) - ($base[.] // 0)) })
       | add // {}')"

  total_diff="$(jq -n --argjson d "$diffs_json" '[$d[]] | add // 0')"
  increased="$(jq -rn --argjson d "$diffs_json" 'if [$d[]] | any(. > 0) then "true" else "false" end')"

  # Human-readable per-package report.
  while IFS= read -r line; do
    echo "$line"
  done < <(jq -rn \
    --argjson head "$head_json" \
    --argjson base "$base_json" \
    --argjson d "$diffs_json" \
    '$d | to_entries[]
       | "  \(.key): \($head[.key] // 0) (head) vs \($base[.key] // 0) (base) => " +
         (if .value > 0 then "+\(.value) ❌"
          elif .value < 0 then "\(.value) ✅"
          else "no change" end)')

  emit "difference=$total_diff"
  emit "increased=$increased"
  emit "package_differences=$diffs_json"

  if [ "$increased" = "true" ]; then
    echo "❌ TypeScript error count increased in one or more packages (total +$total_diff)."
    if [ "$fail_on_increase" = "true" ]; then exit 1; fi
  else
    echo "✅ TypeScript error count did not increase (total change: $total_diff)."
  fi
else
  head_errors="${HEAD_ERRORS:-0}"
  base_errors="${BASE_ERRORS:-0}"
  difference=$(( head_errors - base_errors ))

  emit "difference=$difference"
  echo "HEAD errors: $head_errors"
  echo "BASE errors: $base_errors"

  if [ "$difference" -gt 0 ]; then
    emit "increased=true"
    echo "❌ TypeScript error count increased by $difference (from $base_errors to $head_errors)."
    if [ "$fail_on_increase" = "true" ]; then exit 1; fi
  else
    emit "increased=false"
    if [ "$difference" -lt 0 ]; then
      echo "✅ Reduced TypeScript errors by $(( -difference ))! ($base_errors -> $head_errors)"
    else
      echo "✅ No change in TypeScript error count ($head_errors)."
    fi
  fi
fi
