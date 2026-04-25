# Spec: validate-ownership-go (D2, wave 3)

## Interface Contract

### CLI

```
furrow validate ownership --path <target> [--row <name>] [--json]
```

Behavior:
- `--row` defaults to the focused row (read from `.furrow/.focused`)
- If no row can be resolved (no `--row` and no focused row), verdict is `not_applicable`
- If the row exists but has no deliverables (`deliverables: []` or empty), verdict is `not_applicable` with reason `row_has_no_deliverables`
- If the path is a canonical row artifact (state.json, definition.yaml, summary.md, learnings.jsonl, research.md, plan.json, team-plan.md, parity-verification.md, or any file inside `.furrow/rows/<name>/specs/`, `.furrow/rows/<name>/reviews/`, `.furrow/rows/<name>/gates/`), verdict is `not_applicable` with reason `canonical_row_artifact`
- Otherwise: read all `deliverables[].file_ownership` globs from the row's definition.yaml; match `--path` against each glob (using Go's `filepath.Match` plus a doublestar matcher for `**` patterns); verdict is `in_scope` with the matched deliverable+glob, or `out_of_scope` if no match

Exit codes:
- `0` — verdict produced (regardless of in_scope vs out_of_scope vs not_applicable; this is a *report* command, not an enforcer)
- `1` — usage error (missing --path, ambiguous flags)

### JSON output (with `--json`)

```json
// in_scope
{ "ok": true, "verdict": "in_scope", "matched_deliverable": "validate-definition-go", "matched_glob": "internal/cli/validate_definition.go" }

// out_of_scope
{
  "ok": true, "verdict": "out_of_scope",
  "envelope": {
    "code": "ownership_outside_scope",
    "category": "ownership",
    "severity": "warn",
    "message": "internal/cli/foo.go is outside file_ownership for any deliverable in pre-write-validation-go-first",
    "remediation_hint": "Add the path to the appropriate deliverable's file_ownership in definition.yaml, or write to a different file.",
    "confirmation_path": "warn-with-confirm"
  }
}

// not_applicable
{ "ok": true, "verdict": "not_applicable", "reason": "no_active_row" }
```

### Files

- `internal/cli/validate_ownership.go` — implementation + CLI handler.
- `internal/cli/validate_ownership_test.go` — table-driven tests.
- `internal/cli/app.go` — registers `ownership` subcommand under the `validate` group already created by D1 in wave 2.

## Acceptance Criteria (Refined)

1. `furrow validate ownership --path internal/cli/validate_ownership.go --row pre-write-validation-go-first --json` exits 0 and emits `verdict: in_scope` with `matched_deliverable: validate-ownership-go`.
2. `furrow validate ownership --path some/random/file.txt --row pre-write-validation-go-first --json` exits 0 and emits `verdict: out_of_scope` with `envelope.code: ownership_outside_scope`.
3. `furrow validate ownership --path foo.txt --json` (no --row, no focused row) exits 0 with `verdict: not_applicable, reason: no_active_row`.
4. `furrow validate ownership --path .furrow/rows/foo/state.json --row foo --json` returns `verdict: not_applicable, reason: canonical_row_artifact` for any of the canonical artifact paths listed above.
5. `--row` defaults to the value in `.furrow/.focused`. If `.furrow/.focused` exists and points to a valid row, `--row` may be omitted.
6. Step-agnostic: the verdict does NOT depend on `state.json.step`. Tested by setting state.step to several values and confirming verdict is unchanged.
7. Glob matching supports both `*` (single segment) and `**` (multi-segment) patterns. Verified by tests using fixtures with both pattern styles.
8. Multi-deliverable globs: when a path matches globs in multiple deliverables, the FIRST matching deliverable in definition.yaml order is reported (deterministic).
9. Every emitted error code (`ownership_outside_scope`) is registered in `schemas/blocker-taxonomy.yaml`. Test asserts via D3's taxonomy.EmitBlocker resolution.
10. `internal/cli/app.go` adds the `ownership` subcommand registration under the existing `validate` group; no duplicate group registration.
11. `go test ./...` passes.

## Test Scenarios

### Scenario: in-scope-exact-match
- **Verifies**: AC #1, #7
- **WHEN**: path `internal/cli/validate_ownership.go`, row `pre-write-validation-go-first`
- **THEN**: verdict `in_scope`; matched_glob equals the literal path
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipInScopeExact -v`

### Scenario: in-scope-glob-match
- **Verifies**: AC #7
- **WHEN**: fixture row with deliverable owning `internal/cli/**/*.go`; path `internal/cli/foo/bar.go`
- **THEN**: verdict `in_scope`; matched_glob equals `internal/cli/**/*.go`
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipDoubleStarGlob -v`

### Scenario: out-of-scope
- **Verifies**: AC #2, #9
- **WHEN**: path `some/unrelated/file.txt`, row with no matching glob
- **THEN**: verdict `out_of_scope`; envelope.code `ownership_outside_scope`
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipOutOfScope -v`

### Scenario: no-row-no-focus
- **Verifies**: AC #3
- **WHEN**: `--row` omitted, `.furrow/.focused` empty/absent
- **THEN**: verdict `not_applicable`; reason `no_active_row`
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipNoRow -v`

### Scenario: focused-row-fallback
- **Verifies**: AC #5
- **WHEN**: `--row` omitted, `.furrow/.focused` contains a valid row name
- **THEN**: verdict computed against that row's definition.yaml
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipFocusedRowFallback -v`

### Scenario: canonical-artifact-carve-out
- **Verifies**: AC #4
- **WHEN**: path is `.furrow/rows/foo/state.json` (or definition.yaml, summary.md, learnings.jsonl, research.md, plan.json, team-plan.md, parity-verification.md, or any specs/ reviews/ gates/ subpath)
- **THEN**: verdict `not_applicable`; reason `canonical_row_artifact`
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipCanonicalArtifact -v`

### Scenario: multi-deliverable-deterministic-match
- **Verifies**: AC #8
- **WHEN**: row has D-A and D-B both listing `internal/cli/foo.go`; D-A appears first in definition.yaml
- **THEN**: verdict `in_scope`; matched_deliverable `D-A`
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipDeterministicOrder -v`

### Scenario: step-agnostic
- **Verifies**: AC #6
- **WHEN**: row's state.json.step varied across `ideate`, `plan`, `implement`; same path queried each time
- **THEN**: verdict and matched_deliverable identical across runs
- **Verification**: `go test ./internal/cli/ -run TestValidateOwnershipStepAgnostic -v`

## Implementation Notes

- Use `github.com/bmatcuk/doublestar/v4` if already vendored for `**` glob support; otherwise implement minimal `**` matching by replacing `**` with regex `.*` and using `filepath.Match` for the rest.
- Canonical-artifact carve-out: implement as a pure prefix/suffix check; no need to inspect file contents.
- Read `definition.yaml.deliverables[].file_ownership` via `gopkg.in/yaml.v3` (already in use).
- D2 does NOT modify `internal/cli/row_workflow.go` or `row_semantics.go` (boundary AC from D3).

## Dependencies

- D1 (validate-definition-go) — wave 2: registers the `validate` command group in app.go.
- D3 (blocker-taxonomy-schema) — wave 1: provides `Taxonomy.EmitBlocker("ownership_outside_scope", ...)`.
- `definition.yaml` schema (existing) — D2 reads `deliverables[].file_ownership` from any row's definition.
- `.furrow/.focused` (existing) — focused row fallback.
