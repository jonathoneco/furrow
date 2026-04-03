# Team Plan: post-merge-cleanup

## Scope Analysis
5 deliverables, all mechanical text replacements. No design decisions remain.

## Team Composition
Single agent — all changes are small text edits across shell scripts and markdown. No specialist dispatch needed; the volume doesn't justify coordination overhead.

## Task Assignment

### Wave 1 (parallel)
- **cli-path-install**: symlink 3 CLIs
- **script-path-fixes**: 9 path replacements in furrow-doctor.sh + measure-context.sh

### Wave 2 (parallel)
- **command-spec-fixes**: ~30 path replacements across 5 command files + remove alm fallback
- **skill-template-refs**: add template pointer to skills/plan.md

### Wave 3 (sequential)
- **stale-state-cleanup**: verify .focused, run doctor + measure-context

## Coordination
None needed — single agent executing sequentially by wave.
