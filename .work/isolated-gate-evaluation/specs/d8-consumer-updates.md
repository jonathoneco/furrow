# Spec: Deliverable 8 — consumer-updates

## Overview

Update all consumers of old terminology, script paths, and `decided_by` vocabulary. Grouped by change type. Every change shows exact old text and new text for mechanical application.

**Dependency**: Deliverables 6 (skill-docs-alignment) and 7 (protocol-docs-update) must be complete.

---

## Group 1: decided_by Vocabulary Changes (hardcoded values)

### File: `adapters/agent-sdk/callbacks/gate_callback.py`

Two occurrences of `"evaluator"` as a `decided_by` value.

#### Change 1a (line 77, in `_autonomous_gate`)

**Old:**
```python
        "decided_by": "evaluator",
```

**New:**
```python
        "decided_by": "evaluated",
```

#### Change 1b (line 110, in `_delegated_gate`)

**Old:**
```python
        "decided_by": "evaluator",
```

**New:**
```python
        "decided_by": "evaluated",
```

---

### File: `commands/lib/rewind.sh`

One occurrence of `"human"` as a `decided_by` value.

#### Change 2 (line 69)

**Old:**
```sh
"${scripts_dir}/record-gate.sh" "${name}" "${boundary}" "fail" "human" \
  "User rewound: auto-advance was incorrect or step needs rework"
```

**New:**
```sh
"${scripts_dir}/record-gate.sh" "${name}" "${boundary}" "fail" "manual" \
  "User rewound: pre-step evaluation was incorrect or step needs rework"
```

---

### File: `commands/redirect.md`

One example showing `decided_by: "human"`.

#### Change 3 (lines 14-21)

**Old:**
```markdown
3. Record redirect as a fail gate entry in `state.json.gates[]`:
   ```json
   {
     "boundary": "{current_step}->{current_step}",
     "outcome": "fail",
     "decided_by": "human",
     "evidence": "Redirect: {reason}",
     "timestamp": "{ISO 8601 now}"
   }
   ```
```

**New:**
```markdown
3. Record redirect as a fail gate entry in `state.json.gates[]`:
   ```json
   {
     "boundary": "{current_step}->{current_step}",
     "outcome": "fail",
     "decided_by": "manual",
     "evidence": "Redirect: {reason}",
     "timestamp": "{ISO 8601 now}"
   }
   ```
```

---

## Group 2: Script Path Reference Updates

### File: `commands/work.md`

Three references to old script names.

#### Change 4a (line 23)

**Old:**
```markdown
  -> If step_status is "completed": run `commands/lib/step-transition.sh`
```

No change needed — `step-transition.sh` is not renamed.

#### Change 4b (line 25, after transition)

**Old:**
```markdown
  -> After any transition: run `commands/lib/auto-advance.sh`
```

**New:**
```markdown
  -> After any transition: run `commands/lib/gate-precheck.sh` then `scripts/run-gate.sh`
```

#### Change 4c (lines 53-54, Step Routing After Transition section)

**Old:**
```markdown
## Step Routing After Transition

After `step-transition.sh` advances the step:
1. Run `commands/lib/auto-advance.sh "{name}"` for trivial step detection.
2. If auto-advanced, repeat until a non-trivial step is reached.
3. Load the new step's skill and begin.
```

**New:**
```markdown
## Step Routing After Transition

After `step-transition.sh` advances the step:
1. Run `commands/lib/gate-precheck.sh` to check if the next step is trivially resolvable.
2. If precheck passes, run `scripts/run-gate.sh` for evaluator confirmation.
3. If prechecked and confirmed, repeat until a non-trivial step is reached.
4. Load the new step's skill and begin.
```

---

### File: `commands/checkpoint.md`

One reference to old script name.

#### Change 5 (line 24-25)

**Old:**
```markdown
9. After transition: run `commands/lib/auto-advance.sh "{name}"`.
```

**New:**
```markdown
9. After transition: run `commands/lib/gate-precheck.sh` then `scripts/run-gate.sh` for pre-step evaluation.
```

---

### File: `adapters/claude-code/commands/work.md`

One reference to work loader skill.

#### Change 6 (lines 28-33, Context Loading section)

**Old:**
```markdown
## Context Loading
This command triggers the work loader skill (`skills/work-loader.md`) which handles:
- Work unit discovery
- State reading and display
- Step skill injection
- Progressive context loading
```

**New:**
```markdown
## Context Loading
This command triggers the work loader skill (`skills/work-loader.md`) which handles:
- Work unit discovery
- State reading and display
- Step skill injection
- Progressive context loading
- Pre-step evaluation via `commands/lib/gate-precheck.sh` and `scripts/run-gate.sh`
```

