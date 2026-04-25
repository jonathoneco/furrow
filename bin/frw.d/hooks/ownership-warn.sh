# shellcheck shell=sh
# ownership-warn.sh — Warn on file_ownership violations
#
# Hook: PreToolUse (matcher: Write|Edit)
# Receives JSON on stdin with tool_name and tool_input.
# Advisory only — always returns 0.
#
# Updated by D6 of pre-write-validation-go-first:
#   - Delegates the verdict to `furrow validate ownership` (the canonical Go
#     validator from D2). This guarantees identical glob-matching semantics
#     across the Pi and Claude adapters — POSIX shell `case` patterns cannot
#     replicate Go's `**` doublestar handling, which would silently break the
#     cross-adapter parity invariant if implemented in shell directly.
#   - Step gating removed: fires in any step (was: implement-only)
#
# Cross-adapter parity: this hook is the non-interactive Claude equivalent of
# the Pi adapter ownership handler at adapters/pi/furrow.ts (D5). Claude shell
# hooks have no interactive primitive at write time, so the surface here is
# log_warning rather than a confirm prompt; the underlying trigger (the
# `furrow validate ownership` verdict) is identical.

# shellcheck source=../lib/common-minimal.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

hook_ownership_warn() {
  input="$(cat)"

  target_path="$(echo "$input" | jq -r '.tool_input.file_path // .tool_input.path // ""' 2>/dev/null)" || target_path=""

  if [ -z "$target_path" ]; then
    return 0
  fi

  work_dir="$(extract_row_from_path "$target_path")"

  # If the path is not inside any row, fall back to .furrow/.focused — but
  # ONLY if .focused is present and names an active row. Do NOT fall through
  # to find_active_row's most-recently-updated heuristic, because the spec
  # requires graceful silence when no explicit row context exists.
  if [ -z "$work_dir" ]; then
    if [ -f ".furrow/.focused" ]; then
      _focused_name="$(cat ".furrow/.focused" 2>/dev/null)" || _focused_name=""
      if [ -n "$_focused_name" ] && [ -f ".furrow/rows/${_focused_name}/state.json" ]; then
        _archived="$(jq -r '.archived_at // "null"' ".furrow/rows/${_focused_name}/state.json" 2>/dev/null)" || _archived="null"
        if [ "$_archived" = "null" ]; then
          work_dir=".furrow/rows/${_focused_name}"
        fi
      fi
    fi
  fi

  if [ -z "$work_dir" ]; then
    return 0
  fi

  row_name="$(basename "$work_dir")"

  # Delegate to the canonical Go validator. Output is JSON; we only need the
  # verdict and (on out_of_scope) the message field.
  cd "${FURROW_ROOT}" || return 0
  result_json="$(go run ./cmd/furrow validate ownership --path "$target_path" --row "$row_name" --json 2>/dev/null)" || return 0

  verdict="$(echo "$result_json" | jq -r '.data.verdict // ""' 2>/dev/null)" || verdict=""

  if [ "$verdict" != "out_of_scope" ]; then
    return 0
  fi

  message="$(echo "$result_json" | jq -r '.data.envelope.message // ""' 2>/dev/null)" || message=""

  if [ -z "$message" ]; then
    message="File write outside file_ownership: ${target_path}"
  fi

  log_warning "${message}"
  return 0
}
