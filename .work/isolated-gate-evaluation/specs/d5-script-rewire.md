# Spec: Deliverable 5 — script-rewire

## Overview

This deliverable performs the renames, deletions, and modifications that rewire the harness from the old auto-advance/run-eval pipeline to the new gate orchestration pipeline. It depends on D4 (gate-orchestration-and-gradient) being complete.

**Files created**: `scripts/check-artifacts.sh`, `commands/lib/gate-precheck.sh`
**Files deleted**: `scripts/auto-advance.sh`, `scripts/run-eval.sh`, `commands/lib/auto-advance.sh`
**Files modified**: `hooks/validate-summary.sh`
**Callers updated**: `commands/work.md`, `commands/checkpoint.md`

---

## Rename 1: `scripts/run-eval.sh` -> `scripts/check-artifacts.sh`

### Git Command

```sh
git mv scripts/run-eval.sh scripts/check-artifacts.sh
```

### What to Keep (lines 1-152)

The entire Phase A section is retained. This is lines 1 through 152 of the current `scripts/run-eval.sh`.

### What to Remove

- **Lines 154-396**: Phase B dimension evaluation (the `select-dimensions.sh` call, dimension loop, all `case` branches for individual dimensions)
- **Lines 398-456**: Review JSON composition, `evaluate-gate.sh` call, and exit code logic

### New Ending (replaces lines 154-456)

After the Phase A section (ending at line 152 with the `phase_a_check` verdict), the script writes Phase A results to a JSON file and outputs its path.

**Replace everything from line 154 onward with:**

```sh
# =====================================================================
# Write Phase A results JSON
# =====================================================================

mkdir -p "$reviews_dir"
phase_a_file="${reviews_dir}/phase-a-results.json"
tmp_file="${phase_a_file}.tmp.$$"

jq -n \
  --arg deliverable "$deliverable" \
  --argjson artifacts_present "$artifacts_present" \
  --argjson acceptance_criteria "$phase_a_ac" \
  --arg phase_a_verdict "$phase_a_verdict" \
  --arg mode "$mode" \
  --arg base_commit "$base_commit" \
  --argjson file_ownership "$file_ownership" \
  --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  '{
    deliverable: $deliverable,
    artifacts_present: $artifacts_present,
    acceptance_criteria: $acceptance_criteria,
    verdict: $phase_a_verdict,
    mode: $mode,
    base_commit: $base_commit,
    file_ownership: $file_ownership,
    timestamp: $timestamp
  }' > "$tmp_file"

# Atomic write
mv "$tmp_file" "$phase_a_file"

echo "Phase A results written: ${phase_a_file}" >&2

# Output path on stdout for consumption by run-gate.sh
echo "$phase_a_file"

# Exit code reflects Phase A verdict
if [ "$phase_a_verdict" = "pass" ]; then
  exit 0
else
  exit 1
fi
```

### Header Update

**Line 2**: Change comment from:
```sh
# run-eval.sh — Deterministic eval runner for deliverable review
```
To:
```sh
# check-artifacts.sh — Phase A deterministic artifact checks
```

**Lines 4-5**: Change usage from:
```sh
# Usage: run-eval.sh <name> <deliverable>
```
To:
```sh
# Usage: check-artifacts.sh <name> <deliverable>
```

**Lines 8-10**: Update exit codes from:
```sh
# Exit codes:
#   0 — pass (review result written)
#   1 — fail (review result written with failures)
#   2 — missing state/files
```
To:
```sh
# Exit codes:
#   0 — Phase A pass (results JSON written, path on stdout)
#   1 — Phase A fail (results JSON written, path on stdout)
#   2 — missing state/files
```

**Line 31**: Update usage message from:
```sh
  echo "Usage: run-eval.sh <name> <deliverable>" >&2
```
To:
```sh
  echo "Usage: check-artifacts.sh <name> <deliverable>" >&2
```

### Complete Resulting File Structure

```
Lines   1-13:  Header (updated)
Lines  14-57:  Paths, temp dir, prerequisite checks (unchanged)
Lines  58-152: Phase A checks A1-A5 (unchanged)
Lines 153+:    Phase A results JSON output (new)
```

Total: approximately 185 lines (down from 456).

---

## Rename 2: `commands/lib/auto-advance.sh` -> `commands/lib/gate-precheck.sh`

### Git Command

```sh
git mv commands/lib/auto-advance.sh commands/lib/gate-precheck.sh
```

