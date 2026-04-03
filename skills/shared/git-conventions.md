# Git Conventions

Shared git workflow conventions for implementation and review steps.

## Branch Naming
Branch format: `work/{row-name}`. One branch per row.
Created at decompose->implement boundary via `rws init` (with branch creation).
Parallel specialists share the branch — file ownership prevents conflicts.

## Commit Format
Conventional commits with row scope and trailers:
```
{type}({row}): {description}

Deliverable: {deliverable-name}
Step: {step}
```
Types: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`.
Gate commits: `chore({name}): gate pass {from}->{to}`.

## When to Commit
- After each deliverable completion (min one commit per deliverable)
- After gate records, summary.md regeneration, definition.yaml, plan.json

## Merge Policy
- Within work branch: rebase onto main periodically.
- Back to main: `git merge --no-ff` via `frw merge-to-main`.
  No squash — individual commits preserve deliverable traceability.
- Merge requires archived row.

## Wave Boundaries
Run `rws diff` before launching the next wave to check for conflicts.
See `docs/git-conventions.md` for the full reference.
