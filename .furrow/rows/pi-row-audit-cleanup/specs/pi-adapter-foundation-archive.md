# Spec: pi-adapter-foundation-archive

## Interface Contract

### 1. Schema Extension — `schemas/definition.schema.json`

Add an optional top-level `supersedes` property to the schema's `properties` map:

```json
"supersedes": {
  "type": "object",
  "description": "Declares that this row's work was superseded by a sibling row before completion. Presence triggers archive-time supersedence confirmation.",
  "required": ["commit", "row"],
  "additionalProperties": false,
  "properties": {
    "commit": {
      "type": "string",
      "description": "Short or full SHA of the commit that contains the superseding work"
    },
    "row": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$",
      "description": "Kebab-case name of the row whose work supersedes this one"
    }
  }
}
```

Insert this property at the top level of `properties` (alongside `objective`, `deliverables`, etc.). Because `supersedes` is NOT added to the `required` array, all existing definition.yaml files continue to validate unchanged.

### 2. Definition File Extension — `pi-adapter-foundation/definition.yaml`

Add this block at the top level of the YAML file (after `gate_policy`):

```yaml
supersedes:
  commit: e4adef5
  row: pi-step-ceremony-and-artifact-enforcement
```

This block must be added AFTER `schemas/definition.schema.json` is updated within the same or a preceding commit to avoid failing schema validation on the intermediate state (see Implementation Notes §Commit Ordering).

### 3. CLI Flag — `furrow row archive`

Register a new value-flag `--supersedes-confirmed <commit>:<row>` on the `furrow row archive` subcommand via `parseArgs` in `runRowArchive`.

Parser behavior:

- Flag name: `supersedes-confirmed`
- Value type: string, single argument
- Format: `<commit>:<row>` — exactly one colon delimiter
- Parsing: split on first `:` only; left side = confirmed commit, right side = confirmed row
- Validation of the parsed halves is delegated to `rowBlockers()` — `runRowArchive` merely passes the raw string to the opts struct

Flag registration in `runRowArchive` (current `parseArgs` call):

```go
// Before (current):
positionals, flags, err := parseArgs(args, nil, nil)

// After:
positionals, flags, err := parseArgs(args, map[string]bool{"supersedes-confirmed": true}, nil)
```

The flag value is read as `flags.values["supersedes-confirmed"]`.

### 4. `rowBlockersOpts` Struct (new)

Introduce a new options struct to extend `rowBlockers()` without breaking existing callers:

```go
// rowBlockersOpts carries optional context beyond state/seed/artifacts.
// The zero value (rowBlockersOpts{}) is safe for all existing callers.
type rowBlockersOpts struct {
    // SupersedesConfirmed is the raw "--supersedes-confirmed <commit>:<row>" value.
    // Empty string means the flag was not passed.
    SupersedesConfirmed string
    // DefinitionSupersedes holds the parsed supersedes block from definition.yaml,
    // or nil if the definition has no supersedes block.
    DefinitionSupersedes map[string]any
}
```

### 5. `rowBlockers()` Signature Change

```go
// Before:
func rowBlockers(state map[string]any, seed map[string]any, artifacts []map[string]any) []map[string]any

// After:
func rowBlockers(state map[string]any, seed map[string]any, artifacts []map[string]any, opts rowBlockersOpts) []map[string]any
```

The new `supersedence_evidence_missing` check is inserted after the seed checks and before the artifact loop (after ~line 1013, before ~line 1014 in the current file):

```go
// Supersedence confirmation check
if opts.DefinitionSupersedes != nil {
    requiredCommit, _ := opts.DefinitionSupersedes["commit"].(string)
    requiredRow, _ := opts.DefinitionSupersedes["row"].(string)
    confirmed := opts.SupersedesConfirmed  // may be ""
    var confirmedCommit, confirmedRow string
    if confirmed != "" {
        parts := strings.SplitN(confirmed, ":", 2)
        if len(parts) == 2 {
            confirmedCommit, confirmedRow = parts[0], parts[1]
        }
    }
    switch {
    case confirmed == "":
        blockers = append(blockers, blocker(
            "supersedence_evidence_missing",
            "archive",
            fmt.Sprintf("row definition declares supersedes (commit=%s, row=%s); pass --supersedes-confirmed %s:%s to acknowledge",
                requiredCommit, requiredRow, requiredCommit, requiredRow),
            map[string]any{"required_commit": requiredCommit, "required_row": requiredRow},
        ))
    case confirmedCommit != requiredCommit || confirmedRow != requiredRow:
        blockers = append(blockers, blocker(
            "supersedence_evidence_missing",
            "archive",
            fmt.Sprintf("--supersedes-confirmed mismatch: got %s:%s, definition requires %s:%s",
                confirmedCommit, confirmedRow, requiredCommit, requiredRow),
            map[string]any{
                "required_commit":  requiredCommit,
                "required_row":     requiredRow,
                "confirmed_commit": confirmedCommit,
                "confirmed_row":    confirmedRow,
            },
        ))
    }
}
```

