#!/bin/bash
# test-rescue.sh — Integration tests for bin/frw.d/scripts/rescue.sh
#
# Subtests:
#   1. head_path          — corrupt common.sh; HEAD has valid; rescue --apply restores
#   2. bundled_path       — bare git repo (no HEAD); rescue uses bundled baseline
#   3. no_common_source_grep — rescue.sh must not source common(-minimal).sh
#   4. baseline_drift     — edit common-minimal.sh without refreshing heredoc; exit 3
#   5. target_missing_no_baseline — missing target, no git; exit 1
#   6. post_write_parse_fail — broken bundled baseline in temp rescue.sh; exit 4
#
# Usage: bash tests/integration/test-rescue.sh

set -eu

# Resolve project root relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESCUE_SH="${PROJECT_ROOT}/bin/frw.d/scripts/rescue.sh"

# shellcheck source=tests/integration/helpers.sh
source "$SCRIPT_DIR/helpers.sh"

TESTS_PASSED=0
TESTS_FAILED=0
TESTS_RUN=0

# ---------------------------------------------------------------------------
# Subtest 1: head_path
# Corrupt common.sh, HEAD has valid version, rescue --apply restores it.
# Operation-count assertion: at most 1 git show invocation.
# ---------------------------------------------------------------------------
test_head_path() {
  echo ""
  echo "--- test_head_path ---"
  local scratch
  scratch="$(mktemp -d)"
  trap 'rm -rf "$scratch"' EXIT INT TERM

  # Set up a git repo with a "valid" common.sh committed to HEAD
  (
    cd "$scratch" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p "bin/frw.d/lib" &&
    cp "${PROJECT_ROOT}/bin/frw.d/lib/common.sh" "bin/frw.d/lib/common.sh" &&
    git add "bin/frw.d/lib/common.sh" &&
    git commit -q -m "initial"
  )

  # Corrupt the file
  printf 'garbage syntax (\n' >> "${scratch}/bin/frw.d/lib/common.sh"

  # Step 1: rescue the corrupt file
  local rc=0
  sh "$RESCUE_SH" --apply --file "${scratch}/bin/frw.d/lib/common.sh" \
    > /dev/null 2>&1 || rc=$?

  assert_exit_code "head_path: rescue exits 0" 0 "$rc"

  local parse_rc=0
  sh -n "${scratch}/bin/frw.d/lib/common.sh" 2>/dev/null || parse_rc=$?
  assert_exit_code "head_path: restored file parses cleanly" 0 "$parse_rc"

  # Content must equal git show HEAD:bin/frw.d/lib/common.sh from the scratch repo
  local expected_file="${scratch}/expected_content.sh"
  git -C "$scratch" show HEAD:bin/frw.d/lib/common.sh > "$expected_file"
  TESTS_RUN=$((TESTS_RUN + 1))
  if cmp -s "$expected_file" "${scratch}/bin/frw.d/lib/common.sh"; then
    printf "  PASS: head_path: content equals HEAD version\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: head_path: content mismatch vs HEAD\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # Operation-count: corrupt again, then trace a rescue run, count git show calls
  printf 'garbage again (\n' >> "${scratch}/bin/frw.d/lib/common.sh"
  local trace_out="${scratch}/op_trace.txt"
  GIT_TRACE=1 sh "$RESCUE_SH" --apply --file "${scratch}/bin/frw.d/lib/common.sh" \
    > /dev/null 2> "$trace_out" || true
  local git_show_count
  git_show_count="$(grep -c 'git.*show' "$trace_out" 2>/dev/null || printf '0')"
  # grep -c returns an integer on a single line; ensure it's a bare integer
  git_show_count="${git_show_count%%[^0-9]*}"
  git_show_count="${git_show_count:-0}"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$git_show_count" -le 1 ]; then
    printf "  PASS: head_path: at most 1 git show invocation (%s found)\n" "$git_show_count"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: head_path: expected <= 1 git show, got %s\n" "$git_show_count" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  trap - EXIT INT TERM
  rm -rf "$scratch"
}

