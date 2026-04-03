# Research: Isolated Gate Evaluation

## RQ1: Gate YAML Schema Design

**Existing dimension YAML pattern** (consistent across all 7 files in `evals/dimensions/`):
```yaml
dimensions:
  - name: "kebab-case-identifier"
    definition: "What this dimension evaluates"
    pass_criteria: "Concrete condition for PASS"
    fail_criteria: "Concrete condition for FAIL"
    evidence_format: "How to present evidence"
```

**Proposed gate YAML structure** (extends this pattern):
```yaml
# evals/gates/{step}.yaml
pre_step:  # Only for research, plan, spec, decompose
  dimensions:
    - name: "..."
      definition: "..."
      pass_criteria: "..."
      fail_criteria: "..."
      evidence_format: "..."

post_step:
  dimensions_from: "evals/dimensions/{step}.yaml"  # Reference, not duplicate
  additional_dimensions:  # Optional step-specific gate criteria
    - name: "..."
      ...
```

**Key design decisions:**
- `dimensions_from` avoids duplicating dimension content
- `additional_dimensions` allows gate-specific criteria beyond the standard dimensions
- Pre-step dimensions are always inline (no reference) since they're gate-specific

**Ideation gate migration**: 4 dimensions (completeness, alignment, feasibility, cross-model) become `post_step.dimensions` in `evals/gates/ideation.yaml`. No pre_step for ideation.

**Schema locations discovered**: Two copies of state.schema.json exist:
- `schemas/state.schema.json` (primary)
- `adapters/shared/schemas/state.schema.json` (adapter copy)

Both must be updated for decided_by vocabulary change.

## RQ2: Subagent Invocation Pattern

**Settled approach**: Shell prepares inputs, in-context agent spawns subagent.

**Concrete mechanism**:
1. `run-gate.sh` runs Phase A (check-artifacts.sh), writes Phase A results to a JSON file
2. `run-gate.sh` writes an evaluator prompt file containing:
   - Path to definition.yaml
   - Path to gate YAML (from select-gate.sh)
   - Phase A results (artifacts_present, file_ownership, etc.)
   - Step output paths (for post_step evaluation)
3. `run-gate.sh` exits with a specific code (e.g., exit 10 = "needs subagent evaluation")
4. The in-context agent reads the prompt file and spawns the subagent via Agent tool
5. Subagent returns structured verdict (PASS/FAIL per dimension)
6. In-context agent calls `evaluate-gate.sh` with the verdict to apply trust gradient

**Isolation contract** (for `skills/shared/gate-evaluator.md`):
- Subagent receives: definition.yaml content, gate YAML content, Phase A results, step output paths
- Subagent must NOT read: summary.md, conversation history, prior step outputs not relevant to current gate
- Subagent returns: JSON with per-dimension verdicts + overall verdict

## RQ3: Phase A Extraction Boundaries

**Phase A** (keep in `check-artifacts.sh`) = `run-eval.sh` lines 59-152:
- A1: Check deliverable exists in definition.yaml
- A2: Read file_ownership from plan.json
- A3: Check owned files were modified (mode-dependent: research checks deliverables/, code checks git diff)
- A4: Read acceptance criteria from definition.yaml
- A5: Build acceptance_criteria array and compute phase_a_verdict

**Phase B** (move to subagent) = `run-eval.sh` lines 155-396:
- B1: Get dimension file path via select-dimensions.sh
- B2: Read dimension names from YAML
- B3: Evaluate each dimension (most return "skipped" / "requires evaluator" for qualitative dims)

**Data flow Phase A → Phase B**:
| Variable | Source | Needed by subagent? |
|----------|--------|-------------------|
| `artifacts_present` | A3 | Yes — baseline for dimension evaluation |
| `file_ownership` | A2 | Yes — for unplanned-changes check |
| `mode` | state.json | Yes — controls evaluation logic |
| `base_commit` | state.json | Yes — for git diff context |
| `phase_a_verdict` | A5 | Yes — overall input to gate decision |

**Key insight**: Phase B currently fakes most evaluations with "artifacts present; qualitative assessment requires evaluator". The subagent properly evaluates these dimensions.

**Review JSON output structure** (maintained by run-gate.sh):
```json
{
  "deliverable": "string",
  "phase_a": { "artifacts_present": bool, "acceptance_criteria": [...], "verdict": "pass|fail" },
  "phase_b": { "dimensions": [...], "verdict": "pass|fail" },
  "overall": "pass|fail",
  "reviewer": "string",
  "cross_model": bool,
  "timestamp": "ISO 8601"
}
```

