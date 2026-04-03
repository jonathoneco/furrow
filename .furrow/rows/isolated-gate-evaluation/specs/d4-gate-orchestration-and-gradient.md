# Spec: Deliverable 4 — gate-orchestration-and-gradient

## Overview

This deliverable creates the new gate orchestration pipeline and updates the `decided_by` vocabulary across all validation layers. It introduces two new scripts (`run-gate.sh`, `select-gate.sh`) and modifies five existing files (`evaluate-gate.sh`, `record-gate.sh`, `update-state.sh`, both `state.schema.json` copies).

**Dependency**: Phase 1 deliverables (gate YAML files in `evals/gates/`, `skills/shared/gate-evaluator.md`) must be complete before this work starts.

---

## New File: `scripts/run-gate.sh`

### Interface

```
Usage: run-gate.sh <name> <gate_type>
  name      — work unit name (kebab-case)
  gate_type — "pre_step" or "post_step"

Exit codes:
  0  — Phase A passed, no subagent needed (pre_step with no pre_step section in gate YAML)
  1  — Phase A failed deterministically (artifacts missing)
  2  — missing state/files/argument error
  10 — needs subagent evaluation (prompt file path on stdout)
```

### Complete Script

```sh
#!/bin/sh
# run-gate.sh — Gate orchestrator: Phase A (deterministic) + Phase B (subagent prep)
#
# Runs check-artifacts.sh for deterministic checks, then prepares a prompt
# file for the subagent evaluator. Does NOT invoke the subagent itself —
# the in-context agent reads the signal (exit 10) and spawns via Agent tool.
#
# Usage: run-gate.sh <name> <gate_type>
#   name      — work unit name (kebab-case)
#   gate_type — "pre_step" or "post_step"
#
# Exit codes:
#   0  — gate resolved without subagent (no applicable gate section)
#   1  — Phase A failed deterministically
#   2  — missing state/files/argument error
#   10 — needs subagent evaluation (prompt file path on stdout)

set -eu

# --- paths ---

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# --- argument validation ---

if [ $# -lt 2 ]; then
  echo "Usage: run-gate.sh <name> <gate_type>" >&2
  exit 2
fi

name="$1"
gate_type="$2"

case "$gate_type" in
  pre_step|post_step) ;;
  *)
    echo "Error: gate_type must be 'pre_step' or 'post_step', got '${gate_type}'" >&2
    exit 2
    ;;
esac

work_dir="${HARNESS_ROOT}/.work/${name}"
state_file="${work_dir}/state.json"
def_file="${work_dir}/definition.yaml"

if [ ! -f "$state_file" ]; then
  echo "Error: state.json not found: ${state_file}" >&2
  exit 2
fi

if [ ! -f "$def_file" ]; then
  echo "Error: definition.yaml not found: ${def_file}" >&2
  exit 2
fi

# --- read current state ---

current_step="$(jq -r '.step' "$state_file")"
mode="$(jq -r '.mode // "code"' "$state_file")"

# --- select gate YAML ---

gate_yaml_path="$("$SCRIPT_DIR/select-gate.sh" "$name")" || {
  echo "Error: failed to select gate for '${name}'" >&2
  exit 2
}

# --- check if gate_type section exists in the gate YAML ---

has_section="$(yq -r ".${gate_type} // null" "$gate_yaml_path")"
if [ "$has_section" = "null" ]; then
  # No section for this gate type (e.g., ideate has no pre_step)
  echo "No ${gate_type} section in gate YAML for step '${current_step}'. Skipping." >&2
  exit 0
fi

# --- Phase A: run check-artifacts.sh (post_step only) ---

phase_a_json=""
if [ "$gate_type" = "post_step" ]; then
  # check-artifacts.sh requires a deliverable name; for gate orchestration
  # we pass the first in-progress or most recent deliverable.
  # However, check-artifacts.sh is called per-deliverable during review.
  # For post_step gate, we run it on the current deliverable context.
  # The caller (in-context agent) is responsible for passing the right deliverable.
  # For now, we collect Phase A results if they exist from the reviews dir.
  phase_a_results="${work_dir}/reviews/phase-a-results.json"
  if [ -f "$phase_a_results" ]; then
    phase_a_json="$(cat "$phase_a_results")"
  else
    phase_a_json='{"note": "No Phase A results available — run check-artifacts.sh first"}'
  fi
else
  # pre_step does not run Phase A artifact checks
  phase_a_json='{"gate_type": "pre_step", "artifact_check": "not_applicable"}'
fi

# --- collect step output paths ---

step_outputs="[]"
if [ "$gate_type" = "post_step" ]; then
  # Gather paths to deliverable outputs for the evaluator
  case "$current_step" in
    ideate)
      step_outputs="$(jq -n --arg p "${def_file}" '[{"type": "definition", "path": $p}]')"
      ;;
    research)
      step_outputs="$(jq -n \
        --arg d "${work_dir}/deliverables" \
        --arg r "${work_dir}/research.md" \
        '[{"type": "deliverables_dir", "path": $d}, {"type": "research_notes", "path": $r}]')"
      ;;
    plan)
      step_outputs="$(jq -n --arg p "${work_dir}/plan.json" '[{"type": "plan", "path": $p}]')"
      ;;
    spec)
      specs_dir="${work_dir}/specs"
      step_outputs="$(jq -n --arg p "$specs_dir" '[{"type": "specs_dir", "path": $p}]')"
      ;;
    decompose)
      step_outputs="$(jq -n --arg p "${work_dir}/plan.json" '[{"type": "plan_with_waves", "path": $p}]')"
      ;;
    implement)
      step_outputs="$(jq -n \
        --arg r "${work_dir}/reviews" \
        '[{"type": "reviews_dir", "path": $r}]')"
      ;;
    review)
      step_outputs="$(jq -n \
        --arg r "${work_dir}/reviews" \
        --arg s "${work_dir}/summary.md" \
        '[{"type": "reviews_dir", "path": $r}, {"type": "summary", "path": $s}]')"
      ;;
  esac
fi

# --- write prompt file ---

prompt_dir="${work_dir}/gate-prompts"
mkdir -p "$prompt_dir"
prompt_file="${prompt_dir}/${gate_type}-${current_step}.yaml"

# Build the prompt YAML that the subagent evaluator will consume
cat > "$prompt_file" <<PROMPT_EOF
# Gate Evaluator Prompt
# Generated by run-gate.sh — do not edit manually
# Consumed by the subagent evaluator via skills/shared/gate-evaluator.md

gate_type: ${gate_type}
step: ${current_step}
mode: ${mode}
work_unit: ${name}

# Paths for the evaluator to read
definition_path: ${def_file}
gate_yaml_path: ${gate_yaml_path}
state_path: ${state_file}

# Phase A results (deterministic artifact checks)
phase_a_results: |
$(echo "$phase_a_json" | sed 's/^/  /')

# Step output paths for evaluator to inspect
step_outputs: |
$(echo "$step_outputs" | sed 's/^/  /')

# Evaluator contract
evaluator_skill: ${HARNESS_ROOT}/skills/shared/gate-evaluator.md
PROMPT_EOF

echo "Prompt file written: ${prompt_file}" >&2

# --- signal: needs subagent evaluation ---

# Exit 10 signals the in-context agent to:
# 1. Read the prompt file at the path printed to stdout
# 2. Spawn a subagent with the gate-evaluator.md skill
# 3. Pass the prompt file contents as context
# 4. After verdict, call evaluate-gate.sh to apply trust gradient
echo "$prompt_file"
exit 10
```

