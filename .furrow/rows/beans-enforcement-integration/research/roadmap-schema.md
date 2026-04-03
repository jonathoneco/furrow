# Research: roadmap.yaml Schema Design (D5)

## Decision: Dual Output

Generate BOTH:
- `.furrow/almanac/roadmap.yaml` — canonical machine-readable data
- Optionally render human-readable summary via `alm show-roadmap` (not stored as file)

ROADMAP.md as a separate rendered artifact is deferred — the YAML is the source of truth.

## Schema Top-Level Keys

```yaml
schema_version: "1.0"

metadata:
  project: "furrow"
  generated_at: "2026-04-03T00:00:00Z"
  total_phases: 9
  completed_phases: 4

dependency_graph:
  nodes:
    - id: "phase_4-wu-2"
      label: "supervised-gating"
      phase: 4
      status: "done"
  edges:
    - from: "phase_4-wu-2"
      to: "phase_4-wu-3"
      kind: "hard"          # hard | inferred
      reason: "sequential file conflict"
  waves:
    - wave: 1
      work_units: ["phase_5-wu-1", "phase_5-wu-2"]

conflict_zones:
  - phase: 4
    file_pattern: "commands/lib/step-transition.sh"
    work_units: ["phase_4-wu-2", "phase_4-wu-3"]
    severity: "low"
    mitigation: "sequential ordering"

phases:
  - number: 4
    title: "Foundational Infrastructure"
    status: "in_progress"    # done | in_progress | planned
    rationale: "Changes enforcement pipeline everything merges through"
    work_units:
      - index: 1
        branch_name: "namespace-rename"
        description: "Rename harness to furrow"
        todos: ["duplication-cleanup", "rename-to-furrow"]
        depends_on: []
        key_files: ["commands/", "scripts/", "hooks/"]
        conflict_risk: "none"
        completed_at: "2026-02-10T00:00:00Z"

deferred:
  - title: "Autonomous triggering"
    reason: "Needs supervised/delegated modes proven"

handoff:
  template: |
    Start with: `/work {branch_name} — {description}`
    Source TODOs: {todo_ids}
    Key files: {key_files}
```

## Gains Over Markdown

- Machine-parseable DAG (no regex on ASCII art)
- Schema-validatable
- Round-trip safe (programmatic read/write)
- `alm next` reads YAML directly instead of parsing MD sections

## What triage-todos.sh Produces

Current JSON output:
```json
{
  "todos": [{id, title, depends_on, files_touched, urgency, impact, effort, status}],
  "graph": {topo_order: [], waves: [{wave, todos}], cycles: []},
  "conflicts": [{todo_a, todo_b, overlapping_files}]
}
```

This maps directly to the roadmap.yaml structure. The `alm triage` subcommand transforms this JSON into the YAML schema, adding phase grouping and rationale (agent-layer reasoning).
