# Spec: Deliverable 7 — protocol-docs-update

## Overview

Update two shared protocol documents to reflect the new gate architecture:
1. `skills/shared/eval-protocol.md` — add Gate Evaluation section
2. `references/gate-protocol.md` — full rewrite for new architecture

**Dependency**: Deliverable 5 (script-rewire) must be complete so all script names and paths are final.

---

## File: `skills/shared/eval-protocol.md`

### Current content (complete file)

```markdown
# Evaluator Protocol — Guidelines, Dimension Loading, Two-Phase Review

## Evaluator Guidelines

1. **Run fresh**: Never evaluate from memory. Run commands, read files, inspect output NOW.
2. **Evidence first**: Gather evidence BEFORE making a judgment. Do not decide, then confirm.
3. **Binary only**: Each dimension is PASS or FAIL. If uncertain, it is FAIL. Explain why.
4. **Quote, don't paraphrase**: Evidence must be a direct quote, file path, or command output.
5. **One dimension at a time**: Evaluate independently. A FAIL on one must not bias another.
6. **State the gap for FAIL**: Say specifically what is missing or wrong, not just "insufficient."
7. **No leniency for effort**: A hard-to-build deliverable still fails if it does not meet criteria.

## Dimension Loading

Phase B review agents load rubrics from `evals/dimensions/{artifact-type}.yaml`:

| Step | Artifact Type | Dimension File |
|------|---------------|----------------|
| research | research | `evals/dimensions/research.yaml` |
| plan | plan | `evals/dimensions/plan.yaml` |
| spec | spec | `evals/dimensions/spec.yaml` |
| decompose | decompose | `evals/dimensions/decompose.yaml` |
| implement | implement | `evals/dimensions/implement.yaml` |

Each dimension has 5 fields: `name`, `definition`, `pass_criteria`, `fail_criteria`, `evidence_format`.

## Two-Phase Protocol

- **Phase A** (artifact validation): Mechanical check — artifacts present, acceptance criteria
  met, plan completion verified. If Phase A fails, Phase B does not run.
- **Phase B** (quality review): Apply dimension rubric for the artifact type. Each dimension
  produces a binary PASS/FAIL verdict with evidence. Overall Phase B is PASS only when ALL pass.
- **Overall**: PASS requires both Phase A and Phase B. A single FAIL dimension means overall FAIL.
```

### New content (complete file replacement)

```markdown
# Evaluator Protocol — Guidelines, Dimension Loading, Two-Phase Review

## Evaluator Guidelines

1. **Run fresh**: Never evaluate from memory. Run commands, read files, inspect output NOW.
2. **Evidence first**: Gather evidence BEFORE making a judgment. Do not decide, then confirm.
3. **Binary only**: Each dimension is PASS or FAIL. If uncertain, it is FAIL. Explain why.
4. **Quote, don't paraphrase**: Evidence must be a direct quote, file path, or command output.
5. **One dimension at a time**: Evaluate independently. A FAIL on one must not bias another.
6. **State the gap for FAIL**: Say specifically what is missing or wrong, not just "insufficient."
7. **No leniency for effort**: A hard-to-build deliverable still fails if it does not meet criteria.

## Dimension Loading

Phase B review agents load rubrics from `evals/dimensions/{artifact-type}.yaml`:

| Step | Artifact Type | Dimension File |
|------|---------------|----------------|
| research | research | `evals/dimensions/research.yaml` |
| plan | plan | `evals/dimensions/plan.yaml` |
| spec | spec | `evals/dimensions/spec.yaml` |
| decompose | decompose | `evals/dimensions/decompose.yaml` |
| implement | implement | `evals/dimensions/implement.yaml` |

Each dimension has 5 fields: `name`, `definition`, `pass_criteria`, `fail_criteria`, `evidence_format`.

## Gate Evaluation

Gate evaluations use `evals/gates/{step}.yaml` files, parallel to `evals/dimensions/`:

| Directory | Purpose | When loaded |
|-----------|---------|-------------|
| `evals/dimensions/` | Quality dimensions for artifact review (Phase B) | Post-step review |
| `evals/gates/` | Gate-specific criteria for step transitions | Pre-step and post-step |

### Gate YAML Structure

```yaml
# evals/gates/{step}.yaml
pre_step:  # Only for research, plan, spec, decompose
  dimensions:
    - name: "kebab-case-identifier"
      definition: "What this dimension evaluates"
      pass_criteria: "Concrete condition for PASS"
      fail_criteria: "Concrete condition for FAIL"
      evidence_format: "How to present evidence"

