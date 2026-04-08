# Spec: specialist-template-enforcement

## Interface Contract

**Shell-level validation** (in `bin/frw.d/scripts/generate-plan.sh`):
After plan.json is written, validate each specialist assignment references an existing file.
```sh
# After plan.json write, before return
for specialist in $(jq -r '.waves[].assignments[].specialist // empty' "$plan_file" | sort -u); do
  if [ ! -f "${FURROW_ROOT}/specialists/${specialist}.md" ]; then
    echo "Warning: specialist template not found: specialists/${specialist}.md" >&2
  fi
done
```
Exit code: 0 (warning only, not blocking).

**Skill-level change** (in `skills/implement.md`):
Lines 25-33 — change from "STOP" / "blocking requirement" to warn+proceed:
- Agent warns on stderr if specialist file missing
- Agent proceeds with dispatch, notes missing specialist in review evidence
- Agent still MUST attempt to load the specialist template

## Acceptance Criteria (Refined)

1. `generate-plan.sh` warns on stderr when a specialist assignment references a non-existent `specialists/{name}.md` file
2. `generate-plan.sh` continues to exit 0 after the warning (not blocking)
3. `skills/implement.md` instructs agents to warn and proceed when specialist template is missing (not STOP)
4. `skills/implement.md` retains the instruction to load specialist templates as the default behavior

## Test Scenarios

### Scenario: Missing specialist warning during plan generation
- **Verifies**: AC 1, 2
- **WHEN**: plan.json assigns specialist `"nonexistent-expert"` and `specialists/nonexistent-expert.md` does not exist
- **THEN**: `frw generate-plan <name>` prints warning to stderr and exits 0
- **Verification**: `frw generate-plan <name> 2>&1 >/dev/null | grep -q 'Warning: specialist template not found'`

### Scenario: Valid specialist passes silently
- **Verifies**: AC 1
- **WHEN**: plan.json assigns specialist `"harness-engineer"` and `specialists/harness-engineer.md` exists
- **THEN**: No warning on stderr
- **Verification**: `frw generate-plan <name> 2>&1 >/dev/null | grep -c 'Warning'` equals 0

## Implementation Notes

- The validation loop goes after the plan.json write in generate-plan.sh, not before
- Use `FURROW_ROOT` for specialist file path (specialists are install-relative, not project-relative)
- Only change the language in implement.md lines 25-33 — do not restructure the surrounding sections
- Keep the skill injection order reference (line 56) unchanged

## Dependencies

- None (independent of wave 1, but scheduled in wave 2 for simplicity)
- `generate-plan.sh` is also modified by project-root-resolution (different lines: 29-30 vs new code at end)
