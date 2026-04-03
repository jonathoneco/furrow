# Phase 2: Enforcement & Execution

## Role

You are designing the enforcement and execution layer for a v2 agentic workflow harness. Phase 1 produced the foundational specs (prompt format, work definition schema, file structure, context model). This phase builds on those to design the concrete enforcement skeleton, eval infrastructure, team templates, and runtime adapters.

## Required Reading

Read **in full** before starting:

1. `.claude/CLAUDE.md` — project config
2. `docs/research/findings-synthesis.md` — key insights and resolved tensions
3. `docs/research/findings-platform-boundary.md` — platform capabilities, dual-runtime pattern
4. `docs/research/findings-eval-and-quality.md` — eval levels, bootstrap sequence, calibration
5. `docs/research/findings-gap-review.md` — enforcement skeleton, behavior catalog (15 behaviors)
6. `docs/research/findings-work-and-context.md` — multi-agent coordination
7. `docs/research/multi-model-architectures.md` — cross-model patterns and failure modes
8. `docs/architecture/PLAN.md` — overall decomposition plan

**Phase 1 outputs (your inputs)**:
9. `docs/architecture/prompt-format.md` — structured prompt format decision
10. `docs/architecture/work-definition-schema.md` — work definition schema
11. `docs/architecture/file-structure.md` — file structure
12. `docs/architecture/context-model.md` — context model

Read Phase 1 outputs carefully — your specs must be consistent with them.

## Settled Decisions

All decisions from Phase 1 are settled. Additionally from research:

- 4 hard gates (hooks): workflow entry, eval trigger, eval pass gate, artifact production
- 5 structural enforcements: one-at-a-time, correction containment, generator-evaluator separation, parallel execution, agent communication via files
- 6 procedural backstops: completion claims, progress validation, work summary, scope-check eval, correction limit, constraint compliance
- Bootstrap: Phase 0 (existence + traces) -> Phase 1 (deterministic + behavioral) -> Phase 2 (LLM-judge gating) -> Phase 3 (calibration) -> Phase 4 (deletion testing)
- Cross-model (Claude + Gemini) default for non-trivial eval
- LLM-as-judge is gating from first deployment, never advisory
- Token cost not a constraint (flat-rate Max plan)

## Deliverables

These 4 specs are largely independent — use parallel agent teams to draft them, then review for cross-spec consistency before finalizing.

### Spec 3: Hook/Callback Set (`docs/architecture/hook-callback-set.md`)

**What**: The minimum set of hooks (Claude Code) and callbacks (Agent SDK) implementing the enforcement skeleton.

**Must include for each hook/callback**:
- Name and purpose
- Which lifecycle event it binds to (Claude Code: which of the 24 lifecycle events; Agent SDK: which callback)
- What it checks or enforces
- What it produces (state updates, eval triggers, summaries, files)
- Which behavior(s) from the catalog it covers (reference by number)
- Enforcement level (Structural/Event-driven)
- Entry in `_rationale.yaml`

