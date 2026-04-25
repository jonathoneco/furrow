# shellcheck shell=sh
# script-guard.sh — Block direct execution of bin/frw.d/ scripts
# (D3 migrated shim).
#
# Hook: PreToolUse (matcher: Bash)
# Backend: internal/cli/shellparse.go::handlePreBashInternalScript
# Returns: 0 (allow) | 2 (block)
#
# The 100-line POSIX-awk shell tokenizer was ported to Go in D2
# (internal/cli/shellparse.go::shellStripDataRegions). The shim just
# translates the Bash tool_input.command into a normalized event.

# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"

hook_script_guard() {
  claude_tool_input_to_event pre_bash_internal_script \
    | furrow_guard pre_bash_internal_script \
    | emit_canonical_blocker
}
