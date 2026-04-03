# Team Plan: Replace /work-roadmap with /harness:triage

## Scope Analysis

4 deliverables, 2 waves, single specialist type (harness-engineer). All deliverables touch different files with no overlap. Small enough for a single implementer executing sequentially.

## Team Composition

No team needed — single harness-engineer implements all deliverables inline. The wave 1 items are independent but small enough that parallelism overhead exceeds benefit.

## Task Assignment

### Wave 1 (independent, any order)

1. **glob-regex-bugfix** — Fix `scripts/triage-todos.sh` lines 202-203: add `gsub("/$"; "/**")` before glob conversion
2. **triage-command-spec** — Copy `commands/work-roadmap.md` → `commands/triage.md`, rename invocation and references to `/harness:triage`
3. **work-todos-auto-commit** — Add commit step after validate in both modes of `commands/work-todos.md`

### Wave 2 (depends on triage-command-spec)

4. **harness-registration** — Create symlink, delete `commands/work-roadmap.md`, repair references in 4 files

## Coordination

Sequential execution, no coordination needed. Wave 2 waits for wave 1 completion only because it deletes the file that wave 1 copies from.

## Execution Order

Recommended: glob-regex-bugfix → triage-command-spec → work-todos-auto-commit → harness-registration

This order ensures the bugfix is in place before the triage command is finalized, and the old file exists when we need to copy it.
