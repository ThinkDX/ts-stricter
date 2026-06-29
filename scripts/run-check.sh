#!/usr/bin/env bash
#
# Run the TypeScript error count for a single package or a whole workspace.
#
# Reads (env):
#   TSCONFIG, STRICT_OVERRIDE   - see lib.sh
#   IS_WORKSPACE                - "true" to run across WORKSPACE_PACKAGES
#   WORKSPACE_PACKAGES          - comma-separated package directories
#   GITHUB_OUTPUT               - optional; when set, results are appended in
#                                 the `key=value` form GitHub Actions expects
#
# Writes (single package):    error_count=<int>
# Writes (workspace):         package_errors=<json {dir: count}>
#                             error_count=<int total across packages>
#
# `error_count` is emitted in *both* modes so the parent action's outputs are
# never empty (workspace mode used to leave it unset).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/lib.sh"

emit() {
  local line="$1"
  printf '%s\n' "$line"
  if [ -n "${GITHUB_OUTPUT:-}" ]; then
    printf '%s\n' "$line" >> "$GITHUB_OUTPUT"
  fi
}

is_workspace="${IS_WORKSPACE:-false}"

if [ "$is_workspace" = "true" ]; then
  if [ -z "${WORKSPACE_PACKAGES:-}" ]; then
    echo "is-workspace is true but workspace-packages is empty." >&2
    exit 1
  fi

  json='{}'
  total=0
  IFS=',' read -ra packages <<< "$WORKSPACE_PACKAGES"
  for raw in "${packages[@]}"; do
    pkg="$(ts_stricter::trim "$raw")"
    [ -z "$pkg" ] && continue
    count="$(ts_stricter::count_errors_in_dir "$pkg")"
    echo "TypeScript errors in $pkg: $count"
    json="$(jq -c --arg k "$pkg" --argjson v "$count" '. + {($k): $v}' <<< "$json")"
    total=$(( total + count ))
  done

  emit "package_errors=$json"
  emit "error_count=$total"
else
  count="$(ts_stricter::count_errors_in_dir ".")"
  echo "TypeScript errors found: $count"
  emit "error_count=$count"
fi
