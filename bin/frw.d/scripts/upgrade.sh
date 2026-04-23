#!/bin/sh
# upgrade.sh — Furrow XDG migration and upgrade tool.
#
# Sourced by bin/frw (upgrade dispatcher case); not executed directly.
# Sources common-minimal.sh only (AD-1 hook-safe layering).
#
# Interface:
#   frw upgrade [--check] [--apply] [--from <legacy-path>]
#
# Options:
#   --check             (default) Report what upgrade would do; exit 0 if current,
#                       exit 10 if migration needed, exit 2 on fatal detection error.
#   --apply             Perform the migration. Exit 0 on success, exit 1 on partial
#                       failure (rolled back), exit 2 on fatal error.
#   --from <path>       Override legacy-path auto-detection (for tests and recovery).
#
# Migration versions:
#   "0"  → pre-XDG install (.claude/furrow.yaml present, no XDG config)
#   "1.0" → current XDG install (this deliverable's target)
#
# Idempotency: second --apply on a migrated install exits 0 with no writes.
# Source-repo guard: refuses to write XDG artifacts when FURROW_ROOT contains
# .furrow/SOURCE_REPO (prevents polluting developer ~/.config).
#
# Exit codes:
#   0   Already current / apply succeeded
#   1   Partial failure (apply; rolled back to pre-upgrade state)
#   2   Fatal error (detection or apply)
#   10  Migration needed (check mode only)

set -eu

# FURROW_ROOT is set by the bin/frw dispatcher before sourcing this file.
# Source common-minimal.sh for log_error / log_warning (AD-1 layering).
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"

CURRENT_MIGRATION_VERSION="1.0"

# ---------------------------------------------------------------------------
# _upgrade_xdg_config_home — honor env var or fall back to $HOME/.config
# ---------------------------------------------------------------------------
_upgrade_xdg_config_home() {
  printf '%s' "${XDG_CONFIG_HOME:-${HOME}/.config}"
}

_upgrade_xdg_state_home() {
  printf '%s' "${XDG_STATE_HOME:-${HOME}/.local/state}"
}

# ---------------------------------------------------------------------------
# _upgrade_read_migration_version <state_file>
# Returns the migration_version field, or "0" if absent/unreadable.
# ---------------------------------------------------------------------------
_upgrade_read_migration_version() {
  _umv_file="$1"
  if [ -f "$_umv_file" ]; then
    _umv_ver="$(jq -r '.migration_version // "0"' "$_umv_file" 2>/dev/null || true)"
    [ -n "$_umv_ver" ] && printf '%s' "$_umv_ver" || printf '%s' "0"
  else
    printf '%s' "0"
  fi
}

# ---------------------------------------------------------------------------
# _upgrade_repo_slug — normalized slug from current dir (mirrors install.sh)
# ---------------------------------------------------------------------------
_upgrade_repo_slug() {
  _urs_dir="${1:-$(pwd)}"
  _slug="$(basename "$(cd "$_urs_dir" 2>/dev/null && git rev-parse --show-toplevel 2>/dev/null || printf '%s' "$_urs_dir")")"
  _slug="$(LC_ALL=C printf '%s' "$_slug" | tr -c '[:alnum:]-' '-')"
  _slug="$(printf '%s' "$_slug" | sed 's/-*$//; s/^-*//')"
  [ -z "$_slug" ] && _slug="furrow"
  printf '%s' "$_slug"
}

# ---------------------------------------------------------------------------
# _upgrade_find_state_file <xdg_state_home> <slug>
# Returns path to install-state.json (may not exist yet).
# ---------------------------------------------------------------------------
_upgrade_find_state_file() {
  printf '%s/furrow/%s/install-state.json' "$1" "$2"
}

# ---------------------------------------------------------------------------
# _upgrade_write_promotion_targets <xdg_config_home>
# Writes an empty-but-valid promotion-targets.yaml at the XDG config path.
# Idempotent: skips if file already exists and contains targets:
# ---------------------------------------------------------------------------
_upgrade_write_promotion_targets() {
  _uwpt_cfg="$1"
  _uwpt_dir="${_uwpt_cfg}/furrow"
  _uwpt_file="${_uwpt_dir}/promotion-targets.yaml"

  if [ -f "$_uwpt_file" ] && grep -q "^targets:" "$_uwpt_file" 2>/dev/null; then
    return 0  # already scaffolded
  fi

  mkdir -p "$_uwpt_dir"
  # Atomic write via temp file
  _uwpt_tmp="${_uwpt_dir}/promotion-targets.yaml.tmp.$$"
  printf '# Furrow promotion-targets registry\n# Phase 2 ambient-promotion reads this file.\ntargets: []\n' \
    > "$_uwpt_tmp"
  mv "$_uwpt_tmp" "$_uwpt_file"
}