### Header Changes

**Lines 1-3**: Update header.

Before:
```sh
#!/bin/sh
# auto-advance.sh — Auto-advance detection for trivially resolved steps
#
# Usage: auto-advance.sh <step> <definition_path> <state_path>
```

After:
```sh
#!/bin/sh
# gate-precheck.sh — Pre-step gate check for trivially resolvable steps
#
# Usage: gate-precheck.sh <step> <definition_path> <state_path>
```

**Lines 8-11**: Update exit code documentation.

Before:
```sh
# Exit codes:
#   0 — should auto-advance (evidence on stdout)
#   1 — should NOT auto-advance
```

After:
```sh
# Exit codes:
#   0 — step is trivially resolvable (evidence on stdout, decided_by: prechecked)
#   1 — step requires full evaluation (not trivially resolvable)
```

**Line 16-17**: Update usage message.

Before:
```sh
  echo "Usage: auto-advance.sh <step> <definition_path> <state_path>" >&2
```

After:
```sh
  echo "Usage: gate-precheck.sh <step> <definition_path> <state_path>" >&2
```

### Change 1: Remove spec testability regex (lines 97-101)

The `grep -ciE` regex that checks for action verbs and path patterns is removed. The AC count >= 2 check (lines 93-96) is retained as a structural check.

Before (lines 89-104):
```sh
  spec)
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    ac_count="$(yq -r '.deliverables[0].acceptance_criteria | length' "${def_path}" 2>/dev/null)" || ac_count="0"
    if [ "${ac_count}" -lt 2 ]; then
      exit 1
    fi
    # Check if criteria are testable (contain action verbs, numbers, or paths)
    testable="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -ciE '(returns|enforces|validates|creates|contains|must|shall|[0-9]+|[/.]\w+)' || true)"
    if [ "${testable}" -lt "${ac_count}" ]; then
      exit 1
    fi
    echo "Single deliverable with ${ac_count} testable acceptance criteria; spec adds no refinement beyond definition"
    exit 0
    ;;
```

After:
```sh
  spec)
    # Single deliverable with well-defined ACs: spec won't add information
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    # At least 2 ACs ensures the definition is specific enough
    ac_count="$(yq -r '.deliverables[0].acceptance_criteria | length' "${def_path}" 2>/dev/null)" || ac_count="0"
    if [ "${ac_count}" -lt 2 ]; then
      exit 1
    fi
    # Testability is now judged by the gate evaluator, not regex
    echo "Single deliverable with ${ac_count} acceptance criteria; spec adds no refinement beyond definition"
    exit 0
    ;;
```

**Rationale for removal**: The testability regex (`grep -ciE '(returns|enforces|validates|creates|contains|must|shall|[0-9]+|[/.]\w+)'`) is a qualitative judgment masquerading as a structural check. It produces false positives on criteria containing common English words. The gate evaluator subagent now handles testability assessment via the `evals/gates/spec.yaml` pre_step dimension.

### Change 2: Tighten research path regex (line 63)

Before (line 63):
```sh
    has_paths="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -cE '[/.]\w+' || true)"
```

After:
```sh
    # AC must reference specific file paths (require / to distinguish from prose like ".yaml")
    has_paths="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -cE '/\w+' || true)"
```

Also update line 72 (the `grep -oE` for first_file extraction):

Before (line 72):
```sh
    first_file="$(yq -r '.deliverables[0].acceptance_criteria[0]' "${def_path}" 2>/dev/null | grep -oE '[^ ]*[/.]\w+' | head -1)"
```

After:
```sh
    # Extract the first path-like string from AC (must contain /)
    first_file="$(yq -r '.deliverables[0].acceptance_criteria[0]' "${def_path}" 2>/dev/null | grep -oE '[^ ]*/\w+[^ ]*' | head -1)"
```

**Rationale**: The old pattern `[/.]\w+` matches bare filenames like `.yaml` or `.md` which appear in prose text, not just path references. Requiring `/` ensures we match actual paths like `evals/gates/foo.yaml`.

### Change 3: Add inline comments to each check

The complete `research` section with inline comments:

