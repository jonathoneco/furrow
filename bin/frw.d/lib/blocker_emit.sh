#!/bin/sh
# blocker_emit.sh — Canonical shell adapter for `furrow guard <event-type>`.
#
# POSIX sh. Source this file from hook shims (D3 deliverable). Do not
# execute directly. Exposes four functions per specs/shared-contracts.md
# §C4 — signatures locked, do not modify:
#
#   claude_tool_input_to_event <event_type>
#       Stdin:  Claude PreToolUse JSON ({tool_name, tool_input: {...}})
#       Stdout: normalized BlockerEvent JSON ({version, event_type,
#               target_path?, payload})
#       Exit:   0 always (input validation errors are the upstream
#               caller's responsibility — claude_tool_input_to_event
#               emits a best-effort payload and lets the guard handler
#               decide on missing keys).
#
#   furrow_guard <event_type>
#       Stdin:  normalized BlockerEvent JSON
#       Stdout: JSON array of zero or more BlockerEnvelope objects
#       Exit:   0 if guard ran cleanly; 1 on guard invocation error
#
#   emit_canonical_blocker
#       Stdin:  envelope-array JSON
#       Stdout: empty
#       Stderr: one `[furrow:<severity>] <message>` line per envelope
#       Exit:   2 if any envelope has severity=block; 0 otherwise
#
#   precommit_init
#       Args/Stdin: none
#       Stdout: empty
#       Side effect: ensures FURROW_ROOT and log_warning/log_error
#                    helpers are available in the caller's environment.
#       Exit:   0 always
#
# Composition pattern (D3 hook shim canonical shape):
#
#   . "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
#   claude_tool_input_to_event pre_write_state_json \
#     | furrow_guard pre_write_state_json \
#     | emit_canonical_blocker
#
# For pre-commit hooks, replace `claude_tool_input_to_event` with
# `precommit_init` (followed by event-specific git-diff plumbing).

# Idempotent source guard, mirroring validate-json.sh:23-26.
if [ -n "${_FRW_BLOCKER_EMIT_SOURCED:-}" ]; then
  return 0 2>/dev/null || true
fi
_FRW_BLOCKER_EMIT_SOURCED=1

# claude_tool_input_to_event <event_type>
#
# Translates a Claude PreToolUse hook payload (stdin) into the normalized
# BlockerEvent shape (stdout) that `furrow guard` consumes. Supports the
# six per-hook event types that originate from Claude tool input:
#
#   - pre_write_state_json
#   - pre_write_verdict
#   - pre_write_correction_limit
#   - pre_bash_internal_script
#   - stop_ideation_completeness        (Claude Stop hook; payload uses row + paths)
#   - stop_summary_validation           (Claude Stop hook)
#   - stop_work_check                   (Claude Stop hook)
#
# Pre-commit event types (`pre_commit_*`) are NOT handled here; their
# shims build the normalized payload directly using `precommit_init` +
# git plumbing.
claude_tool_input_to_event() {
  _bem_event_type="${1:-}"
  if [ -z "$_bem_event_type" ]; then
    printf 'claude_tool_input_to_event: missing event_type arg\n' >&2
    return 0
  fi
  _bem_input="$(cat 2>/dev/null || true)"

  case "$_bem_event_type" in
    pre_write_state_json|pre_write_verdict|pre_write_correction_limit)
      # Pre-write events extract target_path from tool_input.
      _bem_target="$(printf '%s' "$_bem_input" | jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // ""' 2>/dev/null || printf '')"
      _bem_tool="$(printf '%s' "$_bem_input" | jq -r '.tool_name // ""' 2>/dev/null || printf '')"
      jq -n \
        --arg version "1" \
        --arg event_type "$_bem_event_type" \
        --arg target_path "$_bem_target" \
        --arg tool_name "$_bem_tool" \
        '{
           version: $version,
           event_type: $event_type,
           target_path: $target_path,
           payload: { target_path: $target_path, tool_name: $tool_name }
         }'
      ;;
    pre_bash_internal_script)
      _bem_command="$(printf '%s' "$_bem_input" | jq -r '.tool_input.command // ""' 2>/dev/null || printf '')"
      jq -n \
        --arg version "1" \
        --arg event_type "$_bem_event_type" \
        --arg command "$_bem_command" \
        '{
           version: $version,
           event_type: $event_type,
           payload: { command: $command }
         }'
      ;;
    stop_ideation_completeness|stop_summary_validation|stop_work_check)
      # Stop hooks: Claude payload is mostly empty for the guard's
      # purposes; the shim is expected to provide row + path context via
      # environment or by composing its own jq filter. The default
      # translation here passes through any row/step/path the caller
      # injected via `--arg`. Callers that need richer payloads should
      # author their own jq filter and feed `furrow_guard` directly.
      jq -n \
        --arg version "1" \
        --arg event_type "$_bem_event_type" \
        --arg row "${FURROW_ROW:-}" \
        --arg step "${FURROW_STEP:-}" \
        '{
           version: $version,
           event_type: $event_type,
           row: $row,
           step: $step,
           payload: { row: $row }
         }'
      ;;
    *)
      printf 'claude_tool_input_to_event: unsupported event_type %s\n' "$_bem_event_type" >&2
      printf '{"version":"1","event_type":"%s","payload":{}}\n' "$_bem_event_type"
      ;;
  esac
  return 0
}

