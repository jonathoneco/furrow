#!/bin/sh
# merge-resolve-plan.sh — Phase 3 of /furrow:merge
#
# Usage: frw_merge_resolve_plan <merge_id> [--regenerate]
#
# Reads audit.json + classify.json, applies merge-policy.yaml rules,
# and writes plan.json + plan.md. Approval is explicit:
#   - plan.json.approved defaults to false
#   - Operator edits plan.json to set "approved": true after reviewing plan.md
#   - Re-running resolve-plan replaces both artifacts and resets approved to false
#
# Exit codes:
#   0  plan artifact written
#   1  usage error
#   2  audit.json or classify.json missing / policy invalid
#   5  human approval marker missing (plan written; operator must approve)

set -eu

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
FURROW_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source shared merge library (policy validation + shared helpers)
. "${SCRIPT_DIR}/merge-lib.sh"

_die() { printf '[furrow:error] merge-resolve-plan: %s\n' "$1" >&2; exit "${2:-1}"; }
_info() { printf '[furrow:info] merge-resolve-plan: %s\n' "$*" >&2; }
_warn() { printf '[furrow:warning] merge-resolve-plan: %s\n' "$*" >&2; }

_get_state_dir() {
  _xdg="${XDG_STATE_HOME:-${HOME}/.local/state}"
  _repo_slug="$(basename "$FURROW_ROOT")"
  printf '%s/furrow/%s/merge-state' "$_xdg" "$_repo_slug"
}

# Compute SHA256 of a string
_sha256_str() {
  _s="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    printf '%s' "$_s" | sha256sum | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    printf '%s' "$_s" | shasum -a 256 | awk '{print $1}'
  else
    printf '%s' "$_s" | cksum | awk '{print $1}'
  fi
}

# Compute inputs hash: sha256 of (audit.json content + classify.json content + policy file content)
_compute_inputs_hash() {
  _audit_file="$1"
  _classify_file="$2"
  _policy_file="$3"

  _combined="$(cat "$_audit_file" "$_classify_file" "$_policy_file")"
  _sha256_str "$_combined"
}

# Match path against a YAML section's path globs
# Returns 0 if matched, 1 otherwise
_match_policy_section() {
  _file="$1"
  _policy_file="$2"
  _section="$3"  # "protected", "machine_mergeable", "prefer_ours", "always_delete_from_worktree_only"

  _in_section=0
  _depth=0

  while IFS= read -r _line; do
    # Detect section header (top-level key)
    case "$_line" in
      protected:*) _in_section=0; [ "$_section" = "protected" ] && _in_section=1; continue ;;
      machine_mergeable:*) _in_section=0; [ "$_section" = "machine_mergeable" ] && _in_section=1; continue ;;
      prefer_ours:*) _in_section=0; [ "$_section" = "prefer_ours" ] && _in_section=1; continue ;;
      always_delete_from_worktree_only:*) _in_section=0; [ "$_section" = "always_delete_from_worktree_only" ] && _in_section=1; continue ;;
      overrides:*|schema_version:*) _in_section=0 ;;
    esac

    [ "$_in_section" -eq 0 ] && continue

    # Extract path values
    case "$_line" in
      *"path:"*|"  - \""*|"  - '"*)
        if printf '%s' "$_line" | grep -q '"path":'; then
          _pat="$(printf '%s' "$_line" | sed 's/.*"path":[[:space:]]*//' | tr -d '"')"
        elif printf '%s' "$_line" | grep -q "path:"; then
          _pat="$(printf '%s' "$_line" | sed "s/.*path:[[:space:]]*//" | tr -d "\"'")"
        else
          # Array element (always_delete_from_worktree_only style)
          _pat="$(printf '%s' "$_line" | sed "s/[[:space:]]*-[[:space:]]*//" | tr -d "\"'")"
        fi
        _pat="$(printf '%s' "$_pat" | tr -d '[:space:]')"
        [ -z "$_pat" ] && continue
        # Shell glob matching
        case "$_file" in
          $_pat) return 0 ;;
        esac
        # Handle ** glob (convert to POSIX case pattern)
        _glob_case="$(printf '%s' "$_pat" | sed 's|\*\*|*|g')"
        case "$_file" in
          $_glob_case) return 0 ;;
        esac
        ;;
    esac
  done < "$_policy_file"

  return 1
}