### 6. `rowBlockers()` Call-Site Audit

Grep result (authoritative — run at spec time):

```
/home/jonco/src/furrow/internal/cli/review.go:58
/home/jonco/src/furrow/internal/cli/row.go:201
/home/jonco/src/furrow/internal/cli/row.go:435
/home/jonco/src/furrow/internal/cli/row.go:599
/home/jonco/src/furrow/internal/cli/row_workflow.go:994  ← definition
```

All four call sites must be updated to pass the new `opts` parameter:

| Call site | Context | Required change |
|---|---|---|
| `row.go:201` (`runRowTransition`) | Step transitions — never archive path | Pass `rowBlockersOpts{}` (zero value) |
| `row.go:435` (`runRowArchive`) | Archive path — load supersedes from definition | Pass `rowBlockersOpts{SupersedesConfirmed: flags.values["supersedes-confirmed"], DefinitionSupersedes: definitionSupersedes(root, rowName)}` |
| `row.go:599` (`buildRowStatusData`) | Status display — no flag context | Pass `rowBlockersOpts{}` (zero value) |
| `review.go:58` (`runReviewStatus`) | Review status display — no flag context | Pass `rowBlockersOpts{}` (zero value) |

The `definitionSupersedes(root, rowName string) map[string]any` helper reads `definition.yaml` for the named row, unmarshals it, and returns the `supersedes` map (or `nil` if absent). Use existing `loadYAMLMap`-style helpers (or equivalent) consistent with the codebase's YAML loading pattern.

### 7. Gate Evidence Echo (P2=B)

When archive succeeds with a `supersedes` block confirmed, echo the confirmed value into `phase_a.notes` of `gates/review-to-archive.json`. The `phase_a` notes field is set in `runRowArchive`'s `writeGateEvidence` call:

```go
// When supersedes block was present and confirmed:
"phase_a": map[string]any{
    ...
    "notes": fmt.Sprintf("supersedence confirmed: %s:%s", confirmedCommit, confirmedRow),
    "blockers": blockers,
},
```

No new top-level fields are added to the gate evidence schema (per constraint P2=B; per research.md Topic 2 §Existing archive.json shape).

### 8. `archive.json` vs `gates/review-to-archive.json` Clarification

Per research.md Topic 2 §Existing archive.json shape and confirmed by reading `runRowArchive` (row.go:447-461): the Go archive command writes `gates/review-to-archive.json` via `writeGateEvidence()`. There is NO separate `archive.json` file written by the Go path.

The file `archive.json` listed in `definition.yaml` D3 `file_ownership` is a stale artifact name. The corrected owned file is `.furrow/rows/pi-adapter-foundation/gates/review-to-archive.json`. The spec amends this understanding; the file_ownership list in definition.yaml will be corrected as an implementation note (see Implementation Notes §file_ownership Correction).

---

## Acceptance Criteria (Refined)

All 11 original ACs, restated with testable specifics:

**AC-1 (Schema)**: `schemas/definition.schema.json` gains an optional top-level `supersedes` property of type object with required string fields `commit` and `row`. Running `frw validate-definition` against all existing `.furrow/rows/*/definition.yaml` files passes without new errors.

**AC-2 (Definition update)**: `pi-adapter-foundation/definition.yaml` gains a top-level `supersedes` block: `{commit: e4adef5, row: pi-step-ceremony-and-artifact-enforcement}`. The file validates against the updated schema.

