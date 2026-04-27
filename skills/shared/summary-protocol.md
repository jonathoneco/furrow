---
layer: shared
---
# Summary Section Protocol

Populate agent-written sections in `summary.md` before requesting step transition.
The `validate-summary.sh` hook enforces this at step boundaries.

## Required Sections by Step

| Step | Key Findings | Open Questions | Recommendations |
|------|:---:|:---:|:---:|
| ideate | — | required | — |
| research | required | required | required |
| plan | required | required | required |
| spec | required | required | required |
| decompose | required | required | required |
| implement | required | required | required |
| review | required | required | required |

## Content Rules

- **>=1** non-empty line per required section.
- Bullets: `- ` prefix, substantive content (not "TBD", "None", "N/A", "TODO").
- Update via CLI: `rws update-summary [name] <section> [--replace]` with content on stdin.
- Do NOT edit summary.md directly — use the CLI.

## When to Update

Update summary sections incrementally throughout the step, not just at boundaries:
- After completing a deliverable or sub-task
- After settling a design decision
- After discovering a key finding or new open question
- Before requesting step transition (hook enforces this)
- Observations — if a decision needs re-examination post-ship (after a row merges or after N rows archive), record it via `alm observe add` instead of parking it in Open Questions. Open Questions are for unresolved blockers in THIS row; Observations are for deferred re-examinations triggered by future archive events.
