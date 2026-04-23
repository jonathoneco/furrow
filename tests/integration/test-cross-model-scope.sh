#!/bin/sh
# test-cross-model-scope.sh — regression coverage for
# cross-model-per-deliverable-diff.
#
# Covers AC1, AC2, AC3, AC5, AC7 of the cross-model-per-deliverable-diff
# deliverable spec:
#   AC1 — `git log -p --no-merges <base>..HEAD -- <globs>` replaces
#          `git diff --stat <base>..HEAD`.
#   AC2 — empty file_ownership → warning on stderr, fall back to unscoped
#          base..HEAD, mark unplanned_changes: not-applicable.
#   AC3 — review record contains diff_scope {base, commits[], files_matched[]}.
#   AC5 — scoped diff payload contains only the deliverable's own commits.
#   AC7 — `--no-merges` excludes merge commits from the diff payload.
#
# Strategy: build a two-deliverable fixture row (a/ vs b/). Run
# cross-model-review.sh in --dry-run / --emit-diff-scope mode so the script
# computes diff_scope and writes the review record without invoking any
# external model. The dry-run branch exercises the same scoping code path
# as production.
#
# POSIX sh. Uses setup_sandbox from the test-isolation-guard contract.

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT_LIVE="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# shellcheck source=helpers.sh
. "${SCRIPT_DIR}/helpers.sh"

echo "=== test-cross-model-scope.sh (cross-model-per-deliverable-diff) ==="

FRW_BIN="${PROJECT_ROOT_LIVE}/bin/frw"

# --- Fixture builder --------------------------------------------------------
# Build a sandbox that looks like a real project with a .furrow/ row and
# non-trivial git history: deliverable A commits touch a/, deliverable B
# commits touch b/, plus one merge commit on a side branch.
build_fixture() {
  unset TMP
  setup_sandbox >/dev/null

  _proj="${TMP}/proj"
  mkdir -p "$_proj"
  cd "$_proj"

  git init -q
  git config user.email "test@test"
  git config user.name "Test"

  # Base commit — empty tree-ish marker file outside either deliverable's
  # file_ownership so it isn't counted against either.
  mkdir -p c
  echo init > c/seed.txt
  git add c/seed.txt
  git commit -q -m "chore: base"
  BASE_SHA="$(git rev-parse HEAD)"

  # Deliverable A — two commits under a/
  mkdir -p a
  echo alpha > a/1.txt
  git add a/1.txt
  git commit -q -m "feat(a): one"
  A_SHA_1="$(git rev-parse HEAD)"

  echo alpha2 > a/2.txt
  git add a/2.txt
  git commit -q -m "feat(a): two"
  A_SHA_2="$(git rev-parse HEAD)"

  # Deliverable B — two commits under b/
  mkdir -p b
  echo beta > b/1.txt
  git add b/1.txt
  git commit -q -m "feat(b): one"
  B_SHA_1="$(git rev-parse HEAD)"

  echo beta2 > b/2.txt
  git add b/2.txt
  git commit -q -m "feat(b): two"
  B_SHA_2="$(git rev-parse HEAD)"

  # Produce a merge commit on a side branch that touches a/ — AC7 asserts
  # its SHA is absent from diff_scope.commits (since --no-merges is set).
  git checkout -q -b side
  echo alpha3 > a/3.txt
  git add a/3.txt
  git commit -q -m "feat(a): side"
  git checkout -q master 2>/dev/null || git checkout -q main 2>/dev/null || true
  git merge --no-ff -q -m "merge: side into trunk" side
  MERGE_SHA="$(git rev-parse HEAD)"

  # Write the row definition.yaml with two deliverables.
  mkdir -p .furrow/rows/demo-row
  cat > .furrow/rows/demo-row/definition.yaml <<YAML
objective: fixture row for cross-model-scope test
deliverables:
  - name: deliverable-a
    acceptance_criteria:
      - "a changes are scoped"
    specialist: harness-engineer
    file_ownership:
      - "a/**"
  - name: deliverable-b
    acceptance_criteria:
      - "b changes are scoped"
    specialist: harness-engineer
    file_ownership:
      - "b/**"
  - name: orphan-deliverable
    acceptance_criteria:
      - "no file_ownership declared"
    specialist: harness-engineer
YAML

  # state.json — just enough for the script to resolve mode + base_commit.
  cat > .furrow/rows/demo-row/state.json <<JSON
{
  "name": "demo-row",
  "mode": "code",
  "step": "implement",
  "base_commit": "${BASE_SHA}"
}
JSON

  # Seed an XDG config with a dummy cross_model.provider so the resolver
  # returns a value. The dry-run branch does not invoke the model.
  mkdir -p "${XDG_CONFIG_HOME}/furrow"
  cat > "${XDG_CONFIG_HOME}/furrow/config.yaml" <<YAML
cross_model:
  provider: "dry-run-provider"
YAML

  # Export vars the test needs.
  export FIXTURE_PROJECT="$_proj"
  export BASE_SHA A_SHA_1 A_SHA_2 B_SHA_1 B_SHA_2 MERGE_SHA
}

