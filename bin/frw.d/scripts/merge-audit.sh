#!/bin/sh
# merge-audit.sh — Phase 1 of /furrow:merge
#
# Usage: frw_merge_audit <branch> <policy_path>
#
# Reads the merge-policy, validates it, calls rws get-reintegration-json,
# and produces audit.json recording contamination signals.
#
# Exit codes:
#   0  audit produced; no blockers
#   1  usage error
#   2  branch missing / policy invalid / missing deps / not archived
#   3  audit found blockers (proceed with caution; human review required)
#
# Stdout: "merge_id=<uuid>" on success.
# Stderr: human-readable summary.
#
# Standalone POSIX sh — no sourcing of common.sh.

set -eu

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
FURROW_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

_die() { printf '[furrow:error] merge-audit: %s\n' "$1" >&2; exit "${2:-1}"; }
_info() { printf '[furrow:info] merge-audit: %s\n' "$*" >&2; }
_warn() { printf '[furrow:warning] merge-audit: %s\n' "$*" >&2; }

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------
_check_deps() {
  command -v jq >/dev/null 2>&1 || _die "jq is required but not found in PATH" 2
  command -v git >/dev/null 2>&1 || _die "git is required but not found in PATH" 2
}

# ---------------------------------------------------------------------------
# Policy validation (lightweight — checks required top-level keys exist)
# ---------------------------------------------------------------------------
_validate_policy_yaml() {
  _pol="$1"
  [ -f "$_pol" ] || _die "policy file not found: $_pol" 2

  # Check required top-level keys exist using grep (avoid yq dependency for validation)
  # A proper YAML-schema validator (ajv) is used in test AC-4; here we do a
  # lightweight sanity check so scripts can report clear errors.
  _missing=""
  for _key in schema_version protected machine_mergeable prefer_ours always_delete_from_worktree_only; do
    grep -q "^${_key}:" "$_pol" || _missing="${_missing} .${_key}"
  done

  if [ -n "$_missing" ]; then
    printf '[furrow:error] merge-audit: merge-policy.yaml: missing required field(s):%s\n' "$_missing" >&2
    exit 2
  fi

  # Check schema_version == "1.0"
  _ver="$(grep '^schema_version:' "$_pol" | head -1 | sed 's/schema_version:[[:space:]]*//' | tr -d '"'"'")"
  if [ "$_ver" != "1.0" ]; then
    printf '[furrow:error] merge-audit: merge-policy.yaml: .schema_version must be "1.0", got "%s"\n' "$_ver" >&2
    exit 2
  fi
}

# ---------------------------------------------------------------------------
# UUID generation (POSIX-compatible)
# ---------------------------------------------------------------------------
_gen_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]' | cut -c1-8
  else
    # fallback: use /proc/sys/kernel/random/uuid or od
    if [ -r /proc/sys/kernel/random/uuid ]; then
      cut -c1-8 /proc/sys/kernel/random/uuid
    else
      od -An -tx1 /dev/urandom 2>/dev/null | tr -d ' \n' | head -c8
    fi
  fi
}

# ---------------------------------------------------------------------------
# Glob matching (fnmatch-style with ** support)
# Returns 0 if path matches glob, 1 otherwise
# ---------------------------------------------------------------------------
_glob_match() {
  _path="$1"
  _pattern="$2"

  # Convert ** glob to match any path separator sequence
  # We'll use a case statement approach with shell expansion
  # For simple patterns we can use case directly
  # For ** patterns, we need to expand

  # Convert glob to a case pattern
  # Replace ** with a placeholder that matches anything including /
  _case_pat="$(printf '%s' "$_pattern" | sed 's|\*\*|STARSTAR|g; s|STARSTAR|*|g')"

  case "$_path" in
    $_case_pat) return 0 ;;
  esac

  # Also try matching with leading directory stripped patterns
  # e.g. ".claude/rules/*" should match ".claude/rules/foo.md"
  return 1
}