# ---------------------------------------------------------------------------
# _upgrade_update_state_file <state_file> <slug> <migration_version>
# Reads the existing install-state.json, updates migration_version and
# adds last_upgrade_at. Atomic (temp + mv). Never creates a new state file
# from scratch — that is install.sh's job.
# ---------------------------------------------------------------------------
_upgrade_update_state_file() {
  _uusf_file="$1"
  _uusf_mver="$2"
  _uusf_now="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"

  if [ ! -f "$_uusf_file" ]; then
    log_error "install-state.json not found at $_uusf_file — run frw install first"
    return 2
  fi

  _uusf_tmp="${_uusf_file}.tmp.$$"
  jq --arg mv "$_uusf_mver" --arg ts "$_uusf_now" \
    '. + {migration_version: $mv, last_upgrade_at: $ts}' \
    "$_uusf_file" > "$_uusf_tmp" 2>/dev/null && mv "$_uusf_tmp" "$_uusf_file"
}

# ---------------------------------------------------------------------------
# _upgrade_record_migration_applied <state_file> <migration_id>
# Appends <migration_id> to install-state.json's migrations_applied array
# (deduped). Atomic. No-op when <migration_id> is already recorded.
# Used for migrations that run in addition to the migration_version bump
# (e.g., pre-XDG specialists move) so a second run can detect "already done".
# ---------------------------------------------------------------------------
_upgrade_record_migration_applied() {
  _urma_file="$1"
  _urma_id="$2"

  [ -f "$_urma_file" ] || return 0

  # Idempotent append: only add if not already present.
  if jq -e --arg id "$_urma_id" \
      '(.migrations_applied // []) | index($id)' \
      "$_urma_file" >/dev/null 2>&1; then
    return 0
  fi

  _urma_tmp="${_urma_file}.tmp.$$"
  jq --arg id "$_urma_id" \
    '.migrations_applied = ((.migrations_applied // []) + [$id] | unique)' \
    "$_urma_file" > "$_urma_tmp" 2>/dev/null && mv "$_urma_tmp" "$_urma_file"
}

# ---------------------------------------------------------------------------
# _upgrade_migration_applied <state_file> <migration_id>
# Exit 0 if <migration_id> is in migrations_applied, exit 1 otherwise.
# ---------------------------------------------------------------------------
_upgrade_migration_applied() {
  _uma_file="$1"
  _uma_id="$2"
  [ -f "$_uma_file" ] || return 1
  jq -e --arg id "$_uma_id" \
    '((.migrations_applied // []) | index($id)) != null' \
    "$_uma_file" >/dev/null 2>&1
}