### Design Notes

- Exit code 10 is a deliberate non-standard code that cannot be confused with success (0), failure (1), or missing files (2).
- The prompt file is YAML so the subagent can parse it easily. It contains paths, not content, to avoid duplication and keep the file small.
- Phase A results are embedded inline because they're typically small JSON.
- The `gate-prompts/` subdirectory is created inside the work unit directory for traceability.

---

## New File: `scripts/select-gate.sh`

### Interface

```
Usage: select-gate.sh <name>
  Outputs absolute path to evals/gates/{step}.yaml on stdout.

Exit codes:
  0 — success (path on stdout)
  2 — state.json not found
  3 — gate file not found
```

### Complete Script

```sh
#!/bin/sh
# select-gate.sh — Return the gate YAML path for the current step
#
# Usage: select-gate.sh <name>
#   Outputs absolute path to evals/gates/{step}.yaml on stdout.
#
# Exit codes:
#   0 — success (path on stdout)
#   1 — usage error
#   2 — state.json not found
#   3 — gate file not found

set -eu

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HARNESS_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ $# -lt 1 ]; then
  echo "Usage: select-gate.sh <name>" >&2
  exit 1
fi

name="$1"
state_file="${HARNESS_ROOT}/.work/${name}/state.json"

if [ ! -f "$state_file" ]; then
  echo "Error: state.json not found at ${state_file}" >&2
  exit 2
fi

step="$(jq -r '.step // ""' "$state_file")"

if [ -z "$step" ]; then
  echo "Error: step is missing from ${state_file}" >&2
  exit 2
fi

# Gate YAML path follows a simple 1:1 convention: step name = file name
gate_path="${HARNESS_ROOT}/evals/gates/${step}.yaml"

if [ ! -f "$gate_path" ]; then
  echo "Error: gate file not found at ${gate_path}" >&2
  exit 3
fi

echo "$gate_path"
```

