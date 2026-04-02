# Learnings Protocol

Capture durable insights during work execution. Learnings accumulate per work
unit and are promoted to project level on archive.

## When to Record

Record a learning when you discover something a future agent working on a
similar task in this project would benefit from knowing. The trigger question:
"Would this insight help a future agent on a similar task?"

## Categories

| Category | Use When |
|----------|----------|
| `pattern` | A reusable approach that worked well |
| `pitfall` | Something that failed or caused problems |
| `preference` | User or project preference discovered |
| `convention` | Naming, structural, or process convention established |
| `dependency` | A quirk or gotcha about an external dependency |

## Schema (JSONL)

Append one JSON object per line to `.work/{name}/learnings.jsonl`:

```json
{"id":"{task}-{NNN}","timestamp":"ISO8601","category":"pattern|pitfall|preference|convention|dependency","content":"actionable insight","context":"what surfaced it","source_task":"{name}","source_step":"{step}","promoted":false}
```

- `id`: `{source_task}-{NNN}` (zero-padded 3-digit sequence)
- `content`: one concise paragraph, actionable (min 10 chars)
- `context`: situation that surfaced the insight (min 10 chars)
- `promoted`: always `false` when writing; set to `true` during archive

## Reading Learnings

At session start, read project-level `learnings.jsonl` if it exists.
Filter to learnings relevant to the current task by matching category and
content keywords against deliverable names and context pointers.
Internalize relevant learnings — do not inject them into permanent context.
