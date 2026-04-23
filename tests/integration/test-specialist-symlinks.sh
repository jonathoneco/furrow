#!/bin/bash
# test-specialist-symlinks.sh — specialist-symlink-unification regression test
#
# Verifies the three Test Scenarios from
# .furrow/rows/post-install-hygiene/specs/specialist-symlink-unification.md:
#
#   1. Consumer install into a fresh fixture produces exactly 22 specialist:*.md
#      symlinks and every one resolves to a real specialists/*.md file.
#   2. Self-hosting install (copy-of-this-repo fixture) produces the same 22
#      symlinks and leaves `git status --porcelain .claude/commands/` empty —
#      i.e. the .gitignore excludes them and nothing leaks into the index.
#   3. An install run against a fixture with a deliberately-deleted specialist
#      exits 1 with stderr containing
#        "install: specialist symlink <name> points to missing target ..."
#      (the install-time validator contract).
#
# All three scenarios run inside setup_sandbox (tests/integration/lib/sandbox.sh)
# so no live-worktree mutation is possible.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=helpers.sh
source "$SCRIPT_DIR/helpers.sh"

echo "=== test-specialist-symlinks.sh (specialist-symlink-unification) ==="

setup_sandbox >/dev/null
snapshot_guard_targets

# -------------------------------------------------------------------------
# _copy_repo_fixture <dest>
#
# Copies the live checkout (PROJECT_ROOT) into <dest> so install.sh can be
# exercised against a writable, throw-away clone. Uses `git ls-files` so we
# only replicate tracked files; then re-inits a git repo so
# `git status --porcelain` is meaningful inside the fixture.
# -------------------------------------------------------------------------
_copy_repo_fixture() {
  _dst="$1"
  mkdir -p "$_dst"
  (
    cd "$PROJECT_ROOT"
    # ls-files respects .gitignore — so specialist symlinks (once untracked)
    # are correctly excluded; the fixture starts in the post-untrack state.
    #
    # We skip tracked symlinks under .claude/commands/ entirely: those
    # `furrow:*.md` symlinks use relative targets like
    # `../../../furrow/commands/*.md` that only resolve inside THIS checkout,
    # not inside a fixture at a different path. install.sh will recreate
    # them correctly in the fixture, so we let it produce them.
    git ls-files -z | while IFS= read -r -d '' _p; do
      case "$_p" in
        .claude/commands/*) continue ;;
      esac
      _dir="$(dirname "$_p")"
      [ -n "$_dir" ] && [ "$_dir" != "." ] && mkdir -p "$_dst/$_dir"
      cp -P "$_p" "$_dst/$_p"
    done
  )
  # Re-init git so the fixture has an independent index/status. .gitignore
  # from the seed determines what counts as drift in self-hosting assertions.
  (
    cd "$_dst"
    git init -q
    git config user.email "test@example.com"
    git config user.name "Test"
    git add -A >/dev/null 2>&1 || true
    git commit -q -m "fixture seed" >/dev/null 2>&1 || true
  )
}

# -------------------------------------------------------------------------
# Scenario 1: consumer install produces 22 resolved symlinks.
# Verifies AC-3, AC-4.
# -------------------------------------------------------------------------
test_consumer_install_22_resolved_symlinks() {
  _proj="$TMP/fixture/consumer-proj"
  mkdir -p "$_proj"
  (cd "$_proj" && git init -q && git config user.email "t@t" && git config user.name "T")

  # Run the bootstrap install.sh against the consumer project.
  # install.sh delegates to `frw install --project <path>`; we invoke that
  # form directly to avoid the bootstrap needing ~/.local/bin on PATH.
  (
    cd "$PROJECT_ROOT"
    FURROW_ROOT="$PROJECT_ROOT" "$PROJECT_ROOT/bin/frw" install \
      --project "$_proj" >/dev/null 2>&1
  )

  _count="$(find "$_proj/.claude/commands" -maxdepth 1 \
    -name 'specialist:*.md' -type l 2>/dev/null | wc -l | tr -d ' ')"
  assert_exit_code "consumer install creates exactly 22 specialist symlinks" \
    22 "$_count"

  _unresolved=0
  for _l in "$_proj/.claude/commands"/specialist:*.md; do
    [ -L "$_l" ] || continue
    if ! readlink -e "$_l" >/dev/null 2>&1; then
      _unresolved=$((_unresolved + 1))
      printf '  UNRESOLVED: %s -> %s\n' "$_l" "$(readlink "$_l")" >&2
    fi
  done
  assert_exit_code "every produced specialist symlink resolves (readlink -e)" \
    0 "$_unresolved"

  rm -rf "$_proj"
}

# -------------------------------------------------------------------------
# Scenario 2: self-hosting install leaves git status clean.
# Verifies AC-3, AC-4, AC-5.
# -------------------------------------------------------------------------
test_self_hosting_leaves_git_status_clean() {
  _fh="$TMP/fixture/furrow-src"
  rm -rf "$_fh"
  _copy_repo_fixture "$_fh"

  # Safety: the untracked specialist symlinks must NOT appear in the fresh
  # fixture before install.sh runs (they are gitignored; the fixture copies
  # tracked files only).
  _pre_tracked="$(cd "$_fh" && git ls-files .claude/commands/ \
    | grep -c '^\.claude/commands/specialist:' || true)"
  assert_exit_code "fixture starts with 0 tracked specialist symlinks" \
    0 "$_pre_tracked"

  # Run install.sh in self-hosting mode (the copied fixture retains the
  # .furrow/SOURCE_REPO sentinel, so INSTALL_MODE=source).
  (
    cd "$_fh"
    FURROW_ROOT="$_fh" "$_fh/bin/frw" install --project "$_fh" >/dev/null 2>&1
  )

  _count="$(find "$_fh/.claude/commands" -maxdepth 1 \
    -name 'specialist:*.md' -type l 2>/dev/null | wc -l | tr -d ' ')"
  assert_exit_code "self-hosting install creates exactly 22 specialist symlinks" \
    22 "$_count"

  _unresolved=0
  for _l in "$_fh/.claude/commands"/specialist:*.md; do
    [ -L "$_l" ] || continue
    if ! readlink -e "$_l" >/dev/null 2>&1; then
      _unresolved=$((_unresolved + 1))
    fi
  done
  assert_exit_code "every self-hosted specialist symlink resolves" \
    0 "$_unresolved"

  # The linchpin assertion: the 22 new working-tree symlinks must NOT surface
  # in `git status --porcelain` because .gitignore excludes the pattern.
  _drift="$(cd "$_fh" && git status --porcelain .claude/commands/ \
    | grep 'specialist:' || true)"
  if [ -n "$_drift" ]; then
    printf '  git status drift:\n%s\n' "$_drift" >&2
  fi
  assert_exit_code "git status --porcelain .claude/commands/ shows no specialist drift" \
    0 "$([ -z "$_drift" ] && echo 0 || echo 1)"

  rm -rf "$_fh"
}

# -------------------------------------------------------------------------
# Scenario 3: install-time validator rejects broken targets.
# Verifies AC-4 (validator contract).
# -------------------------------------------------------------------------
test_validator_rejects_missing_specialist() {
  _fb="$TMP/fixture/furrow-broken"
  rm -rf "$_fb"
  _copy_repo_fixture "$_fb"

  # Delete a specialist AFTER the fixture is seeded so the symlink the
  # install-loop produces will dangle. The glob discovery uses
  # $FURROW_ROOT/specialists/*.md so deleting the file removes the
  # specialist from both the loop's inputs and from subsequent `readlink -e`
  # resolution. To actually trigger the validator's dangling path, we run
  # install once to produce the 22 symlinks, THEN delete the target file,
  # THEN re-run install: the existing symlink is preserved by symlink() when
  # already correct, but readlink -e now fails.
  (
    cd "$_fb"
    FURROW_ROOT="$_fb" "$_fb/bin/frw" install --project "$_fb" >/dev/null 2>&1
  )

  rm -f "$_fb/specialists/api-designer.md"

  _out="$(cd "$_fb" && FURROW_ROOT="$_fb" "$_fb/bin/frw" install \
    --project "$_fb" 2>&1)" && _rc=0 || _rc=$?

  assert_exit_code "install exits 1 when a specialist target is missing" \
    1 "$_rc"

  if printf '%s\n' "$_out" \
      | grep -q 'install: specialist symlink api-designer points to missing target'; then
    assert_exit_code "stderr names the broken specialist in the canonical format" 0 0
  else
    printf '  install output:\n%s\n' "$_out" >&2
    assert_exit_code "stderr names the broken specialist in the canonical format" 0 1
  fi

  rm -rf "$_fb"
}

# -------------------------------------------------------------------------
# Run
# -------------------------------------------------------------------------
run_test test_consumer_install_22_resolved_symlinks
run_test test_self_hosting_leaves_git_status_clean
run_test test_validator_rejects_missing_specialist

# Sandbox guard: fail the suite if any protected path was mutated.
assert_no_worktree_mutation

print_summary