post_step:
  dimensions_from: "evals/dimensions/{step}.yaml"  # Reference, not duplicate
  additional_dimensions:  # Optional gate-specific criteria
    - name: "..."
      ...
```

### Key conventions

- `dimensions_from` references `evals/dimensions/` files — gate YAMLs do not duplicate dimension content
- `pre_step` dimensions are always inline (gate-specific, no shared reference)
- `additional_dimensions` under `post_step` adds gate-specific criteria beyond the standard dimensions
- Ideate, implement, and review have `post_step` only (no `pre_step`)
- Gate evaluators follow `skills/shared/gate-evaluator.md` for invocation and isolation contract

## Two-Phase Protocol

- **Phase A** (artifact validation): Mechanical check — artifacts present, acceptance criteria
  met, plan completion verified. If Phase A fails, Phase B does not run.
- **Phase B** (quality review): Apply dimension rubric for the artifact type. Each dimension
  produces a binary PASS/FAIL verdict with evidence. Overall Phase B is PASS only when ALL pass.
- **Overall**: PASS requires both Phase A and Phase B. A single FAIL dimension means overall FAIL.
```

### Diff summary

The only change is the addition of the `## Gate Evaluation` section between `## Dimension Loading` and `## Two-Phase Protocol`. All existing content is preserved verbatim. The new section is 27 lines.

---

## File: `references/gate-protocol.md`

### Current content (complete file, 98 lines)

The current file documents the old gate flow with `decided_by: human | evaluator | auto-advance` vocabulary and a single auto-advance concept.

### New content (complete file replacement)

```markdown
# Gate Protocol

## Overview

Every step transition requires a gate check. Gates enforce quality and ensure
no step advances prematurely. Gate evaluation has two phases and two moments.

## Two Evaluation Moments

| Moment | When | Question | Steps with this moment |
|--------|------|----------|----------------------|
| Pre-step | Before step begins | Should this step run, or is its output trivially determined? | research, plan, spec, decompose |
| Post-step | After step completes | Is the step's output good enough to advance? | All 7 steps |

Pre-step evaluation can determine a step adds no information beyond what previous
steps already produced. When this happens, the gate records `decided_by: prechecked`
and advances without executing the step.

## Gate Evaluation Flow

```
Step agent signals completion (or step is next in sequence)
  │
  ├─ Phase A (deterministic, shell)
  │   commands/lib/gate-precheck.sh checks structural criteria:
  │   - Deliverable count, dependencies, specialist diversity
  │   - Acceptance criteria presence and count
  │   - Mode-specific exclusions (research mode blocks research pre-step)
  │   - gate_policy and force_stop_at overrides
  │
  │   scripts/check-artifacts.sh checks artifact presence:
  │   - Deliverable files exist per file_ownership
  │   - Owned files were modified (git diff or deliverables/ check)
  │   - Acceptance criteria from definition.yaml addressed
  │
  ├─ Phase B (judgment, isolated subagent)
  │   scripts/run-gate.sh prepares evaluator inputs:
  │   - definition.yaml content
  │   - evals/gates/{step}.yaml content
  │   - Phase A results
  │   - Step output paths
  │
  │   In-context agent spawns isolated subagent (Agent tool):
  │   - Subagent loads skills/shared/gate-evaluator.md
  │   - Evaluates each dimension from gate YAML
  │   - Returns per-dimension PASS/FAIL with evidence
  │
  └─ Trust gradient (scripts/evaluate-gate.sh)
      Applies gate_policy to evaluator verdict:
      - supervised: WAIT_FOR_HUMAN
      - delegated: accept most, human for implement->review and review->archive
      - autonomous: accept all
