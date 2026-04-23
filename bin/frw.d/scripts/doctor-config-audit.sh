#!/bin/sh
# doctor-config-audit.sh — Field → consumer audit for XDG config.
#
# Enumerates known config fields against resolver call sites in the codebase
# and emits a non-gating warning for any field that has zero consumers.
#
# Contract:
#   Args:    none
#   Reads:   hardcoded list of known fields; scans source tree for
#            `resolve_config_value "<field>"` call sites.
#   Stdout:  human-readable table `field<TAB>consumer_count<TAB>status`
#   Stderr:  WARN lines for fields with zero consumers (advisory; non-fatal)
#   Exit:    0 always (warnings are non-gating; see AC-6).
#
# Invoked by the existing `frw doctor` subcommand via a single shell-out —
# bin/frw itself is not modified. Source of truth for the field list is
# `docs/architecture/config-resolution.md` (Field → Consumer → Test table).

set -eu

# --- Resolve FURROW_ROOT (the install/source tree) --------------------------
SCRIPT_PATH="$(readlink -f "$0" 2>/dev/null || printf '%s' "$0")"
if [ -z "${FURROW_ROOT:-}" ]; then
  # bin/frw.d/scripts/<script> → FURROW_ROOT is three dirs up.
  FURROW_ROOT="$(cd "$(dirname "$SCRIPT_PATH")/../../.." && pwd)"
fi

# --- Known config fields (mirror of docs/architecture/config-resolution.md) -
# Order matches the audit table; doctor-config-audit.sh is the canonical
# machine-readable source once the doc diverges.
KNOWN_FIELDS="
cross_model.provider
gate_policy
preferred_specialists
promotion_targets_path
"

# --- Count resolver call sites for a field ---------------------------------
# Matches `resolve_config_value <field>` or `resolve_config_value "<field>..."
# (dotted subkeys like preferred_specialists.<role> count as consumers of the
# parent field).
_count_consumers() {
  _ccu_field="$1"
  # Search in bin/, skills/, commands/. Exclude this audit script itself to
  # avoid self-counting of the field list literal.
  _ccu_paths="${FURROW_ROOT}/bin ${FURROW_ROOT}/skills ${FURROW_ROOT}/commands"
  _ccu_count=0
  for _p in $_ccu_paths; do
    [ -d "$_p" ] || continue
    _n=$(grep -R --include='*.sh' --include='*.md' -F "resolve_config_value" "$_p" 2>/dev/null \
      | grep -v 'doctor-config-audit.sh' \
      | grep -F "$_ccu_field" \
      | wc -l) || _n=0
    _ccu_count=$((_ccu_count + _n))
  done
  printf '%s' "$_ccu_count"
}

# --- Main --------------------------------------------------------------------
printf 'field\tconsumers\tstatus\n'

_had_warn=0
for _field in $KNOWN_FIELDS; do
  [ -n "$_field" ] || continue
  _count=$(_count_consumers "$_field")
  if [ "$_count" -gt 0 ]; then
    _status="ok"
  else
    _status="UNWIRED"
    printf 'WARN: config field %s has zero resolve_config_value call sites\n' \
      "$_field" >&2
    _had_warn=1
  fi
  printf '%s\t%s\t%s\n' "$_field" "$_count" "$_status"
done

# Always exit 0 — audit warnings are advisory, not failures. See AC-6.
exit 0
