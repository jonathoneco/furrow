#!/bin/sh
# make-legacy-install.sh — Build a synthetic legacy-install fixture tree.
#
# Usage: make-legacy-install.sh <dest-dir>
#   <dest-dir>  An existing empty directory to populate.
#
# Produces:
#   <dest-dir>/.claude/furrow.yaml        — legacy config with three keys
#   <dest-dir>/.claude/commands/          — empty placeholder
#   <dest-dir>/.furrow/                   — minimal project .furrow (no furrow.yaml)
#
# Does NOT produce:
#   $XDG_CONFIG_HOME/furrow/config.yaml  — consumer must unset this
#   install-state.json                   — consumer must handle XDG state dir
#
# This fixture is used by:
#   tests/integration/test-upgrade-idempotency.sh
#   tests/integration/test-upgrade-migration.sh

set -eu

if [ $# -lt 1 ] || [ -z "$1" ]; then
  printf 'Usage: make-legacy-install.sh <dest-dir>\n' >&2
  exit 1
fi

dest="$1"

if [ ! -d "$dest" ]; then
  printf 'make-legacy-install: dest-dir does not exist: %s\n' "$dest" >&2
  exit 1
fi

# Create .claude/ structure
mkdir -p "${dest}/.claude/commands"

# Write legacy config (three representative keys)
cat > "${dest}/.claude/furrow.yaml" << 'YAML'
# Legacy Furrow config (.claude/furrow.yaml — pre-XDG location)
cross_model:
  provider: gemini
gate_policy: supervised
preferred_specialists:
  - harness-engineer
  - shell-specialist
YAML

# Create minimal .furrow/ project directory
mkdir -p "${dest}/.furrow/rows"
mkdir -p "${dest}/.furrow/almanac"

# Initialize git so repo_slug works
if ! git -C "$dest" rev-parse --git-dir > /dev/null 2>&1; then
  git -C "$dest" init -q
  git -C "$dest" config user.email "test@test.com"
  git -C "$dest" config user.name "Test"
  printf 'init\n' > "${dest}/.gitkeep"
  git -C "$dest" add .gitkeep
  git -C "$dest" commit -q -m "initial"
fi

printf 'make-legacy-install: fixture created at %s\n' "$dest"
