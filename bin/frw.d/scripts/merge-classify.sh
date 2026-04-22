#!/bin/sh
# merge-classify.sh — Phase 2 of /furrow:merge
#
# Usage: frw_merge_classify <merge_id>
#
# Reads audit.json from the merge-state directory and classifies each
# worktree commit into: safe / redundant-with-main / destructive / mixed.
#
# Exit codes:
#   0  classification produced; all commits safe or redundant
#   1  usage error
#   2  audit.json missing or malformed / policy invalid
#   4  one or more destructive or mixed commits found
#
# Stdout: path to classify.json
# Stderr: human-readable summary.

set -eu

SCRIPT_PATH="$(readlink -f "$0")"
SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"
FURROW_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

_die() { printf '[furrow:error] merge-classify: %s\n' "$1" >&2; exit "${2:-1}"; }
_info() { printf '[furrow:info] merge-classify: %s\n' "$*" >&2; }
_warn() { printf '[furrow:warning] merge-classify: %s\n' "$*" >&2; }

_get_state_dir() {
  _xdg="${XDG_STATE_HOME:-${HOME}/.local/state}"
  _repo_slug="$(basename "$FURROW_ROOT")"
  printf '%s/furrow/%s/merge-state' "$_xdg" "$_repo_slug"
}

frw_merge_classify() {
  [ $# -ge 1 ] || { printf 'Usage: frw merge-classify <merge_id>\n' >&2; exit 1; }

  _merge_id="$1"
  _state_base="$(_get_state_dir)"
  _merge_dir="${_state_base}/${_merge_id}"
  _audit_json="${_merge_dir}/audit.json"

  command -v jq >/dev/null 2>&1 || _die "jq is required but not found in PATH" 2

  [ -f "$_audit_json" ] || _die "audit.json not found at ${_audit_json} — run merge-audit first" 2

  # Validate audit.json is valid JSON
  jq . "$_audit_json" >/dev/null 2>&1 || _die "audit.json is malformed" 2

  _branch="$(jq -r '.branch' "$_audit_json")"
  _base_sha="$(jq -r '.base_sha' "$_audit_json")"
  _head_sha="$(jq -r '.head_sha' "$_audit_json")"

  _info "classifying commits on $_branch (base=$_base_sha head=$_head_sha)"

  # Get commits from reintegration_json if available, else fall back to git log
  _reint_commits="$(jq -r '.reintegration_json.commits // [] | length' "$_audit_json" 2>/dev/null || echo 0)"

  # Build commit list from git log between base and head
  _commits_json="[]"
  _has_destructive=0

  # Get overlap commit SHAs from audit
  _overlap_shas="$(jq -r '.overlap_commits[].sha // empty' "$_audit_json" 2>/dev/null || true)"

  # Get install artifact additions from audit
  _has_artifacts="$(jq -r '.install_artifact_additions | length' "$_audit_json")"

  # Get protected touches from audit
  _has_protected="$(jq -r '.protected_touches | length' "$_audit_json")"

  # Get symlink typechanges from audit
  _has_symlinks="$(jq -r '.symlink_typechanges | length' "$_audit_json")"

  # Iterate over worktree commits
  _git_log="$(git -C "$PROJECT_ROOT" log --pretty=format:'%H %s' "${_base_sha}..${_head_sha}" 2>/dev/null || true)"

  # Get files changed per commit
  while IFS= read -r _commit_line; do
    [ -z "$_commit_line" ] && continue
    _sha="$(printf '%s' "$_commit_line" | awk '{print $1}')"
    _subj="$(printf '%s' "$_commit_line" | cut -d' ' -f2-)"

    # Default label
    _label="safe"
    _rationale="Pure source change; no contamination signals detected."

    # Check if redundant with main (subject in overlap commits)
    _is_overlap=0
    for _os in $_overlap_shas; do
      [ "$_os" = "$_sha" ] && _is_overlap=1 && break
    done

    if [ "$_is_overlap" -eq 1 ]; then
      _label="redundant-with-main"
      _rationale="Commit subject matches a commit on main — likely a cherry-pick duplicate."
    else
      # Get files changed in this commit
      _commit_files="$(git -C "$PROJECT_ROOT" diff-tree --no-commit-id -r --name-only "$_sha" 2>/dev/null || true)"

      # Check for destructive signals in this commit's files
      _commit_has_artifact=0
      _commit_has_symlink=0
      _commit_has_protected=0
      _commit_has_safe=0

      for _f in $_commit_files; do
        # Check install artifacts
        case "$_f" in
          bin/*.bak|.claude/rules/*.bak|*/.bak)
            _commit_has_artifact=1
            ;;
        esac

        # Check symlink typechanges
        _f_old_mode="$(git -C "$PROJECT_ROOT" diff-tree --no-commit-id -r --diff-filter=T "$_sha" -- "$_f" 2>/dev/null | awk '{print $1}' | head -1 || echo '')"
        [ -n "$_f_old_mode" ] && _commit_has_symlink=1

        # Check protected paths (simplified: check common protected paths)
        case "$_f" in
          bin/alm|bin/rws|bin/sds|bin/frw.d/lib/common.sh|bin/frw.d/lib/common-minimal.sh)
            _commit_has_protected=1
            ;;
          .claude/rules/*)
            _commit_has_protected=1
            ;;
          schemas/*.json|schemas/*.yaml)
            _commit_has_protected=1
            ;;
          *)
            _commit_has_safe=1
            ;;
        esac
      done

      # Also check install_artifact_risk from reintegration_json
      _rir="none"
      if [ "$_reint_commits" -gt 0 ]; then
        _rir="$(jq -r --arg sha "$_sha" \
          '.reintegration_json.commits[] | select(.sha == $sha or (.sha | startswith($sha)) or ($sha | startswith(.sha))) | .install_artifact_risk // "none"' \
          "$_audit_json" 2>/dev/null | head -1 || echo 'none')"
      fi

      # Classify
      _is_destructive=0
      [ "$_commit_has_artifact" -eq 1 ] && _is_destructive=1
      [ "$_commit_has_symlink" -eq 1 ] && _is_destructive=1
      [ "$_rir" = "high" ] && _is_destructive=1
      [ "$_rir" = "medium" ] && _is_destructive=1

      if [ "$_is_destructive" -eq 1 ] && [ "$_commit_has_safe" -eq 1 ]; then
        _label="mixed"
        _rationale="Commit mixes source changes with install artifacts or protected-file modifications."
        _has_destructive=1
      elif [ "$_is_destructive" -eq 1 ]; then
        _label="destructive"
        _rationale="Commit adds install artifacts or modifies protected paths (install_artifact_risk=${_rir})."
        _has_destructive=1
      fi
    fi

    # Append to commits array
    _entry="$(jq -n \
      --arg sha "$_sha" \
      --arg subject "$_subj" \
      --arg label "$_label" \
      --arg rationale "$_rationale" \
      '{sha: $sha, subject: $subject, label: $label, rationale: $rationale}')"

    _commits_json="$(printf '%s' "$_commits_json" | jq --argjson e "$_entry" '. + [$e]')"

  done <<EOF
$_git_log
EOF

  # Write classify.json
  jq -n \
    --arg schema_version "1.0" \
    --arg merge_id "$_merge_id" \
    --arg branch "$_branch" \
    --argjson commits "$_commits_json" \
    '{
      schema_version: $schema_version,
      merge_id: $merge_id,
      branch: $branch,
      commits: $commits
    }' > "${_merge_dir}/classify.json"

  # Write classify.md (human-readable table)
  {
    printf '# Merge Classification: %s\n\n' "$_branch"
    printf '| SHA | Subject | Label | Rationale |\n'
    printf '|-----|---------|-------|-----------|\n'
    printf '%s' "$_commits_json" | jq -r '.[] | "| \(.sha[0:8]) | \(.subject | .[0:60]) | \(.label) | \(.rationale | .[0:80]) |"'
    printf '\n'
    if [ "$_has_destructive" -eq 1 ]; then
      printf '> **Warning**: One or more commits are classified as `destructive` or `mixed`.\n'
      printf '> Review `classify.json` and edit `plan.md` to resolve before executing.\n'
    fi
  } > "${_merge_dir}/classify.md"

  _total="$(printf '%s' "$_commits_json" | jq 'length')"
  _info "classified $_total commit(s)"
  printf '%s\n' "${_merge_dir}/classify.json"

  if [ "$_has_destructive" -eq 1 ]; then
    _warn "One or more commits are destructive or mixed — human review required."
    exit 4
  fi

  exit 0
}

frw_merge_classify "$@"
