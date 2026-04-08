# Spec: cross-model-ideation-review

## Interface Contract

**New CLI interface**:
```
frw cross-model-review <name> --ideation
```

**Behavior**:
- Reads `definition.yaml` for objective, deliverables, constraints
- Reads `summary.md` for Open Questions section
- Builds ideation framing review prompt
- Invokes cross-model provider (codex or claude --model)
- Parses structured JSON response
- Writes result to `reviews/ideation-cross.json`

**Exit codes** (same as existing):
- 0: review complete, result written
- 1: usage error or provider not configured
- 2: invocation failed or parse error

**Codex fix**: All codex exec invocations include `-c 'approval_policy="never"'`.

## Acceptance Criteria (Refined)

1. `frw cross-model-review <name> --ideation` reads definition.yaml + summary.md and produces a framing review
2. Output JSON written to `.furrow/rows/{name}/reviews/ideation-cross.json`
3. Codex exec invocations include `approval_policy="never"` to prevent interactive hang
4. Script uses `$PROJECT_ROOT` (not `$FURROW_ROOT`) for project data paths (covered by wave 1)
5. `skills/ideate.md` documents `frw cross-model-review <name> --ideation` as the correct invocation
6. Existing deliverable-level review (`frw cross-model-review <name> <deliverable>`) continues to work

## Test Scenarios

### Scenario: Ideation review produces output
- **Verifies**: AC 1, 2
- **WHEN**: Row has definition.yaml and summary.md, cross_model.provider configured
- **THEN**: `frw cross-model-review infra-fixes --ideation` exits 0, `reviews/ideation-cross.json` exists
- **Verification**: `frw cross-model-review infra-fixes --ideation && test -f .furrow/rows/infra-fixes/reviews/ideation-cross.json`

### Scenario: Codex doesn't hang
- **Verifies**: AC 3
- **WHEN**: Provider is codex, no interactive terminal
- **THEN**: codex exec runs non-interactively with approval_policy=never
- **Verification**: `grep -q 'approval_policy' bin/frw.d/scripts/cross-model-review.sh`

### Scenario: Existing deliverable review unbroken
- **Verifies**: AC 6
- **WHEN**: `frw cross-model-review <name> <deliverable>` called with existing args
- **THEN**: Behavior unchanged
- **Verification**: No `--ideation` flag → original code path runs

## Implementation Notes

### Flag parsing:
```sh
# At top of frw_cross_model_review()
ideation=false
while [ $# -gt 0 ]; do
  case "$1" in
    --ideation) ideation=true; shift ;;
    *) break ;;
  esac
done
```

If `$ideation` is true, call `frw_cross_model_review_ideation "$@"`.
Otherwise, existing `frw_cross_model_review "$@"` logic runs.

### Ideation prompt structure:
```
You are reviewing the ideation framing for row '{name}'.

## Objective
{definition.yaml objective}

## Deliverables
{list with names, dependencies, acceptance criteria counts}

## Constraints
{definition.yaml constraints}

## Open Questions
{summary.md ## Open Questions section, or "None documented"}

## Instructions
Evaluate: (1) feasibility, (2) deliverable-objective alignment,
(3) dependency validity, (4) constraint adequacy, (5) risk assessment.

Output JSON: {"dimensions": [...], "framing_quality": "sound|questionable|unsound", "suggested_revisions": [...]}
```

### Codex fix (both invocation paths):
```sh
# Line ~120 (codex with model)
response="$(codex exec -c 'approval_policy="never"' -m "$_model" "$prompt" 2>"$_invoke_err")" || true
# Line ~122 (codex default)
response="$(codex exec -c 'approval_policy="never"' "$prompt" 2>"$_invoke_err")" || true
```

### Output file:
Write to `${work_dir}/reviews/ideation-cross.json` with structure:
```json
{
  "type": "ideation",
  "dimensions": [...],
  "framing_quality": "sound|questionable|unsound",
  "suggested_revisions": [...],
  "reviewer": "{provider}",
  "cross_model": true,
  "timestamp": "..."
}
```

### frw usage text update:
```
cross-model-review <name> <deliverable>   Run cross-model review
cross-model-review <name> --ideation      Run ideation framing review
```

## Dependencies

- Depends on: project-root-resolution (FURROW_ROOT→PROJECT_ROOT in lines 23, 26)
- The PROJECT_ROOT fix is in wave 1; this deliverable is wave 2
