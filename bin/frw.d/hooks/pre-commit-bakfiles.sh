#!/bin/sh
# pre-commit-bakfiles.sh — Block staging of install-artifact .bak files
# (D3 migrated shim).
#
# Hook: git pre-commit dispatcher (invoked directly, not via `frw hook`)
# Backend: internal/cli/precommit.go::handlePreCommitBakfiles
# Returns: 0 (allow) | 1 (block — git pre-commit convention)
#
# The shim's only responsibility is git plumbing: capture the staged path
# list and hand a structured payload to `furrow guard`.

set -eu

FURROW_ROOT="${FURROW_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
export FURROW_ROOT
# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
# shellcheck source=../lib/precommit_payloads.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/precommit_payloads.sh"

main() {
  precommit_init
  _ev="$(precommit_event_bakfiles)"
  [ -n "$_ev" ] || exit 0
  _ec=0
  printf '%s' "$_ev" | furrow_guard pre_commit_bakfiles | emit_canonical_blocker || _ec=$?
  # Translate canonical block exit (2) to git pre-commit convention (1).
  [ "$_ec" -eq 2 ] && exit 1
  exit "$_ec"
}

main
