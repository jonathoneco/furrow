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

1. Find active task via `furrow row status`.
2. Read `state.json`, `definition.yaml`, and `plan.json`.
3. If `--re-review`: increment `state.json.deliverables[name].corrections`.

4. **Dimension selection** (per `state.json.mode`):
   - Code mode: load `evals/dimensions/implement.yaml`
   - Research mode: load `evals/dimensions/research-implement.yaml`

5. For each deliverable (or specified deliverable):

   a. **Phase A** (in-session, deterministic):
      - Code mode: verify files touched match `file_ownership` globs.
      - Research mode: verify `.furrow/rows/{name}/deliverables/` files exist.
      - Check acceptance criteria from `definition.yaml`.
      - If Phase A fails, record FAIL and skip Phase B for this deliverable.

   b. **Phase B** (fresh-session via `claude -p`):
      1. Build review prompt:
         - Read `templates/review-prompt.md` as the base template.
         - Inject: deliverable name, artifact file paths from `file_ownership`,
           acceptance criteria from `definition.yaml`.
         - Load eval dimensions from `evals/dimensions/{artifact-type}.yaml`.
         - Write assembled prompt to a temp file.
      2. Construct JSON schema for structured output:
         ```json
         {"type":"object","required":["deliverable","dimensions","overall"],
          "properties":{"deliverable":{"type":"string"},
          "dimensions":{"type":"array","items":{"type":"object",
          "required":["name","verdict","evidence"],
          "properties":{"name":{"type":"string"},
          "verdict":{"type":"string","enum":["PASS","FAIL"]},
          "evidence":{"type":"string"}}}},
          "overall":{"type":"string","enum":["PASS","FAIL"]}}}
         ```
      3. Run isolated reviewer (`--bare` strips MCP, hooks, CLAUDE.md, memory):
         ```sh
         claude -p \
           --bare \
           --tools "Read,Glob,Grep,Bash" \
           --model opus \
           --system-prompt-file "${prompt_file}" \
           --json-schema "${schema}" \
           --max-budget-usd 2.00 \
           --no-session-persistence \
           --output-format json \
           "Review deliverable: ${deliverable_name}"
         ```
      4. Parse response JSON:
         - Check `is_error` field (exit code is 0 even on errors).
         - If `is_error: true`: report error from `errors[]`, skip review recording.
         - If budget exceeded (`subtype: "error_max_budget_usd"`): report limit.
         - Extract `structured_output` for per-dimension verdicts.
         - If `structured_output` missing: attempt to parse `result` text as fallback.
      5. Write result to `reviews/{deliverable}.json`.

6. Aggregate results: overall pass requires all deliverables pass.
7. Record gate in `state.json.gates[]`.

8. **Learnings promotion**: After review, invoke `commands/lib/promote-learnings.sh`
   to identify durable findings for promotion.

9. Present results. If all pass: suggest `/archive`.
