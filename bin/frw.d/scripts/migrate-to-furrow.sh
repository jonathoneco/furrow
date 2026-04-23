#!/bin/sh
# migrate-to-furrow.sh — Migrate harness state to .furrow/ directory structure.
#
# Moves .work/ -> .furrow/rows/, .beans/ -> .furrow/seeds/,
# todos.yaml/ROADMAP.md/_rationale.yaml -> .furrow/almanac/.
# Renames state.json fields: issue_id -> seed_id, epic_id -> epic_seed_id.
#
# Usage: frw migrate-to-furrow [--dry-run]
# Return 0 on success, 1 on error. Idempotent.

frw_migrate_to_furrow() {
  set -eu

  DRY_RUN=false
  if [ "${1:-}" = "--dry-run" ]; then
    DRY_RUN=true
  fi

  log() { printf '%s\n' "$*"; }
  run() {
    if [ "$DRY_RUN" = true ]; then
      log "[dry-run] $*"
    else
      "$@"
    fi
  }

  # 1. Create .furrow/ structure
  log "Creating .furrow/ directory structure..."
  run mkdir -p .furrow/rows .furrow/seeds .furrow/almanac

  # 2. Move row directories
  if [ -d .work ]; then
    for dir in .work/*/; do
      [ ! -d "$dir" ] && continue
      name="$(basename "$dir")"
      # Skip _meta.yaml (it's a file, not a dir, but guard anyway)
      [ "$name" = "_meta.yaml" ] && continue
      if [ -d ".furrow/rows/$name" ]; then
        log "  skip: .furrow/rows/$name already exists"
      else
        log "  move: .work/$name/ -> .furrow/rows/$name/"
        run mv "$dir" ".furrow/rows/$name/"
      fi
    done
  else
    log "  skip: .work/ does not exist (already migrated or never existed)"
  fi

  # 3. Move metadata files
  if [ -f .work/.focused ] && [ ! -f .furrow/.focused ]; then
    log "  move: .work/.focused -> .furrow/.focused"
    run mv .work/.focused .furrow/.focused
  fi
  if [ -f .work/_meta.yaml ] && [ ! -f .furrow/_meta.yaml ]; then
    log "  move: .work/_meta.yaml -> .furrow/_meta.yaml"
    run mv .work/_meta.yaml .furrow/_meta.yaml
  fi

  # 4. Move seeds data
  if [ -d .beans ]; then
    log "Moving .beans/ -> .furrow/seeds/..."
    if [ -f .beans/issues.jsonl ] && [ ! -f .furrow/seeds/seeds.jsonl ]; then
      run mv .beans/issues.jsonl .furrow/seeds/seeds.jsonl
    fi
    if [ -f .beans/config ] && [ ! -f .furrow/seeds/config ]; then
      run mv .beans/config .furrow/seeds/config
    fi
    if [ -f .beans/.lock ]; then
      run mv .beans/.lock .furrow/seeds/.lock
    fi
    run rmdir .beans 2>/dev/null || true
  else
    log "  skip: .beans/ does not exist"
  fi

  # 5. Move almanac data
  if [ -f todos.yaml ] && [ ! -f .furrow/almanac/todos.yaml ]; then
    log "  move: todos.yaml -> .furrow/almanac/todos.yaml"
    run mv todos.yaml .furrow/almanac/todos.yaml
  fi
  if [ -f ROADMAP.md ] && [ ! -f .furrow/almanac/roadmap-legacy.md ]; then
    log "  move: ROADMAP.md -> .furrow/almanac/roadmap-legacy.md (run 'alm triage' to generate roadmap.yaml)"
    run mv ROADMAP.md .furrow/almanac/roadmap-legacy.md
  fi
  if [ -f _rationale.yaml ] && [ ! -f .furrow/almanac/rationale.yaml ]; then
    log "  move: _rationale.yaml -> .furrow/almanac/rationale.yaml"
    run mv _rationale.yaml .furrow/almanac/rationale.yaml
  fi

  # 6. Rename state.json fields in all existing rows
  log "Renaming state.json fields (issue_id -> seed_id, epic_id -> epic_seed_id)..."
  for state in .furrow/rows/*/state.json; do
    [ ! -f "$state" ] && continue
    # Check if already migrated (has seed_id field)
    if jq -e '.seed_id' "$state" >/dev/null 2>&1; then
      log "  skip: $state already migrated"
      continue
    fi
    log "  rename fields: $state"
    if [ "$DRY_RUN" = false ]; then
      jq '.seed_id = .issue_id | .epic_seed_id = .epic_id | del(.issue_id, .epic_id)' \
        "$state" > "$state.tmp" && mv "$state.tmp" "$state"
    fi
  done

  # 7. Update .gitattributes
  if [ -f .gitattributes ]; then
    if grep -q '\.beans/issues\.jsonl' .gitattributes 2>/dev/null; then
      log "  update: .gitattributes (beans -> seeds path)"
      if [ "$DRY_RUN" = false ]; then
        sed -i 's|\.beans/issues\.jsonl|.furrow/seeds/seeds.jsonl|g' .gitattributes
      fi
    fi
  fi

  # 8. Clean up empty .work/
  if [ -d .work ]; then
    run rmdir .work 2>/dev/null || log "  note: .work/ not empty, kept"
  fi

  log "Migration complete."
}
