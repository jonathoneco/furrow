# Spec: Deliverable 6 — skill-docs-alignment

## Overview

Update all 7 step skills and `skills/work-context.md` to replace auto-advance language with pre-step/post-step evaluation language. This is documentation-only — no runtime behavior changes.

**Dependency**: Deliverable 5 (script-rewire) must be complete. `commands/lib/gate-precheck.sh` must exist with its final checks so Shell-checked subsections are accurate.

**Line budget constraint**: Step skills must stay at or under 50 lines. The new Step Mechanics sections use a compact format: one line for shell-checked criteria, one line for evaluator-judged reference. No subsection headers. This keeps the net line change to +3 or fewer per file.

---

## File: `skills/research.md`

Current: 41 lines. Budget: 50 lines.

### Old text (lines 27-31)

```
## Step Mechanics
Transition out: gate record `research->plan` with outcome `pass` required.
Auto-advance when: single deliverable with file-path-specific criteria, code mode,
no directory context pointers. Research mode never auto-advances research.
Next step expects: research findings addressing all ideation questions, recorded
in `research.md` or `research/` directory with `synthesis.md`.
```

### New text (net +3 lines = 44 total)

```
## Step Mechanics
Transition out: gate record `research->plan` with outcome `pass` required.
Pre-step shell check (`gate-precheck.sh`): 1 deliverable, code mode, path-referencing
ACs, no directory context pointers, not supervised, not force-stopped.
Pre-step evaluator (`evals/gates/research.yaml`): path-relevance — are referenced
paths sufficient without broader investigation? Per `skills/shared/gate-evaluator.md`.
Next step expects: research findings addressing all ideation questions, recorded
in `research.md` or `research/` directory with `synthesis.md`.
```

---

## File: `skills/plan.md`

Current: 47 lines. Budget: 50 lines.

### Old text (lines 38-42)

```
## Step Mechanics
Transition out: gate record `plan->spec` with outcome `pass` required.
Auto-advance when: single deliverable with no dependencies and no parallelism.
Next step expects: architecture decisions in `summary.md`, `plan.json` if
parallel execution needed, and clear implementation path per deliverable.
```

### New text (net +2 lines = 49 total)

```
## Step Mechanics
Transition out: gate record `plan->spec` with outcome `pass` required.
Pre-step shell check (`gate-precheck.sh`): 1 deliverable, no depends_on, not
supervised, not force-stopped.
Pre-step evaluator (`evals/gates/plan.yaml`): complexity-assessment — does the
deliverable need architectural decisions beyond definition.yaml? Per `skills/shared/gate-evaluator.md`.
Next step expects: architecture decisions in `summary.md`, `plan.json` if
parallel execution needed, and clear implementation path per deliverable.
```

---

## File: `skills/spec.md`

Current: 49 lines. Budget: 50 lines.

### Old text (lines 26-31)

```
## Step Mechanics
Transition out: gate record `spec->decompose` with outcome `pass` required.
Auto-advance when: single deliverable with >=2 testable acceptance criteria
(containing action verbs, numeric thresholds, or file path references).
Next step expects: implementation-ready specs in `spec.md` or `specs/` with
refined acceptance criteria per deliverable.
```

### New text (net +1 line = 50 total)

```
## Step Mechanics
Transition out: gate record `spec->decompose` with outcome `pass` required.
Pre-step shell check (`gate-precheck.sh`): 1 deliverable, >=2 ACs, not supervised,
not force-stopped.
Pre-step evaluator (`evals/gates/spec.yaml`): testability — are ACs specific enough
to implement without refinement? Per `skills/shared/gate-evaluator.md`.
Next step expects: implementation-ready specs in `spec.md` or `specs/` with
refined acceptance criteria per deliverable.
```

---

## File: `skills/decompose.md`

Current: 45 lines. Budget: 50 lines.

### Old text (lines 29-33)

```
## Step Mechanics
Transition out: gate record `decompose->implement` with `pass` required.
Auto-advance when: <=2 deliverables, no dependencies, same specialist type.
At this boundary, `scripts/create-work-branch.sh` creates the work branch.
Next step expects: `plan.json` with waves, `team-plan.md` with coordination.
```

### New text (net +3 lines = 48 total)

```
## Step Mechanics
Transition out: gate record `decompose->implement` with `pass` required.
Pre-step shell check (`gate-precheck.sh`): <=2 deliverables, no depends_on, same
specialist type, not supervised, not force-stopped.
Pre-step evaluator (`evals/gates/decompose.yaml`): wave-triviality — can all
deliverables execute in a single wave without coordination? Per `skills/shared/gate-evaluator.md`.
At this boundary, `scripts/create-work-branch.sh` creates the work branch.
Next step expects: `plan.json` with waves, `team-plan.md` with coordination.
```

---

## File: `skills/ideate.md`

Current: 47 lines. Budget: 50 lines.

### Old text (lines 38-42)

```
## Step Mechanics
Transition out: gate record `ideate->research` with outcome `pass` required.
Ideation never auto-advances. The gate evaluator checks completeness, alignment,
feasibility, and cross-model evidence (see `evals/ideation-gate.md`).
Next step expects: validated `definition.yaml` and initialized `state.json`.
```

### New text (net +0 lines = 47 total)

