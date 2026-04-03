# Spec: phase-two-capabilities

New operational capabilities built on Phase I wiring.

## Components

### 1. `scripts/generate-plan.sh`

**Interface**: `generate-plan.sh <name>`
- Exit 0 = plan.json written
- Exit 2 = definition.yaml not found
- Exit 3 = validation error (missing specialist, cycle detected, etc.)

**Logic**:
1. Read deliverables from `.work/{name}/definition.yaml` (name, depends_on, specialist, file_ownership)
2. **Require specialist field** on every deliverable — error if any deliverable is missing it
3. Build dependency graph from depends_on fields
4. Topological sort to assign waves:
   - Wave 1: deliverables with no dependencies
   - Wave N: deliverables whose ALL dependencies are in waves < N
   - Cycle detection: if any deliverable can't be assigned, error with cycle details
5. Build assignments map per deliverable: specialist (from definition), file_ownership (from definition), skills (empty array default)
6. Add metadata: `created_at` (ISO 8601), `created_by: "generate-plan"`
7. Write to temp file, validate with `validate_plan_json` (source `hooks/lib/validate.sh`), atomic move to `.work/{name}/plan.json`

**Topological sort implementation**: Use Python for the graph walk (follow pattern from `scripts/validate-definition.sh` lines 85-131 which already does cycle detection in Python). Shell handles I/O and validation.

**Wave conflict check integration**: After writing plan.json, also add a call to `scripts/check-wave-conflicts.sh` in `commands/lib/step-transition.sh` at the `implement->review` boundary (non-blocking warning).

### 2. `hooks/correction-limit.sh`

**Interface**: Hook on PreToolUse (Write|Edit) during implement step
- Exit 0 = allowed
- Exit 2 = blocked (correction limit reached, message on stderr)

**Logic**:
1. Read stdin for hook JSON (tool_name, tool_input.file_path)
2. Find active work unit via inline discovery (same pattern as stop-ideation.sh)
3. Check current step is `implement` — if not, exit 0
4. Read `state.json.deliverables` — for each deliverable, check `corrections` field
5. Map file being written to a deliverable via file_ownership globs in plan.json
6. If the matched deliverable has `corrections >= limit`, exit 2 with error message
7. Limit from `.claude/harness.yaml` `defaults.correction_limit` (default: 3)

**Correction increment**: When `step-transition.sh` records a gate with outcome `fail` during the implement or review step, it also increments the `corrections` count for the relevant deliverable via `scripts/update-state.sh`. Add this to step-transition.sh's fail handler (line 87-91).

**Hook registration**: Add to `.claude/settings.json` PreToolUse Write|Edit matcher:
```json
{ "type": "command", "command": "hooks/correction-limit.sh" }
```

**Config**: Add to `.claude/harness.yaml` under defaults:
```yaml
correction_limit: 3
```

## Acceptance Criteria (Refined)

1. `generate-plan.sh` produces valid plan.json from a multi-deliverable definition.yaml
2. `generate-plan.sh` errors when any deliverable is missing the specialist field
3. `generate-plan.sh` errors on dependency cycles
4. `generate-plan.sh` assigns independent deliverables to the same wave
5. `generate-plan.sh` output passes `validate_plan_json`
6. `correction-limit.sh` exits 0 when corrections < limit
7. `correction-limit.sh` exits 2 with message when corrections >= limit for the deliverable owning the file
8. `correction-limit.sh` exits 0 when current step is not implement
9. Gate failure during implement/review increments correction count for relevant deliverable
10. `check-wave-conflicts.sh` runs at implement->review boundary (non-blocking)
