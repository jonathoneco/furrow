# Implementation Plan

## Objective
Implement the next Furrow-in-Pi slice around a primary `/work`-like entrypoint with supervised stage ceremony, create-on-use active-step scaffolding, blocker surfacing, seed visibility, and backend-canonical mutations.

## Planned work
1. Inspect backend and Pi adapter gaps against the architecture docs. ✅
2. Add minimal Go backend support for row init/focus, seed visibility, blocker reporting, and active-step artifact scaffolding. ✅
3. Build a primary Pi `/work` command that resolves or initializes rows, scaffolds the active step artifact on use, surfaces seed/blocker/checkpoint state, and uses backend commands for mutations. ✅
4. Update tests and relevant architecture docs if implementation changes planned reality. ✅
5. Validate Go tests, backend command flows, and Pi headless behavior. ✅

## Landed scope
- Backend: `row init`, `row focus`, `row scaffold`, enriched `row status`, stricter `row transition`, stricter `row complete`
- Pi: primary `/work` loop plus richer `/furrow-next`
- Docs: contract and architecture status updates
