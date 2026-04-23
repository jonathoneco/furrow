# Learnings Protocol

Capture durable insights during work execution. Learnings accumulate per row
and are surfaced to project level during archive.

## When to Record

Record a learning when you discover something a future agent working on a
similar task in this project would benefit from knowing. The trigger question:
"Would this insight help a future agent on a similar task?"

## Kinds

| Kind | Use When |
|----------|----------|
| `pattern` | A reusable approach that worked well |
| `pitfall` | Something that failed or caused problems |
| `preference` | User or project preference discovered |
| `convention` | Naming, structural, or process convention established |
| `dependency` | A quirk or gotcha about an external dependency |

## Schema (JSONL)

Append one JSON object per line to `.furrow/rows/{name}/learnings.jsonl`:

```json
{"ts":"ISO-8601","step":"ideate|research|plan|spec|decompose|implement|review","kind":"pattern|pitfall|preference|convention|dependency","summary":"actionable insight","detail":"situation that surfaced it","tags":["..."]}
```

- `ts`: ISO-8601 UTC (e.g. `2026-04-23T17:40:00Z`)
- `step`: Furrow step in which the insight surfaced
- `kind`: one of the five kinds above
- `summary`: one concise paragraph, actionable (min 10 chars)
- `detail`: situation that surfaced the insight (min 10 chars)
- `tags`: free-form array; may be empty

The canonical shape is codified in `schemas/learning.schema.json`
(`additionalProperties: false`). Appends are validated by the
`append-learning` hook, which refuses writes that fail validation.

## Reading Learnings

At session start, read project-level `learnings.jsonl` if it exists.
Filter to learnings relevant to the current task by matching `kind`, `tags`,
and `summary` keywords against deliverable names and pointers supplied by the
current row's definition. Internalize relevant learnings — do not inject them
into permanent conversation memory.
