# Spec: todos-roadmap-refresh

## Files
- `.furrow/almanac/todos.yaml` — update statuses, add new items
- `.furrow/almanac/roadmap-legacy.md` — regenerate via `alm triage`

## TODOs to Mark Done

Cross-reference with archived rows:
- `rename-to-furrow` — completed by namespace-rename row (archived)
- `beans-enforcement-integration` — completed by beans-enforcement-integration row (archived)
- `merge-specialist` — addressed by this row
- `legacy-todos-migration` — addressed by this row (audit found nothing to migrate)
- `almanac-knowledge-subcommands-learn-rationale-docs` — completed by cli-enhancements row (archived)
- `rws-review-archive-flow-and-deliverable-tracking` — completed by cli-enhancements row (archived)
- `default-supervised-gating` — completed by default-supervised-gating row (archived)

For each: set `status: done`, update `updated_at` to current ISO 8601.

## TODOs to Audit for Staleness

Review remaining active TODOs against current architecture:
- `seeds-concept` — check if seeds are now implemented (they are in .furrow/seeds/)
- `duplication-cleanup` — check if addressed by namespace-rename
- `work-folder-structure-and-cleanup` — check if addressed by furrow migration

## New TODOs to Add

Architecture implications discovered during this row:
- Any gaps identified during rationale audit that aren't covered by existing TODOs
- Bootstrap gap: merge-specialist can't guide its own first merge (document as known limitation, not a TODO)

## Roadmap Regeneration

1. After todos.yaml updates, run `alm validate` to confirm schema compliance
2. Run `alm triage` to regenerate roadmap with updated dependency graph
3. Verify the regenerated roadmap reflects Phase 4 completion status