```sh
  research)
    # Research mode always needs full research -- never trivially skip
    if [ "${mode}" = "research" ]; then
      exit 1
    fi
    # Multiple deliverables means research scope is non-trivial
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    # AC must reference specific file paths (require / to distinguish from prose like ".yaml")
    has_paths="$(yq -r '.deliverables[0].acceptance_criteria[]' "${def_path}" 2>/dev/null | grep -cE '/\w+' || true)"
    if [ "${has_paths}" -eq 0 ]; then
      exit 1
    fi
    # Directory context pointers signal need for exploration (non-trivial)
    has_dirs="$(yq -r '.context_pointers[].path' "${def_path}" 2>/dev/null | grep -cE '/$' || true)"
    if [ "${has_dirs}" -gt 0 ]; then
      exit 1
    fi
    # Extract the first path-like string from AC (must contain /)
    first_file="$(yq -r '.deliverables[0].acceptance_criteria[0]' "${def_path}" 2>/dev/null | grep -oE '[^ ]*/\w+[^ ]*' | head -1)"
    echo "Single deliverable targeting known location (${first_file}); no architectural unknowns"
    exit 0
    ;;
```

The complete `plan` section with inline comments:

```sh
  plan)
    # Multiple deliverables need wave assignment and dependency ordering
    if [ "${deliv_count}" -ne 1 ]; then
      exit 1
    fi
    # Dependencies between deliverables require plan-level reasoning
    deps="$(yq -r '.deliverables[0].depends_on | length' "${def_path}" 2>/dev/null)" || deps="0"
    if [ "${deps}" -gt 0 ]; then
      exit 1
    fi
    echo "Single deliverable, no dependencies, no parallelism -- plan adds no information beyond definition"
    exit 0
    ;;
```

The complete `decompose` section with inline comments:

```sh
  decompose)
    # 3+ deliverables need non-trivial wave ordering and specialist assignment
    if [ "${deliv_count}" -gt 2 ]; then
      exit 1
    fi
    # Dependencies between deliverables need wave sequencing
    has_deps="$(yq -r '[.deliverables[] | select(.depends_on != null and (.depends_on | length) > 0)] | length' "${def_path}" 2>/dev/null)" || has_deps="0"
    if [ "${has_deps}" -gt 0 ]; then
      exit 1
    fi
    # Multiple specialist types need coordination strategy
    specialist_count="$(yq -r '[.deliverables[].specialist // "default"] | unique | length' "${def_path}" 2>/dev/null)" || specialist_count="1"
    if [ "${specialist_count}" -gt 1 ]; then
      exit 1
    fi
    echo "Single wave, ${deliv_count} deliverable(s), no dependency ordering needed -- decomposition is trivial"
    exit 0
    ;;
```

### Change 4: Update evidence messages

Update the output messages to use "gate precheck" vocabulary instead of "auto-advance".

- research: `"Single deliverable targeting known location (${first_file}); no architectural unknowns"` -- **keep as-is** (already neutral vocabulary)
- plan: `"Single deliverable, no dependencies, no parallelism -- plan adds no information beyond definition"` -- **keep as-is**
- spec: Change from `"Single deliverable with ${ac_count} testable acceptance criteria; spec adds no refinement beyond definition"` to `"Single deliverable with ${ac_count} acceptance criteria; spec adds no refinement beyond definition"` (remove "testable" since we removed the testability check)
- decompose: `"Single wave, ${deliv_count} deliverable(s), no dependency ordering needed -- decomposition is trivial"` -- **keep as-is**

---

## Deletion: `scripts/auto-advance.sh`

### Git Command

```sh
git rm scripts/auto-advance.sh
```

**Replaced by**: `scripts/run-gate.sh` (created in D4). The pre-step evaluation that `auto-advance.sh` orchestrated is now handled by:
1. `commands/lib/gate-precheck.sh` (structural prechecks -- renamed from `commands/lib/auto-advance.sh`)
2. `scripts/run-gate.sh` with `gate_type=pre_step` (subagent evaluation)

The old `scripts/auto-advance.sh` did three things that are now split:
- **Policy check + step validation** (lines 43-83): Now in `gate-precheck.sh` (was already there as `commands/lib/auto-advance.sh`)
- **Record gate with `decided_by: auto-advance`** (line 102): Now handled by the in-context agent calling `record-gate.sh` with `decided_by: prechecked`
- **Advance step** (line 106): Now handled by the in-context agent calling `advance-step.sh`

---

## Modified File: `hooks/validate-summary.sh`

### Change: `decided_by` check (lines 43-44)

Before:
```sh
# --- skip if last gate was auto-advance ---

last_decided="$(jq -r '.gates | last | .decided_by // ""' "${state_file}" 2>/dev/null)" || last_decided=""
if [ "${last_decided}" = "auto-advance" ]; then
  exit 0
fi
```