**AC-3 (Flag registration)**: `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement` parses the flag without "unknown flag" error (i.e., flag is registered in `parseArgs` call). `furrow row archive --help` text reflects the flag or at minimum does not crash on unknown flag.

**AC-4 (Blocker emission)**: `rowBlockers()` emits a blocker with `code: "supersedence_evidence_missing"` when `opts.DefinitionSupersedes` is non-nil and: (a) `opts.SupersedesConfirmed` is empty, OR (b) the parsed commit or row from the flag does not match the definition's `commit`/`row` values. When `opts.DefinitionSupersedes` is nil (no supersedes block), the blocker is NEVER emitted regardless of flag state.

**AC-5 (Negative test — missing flag)**: Running `furrow row archive pi-adapter-foundation` (without `--supersedes-confirmed`) exits non-zero (exit code 2). Stderr or JSON error message names both the required commit (`e4adef5`) and required row (`pi-step-ceremony-and-artifact-enforcement`).

**AC-6 (Negative test — mismatched flag)**: Running `furrow row archive pi-adapter-foundation --supersedes-confirmed wrong-commit:wrong-row` exits non-zero (exit code 2). Error message explicitly states it is a mismatch and names the expected vs actual commit and row values.

**AC-7 (Positive test)**: Running `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement` (when all other blockers are clear) exits 0. The resulting `gates/review-to-archive.json` has `phase_a.blockers` as an empty array.

**AC-8 (Live archive)**: `pi-adapter-foundation/state.json.archived_at` is non-null after the live archive run. `gates/review-to-archive.json` is created at `.furrow/rows/pi-adapter-foundation/gates/review-to-archive.json`. The `phase_a.notes` field contains the string `supersedence confirmed: e4adef5:pi-step-ceremony-and-artifact-enforcement`.

**AC-9 (handoff.md cleanup)**: Line 62 of `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md` — the line reading "Stay inside roadmap row `work/pi-adapter-foundation` and todo `work-loop-boundary-hardening`, but continue in a new in-scope row rather than reopening this archived one." — is removed entirely. The section heading "## Recommended next slice" and following items may be removed or retained depending on whether the entire block constitutes the dangling-successor instruction (Decision 3: remove, not rewrite).

**AC-10 (rws list)**: `rws list` (or `furrow row list --active`) does not include `pi-adapter-foundation` in output after archival.

**AC-11 (.focused cleared)**: `.furrow/.focused` does not contain `pi-adapter-foundation`. If it did before archival, the Go archive path (`runRowArchive` does NOT clear `.focused` — this is done by the shell path). Verify `.focused` state before archive; if it points to `pi-adapter-foundation`, clear it via `furrow row focus --clear` before or after archival.

