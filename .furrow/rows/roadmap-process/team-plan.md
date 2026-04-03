# Team Plan: roadmap-process

## Wave 1 (parallel)

### Agent: api-designer
- **Deliverable**: todos-schema-extension
- **Files**: `adapters/shared/schemas/todos.schema.yaml`
- **Task**: Add 7 optional fields (depends_on, files_touched, urgency, impact, effort, phase, status) to todos schema. Validate existing entries still pass.

### Agent: harness-engineer-template
- **Deliverable**: roadmap-template
- **Files**: `templates/roadmap.md.tmpl`, `templates/roadmap-sections.yaml`
- **Task**: Create section registry YAML and markdown template with section markers and placeholder variables.

## Wave 2 (sequential)

### Agent: harness-engineer-script
- **Deliverable**: triage-script
- **Files**: `scripts/triage-todos.sh`
- **Task**: Build triage script adapting Kahn's algorithm from generate-plan.sh and glob-to-regex from check-wave-conflicts.sh. Output structured JSON.

## Wave 3 (sequential)

### Agent: harness-engineer-command
- **Deliverable**: command-skill
- **Files**: `commands/work-roadmap.md`
- **Task**: Write command skill following work-todos.md pattern. Full pipeline: triage + group + sequence + generate. Confirmation UX. --full flag.

## Wave 4 (sequential)

### Agent: harness-engineer-integration
- **Deliverable**: harness-integration
- **Files**: `.claude/harness.yaml`, `.claude/CLAUDE.md`, `todos.yaml`
- **Task**: Add roadmap.template config key, update command table, update todo entry references.
