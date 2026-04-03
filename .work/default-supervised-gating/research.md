# Research: Default Supervised Gating

## 1. Two-Phase Gate Mechanism

### Current step-transition.sh Flow
```
step-transition.sh <name> <outcome> <decided_by> <evidence> [conditions_json]
  1. Record gate → record-gate.sh (appends to .gates array)
  2. Validate step artifacts → validate-step-artifacts.sh
  3. If fail: reset step_status, increment corrections, EXIT
  4. Wave conflict check (implement→review only, non-blocking)
  5. Validate summary sections (Key Findings, Open Questions, Recommendations)
  6. Regenerate summary.md
  7. Advance step → advance-step.sh (.step = next, .step_status = "not_started")
```

### Proposed Split

**--request phase** (steps 1-5): Record gate, validate artifacts, validate summary. Set `step_status = "pending_approval"`. Exit without advancing.

**--confirm phase** (steps 6-7): Verify `step_status = "pending_approval"` and passing gate exists. Regenerate summary. Advance step.

**Fail path unchanged**: outcome=fail records gate, resets step_status to in_progress, no --confirm needed.

### Schema Changes Required
- Add `"pending_approval"` to step_status enum in:
  - `schemas/state.schema.json`
  - `scripts/update-state.sh` (line 91 jq check)
  - `hooks/lib/validate.sh` (line 106 case statement)

### Policy Validation in --confirm
Read `gate_policy` from `definition.yaml`. Enforce:
- supervised → only `decided_by: manual` accepted
- delegated → `manual` or `evaluated` accepted
- autonomous → all accepted

Hard reject (exit non-zero) on mismatch.

### Ordering Concern
Gate is recorded BEFORE artifact validation. If validation fails, gate persists but transition doesn't complete. This is existing behavior — the two-phase split doesn't change it.

---

## 2. Verdict File Enforcement

### Current run-gate.sh Behavior
- Writes YAML prompt to `.work/{name}/gate-prompts/{gate_type}-{step}.yaml`
- Contains: gate_type, step, mode, file paths, phase_a_results, step_outputs
- Exits 10 to signal "subagent evaluation needed"
- No nonce exists currently

### Nonce Design
- `run-gate.sh` generates nonce via `uuidgen` or `openssl rand -hex 16`
- Writes nonce into prompt YAML as `nonce: {value}`
- Evaluator subagent includes nonce in verdict JSON
- `step-transition.sh --confirm` reads nonce from prompt file, validates it matches verdict file

### Verdict File Location
`.work/{name}/gate-verdicts/{boundary}.json` (new directory, parallels gate-prompts/)

### Write Guard
New hook `hooks/verdict-guard.sh` following `state-guard.sh` pattern:
- PreToolUse matcher: `Write|Edit`
- Block writes to `*/gate-verdicts/*`
- Add to existing Write|Edit hook array in `.claude/settings.json`

---

## 3. Bypass Prevention

### Hook Architecture
PreToolUse Bash hooks only fire on top-level Bash tool invocations. When step-transition.sh calls record-gate.sh and advance-step.sh internally as subprocesses, those do NOT trigger hooks. This means a single hook can block direct calls without blocking step-transition.sh's internal calls.

### New Hook: transition-guard.sh
- PreToolUse matcher: `Bash`
- Match: command contains `record-gate.sh` or `advance-step.sh`
- Allow: command contains `step-transition.sh` (user is calling the orchestrator)
- Block: direct invocations of the sub-scripts
- Add to existing Bash hook array alongside gate-check.sh

### Current Hook Config
```json
"PreToolUse": [
  { "matcher": "Write|Edit", "hooks": [state-guard, ownership-warn, validate-definition, correction-limit] },
  { "matcher": "Bash", "hooks": [gate-check] }
]
```

---

## 4. Pre-Step Evaluation in Supervised Mode

### Change Required
Remove lines 35-39 from `gate-precheck.sh`:
```sh
gate_policy="$(yq -r '.gate_policy // "supervised"' "${def_path}" 2>/dev/null)" || gate_policy="supervised"
if [ "${gate_policy}" = "supervised" ]; then
  exit 1
fi
```

### evaluate-gate.sh Already Handles It
Lines 52-54: supervised mode always returns `WAIT_FOR_HUMAN`, regardless of boundary type (pre-step or post-step). No changes needed.

### Pre-Step Evaluator Dimensions
| Step | Dimension | Question |
|------|-----------|----------|
| research | path-relevance | Are AC file references genuine work targets? |
| plan | complexity-assessment | Is work simple enough to skip planning? |
| spec | testability | Can ACs be mechanically verified? |
| decompose | wave-triviality | Is single-wave no-ordering genuinely correct? |

### User Flow After Change
1. Precheck runs structural checks → exit 0 if criteria met
2. run-gate.sh spawns evaluator subagent
3. Evaluator returns verdict
4. evaluate-gate.sh returns WAIT_FOR_HUMAN (supervised)
5. Agent presents: "Evaluator recommends skipping {step}: {reason}. Skip? [yes/no]"
6. User approves → step-transition with decided_by=manual
7. User rejects → step runs normally

---

## 5. Summary Generation Fix

### Root Cause
`regenerate-summary.sh` writes placeholder text ("To be written by step agent") when agent sections are empty or < 2 lines. This placeholder then fails the validation hook.

### Fix
- Remove placeholder fallback (lines 143-153 of regenerate-summary.sh)
- Write empty sections instead: just `## Header` with no content below
- Validation hook (`validate-summary.sh`) already enforces 2+ lines — it becomes the sole enforcement point
- Read deliverable count from definition.yaml when state.json.deliverables is empty

### Transition Protocol Integration
The prescriptive transition blocks in step skills must require the agent to write Key Findings/Open Questions/Recommendations BEFORE calling step-transition.sh --request.

---

## 6. Skill Transition Protocol

### Template Block (for each step skill)
```
## Supervised Transition Protocol
Before requesting a step transition:
1. Write Key Findings, Open Questions, and Recommendations in summary.md
2. Present deliverables and findings to user per summary-protocol.md
3. Ask explicitly: "Ready to advance to {next_step}? [yes/no]"
4. On user approval: call step-transition.sh --request with decided_by=manual
5. On user confirmation of --request: call step-transition.sh --confirm
6. Do NOT call step-transition.sh without explicit user approval
```

### Files to Update
All 7 step skills: ideate.md, research.md, plan.md, spec.md, decompose.md, implement.md, review.md