Note: The adapter `work.md` does not directly reference `auto-advance.sh`. The addition documents the new gate flow entry point. If the file references `auto-advance.sh` elsewhere (check via grep), update those references to `gate-precheck.sh` / `run-gate.sh`.

---

### File: `adapters/claude-code/skills/gate-prompt.md`

#### Change 7 (line 54, Rules section)

**Old:**
```markdown
- Per-deliverable gate overrides (`gate: human | automated`) take precedence.
```

**New:**
```markdown
- Per-deliverable gate overrides take precedence over top-level `gate_policy`.
```

Note: The old text used `human | automated` which was already inconsistent with the vocabulary. The new text avoids embedding specific values.

---

## Group 3: Terminology Updates

### File: `ROADMAP.md`

Multiple references to "auto-advance" and old script names.

#### Change 8a (line 10, Dependency DAG)

**Old:**
```
         ┌── T5 (Auto-Advance) ·····················── [terminal]
```

**New:**
```
         ┌── T5 (Gate Evaluation) ··················── [terminal]
```

#### Change 8b (lines 28-29, File Conflict Zones)

**Old:**
```
| Auto-advance pipeline | `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh`, `skills/spec.md` | T5 only |
```

**New:**
```
| Gate evaluation pipeline | `commands/lib/gate-precheck.sh`, `scripts/run-gate.sh`, `scripts/check-artifacts.sh`, `skills/spec.md` | T5 only |
```

#### Change 8c (line 35, Eval scripts zone)

**Old:**
```
| Eval scripts | `scripts/run-eval.sh`, `hooks/correction-limit.sh`, `scripts/generate-plan.sh` | T10 only |
```

**New:**
```
| Eval scripts | `scripts/check-artifacts.sh`, `hooks/correction-limit.sh`, `scripts/generate-plan.sh` | T10 only |
```

#### Change 8d (line 62, Phase 1 lessons)

**Old:**
```
- T3 found real bugs in `run-eval.sh`, `select-dimensions.sh`, `auto-advance.sh`, `step-transition.sh`, `promote-components.sh`, `skills/plan.md` — Phase 2 work should re-read these files as they've changed since the original TODO descriptions were written.
```

**New:**
```
- T3 found real bugs in `check-artifacts.sh` (formerly `run-eval.sh`), `select-dimensions.sh`, `gate-precheck.sh` (formerly `auto-advance.sh`), `step-transition.sh`, `promote-components.sh`, `skills/plan.md` — Phase 2 work should re-read these files as they've changed since the original TODO descriptions were written.
```

#### Change 8e (lines 79-86, Track 2a section)

**Old:**
```
### Track 2a: T5 — Auto-Advance Enforcement

**Work description**: Decide and implement whether auto-advance criteria should be harness-enforced (deterministic shell checks) or evaluator-judged (prose in skills). Add testability checks if going the enforcement route.

**Branch**: `work/auto-advance`
**Key files**: `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh`, `skills/spec.md`
**Conflict risk**: None — auto-advance pipeline is isolated.
**Note**: T3 modified `commands/lib/auto-advance.sh` — re-read before starting.
```

**New:**
```
### Track 2a: T5 — Gate Evaluation Rearchitecture

**Work description**: Rearchitect gate evaluation with isolated subagent evaluators (generator-evaluator separation), pre-step/post-step evaluation moments, and deterministic shell prechecks. Trust gradient controls human oversight of evaluator verdicts.

**Branch**: `work/auto-advance`
**Key files**: `commands/lib/gate-precheck.sh`, `scripts/run-gate.sh`, `scripts/check-artifacts.sh`, `evals/gates/`, `skills/shared/gate-evaluator.md`
**Conflict risk**: None — gate evaluation pipeline is isolated.
**Note**: T3 modified the pre-filter script — re-read `commands/lib/gate-precheck.sh` before starting.
```

#### Change 8f (line 131, Track 3b reference)

**Old:**
```
**Key files**: New `scripts/run-integration-tests.sh` + test fixtures. Tests (reads) `scripts/generate-plan.sh`, `hooks/correction-limit.sh`, `scripts/run-eval.sh`, `commands/lib/step-transition.sh`, `commands/lib/load-step.sh`
```

**New:**
```
**Key files**: New `scripts/run-integration-tests.sh` + test fixtures. Tests (reads) `scripts/generate-plan.sh`, `hooks/correction-limit.sh`, `scripts/check-artifacts.sh`, `commands/lib/step-transition.sh`, `commands/lib/load-step.sh`
```