After:
```sh
# --- skip if last gate was prechecked (trivially resolved step) ---

last_decided="$(jq -r '.gates | last | .decided_by // ""' "${state_file}" 2>/dev/null)" || last_decided=""
if [ "${last_decided}" = "prechecked" ]; then
  exit 0
fi
```

Also update the header comment (line 7):

Before:
```sh
# Skips validation for auto-advanced steps.
```

After:
```sh
# Skips validation for prechecked (trivially resolved) steps.
```

And the exit code documentation (line 10):

Before:
```sh
#   0 — valid (or no active work unit, or auto-advanced)
```

After:
```sh
#   0 — valid (or no active work unit, or prechecked)
```

---

## Caller Updates

### `commands/work.md`

**Line 23**: Reference to `commands/lib/auto-advance.sh`.

Before:
```
  -> After any transition: run `commands/lib/auto-advance.sh`
```

After:
```
  -> After any transition: run `commands/lib/gate-precheck.sh`
```

**Line 53**: Reference to `commands/lib/auto-advance.sh`.

Before:
```
1. Run `commands/lib/auto-advance.sh "{name}"` for trivial step detection.
```

After:
```
1. Run `commands/lib/gate-precheck.sh "{name}"` for trivial step detection.
```

**Line 54**: "auto-advanced" terminology.

Before:
```
2. If auto-advanced, repeat until a non-trivial step is reached.
```

After:
```
2. If prechecked, repeat until a non-trivial step is reached.
```

### `commands/checkpoint.md`

**Line 24**: Reference to `commands/lib/auto-advance.sh`.

Before:
```
9. After transition: run `commands/lib/auto-advance.sh "{name}"`.
```

After:
```
9. After transition: run `commands/lib/gate-precheck.sh "{name}"`.
```

---

## Caller Updates NOT in This Deliverable

The following files reference old script names or vocabulary but are owned by later deliverables (Phase 3: consumer-updates). They are listed here for completeness but must NOT be modified in D5:

| File | Reference | Owner |
|------|-----------|-------|
| `_rationale.yaml` lines 131, 384 | `scripts/auto-advance.sh`, `commands/lib/auto-advance.sh` | D8 (consumer-updates) |
| `ROADMAP.md` lines 29, 35, 62, 84, 86 | auto-advance and run-eval references | D8 |
| `todos.yaml` lines 4, 14-15 | `commands/lib/auto-advance.sh`, `scripts/auto-advance.sh` | D8 |
| `skills/work-context.md` line 109 | decided_by vocabulary | D7 (skill-docs-alignment) |
| `skills/implement.md`, `skills/review.md`, etc. | "auto-advances" language | D7 |
| `commands/lib/step-transition.sh` lines 4, 7 | decided_by interface docs | D8 |
| `commands/redirect.md` line 19 | decided_by example | D8 |
| `commands/lib/rewind.sh` line 69 | hardcoded "human" | D8 |
| `adapters/agent-sdk/callbacks/gate_callback.py` lines 77, 110 | hardcoded "evaluator" | D8 |
| `adapters/claude-code/commands/work.md` line 26 | script reference | D8 |
| `adapters/claude-code/skills/gate-prompt.md` line 14 | script reference | D8 |
| `references/gate-protocol.md` | Protocol docs | D8 (protocol-docs-update) |
| Archived `.work/*/` directories | Old decided_by values in state.json | Migration note only |

---

## Implementation Order

1. **Rename `run-eval.sh` to `check-artifacts.sh`**: `git mv` then edit
2. **Rename `auto-advance.sh` to `gate-precheck.sh`**: `git mv` then edit
3. **Delete `scripts/auto-advance.sh`**: `git rm`
4. **Update `hooks/validate-summary.sh`**: `decided_by` check
5. **Update `commands/work.md`**: Script path references
6. **Update `commands/checkpoint.md`**: Script path reference
7. **Grep sweep**: Verify no remaining references to old names in runtime files

### Pre-implementation Grep Sweep

Before starting, capture the baseline:

```sh
# Old names that should be eliminated from runtime scripts/commands/hooks:
grep -rn 'run-eval\.sh\|auto-advance\.sh' \
  --include='*.sh' --include='*.md' \
  commands/ scripts/ hooks/ \
  | grep -v '\.work/' \
  | grep -v '_rationale\|ROADMAP\|todos\.yaml'
```

