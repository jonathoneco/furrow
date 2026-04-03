# Phase 4: Operations

## Role

You are designing the operational layer for a v2 agentic workflow harness. Phases 1-3 established the data model, enforcement skeleton, eval infrastructure, team templates, and lifecycle workflows. This phase designs how Furrow operates in production — autonomous triggering, observability, concurrency, error recovery, and health checks.

## Required Reading

Read **in full** before starting:

1. `.claude/CLAUDE.md` — project config
2. `docs/research/findings-synthesis.md` — key insights
3. `docs/research/findings-gap-review.md` — trust gradient, behavior catalog
4. `docs/research/findings-platform-boundary.md` — platform capabilities
5. `docs/research/findings-eval-and-quality.md` — eval levels, quality gates
6. `docs/architecture/PLAN.md` — overall decomposition plan

**Phase 1-3 outputs** (read all):
7. `docs/architecture/prompt-format.md`
8. `docs/architecture/work-definition-schema.md`
9. `docs/architecture/file-structure.md`
10. `docs/architecture/context-model.md`
11. `docs/architecture/hook-callback-set.md`
12. `docs/architecture/eval-infrastructure.md`
13. `docs/architecture/team-templates.md`
14. `docs/architecture/dual-runtime-adapters.md`
15. `docs/architecture/ideation-loop.md`
16. `docs/architecture/git-workflow.md`
17. `docs/architecture/scope-change-protocol.md`

## Settled Decisions

All Phase 1-3 decisions are settled. Key operational decisions from research:

- Trust gradient with three levels (Supervised/Delegated/Autonomous)
- Same agent behavior at all trust levels; only gate policies differ
- Gate rollback capability (operator can undo gate approval within window)
- Correction limit: after N eval failures on same deliverable, pause
- Work context in files, not conversation (survives unplanned session boundaries)
- Auto-generated work summaries at boundaries

## Deliverables

These 5 specs are independent — use parallel agent teams.

### Spec 11: Autonomous Triggering (`docs/architecture/autonomous-triggering.md`)

**What**: At trust level 3 (autonomous), work starts from events, not humans.