```

## Gate Record Format

Each gate produces a record appended to `state.json.gates[]`:

```json
{
  "boundary": "{from_step}->{to_step}",
  "outcome": "pass | fail | conditional",
  "decided_by": "manual | evaluated | prechecked",
  "evidence": "one-line proof summary or path to gates/{boundary}.json",
  "conditions": ["only present when outcome is conditional"],
  "timestamp": "ISO 8601"
}
```

### decided_by Vocabulary

| Value | Meaning | When used |
|-------|---------|-----------|
| `manual` | Human reviewed and approved | supervised mode always; delegated mode for implement->review and review->archive |
| `evaluated` | Isolated subagent evaluated, trust gradient auto-approved | delegated mode (most gates); autonomous mode (all gates) |
| `prechecked` | Pre-step evaluation determined step not needed | Pre-step gate-precheck.sh + evaluator agreed step is trivial |

## Trust Gradient

The trust gradient controls human oversight of evaluator verdicts — it does NOT
control whether evaluation happens. Evaluation always runs.

| `gate_policy` | Who Decides | Pre-Step Evaluation |
|--------------|------------|---------------------|
| `supervised` | Human approves every gate (`decided_by: manual`) | Evaluator runs, verdict presented to human |
| `delegated` | Evaluator for most (`decided_by: evaluated`); human for implement->review and review->archive (`decided_by: manual`) | Allowed for all applicable steps |
| `autonomous` | Evaluator for all gates (`decided_by: evaluated`) | Allowed for all applicable steps |

Per-deliverable `gate` field overrides the top-level policy for that deliverable's
review only.

## Outcomes

| Outcome | Effect | When Used |
|---------|--------|-----------|
| `pass` | Advance to next step | Output meets all requirements |
| `fail` | Stay at current step | Output has deficiencies |
| `conditional` | Advance with conditions | Output is acceptable but has caveats |

When `outcome` is `conditional`, the `conditions` array becomes a checklist for the
next step. The next step must address all conditions before its own gate.

## Subagent Invocation Pattern

The shell layer prepares inputs but never invokes the LLM directly:

1. `scripts/run-gate.sh` runs Phase A (`scripts/check-artifacts.sh`)
2. `run-gate.sh` writes an evaluator prompt file (YAML) containing inputs for the subagent
3. `run-gate.sh` exits with code 10 ("needs subagent evaluation") and prints the prompt file path
4. The in-context agent reads the prompt file and spawns the subagent via Agent tool
5. Subagent follows `skills/shared/gate-evaluator.md` contract
6. Subagent returns structured JSON: per-dimension verdicts + overall verdict
7. In-context agent calls `scripts/evaluate-gate.sh` with the verdict to apply trust gradient

This pattern enforces generator-evaluator separation: the agent that produced the
step's output never evaluates its own work. The subagent runs with fresh context
and no access to the conversation that generated the artifacts.

## Extended Gate File

When full review evidence is needed beyond the one-line summary, write a structured
file to `gates/{from}-to-{to}.json`:

```json
{
  "boundary": "{from}->{to}",
  "dimensions": [
    { "name": "dimension-name", "verdict": "pass|fail", "evidence": "one-line" }
  ],
  "overall": "pass | fail | conditional",
  "reviewer": "agent identifier",
  "cross_model": false,
  "notes": "optional reviewer narrative",
  "timestamp": "ISO 8601"
}
```

## Step Boundary Protocol

At every boundary:
1. Gate check evaluates step output (Phase A + Phase B).
2. Gate record appended to `state.json.gates[]`.
3. `summary.md` regenerated (latest version only; previous in git history).
4. `state.json.step` advanced; `step_status` set to `not_started`.
5. `state.json.updated_at` refreshed.
```

---

## Verification Checklist

After applying all changes:

1. `skills/shared/eval-protocol.md` contains a `## Gate Evaluation` section
2. `skills/shared/eval-protocol.md` references `evals/gates/` and `skills/shared/gate-evaluator.md`
3. `skills/shared/eval-protocol.md` documents `dimensions_from` and `pre_step/post_step` structure
4. `references/gate-protocol.md` contains no references to old decided_by values (`human`, `evaluator`, `auto-advance`)
5. `references/gate-protocol.md` documents Phase A + Phase B gate flow
6. `references/gate-protocol.md` documents `manual | evaluated | prechecked` vocabulary
7. `references/gate-protocol.md` documents the subagent invocation pattern
8. `references/gate-protocol.md` documents two evaluation moments (pre-step and post-step)
9. No reference to `scripts/auto-advance.sh`, `scripts/run-eval.sh`, or `commands/lib/auto-advance.sh` in either file