### Design Notes

- Deliberately simple: no mode-dependent routing (unlike `select-dimensions.sh`). Every step has exactly one gate YAML file; the gate YAML itself has `pre_step` and `post_step` sections that handle mode differences.
- Mirrors the structure of `select-dimensions.sh` for consistency.

---

## Modified File: `scripts/evaluate-gate.sh`

### Change: `decided_by` vocabulary in comments and documentation

The script itself does not validate or reference `decided_by` values -- it operates on `evaluator_verdict` and `gate_policy` to produce output decisions. However, the header comments reference the old vocabulary.

**Line 2** (comment): Update caller reference.

Before:
```sh
# Called by the eval runner (scripts/run-eval.sh), NOT by step-transition.sh
```

After:
```sh
# Called by the in-context agent after subagent evaluation returns a verdict.
# The agent calls: evaluate-gate.sh <name> <boundary> <evaluator_verdict>
# Then uses the output decision to call record-gate.sh or present to human.
```

**Lines 3-4** (comment): Update description.

Before:
```sh
# directly. Step-transition accepts explicit verdicts from the human or
# evaluator; this script applies gate_policy to an evaluator's raw verdict
```

After:
```sh
# Step-transition accepts explicit verdicts from the human or evaluator;
# this script applies gate_policy to an evaluator's raw verdict
```

**No functional changes to the script body.** The `evaluate-gate.sh` script's logic is already correct for the new architecture -- it takes an evaluator verdict and applies gate_policy to decide `PASS`, `FAIL`, `CONDITIONAL`, or `WAIT_FOR_HUMAN`. The calling pattern changes (run-gate.sh orchestrates instead of run-eval.sh), but the interface is identical.

---

## Modified File: `scripts/record-gate.sh`

### Change 1: `decided_by` enum validation (lines 87-95)

Before (lines 87-95):
```sh
# --- validate decided_by ---

case "${decided_by}" in
  human|evaluator|auto-advance) ;;
  *)
    echo "Invalid decided_by: '${decided_by}'. Must be 'human', 'evaluator', or 'auto-advance'." >&2
    exit 3
    ;;
esac
```

After:
```sh
# --- validate decided_by ---

case "${decided_by}" in
  manual|evaluated|prechecked) ;;
  *)
    echo "Invalid decided_by: '${decided_by}'. Must be 'manual', 'evaluated', or 'prechecked'." >&2
    exit 3
    ;;
esac
```

### Change 2: Header comment (line 9)

Before:
```sh
#   decided_by      — "human" | "evaluator" | "auto-advance"
```

After:
```sh
#   decided_by      — "manual" | "evaluated" | "prechecked"
```

### Change 3: Usage error message (line 19)

No change needed -- the line references parameter names, not enum values.

---

## Modified File: `scripts/update-state.sh`

### Change: Gate record `decided_by` validation (line 143)

Before (line 143):
```sh
    elif ([.decided_by] | inside(["human","evaluator","auto-advance"]) | not) then "enum:decided_by"
```

After:
```sh
    elif ([.decided_by] | inside(["manual","evaluated","prechecked"]) | not) then "enum:decided_by"
```

