# Spec: phase-one-wiring

Wire existing but disconnected components together.

## Components

### 1. `scripts/validate-step-artifacts.sh`

**Interface**: `validate-step-artifacts.sh <name> <boundary>`
- Exit 0 = artifacts valid
- Exit 3 = validation failed (details on stderr)
- Exit 2 = state.json not found

**Deterministic checks per boundary**:

| Boundary | Checks |
|----------|--------|
| `research->plan` | File exists (`research.md` OR `research/synthesis.md`), non-empty, contains at least one `##` heading |
| `plan->spec` | If deliverable count > 1: `plan.json` exists AND `validate_plan_json()` passes (source `hooks/lib/validate.sh`) |
| `spec->decompose` | `spec.md` exists OR `specs/` dir has >= 1 `.md` file. If multi-deliverable: specs dir has entry per deliverable name |
| `decompose->implement` | `plan.json` exists and valid via `validate_plan_json()`. `state.json.branch` is not null/empty |
| `implement->review` | Code mode: `git diff --stat ${base_commit}..HEAD` non-empty. Research mode: `.work/{name}/deliverables/` has >= 1 non-empty file |
| `review->archive` | `reviews/` dir has a `.json` file for each deliverable in `state.json.deliverables`. Each file has `"overall": "pass"` |

**Dependencies**: Source `hooks/lib/validate.sh` (for `validate_plan_json`), `hooks/lib/common.sh` (for `read_state_field`).

### 2. `commands/lib/step-transition.sh` modification

Insert artifact validation between line 83 (gate recorded) and line 85 (fail handler):

```
if [ "${outcome}" != "fail" ]; then
  "${scripts_dir}/validate-step-artifacts.sh" "${name}" "${boundary}" || {
    echo "Artifact validation failed for ${boundary}" >&2
    exit 4
  }
fi
```

Gate is recorded first (immutable audit trail), then artifacts are checked. If validation fails, gate record exists but step does not advance.

### 3. `commands/lib/init-work-unit.sh` modifications

**New interface**: `init-work-unit.sh <name> [--title <title>] [--description <desc>] [--mode code|research] [--gate-policy supervised|delegated|autonomous]`

Changes:
- Parse named flags after positional `<name>` argument using a while loop
- `--mode`: default from `yq -r '.defaults.mode // "code"' .claude/harness.yaml`. Write to `state.json` mode field (replace hardcoded `"code"` at current line 74)
- `--gate-policy`: default from `yq -r '.defaults.gate_policy // "supervised"' .claude/harness.yaml`. Write to `.work/{name}/.gate_policy_hint`
- `--title`: default to name (current behavior)
- `--description`: default to title (current behavior)
- Create `reviews/` subdirectory: change `mkdir -p "${work_dir}"` to `mkdir -p "${work_dir}/reviews"`

**Backward compatibility**: Bare `init-work-unit.sh myname` still works (no flags = all defaults).

### 4. `scripts/select-dimensions.sh`

**Interface**: `select-dimensions.sh <name>`
- Exit 0 = path on stdout
- Exit 2 = state.json not found
- Exit 3 = dimension file not found

**Logic** (from `references/research-mode.md`):
```
mode = .mode from state.json (default: "code")
step = .step from state.json
if mode == "research" AND step == "implement": research-implement.yaml
elif mode == "research" AND step == "spec": research-spec.yaml
else: {step}.yaml
```

Output: absolute path to `evals/dimensions/{result}.yaml`. Verify file exists before output.

### 5. `scripts/evaluate-gate.sh`

**Interface**: `evaluate-gate.sh <name> <boundary> <evaluator_verdict>`
- Exit 0 = decision on stdout: PASS | FAIL | CONDITIONAL | WAIT_FOR_HUMAN

**Logic** (from `references/gate-protocol.md`):
```
gate_policy = from definition.yaml (default: "supervised")
supervised → always WAIT_FOR_HUMAN
delegated → WAIT_FOR_HUMAN for implement->review, else evaluator_verdict
autonomous → evaluator_verdict
```

**Caller**: eval runner (Phase III `run-eval.sh`), NOT step-transition.sh. Document this in script header: "This script is called by the eval runner to decide whether to auto-approve or escalate. step-transition.sh accepts explicit verdicts from human or evaluator."

**Documentation**: Also update `references/gate-protocol.md` to note this caller relationship.

### 6. Schema symlinks

```
schemas/plan.schema.json -> ../adapters/shared/schemas/plan.schema.json
schemas/review-result.schema.json -> ../adapters/shared/schemas/review-result.schema.json
```

### 7. Templates

**`templates/plan.json`**: Valid example with 2 waves, dependency ordering, file_ownership globs. Matches `adapters/shared/schemas/plan.schema.json`.

**`templates/spec.md`**: Single-deliverable spec structure with sections: Interface Contract, Acceptance Criteria (Refined), Implementation Notes, Dependencies.

### 8. Specialist frontmatter

Add YAML frontmatter to all files in `specialists/`:
```yaml
---
name: harness-engineer
description: Shell scripting, hooks, schemas, validation pipelines for workflow harness
type: specialist
---
```

This makes them loadable as skills (solo path) while still readable as plain markdown (agent prompt path). Update `references/specialist-template.md` to document the two-path consumption model.

### 9. Documentation updates

- `skills/plan.md`: Add note about CC plan mode being a within-step tool
- `skills/implement.md`: Add specialist loading instructions (solo: invoke skill, multi-agent: include in agent prompt)
- `references/specialist-template.md`: Document two-path consumption (skill invocation vs agent prompt)
- `references/gate-protocol.md`: Document evaluate-gate.sh caller relationship (eval runner, not step-transition)

## Acceptance Criteria (Refined)

1. `validate-step-artifacts.sh` blocks advancement when artifacts are missing (tested per boundary)
2. `validate-step-artifacts.sh` passes when all artifacts exist and meet deterministic quality checks
3. `step-transition.sh` calls artifact validation after gate recording, before advancement
4. `init-work-unit.sh --mode research` writes `"research"` to state.json mode field
5. `init-work-unit.sh --gate-policy delegated` writes hint file
6. `init-work-unit.sh` with no flags uses harness.yaml defaults
7. `init-work-unit.sh` creates `reviews/` subdirectory
8. `select-dimensions.sh` returns `research-implement.yaml` for research mode implement step
9. `select-dimensions.sh` returns `implement.yaml` for code mode implement step
10. `evaluate-gate.sh` returns WAIT_FOR_HUMAN for supervised mode regardless of verdict
11. Schema symlinks resolve correctly
12. Specialist templates have YAML frontmatter
13. Documentation updates reference correct caller relationships and consumption paths
