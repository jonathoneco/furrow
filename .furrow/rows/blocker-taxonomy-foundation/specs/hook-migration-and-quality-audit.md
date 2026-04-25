# Spec: hook-migration-and-quality-audit

> See `specs/shared-contracts.md` for cross-cutting decisions; that document overrides any conflicting detail here.

**Wave**: 3 (depends on `normalized-blocker-event-and-go-emission-path` — D2)
**Specialist**: shell-specialist
**Source**: definition.yaml lines 50-63; team-plan.md "Wave 3"; research/hook-audit.md (full)

This deliverable reduces every emit-bearing hook in `bin/frw.d/hooks/` to a thin
shell shim that does nothing but translate host events into normalized
`BlockerEvent` JSON, hand them to the Go backend (`furrow guard <event-type>`)
landed by D2, and translate the resulting canonical `BlockerEnvelope` into the
host's exit-code / stdout convention. Domain logic — condition checks, message
construction, severity decisions, glob matching — moves into Go. Quality
findings from `research/hook-audit.md` Section 8 are tightened or formally
deferred during the same pass.

The locked plan decisions from D3 planning are non-negotiable for this spec:

- **10 hooks migrated**, **`gate-check.sh` deleted** (dead code per audit §2.2).
- Every shim is **≤30 lines of executable shell** (definition below in
  Acceptance Criteria §2.1).
- Every helper used by **≥2 shims** lives once in `bin/frw.d/lib/` — no
  cut-and-paste across hooks.
- **No conditional emission of non-canonical free-text strings** anywhere in
  any shim. The only stderr/stdout output is what the Go backend printed,
  forwarded verbatim.
- Audit report lands **row-local** at
  `.furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md`.
- **Fallback thresholds** (constraints §131): `script-guard.sh` Go port may
  defer if implement time exceeds **4 hours**; `work-check.sh` `updated_at`
  side-effect split may defer if implement time exceeds **2 hours**. A
  deferral lands a named TODO in `.furrow/almanac/todos.yaml` **before W4
  starts** so D4's parity-test surface is stable.

---

## Interface Contract

### 1. Canonical migrated shim — exact 4-line skeleton

Every migrated shim MUST conform to this template. The body of the
`hook_<name>()` function is exactly four executable lines (excluding shebang,
comments, and the library `source` line, which are not counted toward the
30-line budget per §2.1). The shape is:

```sh
# shellcheck shell=sh
# <name>.sh — <one-line purpose>
#
# Hook: <Claude PreToolUse|Stop|pre-commit dispatcher matcher>
# Returns: 0 (allow) | 1 (usage) | 2 (block) | 3 (validation)

# shellcheck source=../lib/common-minimal.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
# shellcheck source=../lib/blocker_emit.sh disable=SC1091
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"

hook_<name>() {
  input="$(cat)"                                    # (1) capture host stdin
  event_json="$(<adapter>_to_blocker_event "$input" "<event-type>")" \
    || return 1                                     # (2) normalize → BlockerEvent
  envelope="$(emit_canonical_blocker "$event_json")" \
    || return $?                                    # (3) call Go backend
  forward_envelope_to_host "$envelope"              # (4) translate exit + stdout
}
```

Where:

- `<adapter>_to_blocker_event` is one of three normalizers landed by D2 in
  `bin/frw.d/lib/blocker_emit.sh`:
  - `claude_tool_input_to_event` — for PreToolUse(Write|Edit|Bash) hooks.
  - `claude_stop_to_event` — for Stop hooks (no `tool_input` field).
  - `precommit_diff_to_event` — for git pre-commit hooks (input is the
    staged-file list captured from `git diff --cached --raw`).
- `emit_canonical_blocker` invokes `furrow guard <event-type> --json` via
  subprocess, passing the normalized JSON on stdin. Exit code 0 = no block,
  exit code 2 = block, exit code 1 = usage error, exit code 3 = validation
  error. Stdout is either empty (no condition triggered) or a single canonical
  `BlockerEnvelope` JSON object.
- `forward_envelope_to_host` is the canonical translator from
  `bin/frw.d/lib/blocker_emit.sh`. It reads the `severity` and `message`
  fields from the envelope, prints the rendered message to stderr, and exits
  with the correct host exit code (block ⇒ 2 for Claude, 1 for git
  pre-commit; warn ⇒ 0 with stderr line; empty ⇒ silent return 0). The mapping
  table is owned by D2; D3 only calls the helper.

The four-line body is the **invariant**: shims that need additional steps
(e.g., reading `tool_name` to dispatch on Write vs Edit) MUST push that
dispatch into the normalizer, not into the shim. If a hook genuinely needs a
fifth executable line, it indicates the normalizer is incomplete and D2's
helper must be extended — D3 does not paper over the gap with shell logic.

### 2. Per-hook target shape

The 10 migrated hooks each target the canonical event-type listed below.
Event-type names are the **suggested** strings from `research/hook-audit.md`
§3 — D2 finalizes the set in `schemas/blocker-event.yaml` and D3 references
the finalized names. If D2 renames an event-type, D3 updates accordingly.

