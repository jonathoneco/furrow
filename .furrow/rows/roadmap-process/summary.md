# Summary: roadmap-process

## Task
Build a /work-roadmap command that reads todos.yaml, triages TODOs using Claude-informed reasoning, groups into dependency-aware phases, and outputs a templated ROADMAP.md with worktree parallelism strategy.

## Current State
- Step: plan (in_progress)
- Ideation: complete (definition.yaml validated, 11 design decisions approved)
- Research: complete (4 parallel agents, synthesis written)
- Plan: plan.json generated (4 waves), team-plan.md written, architecture decisions below
- Deliverables: 5 defined across 4 waves, all not_started

## Artifact Paths
- Definition: `.work/roadmap-process/definition.yaml`
- Research synthesis: `.work/roadmap-process/research/synthesis.md`
- Plan: `.work/roadmap-process/plan.json`
- Team plan: `.work/roadmap-process/team-plan.md`
- Todos schema: `adapters/shared/schemas/todos.schema.yaml`
- Existing scripts: `scripts/generate-plan.sh`, `scripts/check-wave-conflicts.sh`
- Command pattern reference: `commands/work-todos.md`
- Output template reference: `ROADMAP.md`
- Template directory: `templates/`

## Settled Decisions
- Full pipeline in one invocation (triage + group + sequence + generate)
- Claude-informed reasoning for prioritization, not just mechanical graph sort
- Templated output with layered resolution (harness.yaml config > .claude/roadmap.tmpl > harness default)
- Sprint-scoped roadmaps: bare invocation preserves completed phases, --full regenerates
- Script provides data (dependency graph, file conflicts), Claude makes decisions
- Triage metadata persisted to todos.yaml for stability across re-runs
- Status field is lightweight/temporary — task tracker replaces long-term
- Schema extension: optional fields (depends_on, files_touched, urgency, impact, effort, phase, status)
- Command follows work-todos.md pattern: read-only state, confirmation UX
- Rendering uses heredoc + ${var} + awk pattern from regenerate-summary.sh
- Architecture: 4 waves — schema+template parallel (W1), triage script (W2), command (W3), integration (W4)
- Template is structural guidance for Claude, not a mechanical rendering engine
- triage-todos.sh adapts Python code from generate-plan.sh for TODO-level graph operations
- Template resolution order: harness.yaml `roadmap.template` > `.claude/roadmap.tmpl` > `templates/roadmap.md.tmpl`

## Key Findings
- Schema: single YAML source at `adapters/shared/schemas/todos.schema.yaml`, `additionalProperties: false`, only /work-todos command consumes it — zero breakage risk from additive optional fields
- Template: 6 section types in current ROADMAP.md (header, DAG, legend, conflict zones, phases, worktree commands), existing `{placeholder}` convention in templates/ directory
- Script: Kahn's algorithm in generate-plan.sh (Python subprocess lines 66-137) directly adaptable for TODO-level deps; glob-to-regex in check-wave-conflicts.sh reusable for file conflict detection
- Command: standard pattern is Header → Syntax → Context Detection → Behavior → Validation → Output; flags use `--flagname` or `--flagname value`; confirmation UX presents numbered proposals
- Tools: yq 4.52.4, jq 1.8.1, python3 3.14.0 all available via mise

## Open Questions
- Phase naming: should titles be auto-generated from grouped TODO titles, or user-provided during confirmation?
- Worktree branch naming: auto-generate `work/{todo-id}` or let user customize during confirmation?

## Recommendations
- Start with todos-schema-extension and roadmap-template in parallel (wave 1, no file conflicts)
- Adapt generate-plan.sh Python code into a reusable lib rather than inlining in triage-todos.sh
- Keep the template system simple — section markers + Claude-generated content, not a full template engine
- Test against current 7 TODOs as the validation set throughout implementation