# ---------------------------------------------------------------------------
# Check if a path matches any protected glob in policy
# ---------------------------------------------------------------------------
_is_protected() {
  _file="$1"
  _pol_file="$2"

  # Extract protected paths from YAML (simple grep approach)
  # Protected section: lines after "^protected:" until next top-level key
  _in_protected=0
  while IFS= read -r _line; do
    case "$_line" in
      protected:*) _in_protected=1; continue ;;
      machine_mergeable:*|prefer_ours:*|always_delete_from_worktree_only:*|overrides:*|schema_version:*) _in_protected=0 ;;
    esac
    if [ "$_in_protected" -eq 1 ]; then
      case "$_line" in
        *"path:"*)
          _pat="$(printf '%s' "$_line" | sed 's/.*path:[[:space:]]*//' | tr -d '"'"'")"
          _glob_match "$_file" "$_pat" && return 0
          ;;
      esac
    fi
  done < "$_pol_file"
  return 1
}

# ---------------------------------------------------------------------------
# Check if path matches install-artifact patterns
# ---------------------------------------------------------------------------
_is_install_artifact() {
  _file="$1"
  case "$_file" in
    bin/*.bak|.claude/rules/*.bak|*/.bak) return 0 ;;
  esac
  return 1
}

# ---------------------------------------------------------------------------
# Get XDG state dir for merge-state
# ---------------------------------------------------------------------------
_get_state_dir() {
  _xdg="${XDG_STATE_HOME:-${HOME}/.local/state}"
  _repo_slug="$(basename "$FURROW_ROOT")"
  printf '%s/furrow/%s/merge-state' "$_xdg" "$_repo_slug"
}