| # | Shim | Hook surface | Event type | Stdin keys (Claude/host shape) | Backend emit-site | Block exit | Notes |
|---|------|--------------|------------|--------------------------------|-------------------|-----------:|-------|
| 1 | `state-guard.sh` | PreToolUse(Write\|Edit) | `pre_write_state_json` | `tool_name`, `tool_input.file_path` (alias `path`) | `internal/cli/guard/state_guard.go::EvaluateStateGuard` | 2 | Mechanical. Audit §2.7. |
| 2 | `verdict-guard.sh` | PreToolUse(Write\|Edit) | `pre_write_verdict` | same as #1 | `internal/cli/guard/verdict_guard.go::EvaluateVerdictGuard` | 2 | Mechanical. Audit §2.10. |
| 3 | `pre-commit-bakfiles.sh` | git pre-commit | `pre_commit_paths` (variant `bakfiles`) | staged paths (no JSON; normalizer wraps) | `internal/cli/guard/precommit_paths.go::EvaluatePrecommitPaths` | 1 | Mechanical. Audit §2.3. |
| 4 | `pre-commit-script-modes.sh` | git pre-commit | `pre_commit_script_modes` | staged paths + `git ls-files -s` index modes | `internal/cli/guard/precommit_modes.go::EvaluatePrecommitModes` | 1 | Mechanical. Audit §2.4. `head -n1` removed (audit §8). |
| 5 | `pre-commit-typechange.sh` | git pre-commit | `pre_commit_typechange` | `git diff --cached --raw` rows | `internal/cli/guard/precommit_typechange.go::EvaluatePrecommitTypechange` | 1 | Mechanical. Audit §2.5. Three `awk` invocations collapsed (audit §8). |
| 6 | `correction-limit.sh` | PreToolUse(Write\|Edit) | `pre_write_correction_limit` | `tool_name`, `tool_input.file_path` | `internal/cli/guard/correction_limit.go::EvaluateCorrectionLimit` (reads state.json + plan.json + furrow.yaml in Go) | 2 | Non-trivial. Audit §2.1. Glob matching moves to Go's doublestar. |
| 7 | `script-guard.sh` | PreToolUse(Bash) | `pre_bash_internal_script` | `tool_name`, `tool_input.command` | `internal/cli/guard/script_guard.go::EvaluateScriptGuard` calls `internal/cli/shellparse/StripDataRegions` | 2 | Non-trivial heavy. Audit §2.6. **Deferral candidate** — see §5. |
| 8 | `stop-ideation.sh` | Stop | `stop_ideation_completeness` | row context resolved by normalizer | `internal/cli/guard/stop_ideation.go::EvaluateStopIdeation` (reuses existing `validate definition` Go validator) | 2 | Non-trivial. Audit §2.8. |
| 9 | `validate-summary.sh` | Stop | `stop_summary_validation` | row context | `internal/cli/guard/stop_summary.go::EvaluateStopSummary` (table-driven required-sections per step) | 2 | Non-trivial. Audit §2.9. Splits into `summary_section_missing` + `summary_section_empty` codes per audit §3. |
| 10 | `work-check.sh` | Stop | `stop_work_check` | row context (per active row) | `internal/cli/guard/stop_work_check.go::EvaluateStopWorkCheck` (warn-only) | 0 (warn) | Non-trivial. Audit §2.11. **Side-effect split** — see §5. |

`gate-check.sh` is **deleted** (no migration target). Settings.json line 18
(`"frw hook gate-check"`) is removed in the same change.

### 3. Where domain logic lives in Go (for non-trivial hooks)

For each non-trivial hook the spec freezes the Go file + function names so
D3 reviewer and D4 test-engineer can locate the implementation. D2 lands
empty stubs; D3 fills them in (or D2 fills them — coordinate at wave-2/3
boundary).

| Hook | Go package | Go file | Top-level function |
|------|-----------|---------|--------------------|
| `correction-limit.sh` | `internal/cli/guard` | `correction_limit.go` | `EvaluateCorrectionLimit(ctx, event BlockerEvent) (*BlockerEnvelope, error)` |
| `script-guard.sh` | `internal/cli/guard` + `internal/cli/shellparse` | `script_guard.go` + `shellparse/strip.go` | `EvaluateScriptGuard(ctx, event)`; helper `StripDataRegions(cmd string) string` |
| `stop-ideation.sh` | `internal/cli/guard` | `stop_ideation.go` | `EvaluateStopIdeation(ctx, event)` (delegates to existing `internal/cli/validate.ValidateDefinition`) |
| `validate-summary.sh` | `internal/cli/guard` | `stop_summary.go` | `EvaluateStopSummary(ctx, event)`; helper `RequiredSections(step Step) []SectionRule` |
| `work-check.sh` | `internal/cli/guard` | `stop_work_check.go` | `EvaluateStopWorkCheck(ctx, event)` (returns slice of warn-severity envelopes) |

The `updated_at` timestamp side-effect currently in `work-check.sh:71` is
**not** carried into Go. It is split out per §5.

### 4. Helpers to land in `bin/frw.d/lib/`

D3 extracts the following helpers into `bin/frw.d/lib/blocker_emit.sh` (some
may already exist from D2). Each helper has exactly one canonical
implementation:

| Helper | Audit ref | Used by shims | Purpose |
|--------|-----------|---------------|---------|
| `claude_tool_input_to_event` | new (D3) | state-guard, verdict-guard, correction-limit, script-guard | Wraps `jq -r '.tool_input.file_path // .tool_input.path // ""'` (or `.command` for Bash) into normalized `BlockerEvent` JSON with `event_type`, `target_path`/`command`, `step`, `row` resolved. |
| `claude_stop_to_event` | new (D3) | stop-ideation, validate-summary, work-check | Resolves active-row context via `find_focused_row` / iteration over `.furrow/rows/*/state.json`, emits one `BlockerEvent` per active row. |
| `precommit_diff_to_event` | audit §2.3-2.5 (`precommit_init` was the original helper name) | pre-commit-bakfiles, pre-commit-script-modes, pre-commit-typechange | Resolves `_git_root` via `git rev-parse --show-toplevel`, captures staged paths + index modes via `git diff --cached --raw` once, emits a single `BlockerEvent` payload covering the full staged set. |
| `emit_canonical_blocker` | D2 deliverable | all 10 | Subprocess call to `furrow guard <event-type> --json`. Stdin = normalized event JSON. Stdout = envelope (or empty). Exit code propagated. |
| `forward_envelope_to_host` | new (D3) | all 10 | Reads severity from envelope; prints `message` to stderr; returns the host's appropriate exit code (Claude block=2, pre-commit block=1, warn=0). |

**Helper extraction rule**: any inline pattern that appears in two or more
shims after D3 lands MUST be moved to `bin/frw.d/lib/`. The reviewer enforces
this via the test scenario "helper extraction completeness" (§Test Scenarios
test G).

---

## Acceptance Criteria (Refined)

The five definition.yaml D3 ACs are restated below in testable form. AC labels
match their position in `definition.yaml` lines 53-58.

### AC-1: Routing through Go emission path

**(definition.yaml:54)** Every one of the 10 emit-bearing hooks invokes the
Go backend via subprocess for emission. Verified by:

- For each shim under `bin/frw.d/hooks/{state-guard,verdict-guard,pre-commit-bakfiles,pre-commit-script-modes,pre-commit-typechange,correction-limit,script-guard,stop-ideation,validate-summary,work-check}.sh`:
  - `grep -E '(furrow guard|emit_canonical_blocker)' <shim>` returns at least
    one match.
  - `grep -cE '^\s*(echo|printf).*>&2' <shim>` returns `0` (no direct stderr
    emission inside the hook function — output is owned by
    `forward_envelope_to_host`).
- `bin/frw.d/hooks/gate-check.sh` does not exist on disk.
- `.claude/settings.json` does not contain the literal string `gate-check`.

### AC-2.1: Per-shim ≤30 executable line count

**(definition.yaml:56)** Each migrated shim is at most **30 lines of
executable shell**, where "executable line" is defined as:

> A line that, after stripping leading whitespace, is non-empty AND does not
> begin with `#` AND is not solely a `. "...common-minimal.sh"` or
> `. "...blocker_emit.sh"` source-library invocation AND is not the shebang.

The `.shellcheck` directive comments (`# shellcheck source=...`,
`# shellcheck disable=...`, `# shellcheck shell=sh`) are **comment lines** and
do not count.

The reference counter is:

```sh
count_exec_lines() {
  awk '
    /^[[:space:]]*$/             { next }      # blank
    /^[[:space:]]*#/             { next }      # comment
    /^#!/                        { next }      # shebang (also matches first line, redundant)
    /^[[:space:]]*\.[[:space:]]+.*\/(common-minimal|blocker_emit|common)\.sh"?[[:space:]]*$/ { next }
    { count++ }
    END                          { print count }
  ' "$1"
}
```

A shim that produces `count_exec_lines >= 31` fails this AC.

### AC-2.2: No domain logic in shell

**(definition.yaml:55)** A shim contains **no domain logic**. Concretely the
following constructs are forbidden inside the `hook_<name>()` function body
of a migrated shim:

- **Forbidden #1**: String comparisons against semantic values. Any of:
  - `[ "$x" = "implement" ]`, `[ "$x" = "ideate" ]`, `[ "$x" = "supervised" ]`,
    `[ "$step" != "..." ]`, `[ "$verdict" = "out_of_scope" ]`, etc. — any
    equality check whose right-hand side is a step name, gate-policy name,
    severity name, verdict, or other semantic enumeration drawn from the
    canonical taxonomy. (Comparing to the empty string `""` to test for
    presence is allowed.)
- **Forbidden #2**: `case "$path" in` patterns whose alternatives are
  semantic path globs (`*/state.json`, `*/gate-verdicts/*`,
  `bin/*.bak`, `*/definition.yaml`, etc.). The single allowed `case` is on
  envelope severity (`block|warn|silent`) inside `forward_envelope_to_host`,
  which lives in `lib/`, not in a shim.
- **Forbidden #3**: Conditional message construction. Any of:
  - `echo "<literal message text>" >&2`,
  - `printf '...' "$x" >&2`,
  - assembling an error string into a variable then printing it,
  - heredoc into stderr (`cat <<EOF >&2`),
  inside the `hook_<name>()` body. The only stderr output permitted is what
  `forward_envelope_to_host` (in `lib/`) writes after reading the envelope.
- **Forbidden #4**: Reading `state.json`, `plan.json`, `definition.yaml`,
  `furrow.yaml`, `summary.md`, or any project file via `jq` / `yq` / `cat` /
  `grep` inside the shim body. File reads happen in Go (or in the normalizer
  helper, which is in `lib/` and shared).

The reviewer scans each shim with these grep patterns:

```sh
# Forbidden #1 (semantic enum compare)
grep -nE '(\[|test) [^]]*"(implement|ideate|research|plan|spec|decompose|review|supervised|delegated|autonomous|out_of_scope|prechecked|block|warn)"' <shim>
# Forbidden #2 (semantic path case)
grep -nE 'case .* in' <shim> | grep -vE 'case .*severity'
# Forbidden #3 (literal stderr message)
grep -nE '(echo|printf|cat).*>&2' <shim>
# Forbidden #4 (project-file read)
grep -nE '(jq|yq|cat|grep)\b.*\.(json|yaml|md)' <shim>
```

