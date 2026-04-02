# Phase 3: Lifecycle Workflows

## Role

You are designing the lifecycle workflows for a v2 agentic work harness. Phases 1-2 produced the foundation (data model, file structure, context model) and enforcement layer (hooks, evals, team templates, runtime adapters). This phase designs how work flows through the system — from ideation through execution to version control.

## Required Reading

Read **in full** before starting:

1. `.claude/CLAUDE.md` — project config
2. `docs/research/findings-synthesis.md` — key insights and resolved tensions
3. `docs/research/findings-work-and-context.md` — work decomposition, context tiers, coordination
4. `docs/research/findings-gap-review.md` — trust gradient, behavior catalog
5. `docs/research/findings-platform-boundary.md` — platform capabilities
6. `docs/architecture/PLAN.md` — overall decomposition plan

**Phase 1 outputs**:
7. `docs/architecture/prompt-format.md`
8. `docs/architecture/work-definition-schema.md`
9. `docs/architecture/file-structure.md`
10. `docs/architecture/context-model.md`

**Phase 2 outputs**:
11. `docs/architecture/hook-callback-set.md`
12. `docs/architecture/eval-infrastructure.md`
13. `docs/architecture/team-templates.md`
14. `docs/architecture/dual-runtime-adapters.md`

Read Phase 1 and 2 outputs carefully — your specs must be consistent with the established data model, enforcement skeleton, and team patterns.

## Settled Decisions

All Phase 1 and Phase 2 decisions are settled. Additionally:

- Trust gradient: Supervised (human + agent) > Delegated (human approves contract, agent executes) > Autonomous (agent + scope-check eval)
- The "handoff moment" in delegated mode: human approves work definition as contract
- Work definitions can grow mid-execution (scope change is a first-class concern)
- Research is a first-class work type
- Git is the audit trail

## Deliverables

These 4 specs are largely independent — use parallel agent teams.

### Spec 7: Ideation Loop (`docs/architecture/ideation-loop.md`)

**What**: How work definitions get created. The research covers execution well but ideation is the least-specified area.

**Must include**:
- **Supervised mode**: How the human and agent collaborate to explore the problem space, clarify requirements, and refine the work definition iteratively. This is pair-programming on the *what*, not the *how*.
- **Delegated mode**: How ideation produces a work definition the human approves as a contract before autonomous execution begins. What makes a good contract? What signals that ideation is "done"?
- **Autonomous mode**: How a trigger or high-level objective gets expanded into a full work definition with deliverables and eval criteria. The scope-check eval validates the result before execution begins.
- **Complexity emergence**: Complexity is NOT assessed upfront — it emerges as the problem space is explored. The ideation phase should surface complexity naturally (how many deliverables? what dependencies? what unknowns?). The work definition's shape IS the complexity assessment. No separate triage step.
- **Ideation artifacts**: What does ideation produce beyond the work definition? Design decisions, architecture notes, research findings that become work-tier context. How are these stored?
- **Adversarial evaluation**: For contested design decisions during ideation, structured deliberation — multiple agents arguing opposing positions, with synthesis producing a verdict. Design the protocol (when triggered, how agents are set up, how synthesis works, where the verdict is recorded).
- **The exploration-to-commitment transition**: At what point does exploration become a work definition? What are the signals? How does the human (or scope-check eval) know the problem space has been sufficiently explored?
- **Ideation for different work types**: A bug fix ideation is different from a feature ideation is different from a research ideation. How does the ideation loop adapt?

**This is the spec most likely to need human input.** Present options and tradeoffs rather than producing a finished spec autonomously. The research provides less guidance here than for other specs.

### Spec 8: Git Workflow (`docs/architecture/git-workflow.md`)

**What**: How the harness maps to version control.

