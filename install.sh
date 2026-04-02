#!/bin/sh
# install.sh — Install V2 work harness into a project or globally.
#
# Usage:
#   install.sh --project <path>   Install into a specific project
#   install.sh --global           Install into ~/.claude (all projects)
#   install.sh --check <path>     Verify installation without modifying
#
# Creates symlinks from the target's .claude/ directory back to this harness.
# Merges hooks into existing settings.json (preserves non-harness hooks).
# Injects harness activation into CLAUDE.md (preserves existing content).

set -eu

HARNESS_ROOT="$(cd "$(dirname "$0")" && pwd)"
MODE=""
TARGET=""
PREFIX="harness"  # Namespace prefix for commands to avoid collisions

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

# Create a symlink, skipping if target already points to the right place
symlink() {
  _src="$1"
  _dst="$2"
  if [ -L "$_dst" ]; then
    _existing="$(readlink -f "$_dst" 2>/dev/null || readlink "$_dst")"
    _expected="$(readlink -f "$_src" 2>/dev/null || echo "$_src")"
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
  echo "=== Harness Installation Check ==="
  echo "Target: $TARGET"
  errors=0

  # Commands (namespaced)
  echo ""
  echo "--- Commands ---"
  for cmd in "$HARNESS_ROOT"/commands/*.md; do
    [ -f "$cmd" ] || continue
    _basename="$(basename "$cmd" .md)"
    if [ "$_basename" = "harness" ]; then
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
    _ok "settings.json has harness hooks"
  else
    _fail "settings.json missing harness hooks"
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
  if [ -f "$TARGET/CLAUDE.md" ] && grep -q "harness:start" "$TARGET/CLAUDE.md" 2>/dev/null; then
    _ok "CLAUDE.md has harness activation"
  else
    _fail "CLAUDE.md missing harness activation"
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

echo "=== Installing V2 Work Harness ==="
echo "Harness: $HARNESS_ROOT"
echo "Target:  $TARGET"
echo "Mode:    $MODE"
echo ""

# --- 1. Commands (namespaced as harness:name to avoid collisions) ---
echo "--- Commands ---"
ensure_dir "$TARGET/commands"
for cmd in "$HARNESS_ROOT"/commands/*.md; do
  [ -f "$cmd" ] || continue
  _basename="$(basename "$cmd" .md)"
  # The harness.md meta-command has subcommands — split into separate namespaced commands
  if [ "$_basename" = "harness" ]; then
    # harness.md contains doctor/update/meta — link as harness:doctor, harness:update, harness:meta
    # The source file is shared; each alias points to the same file
    symlink "$cmd" "$TARGET/commands/${PREFIX}:doctor.md"
    symlink "$cmd" "$TARGET/commands/${PREFIX}:update.md"
    symlink "$cmd" "$TARGET/commands/${PREFIX}:meta.md"
  else
    symlink "$cmd" "$TARGET/commands/${PREFIX}:${_basename}.md"
  fi
done
# Also link commands/lib/ (internal scripts called by commands)
if [ -d "$HARNESS_ROOT/commands/lib" ]; then
  ensure_dir "$TARGET/commands/lib"
  for lib in "$HARNESS_ROOT"/commands/lib/*; do
    [ -f "$lib" ] || continue
    _name="$(basename "$lib")"
    symlink "$lib" "$TARGET/commands/lib/$_name"
  done
fi

# --- 1b. Specialists (registered as specialist:name commands) ---
echo ""
echo "--- Specialists ---"
if [ -d "$HARNESS_ROOT/specialists" ]; then
  for spec in "$HARNESS_ROOT"/specialists/*.md; do
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
_harness_claude="$(cd "$HARNESS_ROOT/.claude" && pwd)"
_target_abs="$(cd "$TARGET" && pwd)"
if [ "$_harness_claude" = "$_target_abs" ]; then
  _skip "rules/ (self-install: source and target are the same directory)"
else
  for rule in "$HARNESS_ROOT"/.claude/rules/*.md; do
    [ -f "$rule" ] || continue
    _name="$(basename "$rule")"
    symlink "$rule" "$TARGET/rules/$_name"
  done
fi

# --- 3. Hooks (settings.json merge) ---
echo ""
echo "--- Hooks ---"
_harness_settings="$HARNESS_ROOT/.claude/settings.json"
_target_settings="$TARGET/settings.json"

if [ ! -f "$_target_settings" ]; then
  # No existing settings — just copy
  cp "$_harness_settings" "$_target_settings"
  _ok "settings.json created with harness hooks"
elif grep -q "hooks/state-guard.sh" "$_target_settings" 2>/dev/null; then
  _skip "settings.json already has harness hooks"
else
  # Merge: add harness hooks to existing settings
  if command -v jq > /dev/null 2>&1; then
    _merged=$(jq -s '
      .[0] as $existing | .[1] as $harness |
      $existing * {hooks: ($existing.hooks // {} | to_entries + ($harness.hooks | to_entries) | from_entries)}
    ' "$_target_settings" "$_harness_settings" 2>/dev/null) || _merged=""
    if [ -n "$_merged" ]; then
      echo "$_merged" > "$_target_settings"
      _ok "settings.json merged with harness hooks"
    else
      _fail "settings.json merge failed — merge manually from $_harness_settings"
    fi
  else
    _fail "jq not available; cannot merge settings.json — copy manually from $_harness_settings"
  fi
fi

# --- 4. Harness config ---
echo ""
echo "--- Config ---"
_harness_yaml="$HARNESS_ROOT/.claude/harness.yaml"
_target_yaml="$TARGET/harness.yaml"
if [ -f "$_harness_yaml" ] && [ ! -f "$_target_yaml" ]; then
  cp "$_harness_yaml" "$_target_yaml"
  _ok "harness.yaml template copied (edit for your project)"
else
  _skip "harness.yaml already exists"
fi

# --- 5. CLAUDE.md injection ---
echo ""
echo "--- CLAUDE.md ---"
_target_claude="$TARGET/CLAUDE.md"
_harness_block="<!-- harness:start -->
## V2 Work Harness

Installed from: $HARNESS_ROOT

| Command | Purpose |
|---------|---------|
| /harness:work | Create or resume a work unit |
| /harness:status | Show step, deliverable progress |
| /harness:checkpoint | Save session progress |
| /harness:review | Run structured review |
| /harness:archive | Archive completed work |
| /harness:reground | Recover context after break |
| /harness:redirect | Record dead end and pivot |
| /harness:triage | Generate ROADMAP.md from todos.yaml |
| /harness:work-todos | Extract and manage TODOs |
| /harness:doctor | Check harness health |
| /harness:update | Check configuration drift |
| /harness:meta | Enter self-modification mode |

Run \`/harness:doctor\` to check health. Run \`install.sh --check\` to verify installation.
<!-- harness:end -->"

if [ ! -f "$_target_claude" ]; then
  echo "$_harness_block" > "$_target_claude"
  _ok "CLAUDE.md created with harness activation"
elif grep -q "harness:start" "$_target_claude" 2>/dev/null; then
  _skip "CLAUDE.md already has harness activation"
else
  # Append harness block
  echo "" >> "$_target_claude"
  echo "$_harness_block" >> "$_target_claude"
  _ok "CLAUDE.md updated with harness activation"
fi

# --- 6. Symlink harness root dirs into project ---
echo ""
echo "--- Harness directories ---"

# Determine project root (parent of .claude/)
if [ "$MODE" = "global" ]; then
  _proj_root="$HOME"
else
  _proj_root="$(dirname "$TARGET")"
fi

# Symlink key directories if they don't exist at project root
for _dir in skills hooks scripts schemas evals specialists references adapters templates tests _rationale.yaml; do
  _src="$HARNESS_ROOT/$_dir"
  _dst="$_proj_root/$_dir"
  if [ -e "$_src" ]; then
    if [ -L "$_dst" ]; then
      _existing="$(readlink -f "$_dst" 2>/dev/null || readlink "$_dst")"
      _expected="$(readlink -f "$_src" 2>/dev/null || echo "$_src")"
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

# --- Summary ---
echo ""
echo "=== Installation Complete ==="
echo ""
echo "Verify with: $HARNESS_ROOT/install.sh --check $(dirname "$TARGET")"
echo "Health check: /harness doctor (from within Claude Code)"
echo ""
echo "Next steps:"
echo "  1. Edit $TARGET/harness.yaml with your project details"
echo "  2. Start a session and type /work to begin"
