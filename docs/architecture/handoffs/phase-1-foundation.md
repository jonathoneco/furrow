# Phase 1: Foundation — Core Data Model & Conventions

## Role

You are designing the foundational architecture for a v2 agentic work harness. This phase produces the 4 specs that everything else builds on. Work collaboratively with the human — present options and tradeoffs at each decision point rather than producing finished specs autonomously.

## Required Reading

Read these files **in full** before starting. They contain settled decisions you must not reopen.

1. `docs/KICKOFF.md` — intent and constraints
2. `.claude/CLAUDE.md` — project config
3. `docs/research/findings-synthesis.md` — 8 key insights, decision dependency map, 5 resolved tensions
4. `docs/research/findings-platform-boundary.md` — platform capabilities, harness identity, dual-runtime pattern
5. `docs/research/findings-work-and-context.md` — work decomposition, context tiers, multi-agent coordination
6. `docs/research/findings-eval-and-quality.md` — 4 eval levels, bootstrap sequence, quality gates
7. `docs/research/findings-gap-review.md` — enforcement skeleton, trust gradient, behavior catalog (15 behaviors)
8. `docs/architecture/PLAN.md` — overall decomposition plan

## Settled Decisions (Do Not Reopen)

- Work definition format: YAML with 5 required fields (objective, deliverables, eval_criteria, context_pointers, constraints)
- Three context tiers: Ambient (platform-managed) > Work (harness-managed) > Session (platform-managed)
- Three enforcement levels: Structural > Event-driven > Advisory
- Trust gradient: Supervised > Delegated > Autonomous (same agent behavior, different gate policies)
- Multi-agent teams default for 2+ deliverables
- Cross-model review default for non-trivial work
- LLM-as-judge gating from first deployment
- ~20-30 files total harness size
- Dual-runtime: Claude Code skills/hooks + Agent SDK programs/callbacks
- Eval-first: every behavioral expectation has an eval

## Deliverables

Produce 4 specs in `docs/architecture/`, working through them sequentially since they're tightly coupled. Each new component must have an entry in `_rationale.yaml`.

### Deliverable 0: Structured Prompt Format Decision

**What**: The harness involves structured prompts throughout — work definitions, eval specs, agent seeding contracts, handoff prompts. Recommend the standard format.

**Options to evaluate**:
- YAML frontmatter + markdown body (Anthropic Skills standard)
- Full YAML
- XML tags (Claude parses these natively)
- Hybrid (structured metadata in YAML, long-form instructions in markdown)

**Consider**:
- Human readability vs machine parseability
- Compatibility with platform standards (Anthropic Skills use YAML frontmatter + markdown)
- Suitability for long-form instructions vs structured metadata
- What the research on prompt composition supports (criteria wording shapes agent output)
- Dual-runtime consumption (both runtimes need to parse these)

**Output**: A short decision document with rationale. Save as `docs/architecture/prompt-format.md`.

**Present the options to the human with tradeoffs before committing.**

### Deliverable 1: Work Definition Schema (`docs/architecture/work-definition-schema.md`)

**What**: The full YAML schema for work definitions — the core data model everything references.

**Must include**:
- The 5 required fields with full type definitions
- Deliverable specifications with dependency annotations for parallel execution
- Eval criteria per deliverable — criteria wording directly shapes agent output (Anthropic blog). Include guidance for criteria phrasing.
- Context pointers (specific symbols/sections, not whole files). Example from research:
  ```yaml
  context_pointers:
    - path: src/auth/middleware.go
      symbols: [AuthMiddleware, ValidateToken]
      note: "Current auth implementation to extend"
  ```
- Gate policy configuration (trust level, per-task)
- Agent team composition (specialist types per deliverable, or auto-derived)
- File ownership declarations per deliverable (which files each specialist can modify — prevents merge conflicts in parallel execution)
- Optional fields: dependency graph between deliverables, complexity signals