## RQ4: Caller Inventory for Renames

### Critical Runtime (MUST update to avoid breakage)

| File | Lines | What changes |
|------|-------|-------------|
| `scripts/record-gate.sh` | 9, 87-92, 124, 131, 141, 147 | decided_by enum validation |
| `scripts/update-state.sh` | 143 | decided_by schema validation |
| `hooks/validate-summary.sh` | 43-44 | Business logic: skips validation for "auto-advance" |
| `commands/lib/step-transition.sh` | 4, 7, 74, 79 | Interface docs + passes decided_by |
| `adapters/agent-sdk/callbacks/gate_callback.py` | 77, 110 | Hardcodes "evaluator" |
| `commands/lib/rewind.sh` | 69 | Hardcodes "human" |
| `schemas/state.schema.json` | 91, 102 | decided_by enum |
| `adapters/shared/schemas/state.schema.json` | 139, 150 | decided_by enum (copy) |

### Documentation (non-breaking but should update)

| File | Lines | Reference type |
|------|-------|---------------|
| `commands/work.md` | 23, 53, 54 | Script path references |
| `commands/checkpoint.md` | 24 | Script path reference |
| `references/gate-protocol.md` | 16, 26, 56-66 | Protocol docs |
| `ROADMAP.md` | 29, 35, 62, 74, 81-86, 131, 169, 174 | Project tracking |
| `_rationale.yaml` | 131-133, 384-386 | Component rationale |
| `todos.yaml` | 4, 14-15 | Task tracking |
| `skills/work-context.md` | 109 | decided_by vocabulary |
| `skills/implement.md` | 36 | "auto-advances" language |
| `skills/review.md` | 27 | "auto-advances" language |
| `skills/research.md` | 28-29 | "auto-advances" language |
| `skills/ideate.md` | 40 | "auto-advances" language |
| `evals/ideation-gate.md` | 53 | decided_by vocabulary |
| `commands/lib/rewind.sh` | 70 | Text reference |
| `commands/redirect.md` | 19 | Example |
| `adapters/claude-code/commands/work.md` | 26 | Script reference |
| `adapters/claude-code/skills/gate-prompt.md` | 14 | Script reference |

### New discoveries (not in original definition)

1. **`adapters/agent-sdk/callbacks/gate_callback.py`** — hardcodes `"evaluator"` for decided_by. Must update to `"evaluated"`. Not in any deliverable's file_ownership.
2. **`adapters/shared/schemas/state.schema.json`** — second copy of state schema. Must update alongside primary.
3. **`adapters/claude-code/commands/work.md`** and **`adapters/claude-code/skills/gate-prompt.md`** — adapter-level references to auto-advance and gate scripts.
4. **`hooks/validate-summary.sh`** — has business logic checking `"auto-advance"` to skip summary validation. Needs mapping to new vocabulary: `"prechecked"` should trigger the same skip behavior.

## RQ5: decided_by Vocabulary Migration

**Current values**: `human | evaluator | auto-advance`
**New values**: `manual | evaluated | prechecked`

**Mapping**:
- `human` → `manual` (human reviewed and approved)
- `evaluator` → `evaluated` (isolated subagent evaluated, trust gradient auto-approved)
- `auto-advance` → `prechecked` (pre-step evaluation determined step trivially skippable)

**Business logic impact** (only 1 place):
- `validate-summary.sh` line 44: `"auto-advance"` check → change to `"prechecked"`
- Same behavior: skip summary validation when step was pre-checked and trivially resolved

**All existing gate records use `"human"`** — no evaluator or auto-advance records exist in practice. Migration is low-risk.

## Definition Updates Needed

Research discovered files missing from deliverable file_ownership:

1. **gate-orchestration-and-gradient** should also own:
   - `adapters/shared/schemas/state.schema.json` (second schema copy)

2. **script-rewire** should also own:
   - `hooks/validate-summary.sh` (business logic on decided_by)

3. **consumer-updates** should also own:
   - `adapters/agent-sdk/callbacks/gate_callback.py` (hardcoded decided_by)
   - `adapters/claude-code/commands/work.md` (script references)
   - `adapters/claude-code/skills/gate-prompt.md` (script references)
   - `commands/work.md` (script path references)
   - `commands/checkpoint.md` (script path reference)
   - `commands/redirect.md` (example reference)
   - `commands/lib/rewind.sh` (hardcoded "human" → "manual")
   - `commands/lib/step-transition.sh` (interface docs)
   - `ROADMAP.md` (project tracking references)
   - `todos.yaml` (task tracking references)