# ---------------------------------------------------------------------------
# Main audit function
# ---------------------------------------------------------------------------
frw_merge_audit() {
  [ $# -ge 2 ] || { printf 'Usage: frw merge-audit <branch> <policy_path>\n' >&2; exit 1; }

  _branch="$1"
  _policy_path="$2"

  _check_deps
  _validate_policy_yaml "$_policy_path"

  # Resolve branch — if it looks like a row name (no slashes), try work/<name>
  _resolved_branch="$_branch"
  case "$_branch" in
    */*)  ;;  # already has a slash — use as-is
    *)
      if git -C "$PROJECT_ROOT" rev-parse "refs/heads/work/${_branch}" >/dev/null 2>&1; then
        _resolved_branch="work/${_branch}"
      fi
      ;;
  esac

  # Verify branch exists
  git -C "$PROJECT_ROOT" rev-parse "refs/heads/${_resolved_branch}" >/dev/null 2>&1 \
    || _die "branch not found: ${_resolved_branch}" 2

  # Get base SHA (merge-base with main)
  _main_branch="$(git -C "$PROJECT_ROOT" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|.*/||' || echo 'main')"
  # Try local main first
  if git -C "$PROJECT_ROOT" rev-parse "refs/heads/main" >/dev/null 2>&1; then
    _main_branch="main"
  elif git -C "$PROJECT_ROOT" rev-parse "refs/heads/master" >/dev/null 2>&1; then
    _main_branch="master"
  fi

  _base_sha="$(git -C "$PROJECT_ROOT" merge-base "$_main_branch" "$_resolved_branch" 2>/dev/null)" \
    || _die "could not compute merge-base between $MAIN_BRANCH and $_resolved_branch" 2
  _head_sha="$(git -C "$PROJECT_ROOT" rev-parse "$_resolved_branch")"
  _our_sha="$(git -C "$PROJECT_ROOT" rev-parse "$_main_branch")"

  # Extract row name from branch
  _row_name="$(printf '%s' "$_resolved_branch" | sed 's|^work/||')"

  # Generate merge-id
  _merge_id="$(_gen_uuid)"

  # Create merge-state dir
  _state_base="$(_get_state_dir)"
  _merge_dir="${_state_base}/${_merge_id}"
  mkdir -p "$_merge_dir"
  mkdir -p "${_merge_dir}/awaiting"

  _info "merge_id=$_merge_id branch=$_resolved_branch base=$_base_sha"

  # ---------------------------------------------------------------------------
  # 1. Call rws get-reintegration-json
  # ---------------------------------------------------------------------------
  _reintegration_json=""
  _rws_exit=0
  _reintegration_json="$(rws get-reintegration-json "$_row_name" 2>/dev/null)" || _rws_exit=$?

  if [ "$_rws_exit" -ne 0 ]; then
    _warn "rws get-reintegration-json exited $_rws_exit for row '$_row_name'"
    _warn "Ensure the row is archived and has a reintegration section."
    _warn "Run /furrow:status to check row state."
    # Non-fatal for audit — we record empty reintegration_json and add a blocker
    _reintegration_json='{"schema_version":"1.0","row_name":"'$_row_name'","commits":[],"files_changed":[],"decisions":[],"open_items":[],"test_results":{"pass":false}}'
  fi

  # Validate it's valid JSON
  printf '%s' "$_reintegration_json" | jq . >/dev/null 2>&1 \
    || { _warn "reintegration JSON is malformed; using empty fallback"; _reintegration_json='{"schema_version":"1.0","row_name":"'$_row_name'","commits":[],"files_changed":[],"decisions":[],"open_items":[],"test_results":{"pass":false}}'; }

  # ---------------------------------------------------------------------------
  # 2. Detect symlink typechanges on protected paths
  # ---------------------------------------------------------------------------
  _symlink_typechanges="[]"
  _protected_touches="[]"

  # Get typechanges between base and branch tip
  _typechanges="$(git -C "$PROJECT_ROOT" diff --diff-filter=T --name-only "$_base_sha" "$_head_sha" 2>/dev/null || true)"

  for _f in $_typechanges; do
    _old_mode="$(git -C "$PROJECT_ROOT" ls-tree "$_base_sha" "$_f" 2>/dev/null | awk '{print $1}' || echo '')"
    _new_mode="$(git -C "$PROJECT_ROOT" ls-tree "$_head_sha" "$_f" 2>/dev/null | awk '{print $1}' || echo '')"
    _from_type="file"
    _to_type="file"
    [ "$_old_mode" = "120000" ] && _from_type="symlink"
    [ "$_new_mode" = "120000" ] && _to_type="symlink"

    _entry="{\"path\":\"${_f}\",\"from\":\"${_from_type}\",\"to\":\"${_to_type}\"}"
    _symlink_typechanges="$(printf '%s' "$_symlink_typechanges" | jq --argjson e "$_entry" '. + [$e]')"

    if _is_protected "$_f" "$_policy_path"; then
      _pt="{\"path\":\"${_f}\",\"side\":\"worktree\"}"
      _protected_touches="$(printf '%s' "$_protected_touches" | jq --argjson e "$_pt" '. + [$e]')"
    fi
  done

  # Also check non-typechange protected file modifications
  _branch_changes="$(git -C "$PROJECT_ROOT" diff --name-only "$_base_sha" "$_head_sha" 2>/dev/null || true)"
  for _f in $_branch_changes; do
    if _is_protected "$_f" "$_policy_path"; then
      # Check if already in protected_touches
      _already="$(printf '%s' "$_protected_touches" | jq --arg p "$_f" '[.[] | select(.path == $p)] | length')"
      if [ "$_already" -eq 0 ]; then
        # Check if also changed on main since base
        _main_changes="$(git -C "$PROJECT_ROOT" diff --name-only "$_base_sha" "$_our_sha" 2>/dev/null || true)"
        _side="worktree"
        for _mf in $_main_changes; do
          [ "$_mf" = "$_f" ] && _side="both" && break
        done
        _pt="{\"path\":\"${_f}\",\"side\":\"${_side}\"}"
        _protected_touches="$(printf '%s' "$_protected_touches" | jq --argjson e "$_pt" '. + [$e]')"
      fi
    fi
  done

  # ---------------------------------------------------------------------------
  # 3. Detect install-artifact additions
  # ---------------------------------------------------------------------------
  _install_artifact_additions="[]"
  for _f in $_branch_changes; do
    if _is_install_artifact "$_f"; then
      _install_artifact_additions="$(printf '%s' "$_install_artifact_additions" | jq --arg f "$_f" '. + [$f]')"
    fi
  done

  # ---------------------------------------------------------------------------
  # 4. Detect overlapping commits (cherry-picks from main)
  # ---------------------------------------------------------------------------
  _overlap_commits="[]"
  _branch_commits="$(git -C "$PROJECT_ROOT" log --oneline "${_base_sha}..${_head_sha}" 2>/dev/null || true)"
  _main_commits="$(git -C "$PROJECT_ROOT" log --oneline "${_base_sha}..${_our_sha}" 2>/dev/null || true)"

  # Simple check: look for matching subjects
  while IFS= read -r _commit_line; do
    [ -z "$_commit_line" ] && continue
    _sha="$(printf '%s' "$_commit_line" | awk '{print $1}')"
    _subj="$(printf '%s' "$_commit_line" | cut -d' ' -f2-)"
    # Check if this subject appears in main commits
    if printf '%s\n' "$_main_commits" | grep -qF "$_subj" 2>/dev/null; then
      _oc="{\"sha\":\"${_sha}\",\"subject\":\"${_subj}\",\"side\":\"main\"}"
      _overlap_commits="$(printf '%s' "$_overlap_commits" | jq --argjson e "$_oc" '. + [$e]')"
    fi
  done <<EOF
$_branch_commits
EOF

  # ---------------------------------------------------------------------------
  # 5. Detect stale references (todos.yaml ids not in roadmap.yaml)
  # ---------------------------------------------------------------------------
  _stale_todos="[]"
  _stale_rows="[]"

  _todos_file="${PROJECT_ROOT}/.furrow/almanac/todos.yaml"
  _roadmap_file="${PROJECT_ROOT}/.furrow/almanac/roadmap.yaml"

  if [ -f "$_todos_file" ] && [ -f "$_roadmap_file" ] && command -v yq >/dev/null 2>&1; then
    _todo_ids="$(yq '.[].id' "$_todos_file" 2>/dev/null || true)"
    for _tid in $_todo_ids; do
      [ -z "$_tid" ] && continue
      if ! grep -q "$_tid" "$_roadmap_file" 2>/dev/null; then
        _stale_todos="$(printf '%s' "$_stale_todos" | jq --arg id "$_tid" '. + [$id]')"
      fi
    done
  fi

  # ---------------------------------------------------------------------------
  # 6. common.sh syntax validity on both sides
  # ---------------------------------------------------------------------------
  _commonsh_ours=true
  _commonsh_theirs=true
  _commonsh_path="bin/frw.d/lib/common.sh"

  # Check ours (main HEAD)
  if git -C "$PROJECT_ROOT" ls-tree "$_our_sha" "$_commonsh_path" >/dev/null 2>&1; then
    _tmp_ours="$(mktemp)"
    git -C "$PROJECT_ROOT" show "${_our_sha}:${_commonsh_path}" > "$_tmp_ours" 2>/dev/null || true
    sh -n "$_tmp_ours" 2>/dev/null || _commonsh_ours=false
    rm -f "$_tmp_ours"
  fi

  # Check theirs (branch HEAD)
  if git -C "$PROJECT_ROOT" ls-tree "$_head_sha" "$_commonsh_path" >/dev/null 2>&1; then
    _tmp_theirs="$(mktemp)"
    git -C "$PROJECT_ROOT" show "${_head_sha}:${_commonsh_path}" > "$_tmp_theirs" 2>/dev/null || true
    sh -n "$_tmp_theirs" 2>/dev/null || _commonsh_theirs=false
    rm -f "$_tmp_theirs"
  fi

  # ---------------------------------------------------------------------------
  # 7. Compute policy SHA256
  # ---------------------------------------------------------------------------
  _policy_sha256=""
  if command -v sha256sum >/dev/null 2>&1; then
    _policy_sha256="$(sha256sum "$_policy_path" | awk '{print $1}')"
  elif command -v shasum >/dev/null 2>&1; then
    _policy_sha256="$(shasum -a 256 "$_policy_path" | awk '{print $1}')"
  fi

  # ---------------------------------------------------------------------------
  # 8. Build blockers list
  # ---------------------------------------------------------------------------
  _blockers="[]"

  _n_symlink="$(printf '%s' "$_symlink_typechanges" | jq 'length')"
  if [ "$_n_symlink" -gt 0 ]; then
    _bl="{\"type\":\"symlink_typechange\",\"message\":\"$_n_symlink protected path(s) changed from file to symlink — likely install artifact contamination\"}"
    _blockers="$(printf '%s' "$_blockers" | jq --argjson e "$_bl" '. + [$e]')"
  fi

  _n_artifacts="$(printf '%s' "$_install_artifact_additions" | jq 'length')"
  if [ "$_n_artifacts" -gt 0 ]; then
    _bl="{\"type\":\"install_artifact\",\"message\":\"$_n_artifacts install artifact(s) detected on worktree branch (e.g. bin/*.bak)\"}"
    _blockers="$(printf '%s' "$_blockers" | jq --argjson e "$_bl" '. + [$e]')"
  fi

  _n_overlap="$(printf '%s' "$_overlap_commits" | jq 'length')"
  if [ "$_n_overlap" -gt 0 ]; then
    _bl="{\"type\":\"overlap_commits\",\"message\":\"$_n_overlap commit(s) appear to already exist on main — possible cherry-pick duplication\"}"
    _blockers="$(printf '%s' "$_blockers" | jq --argjson e "$_bl" '. + [$e]')"
  fi

  _n_stale_todos="$(printf '%s' "$_stale_todos" | jq 'length')"
  if [ "$_n_stale_todos" -gt 0 ]; then
    _bl="{\"type\":\"stale_references\",\"message\":\"$_n_stale_todos stale todo id(s) not referenced in roadmap.yaml\"}"
    _blockers="$(printf '%s' "$_blockers" | jq --argjson e "$_bl" '. + [$e]')"
  fi

  if [ "$_commonsh_ours" = "false" ] || [ "$_commonsh_theirs" = "false" ]; then
    _side="unknown"
    [ "$_commonsh_ours" = "false" ] && _side="ours"
    [ "$_commonsh_theirs" = "false" ] && _side="theirs"
    [ "$_commonsh_ours" = "false" ] && [ "$_commonsh_theirs" = "false" ] && _side="both"
    _bl="{\"type\":\"commonsh_syntax\",\"message\":\"common.sh fails sh -n on side: ${_side} — merge will break hook cascade\"}"
    _blockers="$(printf '%s' "$_blockers" | jq --argjson e "$_bl" '. + [$e]')"
  fi

  if [ "$_rws_exit" -ne 0 ]; then
    _bl="{\"type\":\"no_reintegration_json\",\"message\":\"rws get-reintegration-json failed (exit $_rws_exit) — row may not be archived or reintegration section may be missing\"}"
    _blockers="$(printf '%s' "$_blockers" | jq --argjson e "$_bl" '. + [$e]')"
  fi

  # ---------------------------------------------------------------------------
  # 9. Write audit.json
  # ---------------------------------------------------------------------------
  _stale_refs="{\"todos\":${_stale_todos},\"rows\":${_stale_rows}}"

  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$_merge_id" \
    --arg branch "$_resolved_branch" \
    --arg base_sha "$_base_sha" \
    --arg head_sha "$_head_sha" \
    --arg policy_path "$_policy_path" \
    --arg policy_sha256 "$_policy_sha256" \
    --argjson symlink_typechanges "$_symlink_typechanges" \
    --argjson protected_touches "$_protected_touches" \
    --argjson install_artifact_additions "$_install_artifact_additions" \
    --argjson overlap_commits "$_overlap_commits" \
    --argjson stale_references "$_stale_refs" \
    --argjson commonsh_parse "{\"ours\":${_commonsh_ours},\"theirs\":${_commonsh_theirs}}" \
    --argjson blockers "$_blockers" \
    --argjson reintegration_json "$_reintegration_json" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      branch: $branch,
      base_sha: $base_sha,
      head_sha: $head_sha,
      policy_path: $policy_path,
      policy_sha256: $policy_sha256,
      symlink_typechanges: $symlink_typechanges,
      protected_touches: $protected_touches,
      install_artifact_additions: $install_artifact_additions,
      overlap_commits: $overlap_commits,
      stale_references: $stale_references,
      commonsh_parse: $commonsh_parse,
      blockers: $blockers,
      reintegration_json: $reintegration_json
    }' > "${_merge_dir}/audit.json"

  _n_blockers="$(printf '%s' "$_blockers" | jq 'length')"
  _info "audit complete: merge_id=$_merge_id blockers=$_n_blockers"
  printf 'merge_id=%s\n' "$_merge_id"

  if [ "$_n_blockers" -gt 0 ]; then
    _warn "Audit found $_n_blockers blocker(s). Review ${_merge_dir}/audit.json before proceeding."
    printf '%s' "$_blockers" | jq -r '.[].message' | while IFS= read -r _msg; do
      printf '[furrow:warning] merge-audit:   - %s\n' "$_msg" >&2
    done
    exit 3
  fi

  exit 0
}

# Allow direct invocation
frw_merge_audit "$@"