### Post-implementation Grep Sweep

After all changes, verify:

```sh
# These should return NO results in runtime files:
grep -rn 'run-eval\.sh' commands/ scripts/ hooks/ --include='*.sh' --include='*.md' | grep -v '\.work/'
grep -rn 'commands/lib/auto-advance\.sh' commands/ scripts/ hooks/ --include='*.sh' --include='*.md' | grep -v '\.work/'
grep -rn 'scripts/auto-advance\.sh' commands/ scripts/ hooks/ --include='*.sh' --include='*.md' | grep -v '\.work/'

# These should exist:
grep -rn 'check-artifacts\.sh' commands/ scripts/ hooks/ --include='*.sh' --include='*.md' | grep -v '\.work/'
grep -rn 'gate-precheck\.sh' commands/ scripts/ hooks/ --include='*.sh' --include='*.md' | grep -v '\.work/'
```

---

## Smoke Test Specification

"End-to-end gate flow smoke-tested on a sample work unit" means the following concrete steps:

### Prerequisites

- D4 (gate-orchestration-and-gradient) is complete: `scripts/run-gate.sh`, `scripts/select-gate.sh` exist
- Phase 1 deliverables are complete: `evals/gates/*.yaml` files exist, `skills/shared/gate-evaluator.md` exists
- An active work unit exists at step `implement` (or any step with both pre_step and post_step gate sections)

### Test 1: Phase A (check-artifacts.sh) runs standalone

```sh
# Run Phase A on an existing deliverable
scripts/check-artifacts.sh isolated-gate-evaluation gate-yaml-schema
echo "Exit: $?"
# Expected: exit 0 or 1, and a JSON file path on stdout
# Verify the JSON file exists and contains expected fields:
cat "$(scripts/check-artifacts.sh isolated-gate-evaluation gate-yaml-schema)"
# Should contain: deliverable, artifacts_present, acceptance_criteria, verdict, mode, base_commit, file_ownership, timestamp
```

### Test 2: select-gate.sh returns correct path

```sh
scripts/select-gate.sh isolated-gate-evaluation
echo "Exit: $?"
# Expected: exit 0
# Stdout: absolute path to evals/gates/{current_step}.yaml
# Verify the file exists:
ls -la "$(scripts/select-gate.sh isolated-gate-evaluation)"
```

### Test 3: run-gate.sh produces prompt file (post_step)

```sh
scripts/run-gate.sh isolated-gate-evaluation post_step
echo "Exit: $?"
# Expected: exit 10
# Stdout: path to the prompt YAML file
# Verify the prompt file:
PROMPT="$(scripts/run-gate.sh isolated-gate-evaluation post_step 2>/dev/null)"
cat "$PROMPT"
# Should contain: gate_type, step, mode, work_unit, definition_path, gate_yaml_path, state_path, phase_a_results, step_outputs, evaluator_skill
```

### Test 4: run-gate.sh handles pre_step correctly

```sh
# For a step that HAS a pre_step section (e.g., research, plan, spec, decompose):
# Set work unit to spec step for testing, then:
scripts/run-gate.sh <name> pre_step
echo "Exit: $?"
# Expected: exit 10 (prompt file generated)

# For a step that has NO pre_step section (e.g., ideate, implement, review):
scripts/run-gate.sh <name> pre_step
echo "Exit: $?"
# Expected: exit 0 (no section, skip)
```

### Test 5: Gate record with new vocabulary

```sh
scripts/record-gate.sh isolated-gate-evaluation "implement->review" "pass" "evaluated" "Smoke test: all dimensions pass"
echo "Exit: $?"
# Expected: exit 0
# Verify the gate record in state.json:
jq '.gates[-1]' .work/isolated-gate-evaluation/state.json
# Should show: decided_by: "evaluated"
```

### Test 6: Old vocabulary rejected

```sh
scripts/record-gate.sh isolated-gate-evaluation "implement->review" "pass" "human" "test"
echo "Exit: $?"
# Expected: exit 3 (invalid decided_by)

scripts/record-gate.sh isolated-gate-evaluation "implement->review" "pass" "auto-advance" "test"
echo "Exit: $?"
# Expected: exit 3 (invalid decided_by)
```

### Test 7: gate-precheck.sh runs correctly