**Must include**:
- **Deliverable-commit relationship**: One commit per deliverable? Atomic commits within deliverables? How does git history map to work progress?
- **Branch strategy**: Branch per work unit? Per deliverable? How do feature branches relate to work definitions?
- **PR as review artifact**: At trust levels 2-3, the PR is the review surface. How is it structured? What does it contain beyond the diff? (Work summary, eval results, evidence package — where do these go in the PR?)
- **Git as audit trail**: How do eval results, progress state, and work summaries map to git history? Are eval results committed? Is progress.json committed at each boundary?
- **Multi-agent git interaction**: How do multi-agent teams interact with git?
  - Option A: Worktrees per specialist (full isolation, merge at wave boundaries)
  - Option B: Single branch with file ownership enforcement (simpler, relies on non-overlapping files)
  - Option C: Hybrid (worktrees for overlapping concerns, single branch otherwise)
  - Recommend one with rationale.
- **Commit message conventions**: How do commit messages reference deliverables, work definitions, eval results?
- **Branch naming**: Convention that links branches to work definitions.

### Spec 9: Research as Work Type (`docs/architecture/research-work-type.md`)

**What**: Investigation and exploration work that produces findings rather than code.

**Must include**:
- **Research deliverables vs implementation deliverables**: What's different? Research produces findings, synthesis, recommendations — not code artifacts. How does the work definition schema accommodate this?
- **Eval criteria for research**: Thoroughness? Source quality? Actionability? Balanced perspective? How do you eval something that doesn't have "tests pass" as a criterion?
- **Research tooling**: Web search, document synthesis, source management. What tools does the research phase need? How are they provisioned via the skill injection matrix?
- **Research-to-implementation flow**: Research findings as context pointers for subsequent implementation work. How does a research work unit's output become input for an implementation work unit?
- **Standalone vs feeding**: Research can stand alone (pure investigation) or feed into implementation. Both paths must be first-class.
- **Research team composition**: What does a multi-agent research team look like? (Researcher + devil's advocate + synthesizer? Domain specialists per sub-topic?)
- **Research artifacts**: How are research findings stored, indexed, and made discoverable for future work?

### Spec 10: Scope Change Protocol (`docs/architecture/scope-change-protocol.md`)

**What**: How work definitions evolve mid-execution.

**Must include**:
- **Signal mechanisms**: How does the agent signal "this deliverable is bigger than expected" or "I found a new requirement"? Concrete format (scope change request in progress.json? separate file?).
- **Approval flow by trust level**:
  - Supervised: human redirects inline
  - Delegated: agent proposes, human approves
  - Autonomous: agent proposes, scope-check eval re-validates
- **Scope change types**: Deliverables can be added, split, removed, or modified. Each type has different implications. What's the protocol for each?
- **Interaction with progress tracking**: When scope changes, what happens to progress.json? How are completed deliverables preserved? How are new deliverables integrated into the dependency graph?
- **Interaction with eval**: Does scope change trigger re-evaluation of the work definition (scope-check eval)? For which trust levels?
- **Pause vs inline adjustment**: When does scope change trigger a pause (wait for approval) vs inline adjustment (proceed with expanded scope)? What's the decision criteria?
- **Scope change limits**: Can an agent keep expanding scope indefinitely? What prevents unbounded growth? (Maximum deliverable count? Maximum scope change count? Human review after N changes?)
- **Audit trail**: How are scope changes recorded? (Git commit? Progress.json history? Separate changelog?)

## How to Work

1. Read all required documents (research + Phase 1 + Phase 2 outputs)
2. Use agent teams to draft the 4 specs in parallel
3. **Spec 7 (Ideation Loop) needs more human input than the others** — present options rather than a finished spec
4. After drafts, review for cross-spec consistency (ideation produces work definitions that the git workflow commits, scope changes modify work definitions that the ideation loop created)
5. Each spec must reference the enforcement mechanisms from Phase 2 where relevant

## Output Format

Markdown files in `docs/architecture/`. Reference prior specs by path. Add entries to `_rationale.yaml` for every new component (no inline annotations). Use the prompt format decided in Phase 1.

## When Done

Notify the human that Phase 3 is complete. They will review in the overseer session before Phase 4 begins.