Any non-empty match in a migrated shim's `hook_<name>()` body fails this AC.
Matches inside `lib/` files are out of scope.

### AC-2.3: Helper extraction completeness

**(definition.yaml:56)** Every parsing pattern duplicated across two or more
migrated shims is extracted into `bin/frw.d/lib/`. The reviewer's check:

- For each pair of shim files `(a.sh, b.sh)`, run:
  ```sh
  comm -12 <(grep -oE '\bjq -r [^|]*' a.sh | sort -u) \
           <(grep -oE '\bjq -r [^|]*' b.sh | sort -u)
  ```
  The result must be empty (no shared `jq -r '...'` invocation appears in
  more than one shim). Same check for `yq -r '...'`, `git rev-parse`, and
  `git diff --cached`. Any non-empty intersection is a finding.
- The five helpers listed in Interface Contract §4 all exist and are sourced
  by their respective shim sets.

### AC-3: No conditional non-canonical free-text

**(definition.yaml:56)** No migrated shim emits a free-text string
conditioned on input. This is a stronger restatement of AC-2.2 forbidden #3:
the shim body has zero string literals other than:

- the event-type identifier passed to the normalizer,
- shell control flow (`return 0`, `return $?`, etc.).

Any literal string longer than 30 characters inside `hook_<name>()` body is
flagged as a likely message-construction violation and fails the AC unless
the reviewer can show it is a path glob argument to a helper.

### AC-4: Audit report at row-local path

**(definition.yaml:57)** The file
`.furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md`
exists and contains:

- a **per-hook table** with the columns specified in Implementation Notes §4
  (name, pre-lines, post-lines, helpers added, quality findings tightened,
  complexity classification confirmed, deferred Y/N, deferral rationale if
  Y),
- one row per migrated hook (10 rows) plus one row for `gate-check.sh` (with
  status "deleted"),
- a "Quality Findings Resolution" subsection that walks every entry from
  `research/hook-audit.md` §8 (the 11 findings) and marks each as `RESOLVED`,
  `MOVED-TO-GO`, or `DEFERRED-WITH-TODO` (no `OPEN` entries permitted at
  D3 close),
- a "Helpers Extracted" subsection listing each new entry in
  `bin/frw.d/lib/blocker_emit.sh` with line ranges and consumer shims.

### AC-5: Deferrals declared with TODO

**(definition.yaml:58, constraints:131)** Any hook deferred from full
migration is named explicitly in the audit report with:

- a TODO entry in `.furrow/almanac/todos.yaml` (added via
  `alm todo add` — never direct YAML edit),
- the deferral rationale tied to one of the two pre-approved threshold
  conditions (`script-guard.sh` Go port >4h **OR** `work-check.sh`
  `updated_at` split >2h),
- the TODO landed **before W4 (D4 coverage-and-parity-tests) starts**.

**Default position**: migrate all 10 hooks. Deferral is the exception and
requires the threshold trip-wire to be tripped on a real implementation
attempt — not pre-emptively skipped.

---

## Test Scenarios

