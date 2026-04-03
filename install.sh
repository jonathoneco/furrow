#!/bin/sh
# install.sh — Install Furrow into a project or globally.
#
# Usage:
#   install.sh --project <path>   Install into a specific project
#   install.sh --global           Install into ~/.claude (all projects)
#   install.sh --check <path>     Verify installation without modifying
#
# Creates symlinks from the target's .claude/ directory back to Furrow.
# Merges hooks into existing settings.json (preserves non-Furrow hooks).
# Injects Furrow activation into CLAUDE.md (preserves existing content).

set -eu

FURROW_ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE=""
TARGET=""
PREFIX="furrow"  # Namespace prefix for commands to avoid collisions

for arg in "$@"; do
  case "$arg" in
    --project) MODE="project" ;;
    --global)  MODE="global"; TARGET="$HOME/.claude" ;;
    --check)   MODE="check" ;;
    *)
      if [ "$MODE" = "project" ] && [ -z "$TARGET" ]; then
        TARGET="$arg/.claude"
      elif [ "$MODE" = "check" ] && [ -z "$TARGET" ]; then
        TARGET="$arg/.claude"
      fi
      ;;
  esac
done

if [ -z "$MODE" ] || [ -z "$TARGET" ]; then
  echo "Usage:"
  echo "  install.sh --project <path>   Install into a project"
  echo "  install.sh --global           Install globally (~/.claude)"
  echo "  install.sh --check <path>     Verify installation"
  exit 1
fi

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

# Create a symlink, skipping if target already points to the right place
symlink() {
  _src="$1"
  _dst="$2"
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
  ln -s "$_src" "$_dst"
  _link "$_src" "$_dst"
}

# ============================================================
# Check mode — verify without modifying
# ============================================================

if [ "$MODE" = "check" ]; then
  echo "=== Furrow Installation Check ==="
  echo "Target: $TARGET"
  errors=0

  # Commands (namespaced)
  echo ""
  echo "--- Commands ---"
  for cmd in "$FURROW_ROOT"/commands/*.md; do
    [ -f "$cmd" ] || continue
    _basename="$(basename "$cmd" .md)"
    if [ "$_basename" = "furrow" ]; then
      for _sub in doctor update meta; do
        if [ -L "$TARGET/commands/${PREFIX}:${_sub}.md" ]; then
          _ok "commands/${PREFIX}:${_sub}.md"
        else
          _fail "commands/${PREFIX}:${_sub}.md not linked"
          errors=$((errors + 1))
        fi
      done
    else
      if [ -L "$TARGET/commands/${PREFIX}:${_basename}.md" ]; then
        _ok "commands/${PREFIX}:${_basename}.md"
      else
        _fail "commands/${PREFIX}:${_basename}.md not linked"
        errors=$((errors + 1))
      fi
    fi
  done

  # Hooks
  echo ""
  echo "--- Hooks ---"
  if [ -f "$TARGET/settings.json" ] && grep -q "hooks/state-guard.sh" "$TARGET/settings.json" 2>/dev/null; then
    _ok "settings.json has Furrow hooks"
  else
    _fail "settings.json missing Furrow hooks"
    errors=$((errors + 1))
  fi

  # Rules
  echo ""
  echo "--- Rules ---"
  if [ -L "$TARGET/rules/workflow-detect.md" ]; then
    _ok "rules/workflow-detect.md"
  else
    _fail "rules/workflow-detect.md not linked"
    errors=$((errors + 1))
  fi

  # CLAUDE.md
  echo ""
  echo "--- CLAUDE.md ---"
  if [ -f "$TARGET/CLAUDE.md" ] && grep -q "furrow:start" "$TARGET/CLAUDE.md" 2>/dev/null; then
    _ok "CLAUDE.md has Furrow activation"
  else
    _fail "CLAUDE.md missing Furrow activation"
    errors=$((errors + 1))
  fi

  # Skills (check symlink to skills dir)
  echo ""
  echo "--- Skills ---"
  if [ -L "$TARGET/../skills" ] || [ -d "$TARGET/../skills" ]; then
    _ok "skills/ accessible"
  else
    _fail "skills/ not accessible from project root"
    errors=$((errors + 1))
  fi

  echo ""
  if [ "$errors" -eq 0 ]; then
    echo "RESULT: INSTALLED"
    exit 0
  else
    echo "RESULT: NOT INSTALLED ($errors issues)"
    exit 1
  fi
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
  # The furrow.md meta-command has subcommands — split into separate namespaced commands
  if [ "$_basename" = "furrow" ]; then
    # furrow.md contains doctor/update/meta — link as furrow:doctor, furrow:update, furrow:meta
    # The source file is shared; each alias points to the same file
    symlink "$cmd" "$TARGET/commands/${PREFIX}:doctor.md"
    symlink "$cmd" "$TARGET/commands/${PREFIX}:update.md"
    symlink "$cmd" "$TARGET/commands/${PREFIX}:meta.md"
  else
    symlink "$cmd" "$TARGET/commands/${PREFIX}:${_basename}.md"
  fi
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
elif grep -q "hooks/state-guard.sh" "$_target_settings" 2>/dev/null; then
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

# Symlink key directories if they don't exist at project root
for _dir in skills hooks scripts schemas evals specialists references adapters templates tests _rationale.yaml; do
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
        ln -s "$_src" "$_dst"
        _link "$_src" "$_dst"
      fi
    elif [ -e "$_dst" ]; then
      _skip "$_dir (exists as real file/dir, not overwriting)"
    else
      ln -s "$_src" "$_dst"
      _link "$_src" "$_dst"
    fi
  fi
done

# --- 6b. CLI tools (sds, rws, alm) ---
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

# --- Summary ---
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Verify with: $FURROW_ROOT/install.sh --check $(dirname "$TARGET")"
echo "Health check: /furrow doctor (from within Claude Code)"
echo ""
echo "Next steps:"
echo "  1. Edit $TARGET/furrow.yaml with your project details"
echo "  2. Start a session and type /work to begin"
