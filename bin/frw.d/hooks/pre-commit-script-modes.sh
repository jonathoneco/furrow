#!/bin/sh
# pre-commit-script-modes.sh — Block staging of bin/frw.d/scripts/*.sh
# at non-100755 modes (D3 migrated shim).
#
# Hook: git pre-commit dispatcher (invoked directly, not via `frw hook`)
# Backend: internal/cli/precommit.go::handlePreCommitScriptModes
# Returns: 0 (allow) | 1 (block — git pre-commit convention)
#
# The redundant `head -n1` from the pre-D3 hook (audit §2.4 finding #1)
# is dropped: precommit_event_script_modes uses `awk 'NR==1'` for the
# same effect with one fewer process.

set -eu

FURROW_ROOT="${FURROW_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
export FURROW_ROOT
# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
# shellcheck source=../lib/precommit_payloads.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/precommit_payloads.sh"

main() {
  precommit_init
  _ec=0
  precommit_event_script_modes \
    | furrow_guard pre_commit_script_modes \
    | emit_canonical_blocker || _ec=$?
  [ "$_ec" -eq 2 ] && exit 1
  exit "$_ec"
}

main
