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
#     Validates that <policy_path> exists and satisfies
#     schemas/merge-policy.schema.json via jsonschema (Draft 7 —
#     matches the schema's declared $schema). Exits 2 on failure;
#     no output on success. <caller_name> is used in error messages
#     (defaults to "merge").

# ---------------------------------------------------------------------------
# _merge_lib_find_schema
#
# Locate schemas/merge-policy.schema.json relative to this library's
# directory. The library lives at <FURROW_ROOT>/bin/frw.d/scripts/, so
# the schema lives four levels up at <FURROW_ROOT>/schemas/.
# ---------------------------------------------------------------------------
_merge_lib_find_schema() {
  _mls_self="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
  # $0 is the caller script; walk up from its directory four levels.
  _mls_dir="$(dirname "$_mls_self")"                    # bin/frw.d/scripts
  _mls_root="$(cd "$_mls_dir/../../.." 2>/dev/null && pwd)" || _mls_root=""
  if [ -n "$_mls_root" ] && [ -f "$_mls_root/schemas/merge-policy.schema.json" ]; then
    printf '%s/schemas/merge-policy.schema.json' "$_mls_root"
    return 0
  fi
  # Fallback: FURROW_ROOT env
  if [ -n "${FURROW_ROOT:-}" ] && [ -f "${FURROW_ROOT}/schemas/merge-policy.schema.json" ]; then
    printf '%s/schemas/merge-policy.schema.json' "$FURROW_ROOT"
    return 0
  fi
  return 1
}

# ---------------------------------------------------------------------------
# merge_validate_policy <policy_path> [<caller_name>]
#
# Validates merge-policy.yaml shape by:
#   (i)  File exists
#   (ii) yq converts it to JSON (valid YAML)
#   (iii) Python jsonschema Draft7Validator validates against
#         schemas/merge-policy.schema.json
#
# The schema requires: schema_version == "1.0", plus the five array
# sections protected / machine_mergeable / prefer_ours /
# always_delete_from_worktree_only, with per-item required fields.
#
# If yq or python3+jsonschema are not available, we fall back to a
# grep-based shape check (same fields the schema requires). The
# schema-backed validation is the authoritative path — the fallback
# exists so merge commands remain usable in stripped-down CI
# environments.
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

  _mvp_schema="$(_merge_lib_find_schema || true)"

  # --- Preferred path: yq + python3 jsonschema ---
  if [ -n "$_mvp_schema" ] \
     && command -v yq >/dev/null 2>&1 \
     && command -v python3 >/dev/null 2>&1; then
    _mvp_json_tmp="$(mktemp)"
    if ! yq -o=json '.' "$_mvp_pol" > "$_mvp_json_tmp" 2>/dev/null; then
      rm -f "$_mvp_json_tmp"
      printf '[furrow:error] %s: merge-policy.yaml: invalid YAML syntax: %s\n' "$_mvp_caller" "$_mvp_pol" >&2
      exit 2
    fi

    _mvp_errors="$(python3 -c '
import json, sys
try:
    from jsonschema import Draft7Validator
except ImportError:
    # Signal "jsonschema not installed" with a specific marker so the
    # shell fallback can decide whether to error or fall through.
    print("__JSONSCHEMA_MISSING__")
    sys.exit(0)
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
validator = Draft7Validator(schema)
errs = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
for e in errs:
    path = ".".join(str(p) for p in e.absolute_path) or "(root)"
    print(f"Schema error at {path}: {e.message}")
' "$_mvp_schema" "$_mvp_json_tmp" 2>&1)"
    rm -f "$_mvp_json_tmp"

    # If jsonschema was present, honor its verdict.
    case "$_mvp_errors" in
      *__JSONSCHEMA_MISSING__*)
        # Fall through to shell fallback below.
        ;;
      "")
        # Schema validated cleanly.
        return 0
        ;;
      *)
        printf '[furrow:error] %s: merge-policy.yaml failed schema validation:\n' "$_mvp_caller" >&2
        printf '%s\n' "$_mvp_errors" | sed '/^$/d' | while IFS= read -r _mvp_line; do
          printf '[furrow:error] %s:   %s\n' "$_mvp_caller" "$_mvp_line" >&2
        done
        exit 2
        ;;
    esac
  fi

  # --- Fallback: grep-based shape check (mirrors schema's required keys) ---
  _mvp_missing=""
  for _mvp_key in schema_version protected machine_mergeable prefer_ours always_delete_from_worktree_only; do
    grep -q "^${_mvp_key}:" "$_mvp_pol" 2>/dev/null || _mvp_missing="${_mvp_missing} .${_mvp_key}"
  done

  if [ -n "$_mvp_missing" ]; then
    printf '[furrow:error] %s: merge-policy.yaml: missing required field(s):%s\n' "$_mvp_caller" "$_mvp_missing" >&2
    exit 2
  fi

  _mvp_ver="$(grep '^schema_version:' "$_mvp_pol" | head -1 | sed 's/schema_version:[[:space:]]*//' | tr -d '"'"'")"
  if [ "$_mvp_ver" != "1.0" ]; then
    printf '[furrow:error] %s: merge-policy.yaml: .schema_version must be "1.0", got "%s"\n' "$_mvp_caller" "$_mvp_ver" >&2
    exit 2
  fi
}
