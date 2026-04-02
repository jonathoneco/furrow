# Architecture Phase — Decomposition Plan

## Overview

19 architectural specs grouped into 6 phases. Each phase runs in a fresh session using the handoff prompt in `docs/architecture/handoffs/`.

## Dependency Graph

```
Phase 1 (Foundation) ─────────────→ Phase 2 (Enforcement & Execution)
  Prompt Format Decision                #3 Hook/Callback Set
  #2 Work Definition Schema             #4 Eval Infrastructure
  #1 File Structure                     #5 Multi-Agent Team Templates
  #17 Context Model                     #6 Dual-Runtime Adapters
          │                                       │
          └──────────────┬────────────────────────┘
                         ▼
                  Phase 3 (Lifecycle)          Phase 4 (Operations)
                    #7 Ideation Loop             #11 Autonomous Triggering
                    #8 Git Workflow              #12 Observability
                    #9 Research as Work Type     #13 Concurrent Work Streams
                    #10 Scope Change Protocol    #14 Error Recovery
                         │                       #15 Health Checks
                         └──────────┬────────────┘
                                    ▼
                          Phase 5 (Knowledge & Ecosystem)
                            #16 Artifacts
                            #18 Self-Improvement
                            #19 Integrations
                                    │
                                    ▼
                          Phase 6 (Cross-Spec Consistency Review)
```

## Phase Summary

| Phase | Specs | Human Involvement | Approach |
|-------|-------|-------------------|----------|
| 1 — Foundation | 4 (sequential) | High — co-design | Interactive design session |
| 2 — Enforcement | 4 (parallel) | Medium — review | Agent team, parallel specs |
| 3 — Lifecycle | 4 (parallel) | Medium — ideation needs input | Agent team, parallel specs |
| 4 — Operations | 5 (parallel) | Low-Medium — review | Agent team, parallel specs |
| 5 — Knowledge | 3 (parallel) | Medium — self-improvement needs input | Agent team, parallel specs |
| 6 — Consistency | 1 (review pass) | Low — review final | Single-pass review |

## Minimum Viable Set for Implementation

Phases 1 + 2 (8 specs) are sufficient to begin Phase 0 of the bootstrap sequence.

## Output Location

All specs write to `docs/architecture/`. Each spec is a separate file named by its topic (e.g., `work-definition-schema.md`, `hook-callback-set.md`).

## Progress Tracking

After each phase session completes, the human reviews output in this overseer session before approving the next phase.

| Phase | Status | Session | Notes |
|-------|--------|---------|-------|
| 1 | NOT STARTED | — | — |
| 2 | NOT STARTED | — | — |
| 3 | NOT STARTED | — | — |
| 4 | NOT STARTED | — | — |
| 5 | NOT STARTED | — | — |
| 6 | NOT STARTED | — | — |