**AC-Guard (spec input #6)**: When archiving a row whose `definition.yaml` has NO `supersedes` block, passing `rowBlockers()` with `rowBlockersOpts{}` does NOT emit `supersedence_evidence_missing`. This regression guard prevents the new check from blocking all archives.

---

## Test Scenarios

### Scenario A: Missing --supersedes-confirmed flag
- **Verifies**: AC-5
- **WHEN**: `pi-adapter-foundation/definition.yaml` has `supersedes: {commit: e4adef5, row: pi-step-ceremony-and-artifact-enforcement}` and `furrow row archive pi-adapter-foundation` is invoked without `--supersedes-confirmed`
- **THEN**: Command exits non-zero (code 2). Error output contains `e4adef5` and `pi-step-ceremony-and-artifact-enforcement`. `state.json.archived_at` remains null.
- **Verification**:
  ```sh
  furrow row archive pi-adapter-foundation; echo "exit: $?"
  # Expected: exit: 2
  # Expected in stderr/JSON: "e4adef5" and "pi-step-ceremony-and-artifact-enforcement"
  jq '.archived_at' .furrow/rows/pi-adapter-foundation/state.json
  # Expected: null
  ```

### Scenario B: Mismatched commit in flag
- **Verifies**: AC-6 (wrong commit)
- **WHEN**: `furrow row archive pi-adapter-foundation --supersedes-confirmed badc0de:pi-step-ceremony-and-artifact-enforcement`
- **THEN**: Exits non-zero (code 2). Error message contains both "mismatch" (or equivalent) and names `e4adef5` as required vs `badc0de` as provided.
- **Verification**:
  ```sh
  furrow row archive pi-adapter-foundation --supersedes-confirmed badc0de:pi-step-ceremony-and-artifact-enforcement; echo "exit: $?"
  # Expected: exit: 2
  ```

### Scenario C: Mismatched row in flag
- **Verifies**: AC-6 (wrong row)
- **WHEN**: `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:wrong-row-name`
- **THEN**: Exits non-zero (code 2). Error names `pi-step-ceremony-and-artifact-enforcement` as required vs `wrong-row-name` as provided.
- **Verification**:
  ```sh
  furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:wrong-row-name; echo "exit: $?"
  # Expected: exit: 2
  ```

### Scenario D: Both commit and row mismatched
- **Verifies**: AC-6 (both wrong)
- **WHEN**: `furrow row archive pi-adapter-foundation --supersedes-confirmed aaa:bbb`
- **THEN**: Exits non-zero (code 2). Single blocker emitted (not two). Message names all four values (got aaa:bbb, required e4adef5:pi-step-ceremony-and-artifact-enforcement).
- **Verification**:
  ```sh
  furrow row archive pi-adapter-foundation --supersedes-confirmed aaa:bbb --json 2>&1 | jq '.error.details.blockers | length'
  # Expected: 1
  ```

### Scenario E: Matching flag — success
- **Verifies**: AC-7
- **WHEN**: Row is at step=review, step_status=completed, all other blockers clear, and `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement` is invoked
- **THEN**: Exits 0. `state.json.archived_at` is non-null. `gates/review-to-archive.json` exists with `phase_a.blockers` = `[]`.
- **Verification**:
  ```sh
  furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement; echo "exit: $?"
  # Expected: exit: 0
  jq '.archived_at' .furrow/rows/pi-adapter-foundation/state.json
  # Expected: non-null ISO 8601 string
  jq '.phase_a.blockers | length' .furrow/rows/pi-adapter-foundation/gates/review-to-archive.json
  # Expected: 0
  ```

### Scenario F: Guard — no supersedes block, no flag (regression prevention)
- **Verifies**: AC-Guard (spec input #6)
- **WHEN**: A test row's `definition.yaml` has NO `supersedes` block, and `rowBlockers()` is called with `rowBlockersOpts{}` (zero value, no SupersedesConfirmed, no DefinitionSupersedes)
- **THEN**: No `supersedence_evidence_missing` blocker is present in the returned slice.
- **Verification** (unit test in `row_workflow_test.go`):
  ```go
  opts := rowBlockersOpts{} // zero value
  blockers := rowBlockers(normalState, normalSeed, nil, opts)
  for _, b := range blockers {
      if b["code"] == "supersedence_evidence_missing" {
          t.Errorf("unexpected supersedence blocker on row without supersedes block")
      }
  }
  ```
  Also verify via a non-pi-adapter-foundation live row that `furrow row archive <normal-row>` without `--supersedes-confirmed` does not error on this blocker.

### Scenario G: Live archive of pi-adapter-foundation
- **Verifies**: AC-8, AC-10, AC-11
- **WHEN**: All prerequisites are met (definition.yaml has supersedes block, row is at step=review step_status=completed, D2 pi-step-ceremony-backfill complete, no other blockers)
- **THEN**: `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement` exits 0; state, gate evidence, and focus pointer are correct
- **Verification**:
  ```sh
  # Exact CLI invocation (MUST use Go binary, not rws):
  furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement

  # AC-8: state.json.archived_at non-null
  jq '.archived_at' .furrow/rows/pi-adapter-foundation/state.json

  # AC-8: gate evidence notes echo
  jq '.phase_a.notes' .furrow/rows/pi-adapter-foundation/gates/review-to-archive.json
  # Expected: "supersedence confirmed: e4adef5:pi-step-ceremony-and-artifact-enforcement"

  # AC-10: not in active list
  furrow row list --active | grep pi-adapter-foundation
  # Expected: no output

  # AC-11: .focused does not point at pi-adapter-foundation
  cat .furrow/.focused 2>/dev/null || echo "(no focused file)"
  ```

---

## Implementation Notes

### rowBlockersOpts Pattern Justification

Using an options struct rather than adding a new positional parameter or a variadic parameter is the idiomatic Go approach for extending function signatures with optional data. Existing callers pass `rowBlockersOpts{}` (zero value), which is a safe no-op — no behavioral change. Future supersedence-like requirements (e.g., dependency chains, audit trails) can add fields to `rowBlockersOpts` without touching callers that don't need them. This was spec input #1 (CRITICAL — load-bearing).

The `DefinitionSupersedes` field is loaded by `runRowArchive` via a helper `definitionSupersedes(root, rowName string) map[string]any`. For all other call sites, this field is `nil` and the check is skipped in `rowBlockers()`.

### Go-Only Archive Path (spec input #2, CRITICAL)

The live archive of `pi-adapter-foundation` (AC-8 / Scenario G) MUST use:

```sh
furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement
```

This invokes the Go binary (`internal/cli/row.go:runRowArchive`), which calls `rowBlockers()` with the opts struct and enforces the supersedence check.

DO NOT use `rws archive pi-adapter-foundation` or invoke `commands/archive.md` slash command (which delegates to `rws archive` at line 59). The shell path (`bin/rws:1958-2020 rws_archive`) does NOT call `rowBlockers()` and will bypass the supersedence check entirely, producing an archive without gate evidence or blocker enforcement. Per research.md Topic 2 §Current archive surface map: "The slash command... Final mutation goes through shell, not Go."

The slash command bypass is a known gap documented in research.md Topic 2 §Also surfaced; it is out of scope for this row. A follow-up TODO should be filed at archive time to route `commands/archive.md:59` through the Go binary.

### Commit Ordering (spec input #8)

Within the D3 implementation commit (or split as D3a/D3b):

1. **D3a (schema + code)**: `schemas/definition.schema.json` supersedes property addition + `internal/cli/row_workflow.go` opts struct + `rowBlockers()` signature + `internal/cli/row.go` flag registration + call-site updates + `internal/cli/row_workflow_test.go` test cases. These changes are logically coupled and should land together.

2. **D3b (definition update + live archive)**: `.furrow/rows/pi-adapter-foundation/definition.yaml` supersedes block addition + live archive run (which creates `gates/review-to-archive.json`) + `handoff.md` cleanup.

The D3a/D3b split ensures `definition.yaml` is only updated after the schema that validates it is already in place. If implemented as a single commit, the schema update must appear in the diff before the definition.yaml change (git processes the working tree atomically; the ordering note here is for author discipline during PR review).

### archive.json vs gates/review-to-archive.json (spec input #5)

Per reading `runRowArchive` (row.go:447-461) and research.md Topic 2 §Existing archive.json shape:

- `runRowArchive` writes `gates/review-to-archive.json` via `writeGateEvidence()`.
- There is no `archive.json` written by the Go archive command.
- The file `.furrow/rows/pi-adapter-foundation/archive.json` listed in `definition.yaml` D3 `file_ownership` is stale. The correct owned file is `.furrow/rows/pi-adapter-foundation/gates/review-to-archive.json`.
- `file_ownership` in the definition is informational metadata; the stale entry does not block implementation, but should not be treated as a file to create.

### handoff.md:62 — Exact Text to Remove

The dangling-successor instruction (AC-9) is the section beginning at line 60 of `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`:

```
## Recommended next slice

Stay inside roadmap row `work/pi-adapter-foundation` and todo `work-loop-boundary-hardening`, but continue in a new in-scope row rather than reopening this archived one.
```

Line 62 is specifically: `Stay inside roadmap row \`work/pi-adapter-foundation\` and todo \`work-loop-boundary-hardening\`, but continue in a new in-scope row rather than reopening this archived one.`

Decision 3 (from definition.yaml context_pointers note) is to remove this entirely, not rewrite it. The heading `## Recommended next slice` and subsequent numbered points (lines 64-67) are part of the same dangling-successor block and should also be removed. The section at lines 69-73 (`## Constraints to preserve`) is retained.

### Wave 3 Shared File Edits (spec input #4)

`internal/cli/app.go` and `bin/rws` both appear in D1 (wave 1) and D3 (wave 3) `file_ownership`. Wave 3 edits are ADDITIVE only:

- `internal/cli/app.go`: The `runRow` switch already has `case "archive"`. No new case is needed. The only wave 3 change, if any, is updating help text to document `--supersedes-confirmed`. This is a net-additive change that does not touch D1's additions (`repair-deliverables` case).
- `bin/rws`: Wave 3 does NOT require changes to `bin/rws`. The `--supersedes-confirmed` flag is a Go-side flag on the `furrow` binary, not on the shell `rws archive` path. The shell archive shim (`rws_archive`) is intentionally not updated (the shell path is the known bypass; updating it would create a parallel implementation). If wave 3 finds a reason to touch `bin/rws`, the change must be additive to wave 1's `repair-deliverables` shim.

### `.focused` Pointer (AC-11)

`runRowArchive` (Go) does NOT currently clear `.furrow/.focused` (per reading row.go:486-514). The shell `rws_archive` does clear it (bin/rws:2016-2021). If `.focused` currently points at `pi-adapter-foundation` (check with `cat .furrow/.focused`), it must be cleared separately:

```sh
furrow row focus --clear
```

Run this **after** the Go archive command exits 0 (not before — clearing focus before archive could mask a focus-state issue from the operator at archive time). Sequence: (1) `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement` exits 0; (2) check `.furrow/.focused`; (3) if it points at pi-adapter-foundation, run `furrow row focus --clear`. AC-11 is satisfied iff the file does not contain `pi-adapter-foundation` at the end of this deliverable.

### Pre-archive transition path for pi-adapter-foundation (precondition for AC-8)

Current state of `pi-adapter-foundation/state.json` is `step: implement, step_status: not_started`, with 5 prior gates already recorded (ideate→…→decompose→implement). The Go archive path requires `step: review, step_status: completed` plus a passing `implement->review` gate (per `runRowArchive` preconditions). The row has 0 deliverables and the spec was satisfied entirely by sibling row `pi-step-ceremony-and-artifact-enforcement` (commit e4adef5) — there is no implement work to perform.

**Required pre-archive transitions** (executed as part of D3b before the live archive command):

1. `rws transition pi-adapter-foundation pass manual "no implement work — phantom row, scope satisfied by sibling row pi-step-ceremony-and-artifact-enforcement (commit e4adef5); supersedence acknowledged"` to advance `implement -> review`.
2. `rws complete-step pi-adapter-foundation` to mark review as completed (or, if review-step gate evidence is required, run the review step's minimum ceremony noting the supersedence rationale).
3. Verify with `rws status pi-adapter-foundation` that `step=review, step_status=completed`.
4. Run the live archive: `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement`.

The transitions are mechanical and rely on the supervised gate policy already recorded; the `--supersedes-confirmed` flag is the load-bearing acknowledgement that prevents accidental archive — the implement→review and review→archive transitions are pro-forma given the row's phantom status.

**If `rws transition` blocks** on missing artifacts (e.g., implement step requires implementation evidence), document the blocker as a follow-up TODO and escalate to the human; do not bypass the gate to satisfy this deliverable. The supersedence flag is the correct place to encode "this row's spec was satisfied elsewhere", not the step transitions.

---

## Dependencies

- **depends_on D2 (pi-step-ceremony-backfill)**: D3 presupposes that `pi-step-ceremony-and-artifact-enforcement` has a corrected deliverables map (via `furrow row repair-deliverables`). The supersedes block in `pi-adapter-foundation/definition.yaml` references this sibling row as the superseding entity; its corrected state is the human-readable evidence basis for the `--supersedes-confirmed` acknowledgement.

- **depends_on D1 (repair-deliverables-cli)**: D2 depends on D1. D3 therefore transitively depends on D1.

- **Schema validation**: The `schemas/definition.schema.json` update is consumed by `frw validate-definition`. Verify that `frw validate-definition` runs against all `.furrow/rows/*/definition.yaml` files after the schema change to confirm no existing files are broken (AC-1).

- **No new external Go dependencies**: Implementation reuses `parseArgs` (app.go), `loadJSONMap`/YAML loading, `writeGateEvidence`, `blocker()`, `latestPassingReviewGate()`, `strings.SplitN` from stdlib. No new imports required beyond what is already present in `internal/cli/`.

- **Research grounding**: Implementation approach sourced from research.md Topic 2 §Recommended rejection site (blocker location in `rowBlockers()`), §Existing archive.json shape (P2=B gate evidence strategy), and §Implementation hints (blocker insertion point, helper reuse).
