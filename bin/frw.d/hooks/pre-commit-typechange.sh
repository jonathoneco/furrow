#!/bin/sh
# pre-commit-typechange.sh — Block type-change to symlink on protected
# paths (D3 migrated shim).
#
# Hook: git pre-commit dispatcher (invoked directly, not via `frw hook`)
# Backend: internal/cli/precommit.go::handlePreCommitTypechange
# Returns: 0 (allow) | 1 (block — git pre-commit convention)
#
# Three separate awk invocations from the pre-D3 hook (audit §2.5 finding
# #1) collapsed into a single awk pass inside precommit_event_typechange.

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
  precommit_event_typechange \
    | furrow_guard pre_commit_typechange \
    | emit_canonical_blocker || _ec=$?
  [ "$_ec" -eq 2 ] && exit 1
  exit "$_ec"
}

main
