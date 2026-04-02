# Research: todos-workflow

## 1. Schema Pattern

Existing schemas live in `adapters/shared/schemas/`. The definition schema is YAML; all others are JSON. All use JSON Schema Draft 2020-12.

Validation pipeline: `yq -o=json` → `python3 jsonschema` → cross-field checks (yq + Python for cycles).

**For todos.schema.yaml**: Follow the definition schema pattern — YAML for readability, validate with same pipeline. New `scripts/validate-todos.sh` wraps yq+jsonschema.

### Proposed todos.yaml Entry Schema

```yaml
id: slug-style-identifier        # stable, human-readable
title: Short description          # one line
context: Why this matters         # prose, multi-line ok
work_needed: Concrete steps       # prose, multi-line ok
risks: What could fail            # prose, multi-line ok
references:                       # list of file paths
  - path/to/file.sh
  - .work/unit-name/artifact.md
source_work_unit: unit-name       # optional — which work unit surfaced this
source_type: open-question        # optional — extraction source category
created_at: ISO 8601
updated_at: ISO 8601
```

## 2. Extraction Sources & Structure

### summary.md Open Questions
- Section header: `## Open Questions`
- Agent-written prose, preserved across regenerations
- Parse: extract text between `## Open Questions` and next `##`

### learnings.jsonl Unpromoted Pitfalls
- JSONL format: `{id, timestamp, category, content, context, source_task, source_step, promoted}`
- Filter: `category == "pitfall" && promoted == false`
- Already structured — direct field mapping to TODO candidate

### reviews/*.json Failed/Review Dimensions
- Structure: `{deliverable, phase_a: {verdict, acceptance_criteria[]}, phase_b: {verdict, dimensions[]}, overall}`
- Filter: dimensions where `verdict != "pass"` OR `overall != "pass"`
- Each failed dimension becomes a candidate with evidence as context

## 3. Archive Integration Point

Archive ceremony sequence:
1. Pre-condition (review gate passed)
2. Promote learnings
3. Promote components
4. **→ Extract TODOs (new step)**
5. Set archived_at
6. Regenerate summary
7. Git commit

Insert after component promotion, before state marking. This ensures all promotion decisions are finalized and state is still mutable.

## 4. Ceremony Pattern

Established pattern from `promote-learnings.sh`:
- Read source → iterate items → auto-recommend action → present with context → user confirms
- Output format: `[N/total] Item: ... | Source: ... | Recommendation: ... | Reason: ...`
- Script is a *presenter*, not a writer — the agent acts on user decisions

For TODO extraction: same pattern. Script outputs JSON candidates; agent presents with dedup reasoning against existing todos.yaml; user confirms add/merge/skip.

## 5. Pruning Linkage

- `definition.yaml` gets optional `source_todo: <id>` field (the todo slug)
- At archive time: if `source_todo` is set, propose marking that todo resolved
- User confirms: yes (remove from todos.yaml), no (keep), partial (add note)
- This requires `definition.schema.yaml` to accept the new optional field

## 6. Key Design Decision: Shell Collector + Agent Reasoner

The extraction script (`extract-todo-candidates.sh`) is a dumb JSON emitter:
```json
[
  {"source": "summary-open-questions", "title": "...", "context": "...", "raw_content": "..."},
  {"source": "learnings-pitfall", "title": "...", "context": "...", "raw_content": "..."},
  {"source": "review-finding", "title": "...", "context": "...", "raw_content": "..."}
]
```

The command markdown (`work-todos.md`) instructs the agent to:
1. Run the script → get candidates
2. Read existing `todos.yaml`
3. For each candidate: reason about semantic overlap with existing entries
4. Present each with proposed action (add new / merge with existing X / skip as duplicate)
5. Write confirmed entries to `todos.yaml`
