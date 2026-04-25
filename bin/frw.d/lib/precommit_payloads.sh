#!/bin/sh
# precommit_payloads.sh — D3 helpers that assemble normalized BlockerEvent
# payloads for the three pre-commit guard event types.
#
# These helpers are NEW in D3 (added per shared-contracts.md §C4 escape
# valve: "D3 may add new helpers to bin/frw.d/lib/ if shared by >=2 shims").
# They factor out git-plumbing so the pre-commit shim bodies stay at the
# canonical 4-step shape and the Go handlers (internal/cli/precommit.go)
# stay free of git-CLI invocation.
#
# Exports (POSIX sh functions):
#
#   precommit_event_bakfiles
#       Stdin:  none
#       Stdout: normalized BlockerEvent JSON for `pre_commit_bakfiles`
#       Side:   reads `git diff --cached --name-only` once
#       Exit:   0 always (empty payload on git failure is fine — the Go
#               handler's `requireArray` will pass cleanly with no emit)
#
#   precommit_event_typechange
#       Stdin:  none
#       Stdout: normalized BlockerEvent JSON for `pre_commit_typechange`
#       Side:   reads `git diff --cached --raw` once
#       Exit:   0 always
#
#   precommit_event_script_modes
#       Stdin:  none
#       Stdout: normalized BlockerEvent JSON for `pre_commit_script_modes`
#       Side:   reads `git diff --cached --name-only --diff-filter=ACM`
#               and one `git ls-files -s` per matching path
#       Exit:   0 always
#
# Each helper writes a JSON object to stdout. The shim then pipes that
# stdout to `furrow_guard <event_type> | emit_canonical_blocker`.

if [ -n "${_FRW_PRECOMMIT_PAYLOADS_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_FRW_PRECOMMIT_PAYLOADS_SOURCED=1

# precommit_event_bakfiles
#
# Pre-commit-bakfiles payload contract (internal/cli/precommit.go::handlePreCommitBakfiles):
#   { "version": "1", "event_type": "pre_commit_bakfiles",
#     "payload": { "staged_paths": [<path>, ...] } }
precommit_event_bakfiles() {
  _staged="$(git diff --cached --name-only 2>/dev/null || printf '')"
  printf '%s' "$_staged" \
    | jq -R -s -c '
        split("\n") | map(select(length > 0)) as $paths
        | { version: "1",
            event_type: "pre_commit_bakfiles",
            payload: { staged_paths: $paths } }
      '
}

# precommit_event_typechange
#
# Parses `git diff --cached --raw` into structured entries. Each raw row:
#   :100644 120000 <sha> <sha> T\tpath
# becomes {path, new_mode, status} in the payload. The Go handler filters
# for status==T && new_mode==120000 on protected paths.
#
# Pre-commit-typechange payload contract (internal/cli/precommit.go::handlePreCommitTypechange):
#   { "version": "1", "event_type": "pre_commit_typechange",
#     "payload": { "typechange_entries": [{path, new_mode, status}, ...] } }
precommit_event_typechange() {
  _raw="$(git diff --cached --raw 2>/dev/null || printf '')"
  # awk one-pass: emit one tab-separated record per raw row (path, new_mode,
  # status), then jq folds them into the JSON array. Combining the three
  # field reads into a single awk replaces the three-awk pattern in the
  # pre-D3 hook (audit §2.5 finding #1).
  printf '%s' "$_raw" \
    | awk 'NF >= 6 {
             # status column 5 is e.g. "T" or "T100" for renames; cut to first char
             status = substr($5, 1, 1)
             # path column 6 onwards (path can contain spaces — collapse rest)
             path = $6
             for (i = 7; i <= NF; i++) path = path " " $i
             printf "%s\t%s\t%s\n", path, $2, status
           }' \
    | jq -R -s -c '
        split("\n") | map(select(length > 0)) | map(split("\t"))
        | map({ path: .[0], new_mode: .[1], status: .[2] }) as $entries
        | { version: "1",
            event_type: "pre_commit_typechange",
            payload: { typechange_entries: $entries } }
      '
}

# precommit_event_script_modes
#
# Pre-commit-script-modes payload contract (internal/cli/precommit.go::handlePreCommitScriptModes):
#   { "version": "1", "event_type": "pre_commit_script_modes",
#     "payload": { "script_modes": [{path, mode}, ...] } }
#
# Iterates staged ACM paths under bin/frw.d/scripts/*.sh and captures each
# path's git index mode via `git ls-files -s`. The Go handler decides
# whether mode != 100755 is a violation.
precommit_event_script_modes() {
  _staged="$(git diff --cached --name-only --diff-filter=ACM 2>/dev/null || printf '')"
  # Collect tab-separated path<TAB>mode lines for matching paths only.
  _entries="$(
    printf '%s\n' "$_staged" \
      | while IFS= read -r _p; do
          [ -n "$_p" ] || continue
          case "$_p" in
            bin/frw.d/scripts/*.sh) ;;
            *) continue ;;
          esac
          _m="$(git ls-files -s -- "$_p" 2>/dev/null | awk 'NR==1{print $1}')"
          [ -n "$_m" ] || continue
          printf '%s\t%s\n' "$_p" "$_m"
        done
  )"
  printf '%s' "$_entries" \
    | jq -R -s -c '
        split("\n") | map(select(length > 0)) | map(split("\t"))
        | map({ path: .[0], mode: .[1] }) as $entries
        | { version: "1",
            event_type: "pre_commit_script_modes",
            payload: { script_modes: $entries } }
      '
}
