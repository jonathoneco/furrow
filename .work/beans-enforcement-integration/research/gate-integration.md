# Research: Gate Integration for Seeds (D4)

## Dual-Layer Approach

### Phase A (Deterministic) — in check-artifacts.sh

Add A6 check after existing artifact checks:
- Read `seed_id` from state.json
- If missing → **hard fail** (seeds mandatory)
- If present → call `sds show <seed_id>` to verify seed exists and is not closed
- Append `seed_check` object to phase-a-results.json

~30 lines of shell added to check-artifacts.sh.

### Phase B (Evaluator Dimension) — seed-sync

New file: `evals/dimensions/seed-consistency.yaml`

```yaml
dimensions:
  - name: "seed-sync"
    definition: "Whether seed status synchronizes with row step"
    pass_criteria: >-
      Seed exists, is not closed, and its status matches the current
      step per mapping: ideate→ideating, research→researching,
      plan→planning, spec→speccing, decompose→decomposing,
      implement→implementing, review→reviewing
    fail_criteria: >-
      Seed not found, seed is closed, or seed status does not match
      expected status for current step
    evidence_format: >-
      Quote seed_id from state.json, status from sds show output,
      and current step. For FAIL, show expected vs actual.
```

Added to all 7 gate YAML files as `additional_dimensions`.

## Step→Status Mapping

| state.step | seed.status |
|---|---|
| ideate | ideating |
| research | researching |
| plan | planning |
| spec | speccing |
| decompose | decomposing |
| implement | implementing |
| review | reviewing |

## Recovery Path

When seed-sync fails (hard block), recovery requires human input:
1. User runs `sds show <seed_id>` to see actual seed state
2. User runs `rws status <name>` to see actual row state
3. User decides correct state and manually runs `sds update <id> --status <correct>`
4. User re-triggers the gate evaluation

This is intentionally manual — mismatches signal procedural errors that shouldn't be auto-resolved.

## Files Changed

| File | Change |
|---|---|
| `scripts/check-artifacts.sh` | Add Phase A.6 seed check (+30 lines) |
| `evals/dimensions/seed-consistency.yaml` | NEW (~9 lines) |
| `evals/gates/*.yaml` (all 7) | Add seed-sync to additional_dimensions |
| `skills/shared/gate-evaluator.md` | Document step→status mapping, seed check protocol |
| `adapters/shared/schemas/state.schema.json` | seed_id (required), epic_seed_id (optional) |

## Design Decision: Phase A vs. Phase B Scope

Phase A checks **existence** (deterministic, fast, hard fail).
Phase B checks **consistency** (evaluator judgment, evidence-based).

This means: if seed doesn't exist at all, the gate fails immediately in Phase A without spawning a subagent. If seed exists but status is wrong, the evaluator catches it in Phase B with full evidence.
