#!/bin/sh
# install.sh — Install Furrow into a project or globally.
#
# Sourced by bin/frw; not executed directly.
# Expects: FURROW_ROOT set by the dispatcher.
#
# Usage (via frw):
#   frw install --project <path>   Install into a specific project
#   frw install --global           Install into ~/.claude (all projects)
#   frw install --check [<path>]   Verify installation without modifying

# --- helpers ---

_ok()   { echo "  [OK]   $1"; }
_skip() { echo "  [SKIP] $1"; }
_fail() { echo "  [FAIL] $1" >&2; }
_link() { echo "  [LINK] $2 -> $1"; }

ensure_dir() {
  if [ ! -d "$1" ]; then
    mkdir -p "$1"
    echo "  [DIR]  Created $1"
  fi
}

# Portable readlink -f: resolve symlink chain and canonicalize path.
# Works on GNU (Linux) and BSD (macOS) without requiring GNU coreutils.
_canonicalize() {
  _cl_path="$1"
  while [ -L "$_cl_path" ]; do
    _cl_dir="$(cd "$(dirname "$_cl_path")" && pwd)"
    _cl_path="$(readlink "$_cl_path")"
    case "$_cl_path" in
      /*) ;;
      *) _cl_path="$_cl_dir/$_cl_path" ;;
    esac
  done
  _cl_dir="$(cd "$(dirname "$_cl_path")" 2>/dev/null && pwd)"
  echo "$_cl_dir/$(basename "$_cl_path")"
}

# Compute relative path from directory $1 to file/dir $2.
# Both arguments must be absolute paths. Uses only POSIX constructs.
_relpath() {
  _rp_from="$1"
  _rp_to="$2"

  # Normalize: strip trailing slashes
  _rp_from="${_rp_from%/}"
  _rp_to="${_rp_to%/}"

  # Find common prefix
  _rp_common="$_rp_from"
  _rp_up=""
  while true; do
    case "$_rp_to/" in
      "$_rp_common/"*) break ;;
    esac
    _rp_common="${_rp_common%/*}"
    _rp_up="../$_rp_up"
  done

  # Build relative path
  _rp_tail="${_rp_to#"$_rp_common"}"
  _rp_tail="${_rp_tail#/}"
  if [ -n "$_rp_up" ] && [ -n "$_rp_tail" ]; then
    echo "${_rp_up}${_rp_tail}"
  elif [ -n "$_rp_up" ]; then
    # Strip trailing slash from _rp_up
    echo "${_rp_up%/}"
  elif [ -n "$_rp_tail" ]; then
    echo "$_rp_tail"
  else
    echo "."
  fi
}

# Create a relative symlink, skipping if target already points to the right place.
# Arguments: $1 = absolute path to target, $2 = absolute path to link location
symlink() {
  _src="$1"
  _dst="$2"
  _src_path="$(cd "$(dirname "$_src")" && pwd)/$(basename "$_src")"
  _dst_path="$(cd "$(dirname "$_dst")" && pwd)/$(basename "$_dst")"
  if [ "$_src_path" = "$_dst_path" ]; then
    _skip "$_dst (source and destination are the same path)"
    return 0
  fi

  if [ -L "$_dst" ]; then
    _existing="$(_canonicalize "$_dst")"
    _expected="$(_canonicalize "$_src")"
    if [ "$_existing" = "$_expected" ]; then
      _skip "$_dst (already linked)"
      return 0
    else
      rm "$_dst"
    fi
  elif [ -f "$_dst" ]; then
    echo "  [WARN] $_dst exists as a regular file, backing up to ${_dst}.bak"
    mv "$_dst" "${_dst}.bak"
  fi
  # Compute relative path from the symlink's parent directory to the target
  _dst_dir="$(cd "$(dirname "$_dst")" && pwd)"
  _src_abs="$(_canonicalize "$_src")"
  _rel="$(_relpath "$_dst_dir" "$_src_abs")"
  ln -s "$_rel" "$_dst"
  _link "$_rel" "$_dst"
}

# --- check mode ---

_frw_install_check() {
  _target="$1"
  _quiet="${2:-}"  # pass "quiet" to suppress output (for auto-install)
  _proj_root="$(dirname "$_target")"
  errors=0

  _log() { [ "$_quiet" = "quiet" ] || echo "$1"; }

  _log "=== Furrow Installation Check ==="
  _log "Target: $_target"
  _log "Furrow: $FURROW_ROOT"

  # Commands (namespaced) — check ALL expected commands exist
  _log ""
  _log "--- Commands ---"
  for cmd in "$FURROW_ROOT"/commands/*.md; do
    [ -f "$cmd" ] || continue
    _basename="$(basename "$cmd" .md)"
    _expected="$_target/commands/${PREFIX}:${_basename}.md"
    if [ -L "$_expected" ]; then
      _existing="$(_canonicalize "$_expected")"
      _src="$(_canonicalize "$cmd")"
      if [ "$_existing" = "$_src" ]; then
        [ "$_quiet" = "quiet" ] || _ok "commands/${PREFIX}:${_basename}.md"
      else
        [ "$_quiet" = "quiet" ] || _fail "commands/${PREFIX}:${_basename}.md points to wrong target"
        errors=$((errors + 1))
      fi
    else
      [ "$_quiet" = "quiet" ] || _fail "commands/${PREFIX}:${_basename}.md not linked"
      errors=$((errors + 1))
    fi
  done

  # Specialists — check ALL expected specialists exist
  _log ""
  _log "--- Specialists ---"
  for spec in "$FURROW_ROOT"/specialists/*.md; do
    [ -f "$spec" ] || continue
    _basename="$(basename "$spec" .md)"
    case "$_basename" in _*) continue ;; esac
    _expected="$_target/commands/specialist:${_basename}.md"
    if [ -L "$_expected" ]; then
      _existing="$(_canonicalize "$_expected")"
      _src="$(_canonicalize "$spec")"
      if [ "$_existing" = "$_src" ]; then
        [ "$_quiet" = "quiet" ] || _ok "specialist:${_basename}.md"
      else
        [ "$_quiet" = "quiet" ] || _fail "specialist:${_basename}.md points to wrong target"
        errors=$((errors + 1))
      fi
    else
      [ "$_quiet" = "quiet" ] || _fail "specialist:${_basename}.md not linked"
      errors=$((errors + 1))
    fi
  done

  # Hooks — check for frw hook pattern
  _log ""
  _log "--- Hooks ---"
  if [ -f "$_target/settings.json" ] && grep -q "frw hook state-guard" "$_target/settings.json" 2>/dev/null; then
    [ "$_quiet" = "quiet" ] || _ok "settings.json has Furrow hooks"
  else
    [ "$_quiet" = "quiet" ] || _fail "settings.json missing Furrow hooks"
    errors=$((errors + 1))
  fi

  # Rules — check ALL expected rules exist
  _log ""
  _log "--- Rules ---"
  _furrow_claude="$(cd "$FURROW_ROOT/.claude" 2>/dev/null && pwd)"
  _target_abs="$(cd "$_target" 2>/dev/null && pwd)"
  if [ "$_furrow_claude" != "$_target_abs" ]; then
    for rule in "$FURROW_ROOT"/.claude/rules/*.md; do
      [ -f "$rule" ] || continue
      _name="$(basename "$rule")"
      if [ -L "$_target/rules/$_name" ]; then
        [ "$_quiet" = "quiet" ] || _ok "rules/$_name"
      else
        [ "$_quiet" = "quiet" ] || _fail "rules/$_name not linked"
        errors=$((errors + 1))
      fi
    done
  else
    [ "$_quiet" = "quiet" ] || _skip "rules/ (self-install)"
  fi

  # CLAUDE.md
  _log ""
  _log "--- CLAUDE.md ---"
  if [ -f "$_target/CLAUDE.md" ] && grep -q "furrow:start" "$_target/CLAUDE.md" 2>/dev/null; then
    [ "$_quiet" = "quiet" ] || _ok "CLAUDE.md has Furrow activation"
  else
    [ "$_quiet" = "quiet" ] || _fail "CLAUDE.md missing Furrow activation"
    errors=$((errors + 1))
  fi

  # Root-level symlinks
  _log ""
  _log "--- Furrow directories ---"
  for _dir in skills schemas evals specialists references adapters templates; do
    _src="$FURROW_ROOT/$_dir"
    _dst="$_proj_root/$_dir"
    if [ ! -e "$_src" ]; then continue; fi
    if [ -L "$_dst" ]; then
      _existing="$(_canonicalize "$_dst")"
      _expected_abs="$(_canonicalize "$_src")"
      if [ "$_existing" = "$_expected_abs" ]; then
        [ "$_quiet" = "quiet" ] || _ok "$_dir/"
      else
        [ "$_quiet" = "quiet" ] || _fail "$_dir/ points to wrong target"
        errors=$((errors + 1))
      fi
    elif [ -d "$_dst" ]; then
      [ "$_quiet" = "quiet" ] || _skip "$_dir/ (real directory, not symlink)"
    else
      [ "$_quiet" = "quiet" ] || _fail "$_dir/ not linked"
      errors=$((errors + 1))
    fi
  done

  # Gitignore
  _log ""
  _log "--- Gitignore ---"
  if [ -f "$_proj_root/.gitignore" ] && grep -q "# furrow:managed" "$_proj_root/.gitignore" 2>/dev/null; then
    [ "$_quiet" = "quiet" ] || _ok ".gitignore has Furrow entries"
  else
    [ "$_quiet" = "quiet" ] || _fail ".gitignore missing Furrow entries"
    errors=$((errors + 1))
  fi

  _log ""
  if [ "$errors" -eq 0 ]; then
    _log "RESULT: INSTALLED"
    return 0
  else
    _log "RESULT: NOT INSTALLED ($errors issues)"
    return 1
  fi
}

# --- main entry point ---

frw_install() {
  MODE=""
  TARGET=""
  PREFIX="furrow"  # Namespace prefix for commands to avoid collisions

  while [ $# -gt 0 ]; do
    case "$1" in
      --project)
        MODE="project"
        [ $# -ge 2 ] || { echo "frw install: --project requires a path" >&2; return 1; }
        TARGET="$2/.claude"; shift 2 ;;
      --global)
        MODE="global"; TARGET="$HOME/.claude"; shift ;;
      --check)
        MODE="check"
        if [ $# -ge 2 ] && [ "${2#-}" = "$2" ]; then
          TARGET="$2/.claude"; shift 2
        else
          # Default: check current project
          TARGET="$(pwd)/.claude"; shift
        fi
        ;;
      *)
        echo "frw install: unknown argument '$1'" >&2; return 1 ;;
    esac
  done

  if [ -z "$MODE" ] || [ -z "$TARGET" ]; then
    echo "Usage:"
    echo "  frw install --project <path>   Install into a project"
    echo "  frw install --global           Install globally (~/.claude)"
    echo "  frw install --check [<path>]   Verify installation"
    return 1
  fi

  # --- Check mode ---
  if [ "$MODE" = "check" ]; then
    _frw_install_check "$TARGET"
    return $?
  fi

  # ============================================================
  # Install mode
  # ============================================================

  echo "=== Installing Furrow ==="
  echo "Furrow: $FURROW_ROOT"
  echo "Target:  $TARGET"
  echo "Mode:    $MODE"
  echo ""

  # --- 1. Commands (namespaced as furrow:name to avoid collisions) ---
  echo "--- Commands ---"
  ensure_dir "$TARGET/commands"
  for cmd in "$FURROW_ROOT"/commands/*.md; do
    [ -f "$cmd" ] || continue
    _basename="$(basename "$cmd" .md)"
    symlink "$cmd" "$TARGET/commands/${PREFIX}:${_basename}.md"
  done
  # Also link commands/lib/ (internal scripts called by commands)
  if [ -d "$FURROW_ROOT/commands/lib" ]; then
    ensure_dir "$TARGET/commands/lib"
    for lib in "$FURROW_ROOT"/commands/lib/*; do
      [ -f "$lib" ] || continue
      _name="$(basename "$lib")"
      symlink "$lib" "$TARGET/commands/lib/$_name"
    done
  fi

  # --- 1b. Specialists (registered as specialist:name commands) ---
  echo ""
  echo "--- Specialists ---"
  if [ -d "$FURROW_ROOT/specialists" ]; then
    for spec in "$FURROW_ROOT"/specialists/*.md; do
      [ -f "$spec" ] || continue
      _basename="$(basename "$spec" .md)"
      # Skip _meta.yaml and similar non-specialist files
      case "$_basename" in _*) continue ;; esac
      symlink "$spec" "$TARGET/commands/specialist:${_basename}.md"
    done
  fi

  # --- 2. Rules ---
  echo ""
  echo "--- Rules ---"
  ensure_dir "$TARGET/rules"
  _furrow_claude="$(cd "$FURROW_ROOT/.claude" && pwd)"
  _target_abs="$(cd "$TARGET" && pwd)"
  if [ "$_furrow_claude" = "$_target_abs" ]; then
    _skip "rules/ (self-install: source and target are the same directory)"
  else
    for rule in "$FURROW_ROOT"/.claude/rules/*.md; do
      [ -f "$rule" ] || continue
      _name="$(basename "$rule")"
      symlink "$rule" "$TARGET/rules/$_name"
    done
  fi

  # --- 3. Hooks (settings.json merge) ---
  echo ""
  echo "--- Hooks ---"
  _furrow_settings="$FURROW_ROOT/.claude/settings.json"
  _target_settings="$TARGET/settings.json"

  if [ ! -f "$_target_settings" ]; then
    # No existing settings — just copy
    cp "$_furrow_settings" "$_target_settings"
    _ok "settings.json created with Furrow hooks"
  elif grep -q "frw hook state-guard" "$_target_settings" 2>/dev/null; then
    _skip "settings.json already has Furrow hooks"
  else
    # Merge: add Furrow hooks to existing settings
    if command -v jq > /dev/null 2>&1; then
      _merged=$(jq -s '
        .[0] as $existing | .[1] as $furrow |
        $existing * {hooks: ($existing.hooks // {} | to_entries + ($furrow.hooks | to_entries) | from_entries)}
      ' "$_target_settings" "$_furrow_settings" 2>/dev/null) || _merged=""
      if [ -n "$_merged" ]; then
        echo "$_merged" > "$_target_settings"
        _ok "settings.json merged with Furrow hooks"
      else
        _fail "settings.json merge failed — merge manually from $_furrow_settings"
      fi
    else
      _fail "jq not available; cannot merge settings.json — copy manually from $_furrow_settings"
    fi
  fi

  # --- 4. Furrow config ---
  echo ""
  echo "--- Config ---"
  _furrow_yaml="$FURROW_ROOT/.claude/furrow.yaml"
  _target_yaml="$TARGET/furrow.yaml"
  if [ -f "$_furrow_yaml" ] && [ ! -f "$_target_yaml" ]; then
    cp "$_furrow_yaml" "$_target_yaml"
    _ok "furrow.yaml template copied (edit for your project)"
  else
    _skip "furrow.yaml already exists"
  fi

  # --- 5. CLAUDE.md injection ---
  echo ""
  echo "--- CLAUDE.md ---"
  _target_claude="$TARGET/CLAUDE.md"
  _furrow_block="<!-- furrow:start -->
## Furrow

Installed from: $FURROW_ROOT

| Command | Purpose |
|---------|---------|
| /furrow:work | Create or resume a row |
| /furrow:status | Show step, deliverable progress |
| /furrow:checkpoint | Save session progress |
| /furrow:review | Run structured review |
| /furrow:archive | Archive completed work |
| /furrow:reground | Recover context after break |
| /furrow:redirect | Record dead end and pivot |
| /furrow:triage | Generate ROADMAP.md from todos.yaml |
| /furrow:next | Generate handoff prompt(s) for next roadmap work |
| /furrow:work-todos | Extract and manage TODOs |
| /furrow:init | Initialize Furrow in a new project |
| /furrow:doctor | Check Furrow health |
| /furrow:update | Check configuration drift |
| /furrow:meta | Enter self-modification mode |

Run \`/furrow:doctor\` to check health. Run \`install.sh --check\` to verify installation.
<!-- furrow:end -->"

  if [ ! -f "$_target_claude" ]; then
    echo "$_furrow_block" > "$_target_claude"
    _ok "CLAUDE.md created with Furrow activation"
  elif grep -q "furrow:start" "$_target_claude" 2>/dev/null; then
    _skip "CLAUDE.md already has Furrow activation"
  else
    # Append Furrow block
    echo "" >> "$_target_claude"
    echo "$_furrow_block" >> "$_target_claude"
    _ok "CLAUDE.md updated with Furrow activation"
  fi

  # --- 6. Symlink Furrow root dirs into project ---
  echo ""
  echo "--- Furrow directories ---"

  # Determine project root (parent of .claude/)
  if [ "$MODE" = "global" ]; then
    _proj_root="$HOME"
  else
    _proj_root="$(dirname "$TARGET")"
  fi

  # Symlink key directories — NOT hooks/ or scripts/ (those live in frw.d now)
  for _dir in skills schemas evals specialists references adapters templates tests; do
    _src="$FURROW_ROOT/$_dir"
    _dst="$_proj_root/$_dir"
    if [ -e "$_src" ]; then
      if [ -L "$_dst" ]; then
        _existing="$(_canonicalize "$_dst")"
        _expected="$(_canonicalize "$_src")"
        if [ "$_existing" = "$_expected" ]; then
          _skip "$_dir (already linked)"
        else
          rm "$_dst"
          _src_abs="$(_canonicalize "$_src")"
          _dst_parent="$(cd "$(dirname "$_dst")" && pwd)"
          _rel="$(_relpath "$_dst_parent" "$_src_abs")"
          ln -s "$_rel" "$_dst"
          _link "$_rel" "$_dst"
        fi
      elif [ -e "$_dst" ]; then
        _skip "$_dir (exists as real file/dir, not overwriting)"
      else
        _src_abs="$(_canonicalize "$_src")"
        _dst_parent="$(cd "$(dirname "$_dst")" && pwd)"
        _rel="$(_relpath "$_dst_parent" "$_src_abs")"
        ln -s "$_rel" "$_dst"
        _link "$_rel" "$_dst"
      fi
    fi
  done

  # --- 7. CLI tools (sds, rws, alm) ---
  echo ""
  echo "--- CLI tools ---"

  # Detect user-level bin directory on PATH
  _user_bin=""
  if [ -d "$HOME/.local/bin" ] && echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin"; then
    _user_bin="$HOME/.local/bin"
  elif [ -d "$HOME/bin" ] && echo "$PATH" | tr ':' '\n' | grep -q "$HOME/bin"; then
    _user_bin="$HOME/bin"
  fi

  for _cli in sds rws alm; do
    _src="$FURROW_ROOT/bin/$_cli"
    if [ -e "$_src" ]; then
      # Project-local symlink (for worktrees)
      ensure_dir "$_proj_root/bin"
      symlink "$_src" "$_proj_root/bin/$_cli"
      # User-level PATH symlink (system-wide availability)
      if [ -n "$_user_bin" ]; then
        symlink "$_src" "$_user_bin/$_cli"
      fi
    fi
  done

  if [ -z "$_user_bin" ]; then
    echo "  note: no ~/.local/bin or ~/bin on PATH — add project bin/ to PATH manually"
  fi

  # --- 8. Gitignore Furrow-managed symlinks (skip for self-install) ---
  echo ""
  echo "--- Gitignore ---"
  _proj_root_abs="$(cd "$_proj_root" && pwd)"
  _furrow_root_abs="$(cd "$FURROW_ROOT" && pwd)"
  if [ "$_proj_root_abs" = "$_furrow_root_abs" ]; then
    _skip ".gitignore (self-install: Furrow source repo owns these files)"
  else
    _gitignore="$_proj_root/.gitignore"
    _marker="# furrow:managed"
    _furrow_ignores="$_marker
skills
schemas
evals
specialists
references
adapters
templates
bin/sds
bin/rws
bin/alm
.claude/commands/furrow:*
.claude/commands/specialist:*
.claude/commands/lib/
.claude/rules/cli-mediation.md
.claude/CLAUDE.md"

    if [ -f "$_gitignore" ] && grep -q "$_marker" "$_gitignore" 2>/dev/null; then
      _skip ".gitignore already has Furrow entries"
    else
      echo "" >> "$_gitignore"
      echo "$_furrow_ignores" >> "$_gitignore"
      _ok ".gitignore updated with Furrow-managed paths"
    fi
  fi

  # --- Summary ---
  echo ""
  echo "=== Installation Complete ==="
  echo ""
  echo "Verify with: frw install --check $(dirname "$TARGET")"
  echo "Health check: /furrow:doctor (from within Claude Code)"
  echo ""
  echo "Next steps:"
  echo "  1. Edit $TARGET/furrow.yaml with your project details"
  echo "  2. Start a session and type /furrow:work to begin"
}