# furrow_guard <event_type>
#
# Invokes the Go backend over a subprocess. Honors the FURROW_BIN env
# override (e.g., to a prebuilt binary) for test-suite speed; falls
# through to `go run ./cmd/furrow` from FURROW_ROOT otherwise.
#
# The cd into FURROW_ROOT mirrors the pattern at
# bin/frw.d/hooks/ownership-warn.sh:60-61.
furrow_guard() {
  _fg_event_type="${1:-}"
  if [ -z "$_fg_event_type" ]; then
    printf 'furrow_guard: missing event_type arg\n' >&2
    return 1
  fi
  _fg_root="${FURROW_ROOT:-}"
  if [ -z "$_fg_root" ]; then
    _fg_root="$(git rev-parse --show-toplevel 2>/dev/null)" || _fg_root="."
  fi

  # Use FURROW_BIN if set (built binary, e.g., /tmp/furrow-test); else
  # `go run ./cmd/furrow` from the project root. The eval is intentional
  # so FURROW_BIN can be a multi-token override (rare, but supported).
  if [ -n "${FURROW_BIN:-}" ]; then
    # shellcheck disable=SC2086
    eval "$FURROW_BIN" guard "$_fg_event_type"
    return $?
  fi

  ( cd "$_fg_root" && go run ./cmd/furrow guard "$_fg_event_type" )
  return $?
}

# emit_canonical_blocker
#
# Reads an envelope-array JSON document on stdin. For each envelope:
#   - prints `[furrow:<severity>] <message>` to stderr;
#   - if remediation_hint is non-empty, prints `        <remediation_hint>`
#     as a continuation line to stderr (matches the indented continuation
#     style of validate-summary.sh's multi-line stderr).
# Returns 2 if any envelope has severity == "block", 0 otherwise.
#
# An empty array (no trigger) is silent.
emit_canonical_blocker() {
  _ecb_input="$(cat 2>/dev/null || true)"
  if [ -z "$_ecb_input" ]; then
    return 0
  fi
  # An empty array short-circuits. jq returns "0" for length([]).
  _ecb_count="$(printf '%s' "$_ecb_input" | jq -r 'length' 2>/dev/null || printf '0')"
  if [ "$_ecb_count" = "0" ]; then
    return 0
  fi

  # Stream envelopes to stderr in canonical format. The compact jq filter
  # emits one stderr block per envelope.
  printf '%s' "$_ecb_input" | jq -r '.[] | "[furrow:\(.severity)] \(.message)\n        \(.remediation_hint)"' >&2

  # Exit code: 2 if any block, else 0. Use jq to detect.
  _ecb_block="$(printf '%s' "$_ecb_input" | jq -r 'any(.severity == "block") | if . then "2" else "0" end' 2>/dev/null || printf '0')"
  if [ "$_ecb_block" = "2" ]; then
    return 2
  fi
  return 0
}

# precommit_init
#
# Eliminates the 8-line boilerplate at the top of every pre-commit hook
# (research/hook-audit.md §2.3 quality finding). Resolves _GIT_ROOT,
# exports FURROW_ROOT, and ensures log_warning/log_error are available.
# Idempotent — safe to call multiple times.
precommit_init() {
  _GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || _GIT_ROOT="."
  FURROW_ROOT="${FURROW_ROOT:-$_GIT_ROOT}"
  export FURROW_ROOT
  if [ -f "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh" ]; then
    # shellcheck disable=SC1091
    . "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
  else
    log_warning() { printf '[furrow:warning] %s\n' "$1" >&2; }
    log_error()   { printf '[furrow:error] %s\n'   "$1" >&2; }
  fi
  return 0
}
