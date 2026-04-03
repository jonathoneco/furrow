# Team Plan: Default Supervised Gating

## Scope Analysis
6 deliverables across 2 waves. All shell-specialist domain. 16 files modified, 2 created.

## Team Composition
Single specialist (shell-specialist) — all deliverables are shell scripts, hooks, and markdown. No parallel agents needed within waves since file ownership doesn't overlap.

## Wave Execution

### Wave 1 (4 deliverables, independent)
| Deliverable | Files | Notes |
|-------------|-------|-------|
| two-phase-gate | step-transition.sh, state.schema.json, update-state.sh, validate.sh | Core mechanism — implement first |
| summary-generation-fix | regenerate-summary.sh | Small, independent |
| bypass-prevention | transition-guard.sh (new), settings.json | Independent |
| precheck-supervised-update | gate-precheck.sh | 5-line deletion |

### Wave 2 (2 deliverables, depends on wave 1)
| Deliverable | Files | Notes |
|-------------|-------|-------|
| verdict-file-enforcement | run-gate.sh, verdict-guard.sh (new), settings.json | Depends on two-phase-gate (--confirm validates verdict) |
| skill-transition-protocol | 7 skill .md files | References final --request/--confirm behavior |

## Coordination
Sequential within session. Wave 1 deliverables can be implemented in any order (no file overlap). Wave 2 starts after wave 1 complete. Settings.json is touched by both bypass-prevention and verdict-file-enforcement — implement bypass-prevention first, then verdict-file-enforcement adds to same hook array.

## Skills
- `specialists/shell-specialist.md` for all deliverables