# Invoke cross-model-review.sh with controlled env; returns stdout.
# Uses --dry-run + --emit-diff-scope so no model is invoked.
invoke_review() {
  _deliverable="$1"
  _out="$2"
  _err="$3"
  (
    cd "$FIXTURE_PROJECT"
    PROJECT_ROOT="$FIXTURE_PROJECT" \
    FURROW_ROOT="$PROJECT_ROOT_LIVE" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
    HOME="$HOME" \
      "$FRW_BIN" cross-model-review --dry-run --emit-diff-scope demo-row "$_deliverable" > "$_out" 2> "$_err"
  )
}

# --- Scenario 1: scoped diff for deliverable A -----------------------------
test_scoped_diff_for_a() {
  printf '\n[Test 1: deliverable-a scoping — AC1, AC5, AC7]\n'
  build_fixture

  _out="${TMP}/a.out.json"
  _err="${TMP}/a.err"
  invoke_review deliverable-a "$_out" "$_err"

  # diff_scope.commits should contain A's two SHAs and neither B's commits
  # nor the merge SHA.
  _commits="$(jq -r '.diff_scope.commits[]' "$_out")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$_commits" | grep -qx "$A_SHA_1" && \
     printf '%s\n' "$_commits" | grep -qx "$A_SHA_2"; then
    printf "  PASS: diff_scope.commits includes both A commits\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: diff_scope.commits missing A commits\n  got: %s\n" "$_commits" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! printf '%s\n' "$_commits" | grep -qx "$B_SHA_1" && \
     ! printf '%s\n' "$_commits" | grep -qx "$B_SHA_2"; then
    printf "  PASS: diff_scope.commits excludes B commits (scoping works)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: B commits leaked into diff_scope.commits\n  got: %s\n" "$_commits" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if ! printf '%s\n' "$_commits" | grep -qx "$MERGE_SHA"; then
    printf "  PASS: diff_scope.commits excludes merge commit (--no-merges, AC7)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: merge SHA leaked into diff_scope.commits (--no-merges broken)\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # files_matched: only paths under a/
  _files="$(jq -r '.diff_scope.files_matched[]' "$_out")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if printf '%s\n' "$_files" | grep -q '^a/' && \
     ! printf '%s\n' "$_files" | grep -q '^b/'; then
    printf "  PASS: files_matched includes a/ paths and excludes b/ paths\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: files_matched has wrong paths\n  got: %s\n" "$_files" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  # unplanned_changes: absent (not the fallback marker)
  _unplanned="$(jq -r '.unplanned_changes' "$_out")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_unplanned" = "absent" ]; then
    printf "  PASS: unplanned_changes='absent' for scoped deliverable\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: unplanned_changes should be 'absent', got '%s'\n" "$_unplanned" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Scenario 2: deliverable B is not flagged as unplanned changes ---------
