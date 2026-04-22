#!/bin/sh
# merge-lib.sh — Shared library for /furrow:merge scripts (Phase 1-5)
#
# Source this file at the top of each merge-*.sh script:
#
#   MERGE_LIB_DIR="$(dirname "$(readlink -f "$0")")"
#   . "${MERGE_LIB_DIR}/merge-lib.sh"
#
# Provides:
#   merge_validate_policy <policy_path> [<caller_name>]
#     Validates that <policy_path> exists and contains all required fields.
#     Exits 2 on failure; no output on success.
#     <caller_name> is used in error messages (defaults to "merge").

# ---------------------------------------------------------------------------
# merge_validate_policy <policy_path> [<caller_name>]
#
# Validates merge-policy.yaml shape:
#   (i)  File exists
#   (ii) All required top-level keys are present
#   (iii) schema_version == "1.0"
#
# Exit codes:
#   0  policy is valid
#   2  file missing or invalid shape
# ---------------------------------------------------------------------------
merge_validate_policy() {
  _mvp_pol="$1"
  _mvp_caller="${2:-merge}"

  # (i) File must exist
  if [ ! -f "$_mvp_pol" ]; then
    printf '[furrow:error] %s: merge-policy.yaml not found: %s\n' "$_mvp_caller" "$_mvp_pol" >&2
    exit 2
  fi

  # (ii) All required top-level keys must be present
  _mvp_missing=""
  for _mvp_key in schema_version protected machine_mergeable prefer_ours always_delete_from_worktree_only; do
    grep -q "^${_mvp_key}:" "$_mvp_pol" 2>/dev/null || _mvp_missing="${_mvp_missing} .${_mvp_key}"
  done

  if [ -n "$_mvp_missing" ]; then
    printf '[furrow:error] %s: merge-policy.yaml: missing required field(s):%s\n' "$_mvp_caller" "$_mvp_missing" >&2
    exit 2
  fi

  # (iii) schema_version must be "1.0"
  _mvp_ver="$(grep '^schema_version:' "$_mvp_pol" | head -1 | sed 's/schema_version:[[:space:]]*//' | tr -d '"'"'")"
  if [ "$_mvp_ver" != "1.0" ]; then
    printf '[furrow:error] %s: merge-policy.yaml: .schema_version must be "1.0", got "%s"\n' "$_mvp_caller" "$_mvp_ver" >&2
    exit 2
  fi
}
