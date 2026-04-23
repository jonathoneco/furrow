#!/bin/sh
# merge-execute.sh — Phase 4 of /furrow:merge
#
# Usage: frw_merge_execute <merge_id>
#
# Verifies plan approval + inputs_hash, executes the planned resolutions
# via git merge --no-commit, applies each per-path strategy, commits.
#
# Exit codes:
#   0  merge committed; execute.json records merge_sha
#   1  usage error
#   2  missing deps / policy invalid
#   5  plan missing / not approved / hash mismatch / human-edit sentinel not cleared
#   6  plan deviation mid-merge (unplanned conflict appeared); execute.json.deviations[]
#   8  common.sh broken after merge; frw rescue --apply recommended

set -eu

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
FURROW_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source shared merge library (policy validation + shared helpers)
. "${SCRIPT_DIR}/merge-lib.sh"

_die() { printf '[furrow:error] merge-execute: %s\n' "$1" >&2; exit "${2:-1}"; }
_info() { printf '[furrow:info] merge-execute: %s\n' "$*" >&2; }
_warn() { printf '[furrow:warning] merge-execute: %s\n' "$*" >&2; }

_get_state_dir() {
  _xdg="${XDG_STATE_HOME:-${HOME}/.local/state}"
  _repo_slug="$(basename "$FURROW_ROOT")"
  printf '%s/furrow/%s/merge-state' "$_xdg" "$_repo_slug"
}

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

_compute_inputs_hash() {
  _audit="$1"; _classify="$2"; _policy="$3"
  _combined="$(cat "$_audit" "$_classify" "$_policy")"
  _sha256_str "$_combined"
}

frw_merge_execute() {
  [ $# -ge 1 ] || { printf 'Usage: frw merge-execute <merge_id>\n' >&2; exit 1; }

  _merge_id="$1"
  _state_base="$(_get_state_dir)"
  _merge_dir="${_state_base}/${_merge_id}"
  _audit_json="${_merge_dir}/audit.json"
  _classify_json="${_merge_dir}/classify.json"
  _plan_json="${_merge_dir}/plan.json"

  command -v jq >/dev/null 2>&1 || _die "jq is required" 2
  command -v git >/dev/null 2>&1 || _die "git is required" 2

  [ -f "$_plan_json" ] || _die "plan.json not found — run merge-resolve-plan first" 5
  [ -f "$_audit_json" ] || _die "audit.json not found" 5
  [ -f "$_classify_json" ] || _die "classify.json not found" 5

  # Check approval
  _approved="$(jq -r '.approved' "$_plan_json")"
  if [ "$_approved" != "true" ]; then
    _die "plan not approved — set approved: true in plan.json after reviewing plan.md" 5
  fi

  # Get policy path and validate its shape (belt-and-suspenders — all phases validate)
  _policy_path="$(jq -r '.policy_path' "$_audit_json")"
  merge_validate_policy "$_policy_path" "merge-execute"

  _stored_hash="$(jq -r '.inputs_hash' "$_plan_json")"
  _fresh_hash="$(_compute_inputs_hash "$_audit_json" "$_classify_json" "$_policy_path")"

  if [ "$_stored_hash" != "$_fresh_hash" ]; then
    printf '[furrow:error] merge-execute: inputs_hash mismatch (stored=%s fresh=%s)\n' "$_stored_hash" "$_fresh_hash" >&2
    printf '[furrow:error] merge-execute: Audit or policy changed since plan was written.\n' >&2
    printf '[furrow:error] merge-execute: Re-run: frw merge-resolve-plan %s\n' "$_merge_id" >&2
    exit 5
  fi

  _branch="$(jq -r '.branch' "$_audit_json")"
  _base_sha="$(jq -r '.base_sha' "$_audit_json")"

  _info "executing merge plan for merge_id=$_merge_id branch=$_branch"

  # Check for uncleared human-edit sentinels
  _await_dir="${_merge_dir}/awaiting"
  if [ -d "$_await_dir" ]; then
    _sentinels="$(ls "$_await_dir" 2>/dev/null | grep -v '^$' || true)"
    if [ -n "$_sentinels" ]; then
      _warn "Human-edit sentinels not cleared:"
      for _s in $_sentinels; do
        printf '[furrow:warning] merge-execute:   - awaiting/%s\n' "$_s" >&2
      done
      _warn "Resolve each path manually, remove the sentinel file, then re-run execute."
      exit 5
    fi
  fi

  # Start the merge (--no-commit so we can apply resolutions)
  _merge_exit=0
  git -C "$PROJECT_ROOT" merge --no-commit --no-ff "$_branch" 2>/dev/null || _merge_exit=$?

  # A merge exit code > 0 means conflicts; that's expected
  # We now apply the planned resolutions

  _deviations="[]"
  _warnings="[]"
  _resolution_count=0

  # Get planned paths
  _planned_paths="$(jq -r '.resolutions[].path' "$_plan_json" 2>/dev/null || true)"

  # Get conflicted files (if merge produced conflicts)
  _conflicted="$(git -C "$PROJECT_ROOT" diff --name-only --diff-filter=U 2>/dev/null || true)"

  # Check for unplanned conflicts
  for _cf in $_conflicted; do
    _is_planned=0
    for _pp in $_planned_paths; do
      [ "$_pp" = "$_cf" ] && _is_planned=1 && break
    done
    if [ "$_is_planned" -eq 0 ]; then
      _dev="{\"path\":\"${_cf}\",\"reason\":\"Unplanned conflict — not in resolution plan\"}"
      _deviations="$(printf '%s' "$_deviations" | jq --argjson e "$_dev" '. + [$e]')"
    fi
  done

  _n_deviations="$(printf '%s' "$_deviations" | jq 'length')"
  if [ "$_n_deviations" -gt 0 ]; then
    _warn "Plan deviation: $_n_deviations unplanned conflict(s) detected"
    # Write partial execute.json
    jq -n \
      --arg schema_version "1.0" \
      --arg merge_id "$_merge_id" \
      --arg status "aborted_deviation" \
      --argjson deviations "$_deviations" \
      --argjson warnings "$_warnings" \
      --argjson commonsh_broken false \
      '{
        schema_version: $schema_version,
        merge_id: $merge_id,
        status: $status,
        merge_sha: null,
        deviations: $deviations,
        warnings: $warnings,
        commonsh_broken: $commonsh_broken
      }' > "${_merge_dir}/execute.json"
    # Abort the merge to leave working tree in merge-in-progress state
    # (We leave it so the operator can inspect)
    exit 6
  fi

  # Apply planned resolutions
  _resolution_count=0
  while IFS= read -r _resolution; do
    [ -z "$_resolution" ] && continue
    _rpath="$(printf '%s' "$_resolution" | jq -r '.path')"
    _rstrategy="$(printf '%s' "$_resolution" | jq -r '.strategy')"

    case "$_rstrategy" in
      ours)
        git -C "$PROJECT_ROOT" checkout --ours -- "$_rpath" 2>/dev/null && \
          git -C "$PROJECT_ROOT" add -- "$_rpath" 2>/dev/null || \
          _warn "ours strategy failed for $_rpath (may not be conflicted)"
        _resolution_count=$((_resolution_count + 1))
        ;;
      theirs)
        git -C "$PROJECT_ROOT" checkout --theirs -- "$_rpath" 2>/dev/null && \
          git -C "$PROJECT_ROOT" add -- "$_rpath" 2>/dev/null || \
          _warn "theirs strategy failed for $_rpath (may not be conflicted)"
        _resolution_count=$((_resolution_count + 1))
        ;;
      delete)
        git -C "$PROJECT_ROOT" rm -f -- "$_rpath" 2>/dev/null || \
          _warn "delete strategy failed for $_rpath (may not be present)"
        _resolution_count=$((_resolution_count + 1))
        ;;
      sort-by-id-union)
        _sort_union="$SCRIPT_DIR/merge-sort-union.sh"
        if [ -x "$_sort_union" ]; then
          sh "$_sort_union" "$_rpath" "id" "created_at" "id" 2>/dev/null || \
            _warn "sort-by-id-union failed for $_rpath"
          git -C "$PROJECT_ROOT" add -- "$_rpath" 2>/dev/null || true
        else
          _warn "merge-sort-union.sh not found; skipping sort-by-id-union for $_rpath"
        fi
        _resolution_count=$((_resolution_count + 1))
        ;;
      human-edit)
        # Already checked sentinels above; if we reach here, sentinel was cleared
        # The file should have been manually resolved and staged
        _resolution_count=$((_resolution_count + 1))
        ;;
      auto)
        # Let git's three-way merge handle it (no action needed)
        ;;
    esac
  done <<EOF
