# Spec: project-root-resolution

## Interface Contract

**New variable**: `PROJECT_ROOT` — the consumer project root directory (where `.furrow/` lives).

**Definition** (in `bin/frw`, after line 10):
```sh
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export PROJECT_ROOT
```

**Contract**:
- `FURROW_ROOT` = Furrow install directory (unchanged). Used for code: hooks, scripts, schemas, specialists, skills.
- `PROJECT_ROOT` = Consumer project root. Used for data: `.furrow/rows/`, `.furrow/furrow.yaml`, state files.
- Both exported by `bin/frw` at startup. Sourced scripts inherit both.
- `PROJECT_ROOT` defaults to PWD if not set in environment.

**Callers**: All scripts in `bin/frw.d/scripts/` that reference project data.

## Acceptance Criteria (Refined)

1. `bin/frw` exports `PROJECT_ROOT` alongside `FURROW_ROOT` — verified by `frw root` equivalent or env inspection
2. All 11 project-relative `$FURROW_ROOT` references replaced with `$PROJECT_ROOT`:
   - generate-plan.sh:29,30
   - check-artifacts.sh:32
   - evaluate-gate.sh:28
   - select-gate.sh:22
   - select-dimensions.sh:26
   - run-gate.sh:39
   - run-ci-checks.sh:25,30
   - cross-model-review.sh:23,26
3. Ambiguous defaults updated: measure-context.sh:10, doctor.sh:18 use `$PROJECT_ROOT` as fallback
4. `frw` commands work when invoked via PATH/symlink from a consumer project
5. `frw` commands still work from the Furrow source repo (where FURROW_ROOT == PROJECT_ROOT)

## Test Scenarios

### Scenario: Consumer project invocation via PATH
- **Verifies**: AC 4
- **WHEN**: `frw` is on PATH via symlink, PWD is a consumer project with `.furrow/rows/`
- **THEN**: `frw check-artifacts <name>` finds row state in PWD, not in Furrow install dir
- **Verification**: `cd /tmp/test-project && frw check-artifacts <name>` succeeds (requires test fixture)

### Scenario: Source repo invocation
- **Verifies**: AC 5
- **WHEN**: PWD is the Furrow source repo itself, `bin/frw` invoked directly
- **THEN**: All commands work as before (FURROW_ROOT and PROJECT_ROOT point to same dir)
- **Verification**: `cd ~/src/furrow && bin/frw doctor` succeeds

### Scenario: No FURROW_ROOT reference leaks
- **Verifies**: AC 2
- **WHEN**: All changes applied
- **THEN**: `grep -rn 'FURROW_ROOT.*\.furrow/rows\|FURROW_ROOT.*\.claude/furrow' bin/frw.d/scripts/` returns no matches
- **Verification**: `grep -rn 'FURROW_ROOT.*\.furrow/rows\|FURROW_ROOT.*\.claude/furrow' bin/frw.d/scripts/ | wc -l` equals 0

## Implementation Notes

- The fix is mechanical: substitute `$FURROW_ROOT` → `$PROJECT_ROOT` in 11 specific lines
- Do NOT change install-relative references (98 correct uses of FURROW_ROOT)
- `bin/rws`, `bin/sds`, `bin/alm` already use PWD-relative paths — no changes needed
- `tests/integration/helpers.sh:94` sets `FURROW_ROOT="$PROJECT_ROOT"` — add real `PROJECT_ROOT` export too

## Dependencies

- None (wave 1 — foundation deliverable)
- Downstream: config-move-and-source-todo, cross-model-ideation-review depend on this