This is the only line in `update-state.sh` that references the `decided_by` enum values. The rest of the validation logic is generic (field types, required fields).

---

## Modified File: `schemas/state.schema.json` (primary)

### Change: `decided_by` enum (lines 102-104)

Before:
```json
          "decided_by": {
            "type": "string",
            "enum": ["human", "evaluator", "auto-advance"]
          },
```

After:
```json
          "decided_by": {
            "type": "string",
            "enum": ["manual", "evaluated", "prechecked"]
          },
```

**Location**: `properties.gates.items.properties.decided_by.enum` (line 104 in the current file).

---

## Modified File: `adapters/shared/schemas/state.schema.json` (adapter copy)

### Change: `decided_by` enum (lines 149-151 inside `$defs.gate_record`)

Before:
```json
        "decided_by": {
          "type": "string",
          "enum": ["human", "evaluator", "auto-advance"]
        },
```

After:
```json
        "decided_by": {
          "type": "string",
          "enum": ["manual", "evaluated", "prechecked"]
        },
```

**Location**: `$defs.gate_record.properties.decided_by.enum` (line 151 in the current file).

---

## Implementation Order

1. Create `scripts/select-gate.sh` (no dependencies on other changes)
2. Create `scripts/run-gate.sh` (depends on `select-gate.sh` existing)
3. Update `schemas/state.schema.json` (primary) -- `decided_by` enum
4. Update `adapters/shared/schemas/state.schema.json` -- `decided_by` enum
5. Update `scripts/record-gate.sh` -- `decided_by` enum validation
6. Update `scripts/update-state.sh` -- `decided_by` gate validation
7. Update `scripts/evaluate-gate.sh` -- header comments only

Steps 3-6 should be done atomically (single commit) since they form a consistency group -- if any one is updated without the others, validation will reject previously valid states.

---

## Verification Checklist

After implementation, verify:

1. **select-gate.sh** returns correct paths:
   ```sh
   # With an active work unit at step "implement":
   scripts/select-gate.sh <name>
   # Expected: /absolute/path/evals/gates/implement.yaml
   ```

2. **run-gate.sh** produces prompt file and exits 10:
   ```sh
   scripts/run-gate.sh <name> post_step
   echo $?  # Should be 10
   # Stdout should be the path to the prompt YAML file
   cat <prompt_file_path>  # Should be valid YAML with all fields
   ```

3. **run-gate.sh** exits 0 for missing gate sections:
   ```sh
   # For ideate step (no pre_step section):
   scripts/run-gate.sh <name> pre_step
   echo $?  # Should be 0
   ```

4. **record-gate.sh** rejects old vocabulary:
   ```sh
   scripts/record-gate.sh <name> "ideate->research" "pass" "human" "test"
   echo $?  # Should be 3 (invalid decided_by)
   
   scripts/record-gate.sh <name> "ideate->research" "pass" "manual" "test"
   echo $?  # Should be 0
   ```

5. **update-state.sh** validates new enum:
   ```sh
   # Append a gate with old vocabulary -- should fail validation (exit 3)
   # Append a gate with new vocabulary -- should succeed
   ```

6. **Both schemas** have identical `decided_by` enum values:
   ```sh
   diff <(jq '.properties.gates.items.properties.decided_by.enum' schemas/state.schema.json) \
        <(jq '."$defs".gate_record.properties.decided_by.enum' adapters/shared/schemas/state.schema.json)
   # Should produce no output (identical)
   ```

---

## Risk Notes

- **Existing gate records**: All existing gate records in `.work/*/state.json` use `decided_by: "human"`. After this change, `"human"` becomes invalid. Archived work units won't be re-validated, but any active work unit with existing gate records will fail `update-state.sh` validation on the next mutation. **Mitigation**: Before implementing, run a sweep to identify any active work units with gate records, and update their `decided_by` values from `"human"` to `"manual"` as part of this deliverable.

- **Schema sync**: The two schema files have different structures (primary uses inline gate schema, adapter uses `$defs`). Both must be updated. A post-implementation `diff` check should verify the enum values match.

- **Exit code 10**: Non-standard. Document in the script header and in `references/gate-protocol.md` (Phase 3). Any caller of `run-gate.sh` must handle exit 10 explicitly.