**Must include**:
- **Trigger types**: What events can trigger autonomous work?
  - Scheduled tasks (cron-style, using Claude Code's CronCreate or Agent SDK scheduling)
  - Webhooks (GitHub events, CI failures, monitoring alerts)
  - Incident alerts (PagerDuty, Grafana, custom monitoring)
  - Dependent work completion (work unit A finishes -> work unit B starts)
  - Manual trigger with autonomous execution (human fires and forgets)
- **Trigger-to-work-definition**: How does a trigger produce a work definition?
  - Template expansion (pre-defined work def with variable substitution from trigger context)
  - LLM generation (agent reads trigger context, produces work def, scope-check eval validates)
  - Pre-registered work definitions activated by conditions
- **Trust configuration**: Per-trigger trust level. Some triggers always produce delegated work (human must approve). Some are fully autonomous. Configuration format.
- **Guardrails**: What prevents runaway autonomous work?
  - Scope limits per trigger (max deliverables, max files touched, restricted directories)
  - Escalation policies (auto-pause after N hours, mandatory human review for certain outputs)
  - Budget guards (max concurrent autonomous work units, max per day)
  - Kill switch (operator can halt all autonomous work instantly)
- **Trigger registration**: How are triggers configured? File-based? CLI command? Both?
- **Trigger audit trail**: What's logged when a trigger fires? (Trigger source, timestamp, generated work definition, scope-check result)

### Spec 12: Observability (`docs/architecture/observability.md`)

**What**: How the operator monitors and reviews work.

**Must include**:
- **Notification system**: What events trigger notifications? Format and channel.
  - Gate failures (eval failed, deliverable blocked)
  - Escalation requests (agent is stuck, needs human input)
  - Work completion (work unit finished, PR ready for review)
  - Anomalies (correction spiral detected, scope change proposed, unusual patterns)
  - Trigger events (autonomous work started, scope-check results)
- **Review queue**: How does the operator review completed autonomous work?
  - Evidence package format and presentation
  - Approval/rejection flow
  - Batch review for multiple completed work units
- **Real-time monitoring**: Can the operator watch work in progress?
  - Progress dashboard (which deliverables done, which in progress, which blocked)
  - Agent activity feed (what the current specialist is doing)
  - Context health (how full is each agent's context, any near-limit warnings)
- **Audit trail**: What's recorded and where?
  - Eval results per deliverable (structured JSON)
  - Agent traces (normalized event log)
  - Decision logs (scope changes, gate approvals/rejections, escalations)
  - Cost metrics (token usage per work unit, per agent, per eval — even on flat rate, for waste detection)
- **Tooling**: CLI commands, dashboard views, or both? What's the concrete interface?

### Spec 13: Concurrent Work Streams (`docs/architecture/concurrent-work-streams.md`)

**What**: Multiple active work definitions running in parallel.

**Must include**:
- **Work isolation**: How are concurrent work units isolated?
  - Separate work directories (each work unit in its own directory)
  - Separate git branches (no merge conflicts between work streams)
  - Context isolation (agents from different work units don't share context)
- **Resource contention**: What shared resources exist and how are conflicts prevented?
  - Git branch conflicts (two work units touching same files)
  - Context budget across concurrent agents
  - File system state (two work units writing to same config files)
- **Cross-work interaction**: Can work units depend on each other?
  - Work unit completion as trigger for another (covered in autonomous triggering)
  - Shared artifacts (one work unit's output is another's input)
  - Merge ordering (when two work units need to merge to same branch)
- **Operator view**: Dashboard showing all active work across all trust levels.
  - Status per work unit (ideation, executing, reviewing, blocked, complete)
  - Resource utilization (agent count, context usage)
  - Conflict detection (overlapping file ownership across work units)
- **Limits**: Maximum concurrent work units. How does Furrow degrade gracefully when at capacity?

### Spec 14: Error Recovery (`docs/architecture/error-recovery.md`)

**What**: What happens when things go wrong during execution.

**Must include**:
- **Failure taxonomy** (three categories with different recovery strategies):
  1. **Correction spiral**: Repeated failures compounding. Recovery: kill agent, clear context, retry fresh. Detected by: eval failure count per deliverable exceeding threshold.
  2. **Transient block**: Missing dependency, access issue, external service down. Recovery: pause, notify human, resume when unblocked. Detected by: specific error patterns (permission denied, not found, timeout).
  3. **Unexpected state**: Agent confused, producing nonsensical output, stuck in loop. Recovery: escalate to human. Detected by: progress stall (no meaningful file changes in N tool calls), incoherent completion claims.
- **Signal mechanisms**: How does the agent signal its state?
  - "I'm blocked" (writes block reason to progress.json, hook notifies)
  - "I failed" (eval failure triggers standard recovery)
  - "I'm spiraling" (correction limit hook detects and halts)
- **Escalation path**: Notification -> human review -> redirect or unblock. Concrete format for escalation requests.
- **State preservation**: How is work state preserved during a block?
  - Progress.json captures current state
  - Specialist output preserved in workspace
  - Context recovery from work summary when agent is replaced
- **Dead-man switch**: Timeout for autonomous agents that stop making progress.
  - What constitutes "progress"? (file changes, tool calls, completion claims)
  - How long before timeout triggers?
  - What action does timeout take? (Pause, notify, kill, retry)
- **Gate rollback**: Operator undoes a gate approval.
  - Rollback window (how long after approval?)
  - What state is reverted? (progress.json, git commits, eval results)
  - How does rollback interact with downstream work? (Block dependents, notify coordinator)
- **Recovery patterns**: For each failure type, the concrete sequence of recovery actions.

### Spec 15: Health Checks (`docs/architecture/health-checks.md`)

**What**: Self-diagnosis capability.

**Must include**:
- **Pre-session validation** (runs at session start):
  - State corruption detection (progress.json inconsistent with file artifacts)
  - Missing artifact detection (work definition references files that don't exist)
  - Invalid schema detection (work definition, eval specs, progress file fail validation)
  - Stale work detection (work in progress but no activity for N days)
- **Post-step validation** (runs after each significant step):
  - Handoff existence check (after deliverable completion, handoff artifact exists)
  - Progress consistency (progress.json matches actual state)
  - Eval result integrity (eval results exist for claimed completions)
- **Automatic repair** (where safe):
  - Re-generate missing handoff from progress state
  - Re-validate and fix progress.json from file artifacts
  - Clean up orphaned specialist workspaces
- **Stale skill detection**:
  - Freshness metadata (last-reviewed date per skill)
  - Automatic flagging when skills haven't been reviewed in N days
  - Eval coverage check (skills without corresponding evals flagged)
- **Invocation modes**:
  - Automatic at session start (via hook)
  - Manual CLI command
  - Post-compaction recovery (detect and repair after context compression)
- **Health report format**: Structured output showing what's healthy, what's degraded, what's broken, with repair actions taken or recommended.

## How to Work

1. Read all required documents
2. Use agent teams to draft all 5 specs in parallel
3. These specs are the most derivative — they build directly on Phases 1-3. Ensure consistency with prior decisions.
4. Present specs to human for review
5. Each spec should be concrete: configuration formats, CLI commands, file paths, not just descriptions

## Output Format

Markdown files in `docs/architecture/`. Reference prior specs by path. Add entries to `_rationale.yaml` for every new component (no inline annotations). Use the decided prompt format.

## When Done

Notify the human that Phase 4 is complete. They will review in the overseer session before Phase 5 begins.