**Specific requirements**:
- **Gate rollback capability**: The operator can undo a gate approval within a configurable window. Design the mechanism (state snapshot before gate, rollback command, interaction with git).
- **Minimum set**: Target the smallest number of hooks that covers all High/Critical behaviors. Consolidate where lifecycle events overlap.
- **Dual-runtime parity**: Each Claude Code hook must have an Agent SDK callback equivalent. Document what's identical vs what differs.
- Map every behavior from the catalog (#1-#15) to its enforcement mechanism. Advisory behaviors (#8, #9, #14, #15) don't need hooks but should be noted as eval-only.

**Key research input**: The gap review identifies these as the minimum hook set:
1. Session-start: load work context + validate schema
2. Completion-claim: validate progress.json + trigger eval
3. Eval-gate: block next deliverable until eval passes
4. Session-end: auto-generate work summary
5. Correction-limit: pause after N eval failures on same deliverable

Design whether this is exactly right or needs adjustment based on Phase 1 decisions.

### Spec 4: Eval Infrastructure (`docs/architecture/eval-infrastructure.md`)

**What**: The eval runner, trace normalizer, LLM-judge runner, and calibration system.

**Must include**:
- **Eval runner**: How evals are discovered, executed, and results stored. Dual-runtime execution (hooks trigger in Claude Code, callbacks in Agent SDK).
- **Trace normalizer**: Normalized event format across both runtimes. What events are captured (tool calls, file mutations, completion claims, deliverable boundaries, eval triggers). Storage format.
- **LLM-judge runner**: How LLM-as-judge evals execute. Cross-model support (spawning eval agent on different model). Result format. How criteria from work definition flow into judge prompts.
- **Scope-check eval**: A distinct eval type validating work definitions before execution. Validates decomposition granularity, eval criteria quality, context pointer specificity. This gates autonomous trust level.
- **Calibration methodology**: Concrete workflow — sample evaluator outputs, surface disagreements to human, generate prompt updates, re-test, measure convergence. What triggers recalibration (agreement rate drops below threshold).
- **Prompt testing pyramid**: Static validation ($0), LLM-as-judge ($0.15/test), E2E via CLI ($3.85/test). How Furrow tests its own prompts and skills.
- **Bootstrap sequence**: Concrete implementation plan for each phase:
  - Phase 0: existence checks + trace infrastructure
  - Phase 1: deterministic + behavioral trace evals (gating)
  - Phase 2: LLM-judge gating + cross-model
  - Phase 3: calibration refinement + self-evolving eval proposals
  - Phase 4: component deletion testing
- **Result storage**: Where eval results live, format, how they feed calibration tracking.
- **Eval spec format**: The YAML format for eval specifications (deterministic, behavioral, LLM-judge types).

**Key research input**:
- Assertion-based behavioral trace evals (test functions that verify trace properties)
- Eval specs identical across runtimes; execution mechanism differs; result format identical
- Calibration metrics: >95% human agreement = well-calibrated; dropping = needs recalibration
- Deterministic eval convention: files in `evals/` returning 0 for pass

### Spec 5: Multi-Agent Team Templates (`docs/architecture/team-templates.md`)

**What**: Default team compositions, agent prompting, and coordination patterns.

**Must include**:
- **Team composition derivation**: How the coordinator decides team composition from the work definition. When to use the four-role architecture (planner, coordinator, specialists, evaluator) vs simpler configurations.
- **Specialist agent prompting**: Domain-appropriate, not generic. How specialist identity is constructed from deliverable metadata. Example prompts for common specialist types.
- **Agent context seeding contract**: Standardized prompt structure for all agent delegation:
  - Identity section (who you are, your domain expertise)
  - Task context (deliverable description, eval criteria, constraints)
  - File ownership (which files you may modify)
  - Input artifacts (what prior deliverables produced, context pointers)
  - Output expectations (what you must produce, format)
  - Completion criteria (how to know you're done, how to signal completion)
- **Model-specific instruction files**: Cross-model teams need provider-specific prompts. How are provider-specific prompt variants stored and loaded? (A Claude specialist and Gemini evaluator respond differently to same instructions.)
- **File-based communication protocol**: What files agents write, format, atomicity guarantees (write to temp then rename), read patterns, conflict resolution.
- **File ownership enforcement**: Each specialist declares files it owns. No overlapping ownership within a parallel wave. Validated at wave boundaries.
- **Parallel wave management**: How the coordinator reads the dependency graph and organizes execution waves. What happens at wave boundaries (eval, handoff, next wave spawn).
- **Cross-model evaluator configuration**: How the evaluator agent is spawned on a different model, what it receives (output artifacts + eval criteria only), result format.
- **Default team templates**: Pre-built compositions for common work types (feature implementation, bug fix, refactor, research, infrastructure change).

**Key research input**:
- Claude + Gemini captures 91% of five-model ceiling
- Error cascading: flat topologies safe, deep hierarchies dangerous
- Specialists named for domain, not process (auth-specialist, database-architect)
- Coordinator context stays lean — work def, progress state, result summaries only
- Both platforms provide team primitives (Claude Code Teams, Agent SDK nested agents)

### Spec 6: Dual-Runtime Adapters (`docs/architecture/dual-runtime-adapters.md`)

**What**: The thin adapters bridging shared conventions to each runtime.

**Must include**:
- **Claude Code adapter**:
  - Skills that load work definitions and set up sessions
  - How hooks bind to Claude Code's 24 lifecycle events
  - How the human-in-loop interacts with gates (approve/reject/rollback)
  - How progressive skill loading maps to the skill injection matrix from the context model
  - How teams/subagents are configured for multi-agent execution
- **Agent SDK adapter**:
  - Program templates that configure the agent loop from work definitions
  - How callbacks bind to Agent SDK's tool-call boundaries
  - How automated gate decisions work (thresholds, escalation)
  - How subagent spawning handles multi-agent execution
  - How session continuity works across long-running autonomous work
- **Shared layer**:
  - What's identical across runtimes (conventions, eval specs, work definitions, result formats)
  - What's runtime-specific (gate execution, human escalation, context injection, progress visibility)
  - The adapter interface — what contract does each adapter fulfill?
- **Parity testing**: How do you verify both adapters produce equivalent behavior? Shared eval specs should pass identically regardless of runtime.

## How to Work

1. Read all required documents (research + Phase 1 outputs)
2. Use agent teams to draft the 4 specs in parallel — these are largely independent
3. After drafts, review for cross-spec consistency (hooks reference eval infrastructure, team templates reference hook lifecycle, adapters reference both)
4. Present each spec to the human for review
5. Each spec must be concrete enough for implementation — hook names, event bindings, file paths, schema definitions

## Output Format

Each spec is a markdown file in `docs/architecture/`. Reference Phase 1 specs by path where relevant. Add entries to `_rationale.yaml` for every new component (no inline annotations). Use the prompt format decided in Phase 1 for any structured data.

## When Done

Notify the human that Phase 2 is complete. They will review in the overseer session before Phase 3 begins.