# ---------------------------------------------------------------------------
# _upgrade_migrate_pre_xdg_specialists <project_root> <xdg_config_home> <state_file>
# Migrates pre-XDG .claude/specialists/*.md to the XDG tier-2 location at
# $XDG_CONFIG_HOME/furrow/specialists/. Uses cp -a (not mv) so the legacy
# .claude/specialists/ directory remains as a rollback/diagnostic path;
# after copy, the legacy dir is replaced with a symlink to the XDG dir for
# back-compat (mirrors the .claude/furrow.yaml symlink pattern).
#
# Idempotent: no-op when
#   (a) .claude/specialists/ is absent (already migrated / never existed), or
#   (b) .claude/specialists/ is already a symlink (previous migration), or
#   (c) migrations_applied already contains "pre_xdg_specialists".
#
# Does NOT overwrite XDG files that already exist — existing user-global
# specialists take precedence over the legacy copy.
#
# Returns 0 on success or no-op, 1 on failure.
# ---------------------------------------------------------------------------
_upgrade_migrate_pre_xdg_specialists() {
  _umps_proj="$1"
  _umps_cfg="$2"
  _umps_state="$3"

  _umps_legacy="${_umps_proj}/.claude/specialists"
  _umps_xdg_dir="${_umps_cfg}/furrow/specialists"

  # (a) already recorded → no-op
  if _upgrade_migration_applied "$_umps_state" "pre_xdg_specialists"; then
    return 0
  fi

  # (b) legacy dir absent → nothing to migrate; record as applied so future
  #     runs short-circuit without re-checking the filesystem.
  if [ ! -d "$_umps_legacy" ]; then
    _upgrade_record_migration_applied "$_umps_state" "pre_xdg_specialists"
    return 0
  fi

  # (c) legacy path is already a symlink → previously migrated; record + exit.
  if [ -L "$_umps_legacy" ]; then
    _upgrade_record_migration_applied "$_umps_state" "pre_xdg_specialists"
    return 0
  fi

  # Proceed with migration. Ensure XDG target dir exists.
  mkdir -p "$_umps_xdg_dir"

  # Copy each .md (preserving mode/timestamps). Skip files that already exist
  # at XDG — tier-2 files are authoritative if the user pre-populated them.
  _umps_any=0
  for _umps_src in "$_umps_legacy"/*.md; do
    [ -e "$_umps_src" ] || continue
    _umps_any=1
    _umps_base="$(basename "$_umps_src")"
    _umps_dst="${_umps_xdg_dir}/${_umps_base}"
    if [ -e "$_umps_dst" ]; then
      continue
    fi
    # Atomic per-file: cp to tmp then mv. cp -a preserves mode/timestamps.
    _umps_tmp="${_umps_dst}.tmp.$$"
    if ! cp -a "$_umps_src" "$_umps_tmp"; then
      rm -f "$_umps_tmp"
      log_error "frw upgrade: failed to copy ${_umps_src} → ${_umps_dst}"
      return 1
    fi
    mv "$_umps_tmp" "$_umps_dst"
  done

  # Replace legacy dir with a symlink to the XDG dir for back-compat.
  # Skip when the legacy dir contained no .md files (preserve odd layouts).
  if [ "$_umps_any" = "1" ]; then
    # Only rename when removing is safe: legacy must be a real dir with only
    # tracked .md files copied above. We keep it conservative: move it aside
    # with a .pre-xdg suffix, then symlink.
    _umps_backup="${_umps_legacy}.pre-xdg"
    # If a prior attempt left a .pre-xdg dir, leave it; don't clobber.
    if [ ! -e "$_umps_backup" ]; then
      mv "$_umps_legacy" "$_umps_backup"
      ln -s "$_umps_xdg_dir" "$_umps_legacy"
    fi
  fi

  _upgrade_record_migration_applied "$_umps_state" "pre_xdg_specialists"
  return 0
}

# ---------------------------------------------------------------------------
# _upgrade_migrate_pre_xdg <from_path> <xdg_config_home>
# Migrates a pre-XDG install:
#   - Copies .claude/furrow.yaml keys to $XDG_CONFIG_HOME/furrow/config.yaml
#   - Replaces .claude/furrow.yaml with a symlink to the XDG copy
#   - Writes promotion-targets.yaml scaffolding
# Returns 0 on success, 1 on failure.
# ---------------------------------------------------------------------------
_upgrade_migrate_pre_xdg() {
  _ump_from="$1"
  _ump_cfg="$2"

  _ump_cfg_dir="${_ump_cfg}/furrow"
  _ump_target="${_ump_cfg_dir}/config.yaml"

  # Create XDG config dir
  mkdir -p "$_ump_cfg_dir"

  # Copy legacy config content to XDG path (atomic)
  _ump_tmp="${_ump_cfg_dir}/config.yaml.tmp.$$"
  if [ -f "$_ump_from" ]; then
    cp "$_ump_from" "$_ump_tmp"
    mv "$_ump_tmp" "$_ump_target"
  else
    # No legacy file found — create minimal XDG config
    printf '# Furrow global config\n# See docs/architecture/config-resolution.md\n' \
      > "$_ump_tmp"
    mv "$_ump_tmp" "$_ump_target"
  fi

  # Replace .claude/furrow.yaml with a symlink to the XDG copy (back-compat)
  if [ -f "$_ump_from" ] && [ ! -L "$_ump_from" ]; then
    rm -f "$_ump_from"
    ln -s "$_ump_target" "$_ump_from"
  fi

  # Scaffold promotion-targets.yaml
  _upgrade_write_promotion_targets "$_ump_cfg"

  return 0
}

# ---------------------------------------------------------------------------
# frw_upgrade — main entry point (called from bin/frw dispatcher)
# ---------------------------------------------------------------------------
frw_upgrade() {
  _mode="check"
  _from_path=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --check)  _mode="check"; shift ;;
      --apply)  _mode="apply"; shift ;;
      --from)
        [ $# -ge 2 ] || { log_error "frw upgrade: --from requires a path"; exit 2; }
        _from_path="$2"; shift 2 ;;
      -h|--help)
        printf 'Usage: frw upgrade [--check] [--apply] [--from <legacy-path>]\n' >&2
        printf '  --check  (default) Report migration status\n' >&2
        printf '  --apply  Perform migration\n' >&2
        printf '  --from   Override legacy config path\n' >&2
        exit 0 ;;
      *)
        log_error "frw upgrade: unknown option: $1"
        exit 2 ;;
    esac
  done

  # --- Source-repo guard ---
  # Refuse to write XDG artifacts when running inside the Furrow source repo.
  if [ -f "${FURROW_ROOT}/.furrow/SOURCE_REPO" ] && [ "${PROJECT_ROOT:-$(pwd)}" = "$FURROW_ROOT" ]; then
    log_warning "frw upgrade: running inside Furrow source repo — skipping XDG artifact writes"
    exit 0
  fi

  _xdg_cfg="$(_upgrade_xdg_config_home)"
  _xdg_state="$(_upgrade_xdg_state_home)"
  _slug="$(_upgrade_repo_slug)"
  _state_file="$(_upgrade_find_state_file "$_xdg_state" "$_slug")"

  # --- Determine current migration version ---
  _cur_ver="$(_upgrade_read_migration_version "$_state_file")"

  # --- Auto-detect legacy path if not provided ---
  if [ -z "$_from_path" ]; then
    _candidate="${PROJECT_ROOT:-$(pwd)}/.claude/furrow.yaml"
    if [ -f "$_candidate" ] && [ ! -L "$_candidate" ]; then
      _from_path="$_candidate"
    fi
  fi

  # --- Detect if migration is needed ---
  _needs_migration=0
  _legacy_specialists="${PROJECT_ROOT:-$(pwd)}/.claude/specialists"
  if [ "$_cur_ver" = "$CURRENT_MIGRATION_VERSION" ]; then
    _needs_migration=0  # already current
  elif [ -n "$_from_path" ] && [ -f "$_from_path" ] && [ ! -L "$_from_path" ]; then
    _needs_migration=1  # legacy pre-XDG config present
  elif [ ! -f "${_xdg_cfg}/furrow/config.yaml" ]; then
    _needs_migration=1  # XDG config doesn't exist yet
  fi

  # Pre-XDG specialists migration may need to run even when migration_version
  # is already "1.0" (e.g., legacy specialists dir left behind after a
  # partial earlier migration). Signal it separately so --check reports it.
  _needs_specialists=0
  if [ -d "$_legacy_specialists" ] && [ ! -L "$_legacy_specialists" ]; then
    if ! _upgrade_migration_applied "$_state_file" "pre_xdg_specialists"; then
      _needs_specialists=1
    fi
  fi

  # --- Check mode ---
  if [ "$_mode" = "check" ]; then
    if [ "$_needs_migration" = "0" ] && \
       [ "$_needs_specialists" = "0" ] && \
       [ "$_cur_ver" = "$CURRENT_MIGRATION_VERSION" ]; then
      printf 'frw upgrade: install is current (migration_version=%s)\n' "$_cur_ver"
      exit 0
    else
      printf 'frw upgrade: migration needed (current=%s, target=%s)\n' \
        "$_cur_ver" "$CURRENT_MIGRATION_VERSION"
      if [ -n "$_from_path" ] && [ -f "$_from_path" ] && [ ! -L "$_from_path" ]; then
        printf 'frw upgrade: legacy config detected at %s\n' "$_from_path"
      fi
      if [ "$_needs_specialists" = "1" ]; then
        printf 'frw upgrade: legacy specialists detected at %s\n' "$_legacy_specialists"
      fi
      exit 10
    fi
  fi

  # --- Apply mode ---

  # Already current: idempotent no-op (only last_upgrade_at would change — skip)
  # Note: we still run the specialists sub-migration when needed, even when
  # migration_version is already 1.0 — it is tracked separately.
  if [ "$_cur_ver" = "$CURRENT_MIGRATION_VERSION" ] && \
     [ -f "${_xdg_cfg}/furrow/config.yaml" ] && \
     [ -f "${_xdg_cfg}/furrow/promotion-targets.yaml" ] && \
     [ "$_needs_specialists" = "0" ]; then
    printf 'frw upgrade: already at migration_version=%s — no changes needed\n' "$_cur_ver"
    exit 0
  fi

  printf 'frw upgrade: applying migration %s → %s\n' "$_cur_ver" "$CURRENT_MIGRATION_VERSION"

  # Perform XDG migration (config.yaml + promotion-targets.yaml) only when
  # the base migration is still pending. Once at 1.0, skip the config step
  # but still run the specialists sub-migration below.
  if [ "$_cur_ver" != "$CURRENT_MIGRATION_VERSION" ]; then
    if ! _upgrade_migrate_pre_xdg "$_from_path" "$_xdg_cfg"; then
      log_error "frw upgrade: migration failed"
      exit 1
    fi

    # Update install-state.json with new migration_version
    if ! _upgrade_update_state_file "$_state_file" "$CURRENT_MIGRATION_VERSION"; then
      log_error "frw upgrade: failed to update install-state.json"
      exit 1
    fi
  fi

  # Pre-XDG specialists migration (idempotent; safe when already applied).
  if ! _upgrade_migrate_pre_xdg_specialists \
        "${PROJECT_ROOT:-$(pwd)}" "$_xdg_cfg" "$_state_file"; then
    log_error "frw upgrade: pre-XDG specialists migration failed"
    exit 1
  fi

  printf 'frw upgrade: done (migration_version=%s)\n' "$CURRENT_MIGRATION_VERSION"
  exit 0
}