The seven scenarios below are the minimum verification surface for D3. They
are run by the reviewer (and by D4's parity test for those that overlap).
Each scenario names its AC reference.

### Scenario A — `gate-check.sh` deletion reflected in callers

- **Verifies**: AC-1.
- **WHEN**: D3 implementation completes.
- **THEN**:
  - `bin/frw.d/hooks/gate-check.sh` does not exist.
  - `.claude/settings.json` contains zero occurrences of `gate-check` (line 18
    of the pre-D3 file is removed).
  - `bin/frw` `frw_hook` dispatch path does not error when called with any
    other hook name (regression check).
- **Verification**:
  ```sh
  test ! -e bin/frw.d/hooks/gate-check.sh
  ! grep -q gate-check .claude/settings.json
  frw hook state-guard < tests/integration/fixtures/blocker-events/state_json_direct_write/claude.json
  ```

### Scenario B — `state-guard.sh` mechanical migration produces canonical envelope

- **Verifies**: AC-1, AC-2.1, AC-2.2, AC-3.
- **WHEN**: a Claude-shape PreToolUse(Write) input naming
  `.furrow/rows/foo/state.json` as `tool_input.file_path` is piped to
  `frw hook state-guard`.
- **THEN**:
  - Exit code is 2.
  - Stderr contains the canonical message rendered from
    `state_json_direct_write` taxonomy entry (NOT the legacy literal
    `"state.json is Furrow-exclusive — use frw update-state"` if D1 chose a
    different message_template — D3 does not pin the wording, only the code).
  - Stdout is empty (envelope flows through stderr per host convention).
- **Verification**:
  ```sh
  printf '%s' '{"tool_name":"Write","tool_input":{"file_path":".furrow/rows/foo/state.json"}}' \
    | frw hook state-guard >/dev/null 2>err
  test "$?" = "2"
  grep -q '"code":"state_json_direct_write"' err || \
    grep -qE 'state\.json' err  # accept rendered prose, but envelope code under --debug
  ```

### Scenario C — `script-guard.sh` migration: awk parser landed in Go OR deferred via TODO

- **Verifies**: AC-1, AC-5, plus the §5 deferral protocol.
- **WHEN**: D3 implementation closes.
- **THEN**: exactly one of the following is true:
  - **(a) Migrated**: `internal/cli/shellparse/strip.go` exists and exports
    `StripDataRegions(string) string`; `internal/cli/guard/script_guard.go`
    exports `EvaluateScriptGuard`; `bin/frw.d/hooks/script-guard.sh` is ≤30
    executable lines and contains no `awk` invocation; piping a Bash
    `tool_input.command` of `bin/frw.d/scripts/foo.sh` through the shim
    returns exit 2.
  - **(b) Deferred**: `.furrow/almanac/todos.yaml` contains an entry with
    `id: script-guard-go-parser-port` (or the renamed final ID), and
    `bin/frw.d/hooks/script-guard.sh` is unchanged from its pre-D3 state
    EXCEPT for cosmetic changes covered by audit §8 quality findings. The
    audit report `hook-audit-final.md` row for `script-guard.sh` has
    `Deferred: Y` and the rationale "Go port exceeded 4h threshold".
- **Verification**:
  ```sh
  if [ -f internal/cli/shellparse/strip.go ]; then
    # case (a)
    test "$(count_exec_lines bin/frw.d/hooks/script-guard.sh)" -le 30
    ! grep -q awk bin/frw.d/hooks/script-guard.sh
  else
    # case (b)
    grep -q 'script-guard-go-parser-port' .furrow/almanac/todos.yaml
    grep -q 'Deferred: Y' .furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md
  fi
  ```

### Scenario D — `work-check.sh` warn-path produces `severity: warn`, not block

- **Verifies**: AC-1, AC-2.2 (warn semantics flow from Go), AC-5 (side-effect
  split decision recorded).
- **WHEN**: a Stop event with an active row whose summary.md is missing
  `Open Questions` is piped to `frw hook work-check`.
- **THEN**:
  - Exit code is **0** (warn does not block at session boundary).
  - Stderr contains a rendered message from the
    `summary_section_missing_warn` (or D1's final code name) taxonomy entry.
  - The envelope JSON (when invoked with `furrow guard --debug`) has
    `"severity":"warn"`.
  - **Side-effect check**: `state.json.updated_at` is **NOT** modified by
    `work-check.sh` invocation. (If the side-effect split is deferred, the
    audit report row for `work-check.sh` declares `Deferred: Y` for the
    `updated_at` split, AND the parity test scenario is updated to assert
    the exact opposite.)
- **Verification**:
  ```sh
  before=$(jq -r .updated_at .furrow/rows/<test-row>/state.json)
  echo '{"hook_event_name":"Stop"}' | frw hook work-check >/dev/null 2>err
  test "$?" = "0"
  after=$(jq -r .updated_at .furrow/rows/<test-row>/state.json)
  if grep -q 'work-check-side-effect-split' .furrow/almanac/todos.yaml; then
    : # deferred — side effect still present, no assertion
  else
    test "$before" = "$after"  # no mutation
  fi
  grep -qE '(missing|empty)' err
  ```

### Scenario E — Shim line-count enforcement (31-line shim fails)

- **Verifies**: AC-2.1.
- **WHEN**: a synthetic 31-executable-line shim is dropped into
  `bin/frw.d/hooks/` during a CI / lint pass.
- **THEN**: the line-count check (`tests/integration/check-shim-budget.sh`,
  authored as part of D3 deliverable) exits non-zero and names the offending
  file.
- **Verification**:
  ```sh
  cp bin/frw.d/hooks/state-guard.sh /tmp/oversized.sh
  for i in $(seq 1 25); do echo "  : noop  # line $i" >> /tmp/oversized.sh; done
  cp /tmp/oversized.sh bin/frw.d/hooks/_test-oversized.sh
  ! tests/integration/check-shim-budget.sh
  rm bin/frw.d/hooks/_test-oversized.sh
  ```
  The script `check-shim-budget.sh` is owned by D3 (lives under
  `tests/integration/`) and is invoked by `run-all.sh`.

### Scenario F — Anti-cheat: every shim grep-matches `furrow guard` (or `emit_canonical_blocker`)

- **Verifies**: AC-1.
- **WHEN**: the reviewer runs the inventory check against `bin/frw.d/hooks/*.sh`.
- **THEN**: every migrated shim contains the literal substring
  `emit_canonical_blocker` (the helper that itself calls `furrow guard`); no
  migrated shim contains an inlined canonical envelope JSON string (which
  would let it pass parity tests by mimicking Go output).
- **Verification**:
  ```sh
  for f in bin/frw.d/hooks/state-guard.sh bin/frw.d/hooks/verdict-guard.sh \
           bin/frw.d/hooks/pre-commit-bakfiles.sh bin/frw.d/hooks/pre-commit-script-modes.sh \
           bin/frw.d/hooks/pre-commit-typechange.sh bin/frw.d/hooks/correction-limit.sh \
           bin/frw.d/hooks/script-guard.sh bin/frw.d/hooks/stop-ideation.sh \
           bin/frw.d/hooks/validate-summary.sh bin/frw.d/hooks/work-check.sh; do
    grep -q emit_canonical_blocker "$f" || { echo "MISSING: $f"; exit 1; }
    ! grep -qE '"code"[[:space:]]*:[[:space:]]*"' "$f" || { echo "INLINED ENVELOPE: $f"; exit 1; }
  done
  ```
  This anti-cheat is reasserted by D4's parity test at a different layer
  (constraints from definition.yaml:71); D3 lands the static grep version,
  D4 lands the runtime interception version.

### Scenario G — Audit report exists with all 10 entries

- **Verifies**: AC-4.
- **WHEN**: D3 implementation closes.
- **THEN**: `.furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md`:
  - exists,
  - contains a markdown table whose body has at least 11 rows (10 migrated +
    1 deleted `gate-check.sh`),
  - every row in `research/hook-audit.md` Section 8 (quality findings — 11
    rows) is referenced once in the "Quality Findings Resolution"
    subsection,
  - the table columns match the schema in Implementation Notes §4.
- **Verification**:
  ```sh
  test -f .furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md
  rows=$(awk '/^\|/ && !/^\|---/ { c++ } END { print c }' \
    .furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md)
  test "$rows" -ge 12  # 1 header + 11 data rows
  for hook in correction-limit gate-check pre-commit-bakfiles pre-commit-script-modes \
              pre-commit-typechange script-guard state-guard stop-ideation \
              validate-summary verdict-guard work-check; do
    grep -q "$hook" .furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md || \
      { echo "MISSING ROW: $hook"; exit 1; }
  done
  ```

---

## Implementation Notes

### 1. Sequenced execution

D3 implements in this order. Each step ends with shellcheck clean and the
relevant test scenarios green before the next step starts.

#### Step 1 — Delete `gate-check.sh` (audit §2.2, §8)

- `git rm bin/frw.d/hooks/gate-check.sh`.
- Edit `.claude/settings.json`: remove the line
  `{ "type": "command", "command": "frw hook gate-check" }` (line 18 of the
  pre-D3 file). Adjust trailing comma on the preceding entry if needed.
- Edit `install.sh` and `bin/frw.d/install.sh` if they reference
  `gate-check` in their hook-installation manifest (search:
  `grep -rn gate-check install.sh bin/frw.d/install.sh`).
- Run `tests/integration/run-all.sh` — no test should reference
  `gate-check`. (If one does, the test was wrong; remove the reference.)
- Run Scenario A.

This step is the smallest and validates the workflow before the first
migration.

#### Step 2 — Confirm D2's helpers exist

- `test -f bin/frw.d/lib/blocker_emit.sh`. If not, escalate to wave-2 owner
  (D3 cannot proceed without `emit_canonical_blocker` and the three
  normalizers).
- Read the helper signatures and document them in `hook-audit-final.md`
  "Helpers Extracted" subsection (the helpers that came from D2 are listed
  there too, with attribution).

#### Step 3 — Migrate the 5 mechanical hooks

In this order, smallest first to build confidence (audit §7 Phase B):

1. `state-guard.sh` (was 12 lines → target ~6 in body, ≤30 total).
2. `verdict-guard.sh` (was 12 lines → target ~6 in body).
3. `pre-commit-bakfiles.sh` (was 19 lines → target ≤25, includes `precommit_diff_to_event` call).
4. `pre-commit-typechange.sh` (was 30 lines → target ≤25; collapse the
   three-`awk` invocations from audit §2.5 finding #2 into the normalizer
   helper).
5. `pre-commit-script-modes.sh` (was 25 lines → target ≤25; drop the
   `head -n1` from audit §2.4 finding #1).

After each shim is migrated, run Scenarios B and F locally for that shim.

#### Step 4 — Extract / verify helpers

After the mechanical wave, audit `bin/frw.d/lib/blocker_emit.sh` to confirm
no shim has reintroduced an inline `jq -r` or `git diff --cached` pattern
that should be in `lib/`. Run AC-2.3's pairwise `comm` check.

#### Step 5 — Migrate the 5 non-trivial hooks

One at a time. After each, run shellcheck + the relevant test scenarios.

1. **`stop-ideation.sh`** (audit §2.8) — easiest non-trivial because the
   existing Go `validate definition` command already does the work. The
   migration is mostly: remove the in-shell `yq -r` field reads, hand off to
   `furrow guard stop_ideation_completeness`. ~1.5h budget.
2. **`validate-summary.sh`** (audit §2.9) — Go side gets a real markdown
   parser + table-driven required-sections per step (`RequiredSections(step)`
   in `internal/cli/guard/stop_summary.go`). Splits into two codes per
   audit §3. ~2h budget.
3. **`correction-limit.sh`** (audit §2.1) — Go side reads state.json,
   plan.json, furrow.yaml itself. Glob matching uses doublestar (audit §2.1
   quality finding). ~2-3h budget.
4. **`work-check.sh`** (audit §2.11) — **side-effect split first**. Move
   `frw_update_state` (line 71 of pre-D3 file) into a new dedicated Stop hook
   `bin/frw.d/hooks/touch-active-rows.sh` OR into `rws transition` epilogue
   — owner's choice, document in audit report. THEN migrate the warning
   emission to Go. **Threshold**: if the side-effect split alone exceeds
   2h, defer per §5 below.
5. **`script-guard.sh`** (audit §2.6) — last because it's the heaviest. The
   Go port of `shell_strip_data_regions` is ~100 LOC awk → ~80 LOC Go with
   table-driven tests. **Threshold**: if total time on this hook exceeds 4h,
   defer per §5.

### 2. Concrete fallback decision criteria

The two pre-approved deferral candidates are `script-guard.sh` (Go parser
port) and `work-check.sh` (`updated_at` side-effect split). The decision
rule:

- **Trigger**: implementer has spent the threshold time (4h or 2h) on the
  hook AND a green test scenario does not yet exist.
- **Action**:
  1. Stop work on that hook.
  2. Run `alm todo add` with the YAML body in audit §6 (script-guard) or
     audit §6 (work-check side-effect). Both YAMLs are already drafted in
     `research/hook-audit.md`.
  3. Update `hook-audit-final.md` row for the hook: `Deferred: Y`, paste
     rationale.
  4. **Do this BEFORE D4 starts** — D4's parity-test fixtures need to know
     which codes are skipped (`fixtures/blocker-events/<code>/SKIP.txt` per
     definition.yaml:69 "explicitly skipped with logged reason").
  5. Notify the row coordinator that D3 is closing with deferral; coordinate
     with D4 owner before they begin fixture authoring.

- **Anti-criteria**: deferral is **NOT** permitted for any of the other 8
  hooks. Mechanical hooks have no deferral path. The 3 non-trivial hooks
  other than script-guard and work-check (`stop-ideation`,
  `validate-summary`, `correction-limit`) must migrate fully — their audit
  classification is non-trivial but bounded (≤3h each).

### 3. Pre-implement checklist

Before starting Step 1, verify:

- [ ] D2 deliverable `normalized-blocker-event-and-go-emission-path` is
      marked complete.
- [ ] `furrow guard` accepts at least one of the 10 event types end-to-end
      (e.g., `furrow guard pre_write_state_json --json` returns valid
      envelope JSON for a sample input). If only stubs exist, escalate.
- [ ] `bin/frw.d/lib/blocker_emit.sh` exists and exports
      `emit_canonical_blocker`. If it exports `furrow_guard_emit` or
      another name, update this spec's Interface Contract §1 reference.
- [ ] D1 (canonical-blocker-taxonomy) is complete and the new code names
      from audit §3 are in `schemas/blocker-taxonomy.yaml`. The shim
      passes the event_type to Go; Go does the code lookup.

### 4. Audit report content (`hook-audit-final.md`)

The row-local audit report has this structure:

```markdown
# Hook Migration — Final Audit

**Row**: `blocker-taxonomy-foundation`
**Deliverable**: `hook-migration-and-quality-audit`
**Closed**: <date>
**Predecessor**: research/hook-audit.md (research-step output)

## 1. Per-hook migration table

| Hook | Pre-lines | Post-lines | Helpers added/used | Quality findings tightened | Complexity (confirmed) | Deferred | Deferral rationale |
|------|----------:|-----------:|--------------------|----------------------------|------------------------|:--------:|--------------------|
| correction-limit.sh | 57 | <N> | claude_tool_input_to_event, emit_canonical_blocker, forward_envelope_to_host | glob unquoting (§2.1 finding #1) → moved to Go doublestar | non-trivial | N | — |
| gate-check.sh | 4 | (deleted) | — | dead code (§2.2) | delete | N | — |
| pre-commit-bakfiles.sh | 19 | <N> | precommit_diff_to_event, emit_canonical_blocker, forward_envelope_to_host | log_warning fallback shim (§2.3 finding) → eliminated | mechanical | N | — |
| pre-commit-script-modes.sh | 25 | <N> | precommit_diff_to_event, ... | head -n1 redundant (§2.4 finding #1) → dropped | mechanical | N | — |
| pre-commit-typechange.sh | 30 | <N> | precommit_diff_to_event, ... | three awks combined (§2.5 finding #1) | mechanical | N | — |
| script-guard.sh | 141 | <N or 141> | claude_tool_input_to_event (command variant) | awk parser → Go shellparse pkg (§2.6 finding) | non-trivial heavy | <Y/N> | <rationale if Y> |
| state-guard.sh | 12 | <N> | claude_tool_input_to_event, ... | echo→printf (§2.7 finding #2) | mechanical | N | — |
| stop-ideation.sh | 45 | <N> | claude_stop_to_event, ... | dead "null" check (§2.8 finding #1) → dropped | non-trivial | N | — |
| validate-summary.sh | 42 | <N> | claude_stop_to_event, ... | per-section awk fork (§2.9 finding #2) → single Go pass | non-trivial | N | — |
| verdict-guard.sh | 12 | <N> | claude_tool_input_to_event, ... | echo→printf (§2.10 finding) | mechanical | N | — |
| work-check.sh | 50 | <N> | claude_stop_to_event, ... | timestamp side-effect split (§2.11 finding #1) | non-trivial | <Y/N> | <rationale if Y> |

## 2. Quality findings resolution

(Walks all 11 rows of research/hook-audit.md §8 with status RESOLVED /
MOVED-TO-GO / DEFERRED-WITH-TODO. No OPEN entries.)

## 3. Helpers extracted

| Helper | Location | Lines | Consumers |
|--------|----------|------:|-----------|
| ... | bin/frw.d/lib/blocker_emit.sh:LL-LL | NN | <list> |

## 4. Deferred items

(One subsection per deferred hook with TODO id and link to almanac entry.
Empty if no deferrals — state explicitly "No deferrals — all 10 hooks fully
migrated".)
```

### 5. Pattern reference: already-canonical hooks

`bin/frw.d/hooks/ownership-warn.sh` (lines 25-77) and
`bin/frw.d/hooks/validate-definition.sh` are the closest existing pattern
references — both are non-trivial hooks that delegate verdict computation to
a Go binary (`furrow validate ownership` / `furrow validate definition`) and
keep shell to a thin translator. D3's migrated shims should look like
`ownership-warn.sh` simplified further: the `extract_row_from_path` /
`find_focused_row` resolution that `ownership-warn.sh:34-50` does inline is
moved into `claude_tool_input_to_event` so individual shims don't carry it.

### 6. Hook surface preservation

The Claude PreToolUse / Stop / pre-commit hook surface is preserved exactly
— D3 does NOT change `.claude/settings.json` matchers, the
`bin/frw.d/install.sh` registration, or the `frw hook <name>` dispatch
contract. Only the implementation of `hook_<name>()` changes. The single
exception is the gate-check entry which is removed.

### 7. Out of scope

- Changes to D1's taxonomy YAML (codes, severities, message_templates) —
  reviewer flags any taxonomy edit and rejects the deliverable.
- Changes to D2's `furrow guard` command surface — D3 calls it via
  helper, never invokes it directly with hand-rolled flags.
- Changes to the 3 non-emitter hooks (`append-learning.sh`,
  `auto-install.sh`, `post-compact.sh`) and the 2 already-canonical hooks
  (`validate-definition.sh`, `ownership-warn.sh`) — out of scope per
  audit §1 and definition.yaml:54.
- Pi-side runtime invocation — handled by D4 fixtures (constraint:
  definition.yaml:132).

---

## Dependencies

### Hard dependencies (must be complete before D3 starts)

1. **D2 (`normalized-blocker-event-and-go-emission-path`)** — definition.yaml
   line 51 declares this dependency. D2 lands:
   - `schemas/blocker-event.yaml` and `.schema.json` (event-type contract).
   - `furrow guard <event-type>` command in `cmd/furrow/`.
   - `bin/frw.d/lib/blocker_emit.sh` exporting:
     - `emit_canonical_blocker`,
     - `claude_tool_input_to_event`,
     - `claude_stop_to_event`,
     - `precommit_diff_to_event`,
     - `forward_envelope_to_host`.
   - Per-event-type backend handlers (the `internal/cli/guard/*.go` files
     listed in Interface Contract §3) — at minimum stubbed with
     `EvaluateXxx` signatures so D3 can wire shims; D3 fills in handler
     bodies if D2 left them as stubs.

2. **D1 (`canonical-blocker-taxonomy`)** — indirect: the codes that the Go
   handlers emit must exist in `schemas/blocker-taxonomy.yaml`. Per
   audit §5, ~10 new codes from hook migration plus ~10 baseline-coverage
   codes; D1 lands all of them.

### Soft dependencies (coordinate but not blocking)

- **D5 (`doc-contradiction-reconciliation`)** runs in parallel with D1 in
  Wave 1; no file overlap with D3.
- **D4 (`coverage-and-parity-tests`)** depends on D3 (definition.yaml:67);
  D3 closes before D4 starts. The deferral protocol (§5) requires D3 to land
  any TODOs **before** D4 begins fixture authoring.

### Files D3 owns (definition.yaml:60-62)

- `bin/frw.d/hooks/**` — all 10 migrated shims plus the deletion of
  `gate-check.sh`.
- `bin/frw.d/lib/**` — D3 may add migration-specific helpers (or extract
  duplicated patterns into existing files); does not modify D2's
  `blocker_emit.sh` exports without coordination.
- `.furrow/almanac/todos.yaml` — only via `alm todo add` (CLI-mediated per
  `.claude/rules/cli-mediation.md`); only for deferral entries per §5.
- `.furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md` —
  the audit report (definition.yaml:57).
- `.claude/settings.json` — single edit: remove the `gate-check` line (§1
  Step 1).
- `tests/integration/check-shim-budget.sh` — the line-count guard
  referenced in Scenario E. New file, owned by D3.

### Tools required at implement time

- `shellcheck` (clean on all migrated shims).
- `jq`, `yq` (already in shim env).
- Go toolchain (for the `internal/cli/guard/*` handlers if D2 left stubs).
- `awk` (for the 30-line counter in AC-2.1).
- `alm` CLI (for any TODO additions per §5).

### Out-of-scope dependencies (explicitly NOT touched)

- `cmd/furrow/main.go` registration of `furrow guard` — D2 owns.
- `schemas/blocker-event.{yaml,schema.json}` — D2 owns.
- `schemas/blocker-taxonomy.yaml` — D1 owns.
- `adapters/pi/**` — D4 owns the test driver under that path; D3 does not
  edit Pi adapter source.

---

## Cross-references

- `definition.yaml` lines 50-63 — D3 deliverable contract.
- `definition.yaml` line 131 — fallback threshold constraint.
- `team-plan.md` Wave 3 — sequenced task list.
- `research/hook-audit.md` §1 — emit-bearing classification.
- `research/hook-audit.md` §2.1-2.11 — per-hook audit (cited throughout
  Interface Contract §2).
- `research/hook-audit.md` §3 — summary table (event-type names).
- `research/hook-audit.md` §4 — proposed shared helpers (refined in
  Interface Contract §4).
- `research/hook-audit.md` §6 — mechanical-vs-non-trivial recommendation
  (drives §1 sequencing).
- `research/hook-audit.md` §7 — migration phase order (adopted as §1
  sequenced execution).
- `research/hook-audit.md` §8 — quality findings (resolution table is
  audit report §2).
- `.claude/rules/cli-mediation.md` — `.furrow/almanac/todos.yaml` mutations
  go through `alm`, never direct edits.
- `bin/frw.d/hooks/ownership-warn.sh` — pattern reference (§Implementation
  Notes 5).
- `bin/frw.d/hooks/validate-definition.sh` — pattern reference.
