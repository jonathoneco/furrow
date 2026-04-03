# Research: CLI Enhancements

## alm learn — Learnings Protocol

From `skills/shared/learnings-protocol.md`, each learning is a JSONL entry:
```json
{"category": "pattern|pitfall|preference|convention|dependency",
 "content": "the insight",
 "context": "where/when discovered",
 "promoted": false,
 "timestamp": "ISO8601"}
```

Sources:
- Per-row: `.furrow/rows/{name}/learnings.jsonl`
- Promoted: `.furrow/almanac/learnings/{row-name}.jsonl`

Promotion = copy learning with `promoted: true` to almanac, mark source as `promoted: true`.

## alm rationale

`.furrow/almanac/rationale.yaml` structure (from existing file):
- Keyed by component path
- Each entry has: `exists_because` (string)
- Organized by directory sections

## rws complete-deliverable

Current state.json deliverables format:
```json
{"deliverable-name": {"status": "completed", "wave": 1, "corrections": 0}}
```

Need to read definition.yaml to validate deliverable names exist.
Wave comes from plan.json assignments.