#### Change 8g (lines 169, 174, Worktree Quick Reference)

No changes needed — branch name `work/auto-advance` stays as-is (it is a git branch name, not terminology).

---

### File: `todos.yaml`

#### Change 9a (id and title, lines 1-2)

**Old:**
```yaml
- id: auto-advance-enforcement
  title: "Auto-Advance Enforcement"
```

**New:**
```yaml
- id: gate-evaluation-rearchitecture
  title: "Gate Evaluation Rearchitecture"
```

#### Change 9b (context field, lines 3-4)

**Old:**
```yaml
  context: |
    Currently, auto-advance eligibility is checked by the gate evaluator reading skill instructions (prose). The `commands/lib/auto-advance.sh` script checks some criteria (deliverable count, dependencies, gate_policy) but doesn't enforce all the conditions described in each step skill.
```

**New:**
```yaml
  context: |
    Gate evaluation rearchitected: isolated subagent evaluators (generator-evaluator separation), pre-step/post-step evaluation moments, deterministic shell prechecks via `commands/lib/gate-precheck.sh`. Trust gradient controls human oversight.
```

#### Change 9c (work_needed field, lines 5-12)

**Old:**
```yaml
  work_needed: |
    Open question (from plan step Q&A): should auto-advance criteria be harness-enforced (shell checks that block/allow auto-advance) or remain evaluator-judged (prose in skills)?

    Examples of unenforced criteria:
    - spec step: auto-advance when single deliverable with >=2 testable ACs. But nothing checks AC testability (verbs, thresholds, file paths).
    - research step: auto-advance when single deliverable + code mode + has path-like ACs. But "path-like" is a fuzzy check.

    Decision needed: Is it worth adding deterministic testability checks to auto-advance, or is the current approach (evaluator judges) sufficient?
```

**New:**
```yaml
  work_needed: |
    Resolved: hybrid approach. Shell prechecks (gate-precheck.sh) handle deterministic structural criteria; isolated subagent evaluators handle judgment calls. Trust gradient controls human oversight of evaluator verdicts. See .work/isolated-gate-evaluation/ for full implementation.
```

#### Change 9d (references field, lines 13-17)

**Old:**
```yaml
  references:
    - "commands/lib/auto-advance.sh"
    - "scripts/auto-advance.sh"
    - "skills/spec.md"
    - ".work/harness-v2-status-eval/recommendations.md"
```

**New:**
```yaml
  references:
    - "commands/lib/gate-precheck.sh"
    - "scripts/run-gate.sh"
    - "scripts/check-artifacts.sh"
    - "evals/gates/"
    - "skills/shared/gate-evaluator.md"
```

---

### File: `commands/lib/step-transition.sh`

Update interface documentation (comment header only, not runtime behavior).

#### Change 10 (lines 3-9, header comment)

**Old:**
```sh
# Usage: step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]
#   name            — work unit name
#   outcome         — "pass" | "fail" | "conditional"
#   decided_by      — "human" | "evaluator" | "auto-advance"
#   evidence        — one-line proof summary
#   conditions_json — JSON array (required for conditional)
```

**New:**
```sh
# Usage: step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]
#   name            — work unit name
#   outcome         — "pass" | "fail" | "conditional"
#   decided_by      — "manual" | "evaluated" | "prechecked"
#   evidence        — one-line proof summary
#   conditions_json — JSON array (required for conditional)
```

---

## Group 4: Structural Updates

### File: `_rationale.yaml`

#### Change 11a: Update existing auto-advance entry (around line 131-133)

**Old:**
```yaml
  - path: scripts/auto-advance.sh
    exists_because: "Claude Code has no built-in trivial step detection and auto-advance"
    delete_when: "Claude Code supports workflow primitives with auto-advance logic"
```

**New:**
```yaml
  - path: scripts/run-gate.sh
    exists_because: "Claude Code has no built-in gate orchestration (Phase A shell + Phase B subagent)"
    delete_when: "Claude Code supports workflow primitives with gate evaluation"

  - path: scripts/check-artifacts.sh
    exists_because: "Claude Code has no built-in Phase A artifact validation for gate checks"
    delete_when: "Claude Code supports workflow primitives with artifact validation"

  - path: scripts/select-gate.sh
    exists_because: "Claude Code has no built-in gate YAML selection for step transitions"
    delete_when: "Claude Code supports workflow primitives with gate configuration"
```

#### Change 11b: Update existing commands/lib/auto-advance.sh entry (around line 384-386)

