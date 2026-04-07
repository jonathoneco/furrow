# Spec: stop-hook-exit-codes

## Interface Contract

Three hook scripts in `bin/frw.d/hooks/`:

**validate-summary.sh** — `hook_validate_summary()`
- Arguments: optional `$1` step name for step-aware validation
- Exit 0: valid, no active row, no summary, or prechecked gate
- Exit 2: validation failure (missing sections or empty agent-written sections)
- Stdin: none (Stop hook, no tool input)

**stop-ideation.sh** — `hook_stop_ideation()`
- Arguments: none
- Exit 0: not in ideation, autonomous mode, or all markers present
- Exit 2: in ideation step with supervised/delegated policy and missing section markers
- Stdin: none
- Section markers to validate: `<!-- ideation:section:{name} -->` for objective, deliverables, context-pointers, constraints, gate-policy

**work-check.sh** — `hook_work_check()`
- No changes. Stays exit 0 always (informational).

## Acceptance Criteria (Refined)

1. `validate-summary.sh` returns exit 2 (not exit 1) when summary.md validation fails
2. `validate-summary.sh` comment header documents exit 2 as the failure code
3. `validate-summary.sh` exit 0 paths unchanged: no active row, no summary, prechecked gate, validation passes
4. `stop-ideation.sh` validates definition.yaml has all required fields (objective, deliverables, context_pointers, constraints, gate_policy) when step=ideate and gate_policy is supervised or delegated
5. `stop-ideation.sh` returns exit 2 when required fields are missing or empty
6. `stop-ideation.sh` returns exit 0 when not in ideation, autonomous mode, or all markers present
7. `work-check.sh` remains unchanged (exit 0 always, informational only)

## Test Scenarios

### Scenario: validate-summary blocks on missing sections
- **Verifies**: AC 1, 3
- **WHEN**: Active row in research step, summary.md exists but missing "Key Findings" section
- **THEN**: Hook returns exit 2 with error message naming the missing section
- **Verification**: `frw hook validate-summary; echo $?` → outputs error, exits 2

### Scenario: validate-summary passes valid summary
- **Verifies**: AC 3
- **WHEN**: Active row with complete summary.md (all sections, all non-empty)
- **THEN**: Hook returns exit 0
- **Verification**: `frw hook validate-summary; echo $?` → exits 0

### Scenario: stop-ideation blocks missing markers
- **Verifies**: AC 4, 5
- **WHEN**: Active row in ideate step, supervised mode, summary.md has no `<!-- ideation:section:* -->` markers
- **THEN**: Hook returns exit 2 listing missing markers
- **Verification**: `frw hook stop-ideation; echo $?` → exits 2

### Scenario: stop-ideation skips non-ideation steps
- **Verifies**: AC 6
- **WHEN**: Active row in research step
- **THEN**: Hook returns exit 0 immediately
- **Verification**: `frw hook stop-ideation; echo $?` → exits 0

## Implementation Notes

- validate-summary.sh: single change — line 73 `return 1` → `return 2`, line 11 comment update
- stop-ideation.sh: needs implementation of marker scanning. Use `grep -c` to check for markers in summary.md. Read summary.md (not conversation) since markers are emitted as HTML comments.
- Pattern: match existing hook style — source common.sh, use `find_focused_row()`, early return 0 for skip cases
- Exit code convention: 0=allow, 2=block. Never use 1 (non-blocking error zone).

## Dependencies

- `bin/frw.d/lib/common.sh` — `find_focused_row()`, `log_error()`
- `.claude/settings.json` — hooks registered under Stop lifecycle
