# Build a /work-todos command that generates TODOS.md at session end. Template with title, context, work needed, risks, references. Auto-populate from summary.md open questions, learnings.jsonl pitfalls, deferred recommendations, unaddressed review findings. — Summary

## Task
Formalize TODO tracking as an integral part of the work harness workflow — a standalone command for creating and extracting TODOs, archive integration for ensuring nothing is forgotten, structured YAML storage for downstream consumption by roadmap and triage tools, and explicit TODO-to-work-unit linkage for lifecycle tracking.

## Current State
Step: review | Status: completed
Deliverables: 5/5
Mode: code

## Artifact Paths
- definition.yaml: .work/todos-workflow/definition.yaml
- state.json: .work/todos-workflow/state.json
- plan.json: .work/todos-workflow/plan.json
- research.md: .work/todos-workflow/research.md
- specs/: .work/todos-workflow/specs/
- team-plan.md: .work/todos-workflow/team-plan.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated; 5 deliverables (schema, extractor, command, archive integration, migration); user approved objective, deliverables, context pointers, constraints, gate policy; cross-model review incorporated (6 recommendations, 4 adopted)
- **research->plan**: pass — Research complete: schema patterns, extraction sources, archive integration point, ceremony pattern, pruning linkage, shell+agent boundary all documented
- **plan->spec**: pass — 4-wave plan with 5 deliverables: schema, extractor+migration (parallel), command, archive integration. Single specialist (harness-engineer). No file conflicts across waves.
- **spec->decompose**: pass — 5 specs written (todos-yaml-schema, extract-candidates-script, work-todos-command, archive-integration, migrate-existing-todos). All grounded in actual artifact structures. Acceptance criteria mapped 1:1 from definition.yaml.
- **decompose->implement**: pass — plan.json validated with 4 waves, no file conflicts. team-plan.md written. 5 deliverables registered in state.json with wave assignments.
- **implement->review**: pass — All 5 deliverables implemented across 4 waves: todos.schema.yaml, validate-todos.sh, extract-todo-candidates.sh, todos.yaml (9 entries migrated), work-todos.md, archive.md updated, definition.schema.yaml updated with source_todo

## Context Budget
Measurement unavailable

## Key Findings
- Shell scripts should be dumb collectors (JSON output); agent handles semantic reasoning (dedup, merge proposals)
- Archive ceremony is the primary integration point — insert TODO extraction after promote-components, before archived_at marking
- Existing ceremony pattern (promote-learnings.sh) provides the interaction template: present candidates with auto-recommendation, user confirms
- TODO entries need stable slug IDs (not positional numbers) for work-unit linkage via `source_todo` field in definition.yaml
- Three extraction sources cover ~95% of value: summary.md open questions, learnings.jsonl unpromoted pitfalls, reviews/*.json failed dimensions

## Open Questions
- Should `/work` init flow auto-populate `source_todo` when a TODO slug is passed as context, or is that a manual step for now?
- Should the `/work-todos` command be registered as a harness skill for discoverability?

## Recommendations
- Run the extraction script against real completed work units (harness-v2-status-eval, review-impl-scripts) during review to validate candidate quality
- The `/work-todos` command markdown should be registered in the harness skill list and CLAUDE.md command table
- Consider adding a `source_todo` field to the `/work` command's init flow so it's auto-populated when starting work from a TODO