# ---------------------------------------------------------------------------
# Subtest 2: bundled_path
# Bare git dir with unborn HEAD (no commits), rescue uses bundled baseline.
# GIT_TRACE proves HEAD path was ATTEMPTED-AND-FAILED.
# ---------------------------------------------------------------------------
test_bundled_path() {
  echo ""
  echo "--- test_bundled_path ---"
  local scratch
  scratch="$(mktemp -d)"
  trap 'rm -rf "$scratch"' EXIT INT TERM

  # Initialize git repo with no commits (unborn HEAD)
  (
    cd "$scratch" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p "bin/frw.d/lib" &&
    printf 'broken syntax (\n' > "bin/frw.d/lib/common.sh"
  )

  local trace_file="${scratch}/git_trace.txt"
  local rc=0
  GIT_TRACE=1 sh "$RESCUE_SH" --apply --file "${scratch}/bin/frw.d/lib/common.sh" \
    > "${scratch}/out.txt" 2> "$trace_file" || rc=$?

  assert_exit_code "bundled_path: rescue exits 0" 0 "$rc"

  local parse_rc=0
  sh -n "${scratch}/bin/frw.d/lib/common.sh" 2>/dev/null || parse_rc=$?
  assert_exit_code "bundled_path: restored file parses cleanly" 0 "$parse_rc"

  # Verify content matches bundled baseline extracted from rescue.sh
  local tmp_bl="${scratch}/expected_baseline.sh"
  awk '
    /^FURROW_BASELINE_COMMON_MINIMAL$/ { if (inside) { exit } else { inside=1; next } }
    inside { print }
  ' "$RESCUE_SH" > "$tmp_bl"
  local exp_sha
  exp_sha="$(sha256sum "$tmp_bl" | cut -d' ' -f1)"
  local act_sha
  act_sha="$(sha256sum "${scratch}/bin/frw.d/lib/common.sh" | cut -d' ' -f1)"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$exp_sha" = "$act_sha" ]; then
    printf "  PASS: bundled_path: content matches bundled heredoc body\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: bundled_path: content mismatch (expected %s, got %s)\n" "$exp_sha" "$act_sha" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # GIT_TRACE proves HEAD path was attempted (git show was called and failed)
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q 'show' "$trace_file" 2>/dev/null; then
    printf "  PASS: bundled_path: GIT_TRACE shows HEAD path was attempted\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: bundled_path: GIT_TRACE has no evidence of git show attempt\n" >&2
    printf "  (trace contents: %s)\n" "$(head -5 "$trace_file" 2>/dev/null || echo '(empty)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  trap - EXIT INT TERM
  rm -rf "$scratch"
}

# ---------------------------------------------------------------------------
# Subtest 3: no_common_source_grep
# rescue.sh must not source common.sh or common-minimal.sh.
# ---------------------------------------------------------------------------
test_no_common_source_grep() {
  echo ""
  echo "--- test_no_common_source_grep ---"
  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -E '(^|[[:space:]])(\.|source)[[:space:]].*common(-minimal)?\.sh' "$RESCUE_SH" > /dev/null 2>&1; then
    printf "  FAIL: no_common_source_grep: rescue.sh sources a common lib\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  else
    printf "  PASS: no_common_source_grep: no common lib sourced in rescue.sh\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  fi
}

# ---------------------------------------------------------------------------
# Subtest 4: baseline_drift
# Edit a tmp copy of common-minimal.sh without refreshing rescue.sh heredoc;
# copy rescue.sh to tmp; run --baseline-check; assert exit 3 + drift stderr.
# ---------------------------------------------------------------------------
test_baseline_drift() {
  echo ""
  echo "--- test_baseline_drift ---"
  local scratch
  scratch="$(mktemp -d)"
  trap 'rm -rf "$scratch"' EXIT INT TERM

  # Create a modified common-minimal.sh (add a spurious comment)
  local fake_cm="${scratch}/common-minimal.sh"
  cp "${PROJECT_ROOT}/bin/frw.d/lib/common-minimal.sh" "$fake_cm"
  printf '# DRIFT MARKER\n' >> "$fake_cm"

  # Create a tmp copy of rescue.sh with FURROW_ROOT pointing to scratch
  # and common-minimal.sh at the modified path.
  # We'll override FURROW_ROOT inside a wrapper.
  local tmp_rescue="${scratch}/rescue_drift.sh"
  cp "$RESCUE_SH" "$tmp_rescue"

  # Override FURROW_ROOT by prepending env var assignment to a wrapper
  local wrapper="${scratch}/rescue_wrapper.sh"
  cat > "$wrapper" <<WRAP
#!/bin/sh
# Wrapper that points FURROW_ROOT to scratch with drifted common-minimal.sh
FURROW_ROOT_OVERRIDE="${scratch}"
# We can't easily override FURROW_ROOT inside rescue.sh since it re-derives it.
# Instead, create the expected directory structure.
mkdir -p "${scratch}/bin/frw.d/lib"
cp "${fake_cm}" "${scratch}/bin/frw.d/lib/common-minimal.sh"
exec sh "${tmp_rescue}" "\$@"
WRAP
  chmod +x "$wrapper"

  # Set up the directory structure rescue.sh expects
  mkdir -p "${scratch}/bin/frw.d/lib"
  cp "$fake_cm" "${scratch}/bin/frw.d/lib/common-minimal.sh"

  # Run rescue.sh (from scratch dir so FURROW_ROOT resolves to scratch)
  # rescue.sh derives FURROW_ROOT as 3 levels up from its own location
  # tmp_rescue is at ${scratch}/rescue_drift.sh
  # So FURROW_ROOT would be ${scratch}/../../.. — wrong.
  # Place rescue.sh in proper relative position.
  mkdir -p "${scratch}/myrepo/bin/frw.d/scripts"
  mkdir -p "${scratch}/myrepo/bin/frw.d/lib"
  cp "$RESCUE_SH" "${scratch}/myrepo/bin/frw.d/scripts/rescue.sh"
  cp "$fake_cm" "${scratch}/myrepo/bin/frw.d/lib/common-minimal.sh"

  local drift_rc=0
  local drift_err="${scratch}/drift_err.txt"
  sh "${scratch}/myrepo/bin/frw.d/scripts/rescue.sh" --baseline-check \
    > /dev/null 2> "$drift_err" || drift_rc=$?

  assert_exit_code "baseline_drift: rescue exits 3 on drift" 3 "$drift_rc"

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q 'drift' "$drift_err" 2>/dev/null; then
    printf "  PASS: baseline_drift: stderr mentions drift\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: baseline_drift: stderr does not mention drift\n" >&2
    printf "  (stderr: %s)\n" "$(cat "$drift_err" 2>/dev/null || echo '(empty)')" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  trap - EXIT INT TERM
  rm -rf "$scratch"
}