frw_merge_resolve_plan() {
  [ $# -ge 1 ] || { printf 'Usage: frw merge-resolve-plan <merge_id> [--regenerate]\n' >&2; exit 1; }

  _merge_id="$1"
  _state_base="$(_get_state_dir)"
  _merge_dir="${_state_base}/${_merge_id}"
  _audit_json="${_merge_dir}/audit.json"
  _classify_json="${_merge_dir}/classify.json"

  command -v jq >/dev/null 2>&1 || _die "jq is required" 2

  [ -f "$_audit_json" ] || _die "audit.json not found — run merge-audit first" 2
  [ -f "$_classify_json" ] || _die "classify.json not found — run merge-classify first" 2

  # Get policy path from audit.json and validate its shape
  _policy_path="$(jq -r '.policy_path' "$_audit_json")"
  merge_validate_policy "$_policy_path" "merge-resolve-plan"

  _branch="$(jq -r '.branch' "$_audit_json")"
  _base_sha="$(jq -r '.base_sha' "$_audit_json")"
  _head_sha="$(jq -r '.head_sha' "$_audit_json")"

  _info "building resolve plan for merge_id=$_merge_id branch=$_branch"

  # Compute inputs hash
  _inputs_hash="$(_compute_inputs_hash "$_audit_json" "$_classify_json" "$_policy_path")"

  # Gather all changed files between base and branch
  _changed_files="$(git -C "$PROJECT_ROOT" diff --name-only "$_base_sha" "$_head_sha" 2>/dev/null || true)"

  # Also gather files that conflict between main and branch (three-way)
  # We do a dry-run merge to find conflicts
  _main_branch="main"
  git -C "$PROJECT_ROOT" rev-parse "refs/heads/master" >/dev/null 2>&1 && _main_branch="master"
  git -C "$PROJECT_ROOT" rev-parse "refs/heads/main" >/dev/null 2>&1 && _main_branch="main"

  # Get files changed on main since base
  _main_changes="$(git -C "$PROJECT_ROOT" diff --name-only "$_base_sha" HEAD 2>/dev/null || true)"

  # Find potential conflicts (files changed on both sides)
  _conflicting_files=""
  for _f in $_changed_files; do
    for _mf in $_main_changes; do
      if [ "$_f" = "$_mf" ]; then
        _conflicting_files="${_conflicting_files} $_f"
        break
      fi
    done
  done

  # Build resolutions array
  _resolutions="[]"

  # Process each changed file
  for _f in $_changed_files; do
    _in_conflicts=0
    for _cf in $_conflicting_files; do
      [ "$_f" = "$_cf" ] && _in_conflicts=1 && break
    done

    _category="auto"
    _strategy="auto"
    _rationale="No conflict detected; git three-way merge applies."
    _conflict=false

    [ "$_in_conflicts" -eq 1 ] && _conflict=true

    # Check protected first (highest priority)
    if _match_policy_section "$_f" "$_policy_path" "protected"; then
      _category="protected"
      _strategy="human-edit"
      _rationale="Protected path — human must decide the resolution."
      _conflict=true  # Always flag protected paths as requiring attention
      # Create awaiting sentinel
      _await_dir="${_merge_dir}/awaiting"
      mkdir -p "$_await_dir"
      # Sanitize path for filename
      _sentinel_name="$(printf '%s' "$_f" | tr '/' '_')"
      touch "${_await_dir}/${_sentinel_name}"

    # Check machine_mergeable
    elif _match_policy_section "$_f" "$_policy_path" "machine_mergeable"; then
      _category="machine_mergeable"
      _strategy="sort-by-id-union"
      _rationale="Machine-mergeable via sort-by-id-union strategy."

    # Check prefer_ours
    elif _match_policy_section "$_f" "$_policy_path" "prefer_ours"; then
      _category="prefer_ours"
      _strategy="ours"
      _rationale="Policy prefers ours (main wins) on conflict."

    # Check always_delete
    elif _match_policy_section "$_f" "$_policy_path" "always_delete_from_worktree_only"; then
      _category="always_delete_from_worktree_only"
      _strategy="delete"
      _rationale="Worktree-only artifact; deleted on merge commit."
      _conflict=false  # Deletion is non-conflicting from main's perspective
    fi

    _entry="$(jq -n \
      --arg path "$_f" \
      --arg category "$_category" \
      --arg strategy "$_strategy" \
      --arg rationale "$_rationale" \
      --argjson conflict "$_conflict" \
      '{path: $path, category: $category, strategy: $strategy, rationale: $rationale, conflict: $conflict}')"

    _resolutions="$(printf '%s' "$_resolutions" | jq --argjson e "$_entry" '. + [$e]')"
  done

  # Write plan.json
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$_merge_id" \
    --arg inputs_hash "$_inputs_hash" \
    --argjson approved false \
    --argjson approved_at 'null' \
    --argjson approved_by 'null' \
    --argjson resolutions "$_resolutions" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      inputs_hash: $inputs_hash,
      approved: $approved,
      approved_at: $approved_at,
      approved_by: $approved_by,
      resolutions: $resolutions
    }' > "${_merge_dir}/plan.json"

  # Write plan.md
  {
    printf '# Merge Resolution Plan\n\n'
    printf '**Merge ID**: `%s`\n' "$_merge_id"
    printf '**Branch**: `%s`\n' "$_branch"
    printf '**Inputs hash**: `%s`\n\n' "$_inputs_hash"
    printf '## Approval\n\n'
    printf 'Review the resolutions below. To approve this plan:\n\n'
    printf '1. Edit `plan.json` in the merge-state directory\n'
    printf '2. Set `"approved": true`\n'
    printf '3. Optionally set `"approved_at"` (ISO-8601) and `"approved_by"` (your name)\n\n'
    printf '> **Note**: Re-running resolve-plan replaces both plan.json and plan.md\n'
    printf '> and resets approval to false. Approve AFTER reviewing the final plan.\n\n'
    printf '<!-- approved:yes -->\n\n'
    printf '## Resolutions\n\n'
    printf '| Path | Category | Strategy | Conflict | Rationale |\n'
    printf '|------|----------|----------|----------|-----------|\n'
    printf '%s' "$_resolutions" | jq -r '.[] | "| `\(.path)` | \(.category) | \(.strategy) | \(.conflict) | \(.rationale | .[0:60]) |"'
    printf '\n'
    printf '## Human-decisions required\n\n'

    _human_count="$(printf '%s' "$_resolutions" | jq '[.[] | select(.strategy == "human-edit")] | length')"
    if [ "$_human_count" -gt 0 ]; then
      printf 'The following paths require human resolution before execute can proceed:\n\n'
      printf '%s' "$_resolutions" | jq -r '.[] | select(.strategy == "human-edit") | "- `\(.path)`: \(.rationale)"'
      printf '\nFor each path:\n'
      printf '1. Resolve the conflict manually in your working tree\n'
      printf '2. Remove the corresponding sentinel file from `merge-state/%s/awaiting/`\n' "$_merge_id"
      printf '3. Run `git add <path>`\n\n'
    else
      printf '_No human decisions required — all resolutions are machine-applicable._\n\n'
    fi
  } > "${_merge_dir}/plan.md"

  _info "plan written to ${_merge_dir}/plan.json"
  printf '%s\n' "${_merge_dir}/plan.md"

  # Always exit 5 on first run to signal human needs to approve
  # (The operator edits plan.json directly to set approved: true)
  _warn "Plan written. Review ${_merge_dir}/plan.md, then set approved: true in plan.json to proceed."
  exit 5
}

frw_merge_resolve_plan "$@"
