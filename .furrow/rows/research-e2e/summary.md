# Research E2E — T3 Summary

## Objective
Sweep research-mode code paths for bugs, fix them, close out ROADMAP T3.

## Approach
Instead of a full pipeline exercise (already done by harness-v2-status-eval), ran a
parallel audit of all research-mode code paths using 4 specialist agents, then fixed
the bugs found.

## Bugs Found and Fixed (7)

| # | File | Fix |
|---|------|-----|
| 1 | `auto-advance.sh` | Validate mode value; warn on invalid/corrupted mode |
| 2 | `step-transition.sh` | Skip wave conflict check in research mode |
| 3 | `run-eval.sh` (Phase A) | Check non-empty files, not just file count |
| 4 | `run-eval.sh` (Phase B) | Add research dimension handling instead of skipping all |
| 5 | `promote-components.sh` | Guard against promotion in research mode |
| 6 | `select-dimensions.sh` | Explicit routing for research step |
| 7 | `skills/plan.md` | Add missing Research Mode section |

## Not Fixed (low severity, deferred)

- `promote-learnings.sh`: No [unverified] check for research-mode learnings
- `generate-plan.sh`: file_ownership passthrough (addressed by plan.md guidance)

## Commit
`6874c1a` on `work/research-e2e`
