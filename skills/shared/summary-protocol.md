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

- **>=2** non-empty bullet points per required section.
- Bullets: `- ` prefix, substantive content (not "TBD", "None", "N/A", "TODO").
- Update BEFORE requesting step transition — the hook blocks incomplete sections.
