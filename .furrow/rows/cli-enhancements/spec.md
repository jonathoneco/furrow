# Spec: CLI Enhancements

## alm learn (full lifecycle)

### Subcommands
- `alm learn list [--row NAME]` — list all learnings, optionally filtered by row
- `alm learn search <query>` — grep across all learnings.jsonl files
- `alm learn show <row> <index>` — show full learning detail by row and line index
- `alm learn promote <row> [--all|--id INDEX]` — copy to .furrow/almanac/learnings/{row}.jsonl, mark source promoted=true
- `alm learn add <row> --category CAT --content C --context CTX` — append validated learning

### Data paths
- Per-row: `.furrow/rows/{name}/learnings.jsonl`
- Promoted: `.furrow/almanac/learnings/{row-name}.jsonl`

### Schema (per learnings-protocol.md)
```json
{"category":"pattern|pitfall|preference|convention|dependency",
 "content":"string","context":"string","promoted":false,
 "timestamp":"ISO8601"}
```

## alm rationale

### Subcommands
- `alm rationale list` — list all components with their rationale
- `alm rationale show <component>` — show specific entry
- `alm rationale add <component> --reason "why"` — add/update entry

### Data: `.furrow/almanac/rationale.yaml`

## Stubs

`alm docs`, `alm specialists`, `alm history` — print help text and exit 1 with "not yet implemented".

## rws complete-deliverable

```
rws complete-deliverable <name> <deliverable>
```
- Read definition.yaml, validate deliverable name exists
- Read plan.json for wave assignment (default wave=1 if no plan)
- Set `.deliverables[deliverable] = {"status":"completed","wave":N,"corrections":0}`
- Exit 3 if deliverable not in definition

## rws complete-step

```
rws complete-step <name>
```
- At review step: validate all deliverables are completed
- Set step_status = "completed"
- Exit 3 if preconditions not met

## rws archive improvements

- On precondition failure, print which specific conditions are unmet