```
## Step Mechanics
Transition out: gate record `ideate->research` with outcome `pass` required.
No pre-step evaluation — ideation always runs. Post-step gate evaluates
completeness, alignment, feasibility, and cross-model evidence.
Reference: `evals/gates/ideation.yaml` post_step, per `skills/shared/gate-evaluator.md`.
Next step expects: validated `definition.yaml` and initialized `state.json`.
```

---

## File: `skills/implement.md`

Current: 52 lines (already over budget — pre-existing). Budget: 50 lines.

### Old text (lines 34-37)

```
## Step Mechanics
Transition out: gate record `implement->review` with `pass` required.
Implement NEVER auto-advances — always requires a gate evaluation.
Next step expects: all deliverables implemented, status updated in state.json.
```

### New text (net +0 lines = 52 total, no regression)

```
## Step Mechanics
Transition out: gate record `implement->review` with `pass` required.
No pre-step evaluation — implementation always runs. Post-step gate evaluates
artifact presence, acceptance criteria, and quality dimensions.
Reference: `evals/gates/implement.yaml` post_step, per `skills/shared/gate-evaluator.md`.
Next step expects: all deliverables implemented, status updated in state.json.
```

Note: implement.md is 52 lines pre-existing. This change replaces 4 lines with 4 lines (net zero). The pre-existing budget violation is out of scope for this deliverable.

---

## File: `skills/review.md`

Current: 45 lines. Budget: 50 lines.

### Old text (lines 27-29)

```
## Step Mechanics
Review is the final step. NEVER auto-advances — always requires gate evaluation.
On pass: work unit ready for archive. On fail: returns to implement step.
```

### New text (net +1 line = 46 total)

```
## Step Mechanics
Review is the final step. No pre-step evaluation — review always runs.
Post-step gate evaluates Phase A and Phase B results across all deliverables.
Reference: `evals/gates/review.yaml` post_step, per `skills/shared/gate-evaluator.md`.
On pass: work unit ready for archive. On fail: returns to implement step.
```

---

## File: `skills/work-context.md`

Current: 132 lines. Budget: 150 lines. Changes add ~10 lines net = 142 total.

### Change 1: Step Sequence section (lines 30-34)

#### Old text

```
All work units traverse all 7 steps. No steps are skipped. Auto-advance may
resolve trivially-completing steps without user input (unless `gate_policy: supervised`).
```

#### New text

```
All work units traverse all 7 steps. No steps are skipped. Pre-step evaluation
may determine a step adds no information and record a `prechecked` gate, advancing
without user input (unless `gate_policy: supervised`).
```

### Change 2: Gate Records section (lines 106-111)

#### Old text

```
## Gate Records

Step transitions produce gate records in `state.json.gates[]`:
- `boundary`: `"{from}->{to}"`
- `outcome`: `pass` | `fail` | `conditional`
- `decided_by`: `human` | `evaluator` | `auto-advance`
- Append-only — never modified after creation.
```

#### New text

```
## Gate Records

Step transitions produce gate records in `state.json.gates[]`:
- `boundary`: `"{from}->{to}"`
- `outcome`: `pass` | `fail` | `conditional`
- `decided_by`: `manual` | `evaluated` | `prechecked`
- Append-only — never modified after creation.

Vocabulary:
- `manual`: human reviewed and approved the gate
- `evaluated`: isolated subagent evaluated, trust gradient auto-approved
- `prechecked`: pre-step evaluation determined step not needed

Gate evaluation flow:
1. Phase A (deterministic, shell): `commands/lib/gate-precheck.sh` checks structural criteria
2. Phase B (judgment, isolated subagent): evaluator assesses quality dimensions from `evals/gates/{step}.yaml`
3. Trust gradient (`scripts/evaluate-gate.sh`) applies `gate_policy` to the evaluator's verdict
```

### Change 3: Trust Gradient section (lines 113-119)

#### Old text

```
## Trust Gradient

`gate_policy` in `definition.yaml` controls the trust level:
- `supervised`: human approves every gate
- `delegated`: evaluator judges most gates; human approves critical transitions
- `autonomous`: evaluator judges all gates

Per-deliverable `gate` field overrides the top-level policy for that deliverable.
```

#### New text

```
## Trust Gradient

`gate_policy` in `definition.yaml` controls human oversight of evaluator verdicts
(not whether evaluation happens — evaluation always runs):
- `supervised`: evaluator runs, verdict presented to human for approval (`decided_by: manual`)
- `delegated`: evaluator verdict accepted for most gates (`decided_by: evaluated`); human reviews implement->review and review->archive (`decided_by: manual`)
- `autonomous`: evaluator verdict accepted for all gates (`decided_by: evaluated`)

Pre-step evaluation that determines a step is trivially skippable records `decided_by: prechecked`.

Per-deliverable `gate` field overrides the top-level policy for that deliverable.
```

---

## Verification Checklist

After applying all changes:

1. No file contains the string `auto-advance` or `auto-advances` (search all 8 files)
2. No file contains `decided_by: "human"` or `decided_by: "evaluator"` or `decided_by: "auto-advance"` (search all 8 files)
3. Every step skill references either pre-step evaluation subsections OR "No pre-step evaluation"
4. Every step skill references its `evals/gates/{step}.yaml` file
5. `skills/work-context.md` uses the new decided_by vocabulary: `manual | evaluated | prechecked`
6. All step skills remain within the 50-line budget (run `scripts/measure-context.sh`)
