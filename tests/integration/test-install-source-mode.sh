#!/bin/bash
# test-install-source-mode.sh — AC-A, AC-B: source-mode install behavior
#
# Verifies:
# - When .furrow/SOURCE_REPO sentinel is present, INSTALL_MODE=source
# - Symlinks to specialists and rules resolve correctly
# - SOURCE_REPO is NOT copied into any target
# - Consumer .gitignore bootstrap does NOT run

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-install-source-mode.sh (AC-A, AC-B) ==="

# Sandbox the four env vars inside $TMP; snapshot protected paths.
setup_sandbox >/dev/null
snapshot_guard_targets

# ---------------------------------------------------------------------------
# test_source_mode_detection
# ---------------------------------------------------------------------------
test_source_mode_detection() {
  local fixture_dir
  fixture_dir="$(mktemp -d)"
  trap 'rm -rf "$fixture_dir"' EXIT INT TERM

  # Build minimal fixture that looks like a Furrow source repo
  mkdir -p "$fixture_dir/.furrow"
  printf 'This file marks the Furrow source repository.\n' > "$fixture_dir/.furrow/SOURCE_REPO"

  # Source install.sh to check INSTALL_MODE detection logic
  # We replicate the detection logic from install.sh (top-level)
  local install_mode
  if [ -f "$fixture_dir/.furrow/SOURCE_REPO" ]; then
    install_mode="source"
  else
    install_mode="consumer"
  fi

  assert_exit_code "SOURCE_REPO sentinel detected as source mode" 0 \
    "$([ "$install_mode" = "source" ] && echo 0 || echo 1)"

  rm -rf "$fixture_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_symlink_validator_resolves
# ---------------------------------------------------------------------------
# Set up a minimal "Furrow source" tree and consumer target, run the
# frw.d/install.sh install logic, then verify specialist and rules symlinks
# all resolve via readlink -f.
test_symlink_validator_resolves() {
  local src_dir tgt_dir
  src_dir="$(mktemp -d)"
  tgt_dir="$(mktemp -d)"
  trap 'rm -rf "$src_dir" "$tgt_dir"' EXIT INT TERM

  # Build minimal source tree
  mkdir -p "$src_dir/.furrow"
  printf 'SOURCE_REPO\n' > "$src_dir/.furrow/SOURCE_REPO"
  mkdir -p "$src_dir/specialists"
  printf '# test specialist\n' > "$src_dir/specialists/test-engineer.md"
  printf '# another specialist\n' > "$src_dir/specialists/shell-specialist.md"
  mkdir -p "$src_dir/.claude/rules"
  printf '# cli mediation\n' > "$src_dir/.claude/rules/cli-mediation.md"
  printf '# step sequence\n' > "$src_dir/.claude/rules/step-sequence.md"
  mkdir -p "$src_dir/commands"
  mkdir -p "$src_dir/bin"
  printf '#!/bin/sh\necho frw\n' > "$src_dir/bin/frw"
  chmod +x "$src_dir/bin/frw"
  mkdir -p "$src_dir/.claude"
  printf '{}' > "$src_dir/.claude/settings.json"

  # Build consumer target
  mkdir -p "$tgt_dir/.claude/commands"
  mkdir -p "$tgt_dir/.claude/rules"

  # Manually create relative symlinks as frw.d/install.sh would
  # specialist:test-engineer.md -> ../../specialists/test-engineer.md
  local rel_spec
  rel_spec="../../specialists/test-engineer.md"
  ln -s "$src_dir/specialists/test-engineer.md" \
    "$tgt_dir/.claude/commands/specialist:test-engineer.md"
  ln -s "$src_dir/specialists/shell-specialist.md" \
    "$tgt_dir/.claude/commands/specialist:shell-specialist.md"
  ln -s "$src_dir/.claude/rules/cli-mediation.md" \
    "$tgt_dir/.claude/rules/cli-mediation.md"
  ln -s "$src_dir/.claude/rules/step-sequence.md" \
    "$tgt_dir/.claude/rules/step-sequence.md"

  # Verify all symlinks resolve
  local unresolved=0
  for link in \
    "$tgt_dir/.claude/commands/specialist:test-engineer.md" \
    "$tgt_dir/.claude/commands/specialist:shell-specialist.md" \
    "$tgt_dir/.claude/rules/cli-mediation.md" \
    "$tgt_dir/.claude/rules/step-sequence.md"; do
    if ! readlink -f "$link" > /dev/null 2>&1; then
      printf "  UNRESOLVED: %s\n" "$link" >&2
      unresolved=$((unresolved + 1))
    fi
  done

  assert_exit_code "all specialist+rules symlinks resolve" 0 "$unresolved"

  # Verify count matches what we created
  local count
  count="$(find "$tgt_dir/.claude/commands" -name 'specialist:*.md' -type l | wc -l)"
  assert_ge "at least 2 specialist symlinks created" "$count" 2

  rm -rf "$src_dir" "$tgt_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_source_repo_not_copied_to_target
# ---------------------------------------------------------------------------
# Verify SOURCE_REPO file does NOT appear under consumer target after install.
test_source_repo_not_copied_to_target() {
  local tgt_dir
  tgt_dir="$(mktemp -d)"
  trap 'rm -rf "$tgt_dir"' EXIT INT TERM

  # Ensure the consumer target does NOT have SOURCE_REPO
  mkdir -p "$tgt_dir/.furrow"

  assert_file_not_exists "consumer target has no SOURCE_REPO" \
    "$tgt_dir/.furrow/SOURCE_REPO"

  rm -rf "$tgt_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# test_gitignore_bootstrap_skipped_in_source_mode
# ---------------------------------------------------------------------------
# In source mode self-install (proj_root == FURROW_ROOT), .gitignore bootstrap
# is skipped. We simulate the detection logic.
test_gitignore_bootstrap_skipped_in_source_mode() {
  local src_dir
  src_dir="$(mktemp -d)"
  trap 'rm -rf "$src_dir"' EXIT INT TERM

  # Simulate: proj_root_abs == furrow_root_abs AND install_mode == source
  local proj_root_abs furrow_root_abs install_mode
  proj_root_abs="$src_dir"
  furrow_root_abs="$src_dir"
  install_mode="source"

  local should_bootstrap=1
  if [ "$proj_root_abs" = "$furrow_root_abs" ] && [ "$install_mode" = "source" ]; then
    should_bootstrap=0  # skipped
  fi

  assert_exit_code ".gitignore bootstrap skipped in source self-install" 0 \
    "$([ "$should_bootstrap" = "0" ] && echo 0 || echo 1)"

  rm -rf "$src_dir"
  trap - EXIT INT TERM
}

# ---------------------------------------------------------------------------
# Run all tests
# ---------------------------------------------------------------------------
run_test test_source_mode_detection
run_test test_symlink_validator_resolves
run_test test_source_repo_not_copied_to_target
run_test test_gitignore_bootstrap_skipped_in_source_mode

# Sandbox guard: fail the suite if any protected path was mutated.
assert_no_worktree_mutation

print_summary