**Old:**
```yaml
  - path: commands/lib/auto-advance.sh
    exists_because: "Claude Code has no native trivial step detection and auto-advance"
    delete_when: "Claude Code supports workflow auto-advance based on definition shape"
```

**New:**
```yaml
  - path: commands/lib/gate-precheck.sh
    exists_because: "Claude Code has no native deterministic pre-step evaluation (structural checks before subagent)"
    delete_when: "Claude Code supports workflow primitives with pre-step evaluation"
```

#### Change 11c: Add new entries for gate evaluation components (after the existing evals section, around line 237)

Insert after the last `evals/dimensions/` entry:

```yaml
  # --- Gate evaluation (Phase 3: Alignment) ---
  - path: evals/gates/
    exists_because: "Gate decisions need structured YAML rubrics with pre_step and post_step dimensions"
    delete_when: "Claude Code provides built-in gate evaluation rubrics"

  - path: skills/shared/gate-evaluator.md
    exists_because: "Isolated subagent evaluators need a contract for inputs, prohibited context, and response format"
    delete_when: "Claude Code provides built-in generator-evaluator separation for workflow gates"
```

#### Change 11d: Update scripts/run-eval.sh entry if present

If `scripts/run-eval.sh` exists in `_rationale.yaml`, replace with `scripts/check-artifacts.sh` entry. If not present, the `check-artifacts.sh` entry in Change 11a covers it.

---

### File: `scripts/harness-doctor.sh`

#### Change 12a: Add gate YAML validation check

Insert a new check section after "Spec-mandated files (Phase 5)" section (after line 249), before the "Unfilled placeholder sections" section:

**New section to insert:**

```sh
# --- Check: Gate evaluation files ---
section "Gate evaluation files"
_gate_missing=0
for _step in ideation research plan spec decompose implement review; do
  if [ ! -f "$ROOT/evals/gates/${_step}.yaml" ]; then
    check_fail "evals/gates/${_step}.yaml missing"
    _gate_missing=$((_gate_missing + 1))
  fi
done
if [ -f "$ROOT/scripts/run-gate.sh" ]; then
  :
else
  check_fail "scripts/run-gate.sh missing"
  _gate_missing=$((_gate_missing + 1))
fi
if [ -f "$ROOT/scripts/check-artifacts.sh" ]; then
  :
else
  check_fail "scripts/check-artifacts.sh missing"
  _gate_missing=$((_gate_missing + 1))
fi
if [ -f "$ROOT/commands/lib/gate-precheck.sh" ]; then
  :
else
  check_fail "commands/lib/gate-precheck.sh missing"
  _gate_missing=$((_gate_missing + 1))
fi
if [ -f "$ROOT/skills/shared/gate-evaluator.md" ]; then
  :
else
  check_fail "skills/shared/gate-evaluator.md missing"
  _gate_missing=$((_gate_missing + 1))
fi
if [ "$_gate_missing" -eq 0 ]; then
  check_pass "all gate evaluation files present"
fi

# --- Check: Old script names absent ---
section "Renamed script cleanup"
_stale_scripts=0
for _old in "scripts/auto-advance.sh" "scripts/run-eval.sh" "commands/lib/auto-advance.sh"; do
  if [ -f "$ROOT/$_old" ]; then
    check_fail "stale script not removed: $_old"
    _stale_scripts=$((_stale_scripts + 1))
  fi
done
if [ "$_stale_scripts" -eq 0 ]; then
  check_pass "all renamed scripts cleaned up"
fi
```

---

### File: `docs/architecture/file-structure.md`

#### Change 13: Add evals/gates/ to the evals section

The current evals section describes behavioral evals. Add the gate evaluation directory.

Locate the `evals/` description in the Harness Layout tree (around line 54) and the evals section description (around line 136).

**In the Harness Layout tree, add after the existing evals entries:**

After:
```
├── evals/                          # Harness behavioral evals
│   ├── test_work_entry.py          # Behavior 1: work def loaded at start
```

Add:
```
│   ├── dimensions/                 # Quality dimension rubrics per artifact type
│   │   ├── research.yaml
│   │   ├── plan.yaml
│   │   ├── spec.yaml
│   │   ├── decompose.yaml
│   │   └── implement.yaml
│   ├── gates/                      # Gate evaluation rubrics per step
│   │   ├── ideation.yaml           # Post-step only
│   │   ├── research.yaml           # Pre-step + post-step
│   │   ├── plan.yaml               # Pre-step + post-step
│   │   ├── spec.yaml               # Pre-step + post-step
│   │   ├── decompose.yaml          # Pre-step + post-step
│   │   ├── implement.yaml          # Post-step only
│   │   └── review.yaml             # Post-step only
```

