# Spec: cross-model-per-deliverable-diff

**Wave**: 3
**Specialist**: harness-engineer
**Depends on**: test-isolation-guard, xdg-config-consumer-wiring

## Interface Contract

### bin/frw.d/scripts/cross-model-review.sh

- **Arguments** (unchanged from today):
  - `$1` — row name
  - `$2` — deliverable name
  - (subsequent args/flags unchanged)
- **New internal behavior**: computes a per-deliverable diff by reading
  `file_ownership` globs from `definition.yaml` for the named deliverable, then
  invoking:
  ```sh
  git log -p --no-merges "${base_commit}..HEAD" -- <glob1> <glob2> ...
  ```
  This single command outputs commit metadata AND patches, naturally filtered
  to matching paths.
- **Fallback**: if `file_ownership` yields zero globs for the deliverable, the
  reviewer emits a warning to stderr, falls back to `base_commit..HEAD`
  unscoped, and marks `unplanned-changes: not-applicable` in the review record
  rather than flagging unrelated commits as unplanned.
- **`cross_model.provider` read**: all four call sites (lines 79, 280, 446,
  631 today) use `resolve_config_value "cross_model.provider"` (from
  `bin/frw.d/lib/common.sh`, adopted in `xdg-config-consumer-wiring`).
- **Review record shape** (`reviews/<deliverable>.json`): new field
  `diff_scope: { base: <sha>, commits: [<sha>, ...], files_matched: [<path>, ...] }`
  for reproducibility and audit.
- **Contract guarantees**:
  - Codex invocation contract unchanged — only the diff *input* is scoped.
  - No change to `bin/frw` dispatcher.
  - Exit codes unchanged.
- **Pattern reuse**: `file_ownership` yq query mirrors the reference impl at
  `bin/frw.d/scripts/check-artifacts.sh:77-106`:
  ```sh
  file_ownership="$(name="${deliverable}" \
    yq -r '.deliverables[] | select(.name == env(name)) | .file_ownership[]?' \
    "$definition_file")"
  ```

### Why `git log -p --no-merges`, not `git diff <first>^..<last>` (AD-2)

Research Section B confirmed `git diff <first>^..<last>` diffs the entire
contiguous range — it would include unrelated commits (e.g., for commits 1,3,5
of a range 1–6 it would include 2,4,6 too). `git log -p --no-merges` selects
by path glob and preserves commit identity. `--follow` is omitted because it
is single-path only; rename tracing is out of scope (documented in AC).

## Acceptance Criteria (Refined)

Derived from definition.yaml ACs; each is testable.

1. **AC1 — Per-deliverable diff via `git log -p --no-merges`**.
   `bin/frw.d/scripts/cross-model-review.sh` reads `file_ownership` from
   `definition.yaml` via yq (pattern from `check-artifacts.sh:77-106`) and
   invokes `git log -p --no-merges <base>..HEAD -- <globs>`. The older `git
   diff <base>..HEAD --stat` call at line 116 is replaced.

2. **AC2 — Empty file_ownership fallback**. If a deliverable has no
   `file_ownership` declared, cross-model-review.sh (a) warns to stderr, (b)
   falls back to unscoped `base..HEAD`, (c) writes
   `unplanned-changes: not-applicable` rather than failing.

3. **AC3 — Review record includes diff_scope**. The written review JSON at
   `reviews/<deliverable>.json` contains a `diff_scope` object with `base`
   (string SHA), `commits` (array of SHAs included), and `files_matched`
   (array of path strings).

4. **AC4 — Resolver adoption for cross_model.provider**. All four existing
   call sites for `cross_model.provider` (lines 79, 280, 446, 631 per
   research Section D) are replaced with calls to `resolve_config_value
   "cross_model.provider"`. No direct `yq` on the xdg config file remains in
   this script.

5. **AC5 — Regression test for scoped diff**.
   `tests/integration/test-cross-model-scope.sh` builds a two-deliverable
   fixture where deliverable A's `file_ownership` covers only `a/**` and
   deliverable B's covers only `b/**`. Running the reviewer for A sees only
   commits that modified `a/**`; B's commits do not appear in the diff
   payload and unplanned-changes does not flag them.

6. **AC6 — No dispatcher change**. `bin/frw` is NOT modified by this
   deliverable (it does not appear in file_ownership). All logic changes are
   internal to `cross-model-review.sh`.

7. **AC7 — `--no-merges` used**. Merge commits are excluded from the diff
   payload passed to codex (confirmed by absence of merge-commit SHAs in the
   test-cross-model-scope.sh fixture).

## Test Scenarios

### Scenario: scoped diff matches only deliverable A's files
- **Verifies**: AC1, AC5, AC7
- **WHEN**: fixture row has deliverable A (`file_ownership: [a/**]`) with two
  commits touching only `a/` files, and deliverable B
  (`file_ownership: [b/**]`) with two commits touching only `b/` files. All
  four commits are in `base..HEAD`, interleaved. Running
  `cross-model-review.sh <row> A`.
- **THEN**: the diff payload captured in the review record references only
  A's two commit SHAs; `files_matched` lists only paths under `a/`.
- **Verification**:
  ```sh
  bin/frw.d/scripts/cross-model-review.sh test-row deliverable-a \
    --dry-run --emit-diff-scope > "$TMP/out.json"
  jq -r '.diff_scope.commits | length' "$TMP/out.json" | grep -q '^2$'
  jq -r '.diff_scope.files_matched[]' "$TMP/out.json" | grep -vq '^b/'
  ```

### Scenario: empty file_ownership triggers fallback + warning
- **Verifies**: AC2
- **WHEN**: fixture deliverable has no `file_ownership` key set
- **THEN**: script prints a warning to stderr containing
  `no file_ownership`; review record contains
  `unplanned-changes: not-applicable`; exit code 0