```sh
# For a trivially resolvable step (single deliverable, no deps):
commands/lib/gate-precheck.sh plan .work/isolated-gate-evaluation/definition.yaml .work/isolated-gate-evaluation/state.json
echo "Exit: $?"
# Expected: exit 0 or 1 depending on definition structure
# If exit 0: evidence string on stdout

# For a non-trivial step:
commands/lib/gate-precheck.sh implement .work/isolated-gate-evaluation/definition.yaml .work/isolated-gate-evaluation/state.json
echo "Exit: $?"
# Expected: exit 1 (implement never passes precheck)
```

### Test 8: validate-summary.sh uses new vocabulary

```sh
# Manually set a gate record with decided_by: "prechecked" in a test state.json
# Then run:
hooks/validate-summary.sh
echo "Exit: $?"
# Expected: exit 0 (skips validation for prechecked steps)
```

### Test 9: Full flow simulation

This is the key integration test. Simulate what the in-context agent does:

```sh
# 1. Run gate precheck
commands/lib/gate-precheck.sh spec .work/<test-unit>/definition.yaml .work/<test-unit>/state.json
PRECHECK_EXIT=$?

if [ $PRECHECK_EXIT -eq 0 ]; then
  echo "Step is trivially resolvable — record as prechecked"
  # The in-context agent would call:
  # scripts/record-gate.sh <name> "spec->decompose" "pass" "prechecked" "<evidence>"
  # scripts/advance-step.sh <name>
else
  echo "Step requires evaluation — run gate"
  # 2. Run Phase A
  PHASE_A_PATH="$(scripts/check-artifacts.sh <name> <deliverable>)"
  
  # 3. Run gate orchestrator
  PROMPT_PATH="$(scripts/run-gate.sh <name> post_step 2>/dev/null)"
  GATE_EXIT=$?
  
  if [ $GATE_EXIT -eq 10 ]; then
    echo "Subagent evaluation needed — prompt at: $PROMPT_PATH"
    # 4. In-context agent spawns subagent with prompt file
    # 5. Subagent returns verdict (simulated as "pass")
    VERDICT="pass"
    
    # 6. Apply trust gradient
    DECISION="$(scripts/evaluate-gate.sh <name> "spec->decompose" "$VERDICT")"
    echo "Gate decision: $DECISION"
    
    # 7. Record and advance (if PASS)
    if [ "$DECISION" = "PASS" ]; then
      scripts/record-gate.sh <name> "spec->decompose" "pass" "evaluated" "Smoke test"
      scripts/advance-step.sh <name>
    fi
  fi
fi
```

### Pass Criteria

All 9 tests pass. Specifically:
- `check-artifacts.sh` writes valid Phase A JSON and exits 0/1
- `select-gate.sh` returns existing gate YAML paths
- `run-gate.sh` exits 10 with valid prompt YAML on stdout
- `run-gate.sh` exits 0 for missing gate sections
- `record-gate.sh` accepts new vocabulary, rejects old vocabulary
- `gate-precheck.sh` produces evidence for trivial steps
- `validate-summary.sh` skips for `prechecked` decided_by
- The full flow simulation completes without errors
- Post-implementation grep sweep finds zero references to old script names in runtime files

---

## Risk Notes

- **Rename ordering**: `git mv` must happen before edits. If we edit first and then rename, the diff becomes harder to review. Always rename first, then modify content.

- **`scripts/auto-advance.sh` deletion**: This file is called by name from `commands/work.md` and `commands/checkpoint.md`. After deletion, those callers must be updated in the same commit. The in-context agent's behavior (calling the script directly) must shift to the new `run-gate.sh` + `gate-precheck.sh` pattern.

- **`check-artifacts.sh` callers**: Currently `run-eval.sh` is called from `scripts/evaluate-gate.sh` (line 2, comment only) and from the in-context agent following `commands/work.md` instructions. The evaluate-gate.sh comment is updated in D4. The work.md instructions are updated in this deliverable.

- **Research path regex tightening**: The change from `[/.]\w+` to `/\w+` is intentionally more restrictive. If any existing work units have acceptance criteria that reference files without a `/` (e.g., `"README.md"` as a bare filename), those will no longer match the precheck. This is the desired behavior -- bare filenames without paths are ambiguous and should not trigger trivial resolution.

- **Phase A results JSON location**: The file is written to `{work_dir}/reviews/phase-a-results.json`. This is the same directory as review results, which is appropriate since Phase A results are inputs to the review. The `run-gate.sh` script reads from this location.
