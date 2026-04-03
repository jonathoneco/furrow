# /review [--deliverable <name>] [--re-review]

Trigger the review step with specialist review agents.

## Arguments

- `--deliverable <name>`: Review a specific deliverable. If absent, reviews all.
- `--re-review`: Re-run review after corrections (increments corrections counter).

## Pre-Conditions

If current step is not `"review"`:
- If implement step is complete (step_status "completed"): advance to review.
- Otherwise: error "Implement step must complete before review."

## Behavior

1. Find active task via `rws status`.
2. Read `state.json`, `definition.yaml`, and `plan.json`.
3. If `--re-review`: increment `state.json.deliverables[name].corrections`.

4. **Dimension selection** (per `state.json.mode`):
   - Code mode: load `evals/dimensions/implement.yaml`
   - Research mode: load `evals/dimensions/research-implement.yaml`

5. For each deliverable (or specified deliverable):
   a. Spawn review agent with `code-quality` skill.
   b. **Phase A** (artifact validation):
      - Code mode: verify files touched match `file_ownership` globs.
      - Research mode: verify `.furrow/rows/{name}/deliverables/` files exist.
      - Check acceptance criteria from `definition.yaml`.
   c. **Phase B** (quality review):
      - Apply dimension rubric from loaded eval dimensions.
      - Produce per-dimension verdict (pass/fail) with evidence.
   d. Write result to `reviews/{deliverable}.json`.

6. Aggregate results: overall pass requires all deliverables pass.
7. Record gate in `state.json.gates[]`.

8. **Learnings promotion**: After review, invoke `commands/lib/promote-learnings.sh`
   to identify durable findings for promotion.

9. Present results. If all pass: suggest `/archive`.