test_b_not_flagged_when_reviewing_a() {
  printf '\n[Test 2: B commits do not flag unplanned-changes for A — AC5]\n'
  # Fixture already built by Test 1 (same $TMP).

  _out="${TMP}/a2.out.json"
  _err="${TMP}/a2.err"
  invoke_review deliverable-a "$_out" "$_err"

  # The per-deliverable scoping means B's files never appear in
  # files_matched; therefore B cannot be flagged as "unplanned" for A.
  _b_leaked="$(jq -r '.diff_scope.files_matched[] | select(startswith("b/"))' "$_out" | wc -l | tr -d ' ')"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_b_leaked" = "0" ]; then
    printf "  PASS: no B-owned files present in A's diff_scope (B not flagged)\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: %s B-owned file(s) leaked into A's diff_scope\n" "$_b_leaked" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Scenario 3: empty file_ownership fallback -----------------------------
test_empty_file_ownership_fallback() {
  printf '\n[Test 3: orphan deliverable (empty file_ownership) — AC2]\n'
  # Fixture already built; orphan-deliverable has no file_ownership.

  _out="${TMP}/orphan.out.json"
  _err="${TMP}/orphan.err"
  invoke_review orphan-deliverable "$_out" "$_err"

  TESTS_RUN=$((TESTS_RUN + 1))
  if grep -q 'no file_ownership' "$_err"; then
    printf "  PASS: warning contains 'no file_ownership' on stderr\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: no-file_ownership warning missing from stderr\n  stderr: %s\n" "$(cat "$_err")" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  _unplanned="$(jq -r '.unplanned_changes' "$_out")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ "$_unplanned" = "not-applicable" ]; then
    printf "  PASS: unplanned_changes='not-applicable' under fallback\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: unplanned_changes should be 'not-applicable' under fallback, got '%s'\n" "$_unplanned" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  _fallback="$(jq -r '.diff_scope.fallback_reason // ""' "$_out")"
  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -n "$_fallback" ]; then
    printf "  PASS: diff_scope.fallback_reason recorded ('%s')\n" "$_fallback"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: diff_scope.fallback_reason should be set under fallback\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Scenario 4: review record persisted with diff_scope -------------------
test_review_record_persisted() {
  printf '\n[Test 4: review record file contains diff_scope — AC3]\n'

  _review="${FIXTURE_PROJECT}/.furrow/rows/demo-row/reviews/deliverable-a-cross.json"

  TESTS_RUN=$((TESTS_RUN + 1))
  if [ -f "$_review" ]; then
    printf "  PASS: review record file exists\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: review record missing at %s\n" "$_review" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
    return 0
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if jq -e '.diff_scope.base | test("^[0-9a-f]{7,40}$")' "$_review" >/dev/null 2>&1; then
    printf "  PASS: diff_scope.base is a SHA\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: diff_scope.base is not a SHA\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if jq -e '.diff_scope.commits | type == "array" and length > 0' "$_review" >/dev/null 2>&1; then
    printf "  PASS: diff_scope.commits is a non-empty array\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: diff_scope.commits is empty or not an array\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi

  TESTS_RUN=$((TESTS_RUN + 1))
  if jq -e '.diff_scope.files_matched | type == "array" and length > 0' "$_review" >/dev/null 2>&1; then
    printf "  PASS: diff_scope.files_matched is a non-empty array\n"
    TESTS_PASSED=$((TESTS_PASSED + 1))
  else
    printf "  FAIL: diff_scope.files_matched is empty or not an array\n" >&2
    TESTS_FAILED=$((TESTS_FAILED + 1))
  fi
}

# --- Main -------------------------------------------------------------------
run_test test_scoped_diff_for_a
run_test test_b_not_flagged_when_reviewing_a
run_test test_empty_file_ownership_fallback
run_test test_review_record_persisted

print_summary