# ---------------------------------------------------------------------------
# Subtest 5: target_missing_no_baseline
# Empty dir, no git, missing target; assert exit 1.
# ---------------------------------------------------------------------------
test_target_missing_no_baseline() {
  echo ""
  echo "--- test_target_missing_no_baseline ---"
  local scratch
  scratch="$(mktemp -d)"
  trap 'rm -rf "$scratch"' EXIT INT TERM

  # Run from a directory with no git repo
  local rc=0
  (
    cd "$scratch" &&
    sh "$RESCUE_SH" --apply --file "/does/not/exist/common.sh" \
      > /dev/null 2> /dev/null
  ) || rc=$?

  assert_exit_code "target_missing_no_baseline: exit 1" 1 "$rc"

  trap - EXIT INT TERM
  rm -rf "$scratch"
}

# ---------------------------------------------------------------------------
# Subtest 6: post_write_parse_fail
# Rig a patched rescue.sh so the post-write sh -n check sees broken content.
# The patched version writes a known-broken shell fragment to _tmp_out after
# the cp, simulating a write-corruption scenario, so the post-write sh -n
# check fires exit 4.
# ---------------------------------------------------------------------------
test_post_write_parse_fail() {
  echo ""
  echo "--- test_post_write_parse_fail ---"
  local scratch
  scratch="$(mktemp -d)"
  trap 'rm -rf "$scratch"' EXIT INT TERM

  # Create a patched rescue.sh that, in the --apply path, overwrites _tmp_out
  # with broken shell after cp so the post-write sh -n check fails (exit 4).
  # We patch the apply block: replace "cp "$_candidate" "$_tmp_out"" with
  # a cp followed by an echo of broken syntax into _tmp_out.
  local patched_rescue="${scratch}/rescue_patched.sh"
  sed 's|cp "\$_candidate" "\$_tmp_out"|cp "$_candidate" "$_tmp_out"; printf "broken syntax (" > "$_tmp_out"|g' \
    "$RESCUE_SH" > "$patched_rescue"
  chmod +x "$patched_rescue"

  # Set up a git repo with a corrupt target so rescue falls through to baseline
  local repo="${scratch}/repo"
  mkdir -p "$repo"
  (
    cd "$repo" &&
    git init -q &&
    git config user.email "test@test.com" &&
    git config user.name "Test" &&
    mkdir -p "bin/frw.d/lib" &&
    printf '#!/bin/sh\necho ok\n' > "bin/frw.d/lib/common.sh" &&
    git add "bin/frw.d/lib/common.sh" &&
    git commit -q -m "initial"
  )
  # Make HEAD also broken so rescue falls through to bundled baseline
  (
    cd "$repo" &&
    printf 'broken head (\n' > "bin/frw.d/lib/common.sh" &&
    git add "bin/frw.d/lib/common.sh" &&
    git commit -q -m "broken"
  )
  # Corrupt working tree file
  printf 'corrupt working tree (\n' > "${repo}/bin/frw.d/lib/common.sh"

  local rc=0
  sh "$patched_rescue" --apply --file "${repo}/bin/frw.d/lib/common.sh" \
    > /dev/null 2>/dev/null || rc=$?

  assert_exit_code "post_write_parse_fail: exit 4 on post-write parse failure" 4 "$rc"

  trap - EXIT INT TERM
  rm -rf "$scratch"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "=== test-rescue.sh ==="

run_test test_head_path
run_test test_bundled_path
run_test test_no_common_source_grep
run_test test_baseline_drift
run_test test_target_missing_no_baseline
run_test test_post_write_parse_fail

print_summary