**In the evals section description, add a paragraph:**

After the existing evals description, add:

```markdown
### evals/gates/ — Gate evaluation rubrics

Gate YAML files define the dimensions used for pre-step and post-step evaluation
at each step boundary. Pre-step dimensions determine whether a step can be skipped
(applies to research, plan, spec, decompose). Post-step dimensions evaluate the
quality of step output. Post-step sections reference `evals/dimensions/` via
`dimensions_from` to avoid duplication.

| File | Pre-step | Post-step |
|------|----------|-----------|
| `ideation.yaml` | No | Yes (completeness, alignment, feasibility, cross-model) |
| `research.yaml` | Yes (path-relevance) | Yes (dimensions_from research.yaml) |
| `plan.yaml` | Yes (complexity-assessment) | Yes (dimensions_from plan.yaml) |
| `spec.yaml` | Yes (testability) | Yes (dimensions_from spec.yaml) |
| `decompose.yaml` | Yes (wave-triviality) | Yes (dimensions_from decompose.yaml) |
| `implement.yaml` | No | Yes (dimensions_from implement.yaml) |
| `review.yaml` | No | Yes (Phase A + B aggregate) |
```

**Update script references in the file-structure description if present.** Any reference to `scripts/auto-advance.sh` should become `scripts/run-gate.sh`. Any reference to `scripts/run-eval.sh` should become `scripts/check-artifacts.sh`. Any reference to `commands/lib/auto-advance.sh` should become `commands/lib/gate-precheck.sh`.

---

## Group 5: Migration Note

### Where to add

Add a `## Migration Notes` section at the bottom of the work unit's `summary.md` (or a standalone `MIGRATION.md` in the work unit directory) before archive.

### Content

```markdown
## Migration Note: Gate Record decided_by Values

When this branch merges to main, any existing archived work units in `.work/`
may contain gate records with old `decided_by` values:

| Old value | New value |
|-----------|-----------|
| `human` | `manual` |
| `evaluator` | `evaluated` |
| `auto-advance` | `prechecked` |

### Impact

- **Read-only consumers** (summary display, status commands): will show old values
  until records are migrated. No runtime breakage.
- **Validation consumers** (`record-gate.sh`, `update-state.sh`): only validate
  NEW records. Old records in the `gates[]` array are append-only and never
  re-validated.
- **Schema validation** (`state.schema.json`): the `decided_by` enum now accepts
  only `manual | evaluated | prechecked`. Old records will fail schema validation
  if the full `gates[]` array is validated.

### Recommended Migration

After merge to main, run a one-time migration on each `.work/*/state.json`:

```sh
# For each active or archived work unit:
for f in .work/*/state.json; do
  jq '
    .gates |= map(
      if .decided_by == "human" then .decided_by = "manual"
      elif .decided_by == "evaluator" then .decided_by = "evaluated"
      elif .decided_by == "auto-advance" then .decided_by = "prechecked"
      else . end
    )
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
done
```

This migration is safe because:
- Gate records are append-only (no new writes target old records)
- The mapping is 1:1 (no ambiguity)
- All existing records in practice use `"human"` (no evaluator or auto-advance records exist yet)
```

---

## Verification Checklist

After applying all changes, run these grep sweeps to confirm completeness:

```sh
# 1. No old decided_by values in consumer files
grep -rn '"human"\|"evaluator"\|"auto-advance"' \
  adapters/agent-sdk/callbacks/gate_callback.py \
  commands/lib/rewind.sh \
  commands/redirect.md \
  commands/lib/step-transition.sh \
  skills/work-context.md

# 2. No old script names in consumer files
grep -rn 'auto-advance\.sh\|run-eval\.sh' \
  commands/work.md \
  commands/checkpoint.md \
  adapters/claude-code/commands/work.md \
  adapters/claude-code/skills/gate-prompt.md \
  ROADMAP.md \
  todos.yaml \
  _rationale.yaml

# 3. New gate files referenced in harness-doctor
grep -q 'evals/gates' scripts/harness-doctor.sh

# 4. New evals/gates/ in file-structure.md
grep -q 'evals/gates/' docs/architecture/file-structure.md

# 5. Migration note exists
grep -q 'decided_by.*migration\|Migration.*decided_by' \
  .work/isolated-gate-evaluation/summary.md \
  .work/isolated-gate-evaluation/MIGRATION.md 2>/dev/null
```

All grep commands should return expected results (items 1-2 should return no matches; items 3-5 should return matches).