$(jq -c '.resolutions[]' "$_plan_json")
EOF

  _info "applied $_resolution_count resolution(s)"

  # Commit the merge
  _merge_sha=""
  _commit_exit=0
  git -C "$PROJECT_ROOT" commit --no-edit -m "chore: merge $_branch into main [merge-id: $_merge_id]" 2>/dev/null \
    || { git -C "$PROJECT_ROOT" commit --no-edit 2>/dev/null; } \
    || _commit_exit=$?

  if [ "$_commit_exit" -ne 0 ]; then
    _warn "Merge commit failed — there may still be unresolved conflicts."
    _warn "Check git status and resolve remaining conflicts, then run git commit."
    # Still check common.sh
  fi

  _merge_sha="$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo 'unknown')"

  # Post-merge: check common.sh syntax
  _commonsh_broken=false
  _commonsh_path="${PROJECT_ROOT}/bin/frw.d/lib/common.sh"
  if [ -f "$_commonsh_path" ]; then
    if ! sh -n "$_commonsh_path" 2>/dev/null; then
      _commonsh_broken=true
    fi
  fi

  # Write execute.json
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$_merge_id" \
    --arg status "$([ "$_commonsh_broken" = "true" ] && echo 'commonsh_broken' || echo 'complete')" \
    --arg merge_sha "$_merge_sha" \
    --argjson deviations "$_deviations" \
    --argjson warnings "$_warnings" \
    --argjson commonsh_broken "$_commonsh_broken" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      status: $status,
      merge_sha: $merge_sha,
      deviations: $deviations,
      warnings: $warnings,
      commonsh_broken: $commonsh_broken
    }' > "${_merge_dir}/execute.json"

  if [ "$_commonsh_broken" = "true" ]; then
    printf '\n' >&2
    printf '[furrow:error] merge-execute: common.sh no longer parses after merge.\n' >&2
    printf '[furrow:error] merge-execute: Run:\n' >&2
    printf '[furrow:error]   ./bin/frw.d/scripts/rescue.sh --apply\n' >&2
    printf '[furrow:error]   Then: /furrow:merge %s --resume %s\n' "$_branch" "$_merge_id" >&2
    printf '[furrow:error] Do NOT abort the merge-in-progress until rescue completes.\n' >&2
    exit 8
  fi

  _info "merge complete: sha=$_merge_sha"
  exit 0
}

frw_merge_execute "$@"
