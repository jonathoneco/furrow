#!/bin/sh
# auto-install.sh — SessionStart hook that verifies Furrow installation
#
# Runs frw install --check silently. If it fails, runs frw install --project
# to self-heal. Designed to be fast and quiet when everything is fine.

hook_auto_install() {
  # Only run if this project has a furrow.yaml (i.e., Furrow is expected here)
  _config=""
  for _candidate in .furrow/furrow.yaml .claude/furrow.yaml furrow.yaml; do
    if [ -f "$_candidate" ]; then
      _config="$_candidate"
      break
    fi
  done
  [ -n "$_config" ] || return 0

  # Quick check — if it passes, we're done (quiet mode suppresses output)
  if frw install --check . >/dev/null 2>&1; then
    return 0
  fi

  # Auto-heal — re-run full install to pick up new commands, specialists, rules
  echo "[furrow] Installation drift detected, auto-repairing..." >&2
  if frw install --project . >/dev/null 2>&1; then
    echo "[furrow] Installation repaired." >&2
  else
    echo "[furrow] Auto-repair failed. Run 'frw install --project .' manually." >&2
  fi
}
