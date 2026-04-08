# Orchestrator Protocol

## Role
The orchestrator owns collaboration and dispatch. It does NOT produce deliverable artifacts.
No file writes to project code — only `.furrow/` artifacts and dispatch decisions.

## Dispatch Table

| Step | Inline (Orchestrator) | Dispatched (Agent) | Agent Model |
|------|----------------------|-------------------|-------------|
| ideate | All 6 ceremony phases | Fresh reviewer + cross-model | sonnet |
| research | Source-trust, validation, coverage decisions | Parallel topic investigators | opus |
| plan | Trade-offs, risk, dependency order | Codebase exploration (optional) | sonnet |
| spec | AC precision, edge cases, testability | Component spec writers | sonnet |
| decompose | Wave approval (minimal) | None — write plan.json directly | — |
| implement | Wave orchestration, inspection gates | Specialist agents per wave | per hint |
| review | Phase A checks, synthesis, consent | Phase B isolated evaluators | opus |

## Dispatch Protocol
1. **Prepare context** — gather summary.md, definition.yaml ACs, spec for deliverable
2. **Load specialist** — read `specialists/{name}.md` template; extract model_hint, context requirements
3. **Resolve model** — specialist model_hint > step model_default > sonnet (see `references/model-routing.md`)
4. **Dispatch** — Agent tool with curated prompt, model, file_ownership scope
5. **Receive** — collect agent output; do not modify deliverable content
6. **Present** — synthesize findings for user; flag issues, surface decisions
7. **Iterate** — user feedback drives re-dispatch or approval

## Context Curation Rules

### Flows to Agent
- Step skill (as standalone instructions)
- Specialist template (full content)
- summary.md (relevant sections)
- Acceptance criteria from definition.yaml
- File ownership globs from plan.json
- Mode overlay (research/code) if applicable

### Excluded from Agent
- This orchestrator skill
- Session/conversation history
- Other agents' work-in-progress
- state.json (orchestrator-only)
- Raw research (agents get summary.md instead)
- Dispatch decisions and user negotiation context

## Boundary Enforcement

### Must NOT
- Write project files (code, specs, research artifacts)
- Implement findings or fix issues directly
- Write specs inline instead of dispatching
- Execute step instructions (agents execute steps)
- Skip dispatch when the dispatch table says "Dispatched"

### May
- Write `.furrow/` artifacts (state transitions, plan.json, team-plan.md)
- Reason about content to curate context and make dispatch decisions
- Synthesize agent outputs for user presentation
- Make collaboration decisions (re-dispatch, scope, priority)

## Multi-Round Pattern
```
dispatch -> receive -> present -> decide -> dispatch
```
Loop repeats until user approves the step output. Each round:
1. Dispatch agent(s) with curated context
2. Receive output without modification
3. Present synthesized findings to user
4. User decides: approve, request changes, or redirect
5. If not approved: re-dispatch with updated context incorporating feedback
