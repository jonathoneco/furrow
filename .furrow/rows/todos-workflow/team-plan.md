# Team Plan: todos-workflow

## Scope Analysis

5 deliverables across 4 waves. All are harness infrastructure (shell scripts, YAML schemas, markdown commands). Single domain — no need for multiple specialist types.

## Team Composition

Single agent (harness-engineer) executing waves sequentially. Wave 2 has two parallel-safe deliverables (extractor script + migration) that can be dispatched as parallel sub-agents.

## Task Assignment

| Wave | Deliverable | Agent | Files |
|------|------------|-------|-------|
| 1 | todos-yaml-schema | lead | `adapters/shared/schemas/todos.schema.yaml`, `scripts/validate-todos.sh` |
| 2a | extract-candidates-script | sub-agent | `scripts/extract-todo-candidates.sh` |
| 2b | migrate-existing-todos | sub-agent | `todos.yaml`, `TODOS.md` |
| 3 | work-todos-command | lead | `commands/work-todos.md` |
| 4 | archive-integration | lead | `commands/archive.md`, `adapters/shared/schemas/definition.schema.yaml` |

## Coordination

- Wave 1 must complete before Wave 2 (both depend on schema + validation script)
- Wave 2a and 2b are independent — no file overlap, can run in parallel
- Wave 3 depends on Wave 2a (command references extraction script)
- Wave 4 depends on Wave 3 (archive delegates to command)

## Skills

- Spec: `specs/todos-yaml-schema.md`, `specs/extract-candidates-script.md`, `specs/work-todos-command.md`, `specs/archive-integration.md`, `specs/migrate-existing-todos.md`
- Specialist: `specialists/harness-engineer.md`