**Design decisions to discuss with human**:
- How much team composition goes in the schema vs is derived by the coordinator?
- Should eval criteria be inline or reference separate eval spec files?
- How granular should file ownership be? (exact files vs glob patterns vs directories)
- Should the schema support work-definition-level defaults that individual deliverables can override?

### Deliverable 2: File Structure (`docs/architecture/file-structure.md`)

**What**: The complete directory layout of the harness. Every file, its purpose, and which research finding it implements.

**Must include**:
- Convention files (work definition schema, eval spec format, progress tracking format)
- Enforcement files (hooks for Claude Code, callback definitions for Agent SDK)
- Runtime adapters (Claude Code skills, Agent SDK program templates)
- Eval infrastructure (eval runner, trace normalizer, LLM-judge runner)
- Documentation (what goes in CLAUDE.md vs skills vs hooks)
- Health check tooling (self-diagnosis for state corruption, missing artifacts)
- Per-work-unit directory structure (where active work lives, where archives go)
- Reusable templates (team templates, specialist prompts, eval specs)

**Constraints**:
- Target ~20-30 files total
- Prefer flat over deep nesting
- Every new component should have a `_rationale.yaml` entry
- The structure itself is a convention — it should be self-documenting

**Design decisions to discuss with human**:
- Flat structure vs grouped by concern (conventions/, enforcement/, adapters/, eval/)?
- Where do work units live? (project-root work/ directory? configurable?)
- How are reusable artifacts (team templates, eval specs) distinguished from instance artifacts (specific work definitions)?

### Deliverable 3: Context Model (`docs/architecture/context-model.md`)

**What**: Deep specification of the three context tiers, cross-work context flow, and the skill injection matrix.

**Must include**:
- **Ambient tier**: What exactly goes in CLAUDE.md? How does the harness contribute? Size budget (target: <=200 lines). Maintenance strategy.
- **Work tier**: Storage format, loading strategy (eager vs on-demand), eviction policy, maximum budget. Context pointers reference specific symbols/sections, not whole files.
- **Session tier**: How does the harness interact with conversation context? What should be in conversation vs on disk?
- **Skill injection matrix**: Different work phases need different skills loaded. A routing table mapping phase/deliverable-type to the skill set needed.
- **Model-specific context handling**: Context anxiety is model-dependent. The context strategy should be configurable per model.
- **Cross-work flow**: How does context promote between tiers? What triggers promotion? Who decides?
- **Context recovery**: When a session starts fresh or compaction occurs — concrete recovery sequence. (Read handoff prompt + progress state, nothing else.)
- **Work summary format**: The ~200-500 token summary auto-generated at boundaries. Exact sections and structure.

**Key research positions to honor**:
- Work context stays in files, not conversation history (single most important principle)
- Progressive loading is the default — session start loads only work summary
- No context-at-70% warning (induces context anxiety, makes things worse)
- Deliverable sizing is a context management strategy (completable in single session)
- Correction limits prevent context bloat from fix spirals

**Design decisions to discuss with human**:
- What's the concrete work-tier budget? (Token count? File count? Both?)
- How does the skill injection matrix interact with Claude Code's progressive skill loading?
- Should cross-work promotion be human-initiated only, or can evals trigger it?

## How to Work

1. Read all research documents in full first
2. Start with Deliverable 0 (prompt format) — present options to the human
3. After prompt format is decided, work through Deliverables 1-3 sequentially
4. For each deliverable: present key design decisions with tradeoffs, get human input, then produce the spec
5. Each spec should be concrete enough for implementation — file paths, schema definitions, not just descriptions
6. Use agent teams for research/exploration, but design decisions happen in conversation with the human

## Output Format

Each spec is a markdown file in `docs/architecture/`. Use the decided prompt format for any structured data within the specs (schemas, examples). Add entries to `_rationale.yaml` for every new component (no inline annotations).

## When Done

Notify the human that Phase 1 is complete. They will review in the overseer session before Phase 2 begins.