- **Verification**:
  ```sh
  bin/frw.d/scripts/cross-model-review.sh test-row orphan-deliverable \
    --dry-run 2> "$TMP/err" > "$TMP/out.json"
  grep -q 'no file_ownership' "$TMP/err"
  jq -r '.unplanned_changes' "$TMP/out.json" | grep -q '^not-applicable$'
  ```

### Scenario: diff_scope field populated in review record
- **Verifies**: AC3
- **WHEN**: successful review run on a deliverable with populated
  `file_ownership`
- **THEN**: `reviews/<deliverable>.json` contains `diff_scope.base`
  (non-empty SHA), `diff_scope.commits[]` (non-empty array), and
  `diff_scope.files_matched[]` (non-empty array)
- **Verification**:
  ```sh
  jq -e '.diff_scope.base | test("^[0-9a-f]{7,40}$")' \
    .furrow/rows/test-row/reviews/deliverable-a.json
  jq -e '.diff_scope.commits | length > 0' \
    .furrow/rows/test-row/reviews/deliverable-a.json
  jq -e '.diff_scope.files_matched | length > 0' \
    .furrow/rows/test-row/reviews/deliverable-a.json
  ```

### Scenario: cross_model.provider resolves via XDG fallback
- **Verifies**: AC4
- **WHEN**: no project `.furrow/furrow.yaml`; XDG config at
  `${XDG_CONFIG_HOME}/furrow/config.yaml` sets `cross_model: { provider:
  codex }`; review run invoked
- **THEN**: each of the four former yq-direct call sites now returns `codex`
  via `resolve_config_value`; no direct yq-on-xdg call remains in the script
- **Verification**:
  ```sh
  ! grep -n 'yq.*XDG_CONFIG_HOME' bin/frw.d/scripts/cross-model-review.sh
  grep -c 'resolve_config_value "cross_model.provider"' \
    bin/frw.d/scripts/cross-model-review.sh | grep -q '^4$'
  ```

### Scenario: merge commits excluded from diff
- **Verifies**: AC7
- **WHEN**: fixture `base..HEAD` includes one merge commit touching files in
  the deliverable's globs
- **THEN**: merge commit SHA is absent from `diff_scope.commits[]`
- **Verification**:
  ```sh
  merge_sha=$(git log --merges --format=%H -1 "$base..HEAD")
  ! jq -r '.diff_scope.commits[]' "$TMP/review.json" | grep -q "$merge_sha"
  ```

### Scenario: bin/frw dispatcher untouched
- **Verifies**: AC6
- **WHEN**: this deliverable's commits are inspected
- **THEN**: `git log --name-only <base>..HEAD -- bin/frw` produces no changes
  attributable to this deliverable
- **Verification**:
  ```sh
  git log --name-only --format= <base>..HEAD -- bin/frw | grep -v '^$' | \
    wc -l | grep -q '^0$'
  ```

## Implementation Notes

- **Diff semantics (AD-2)**. The chosen invocation is
  `git log -p --no-merges "${base_commit}..HEAD" -- <globs>`. This is a
  single-command replacement for the current `git diff --stat
  "${base_commit}..HEAD"` at line 116. Do NOT use
  `git diff <first>^..<last>` — it is semantically wrong for non-contiguous
  commits (see AD-2 in team-plan.md, research Section B).
- **Globs are passed literally to git**. yq emits one path per line; shell
  splits them into positional arguments. Ensure globs are not quoted when
  passed to git (git expands them itself under `--`).
- **Rename tracking out of scope**. `--follow` is single-path only and cannot
  be combined with multi-glob queries. Documented in AC; do not attempt
  workarounds.
- **check-artifacts.sh pattern reuse (research Section A)**. The yq query
  idiom is already proven:
  ```sh
  yq -r '.deliverables[] | select(.name == env(name)) | .file_ownership[]?' \
    "$definition_file"
  ```
  Reuse verbatim; do not invent a new query.
- **Resolver adoption is one-line per site**. Each of lines 79, 280, 446, 631
  becomes:
  ```sh
  provider=$(resolve_config_value cross_model.provider) || provider=""
  ```
  The existing "no provider configured" skip check remains; only the *read*
  changes.
- **diff_scope capture**. Collect `commits[]` via
  `git log --format=%H --no-merges "${base}..HEAD" -- <globs>`. Collect
  `files_matched[]` via `git log --name-only --format= --no-merges
  "${base}..HEAD" -- <globs> | sort -u`.
- **Sandbox**. `tests/integration/test-cross-model-scope.sh` uses
  `setup_sandbox` from wave-1's `tests/integration/lib/sandbox.sh`. No live
  worktree mutation.
- **POSIX sh**. Preserve existing shebang; shell style unchanged.

## Dependencies

- **Upstream deliverables**:
  - `test-isolation-guard` (wave-1): `setup_sandbox` helper; sandbox guard in
    `run-all.sh`.
  - `xdg-config-consumer-wiring` (wave-2): provides `resolve_config_value`
    adoption pattern and ensures `cross_model.provider` resolves through the
    three-tier chain (common.sh is untouched by this deliverable).
- **Scripts/libs consumed**:
  - `bin/frw.d/lib/common.sh` — `resolve_config_value` (read-only dependency).
  - `bin/frw.d/scripts/check-artifacts.sh:77-106` — reference pattern for
    file_ownership yq query.
- **Tools**: `yq`, `git` (log/diff), `jq` (for review record writing).

## File Ownership

Per plan.json:
- `bin/frw.d/scripts/cross-model-review.sh`
- `tests/integration/test-cross-model-scope.sh`
