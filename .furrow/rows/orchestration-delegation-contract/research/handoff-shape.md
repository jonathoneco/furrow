# Handoff-Shape Study (T1)

**Research date:** 2026-04-25
**Question:** What field set should Furrow's typed handoff schema contain, and is the
"typed-fields-rendered-to-markdown" framing structurally valid?

## Q1 — Field-Set Recommendation

A delegation/handoff contract decomposes into **three logical bands**. Every framework
surveyed touches at least the first two; well-engineered ones split all three.

### Band A — Receiver identity & persona (who is receiving)

These fields describe the *receiving* agent, set independently of any single task.
Common across Claude Code subagents, OpenAI Agents SDK, CrewAI, and Furrow's own
`specialists/{name}.md` template.

- `target` *(required)* — addressing axis: `driver:{step}` | `engine:specialist:{id}` | `operator`. **Furrow-specific:** carries the layer label so D3's enforcement can scope tools.
- `persona` *(optional, by reference)* — pointer to a specialist brief / role definition (not inlined; loaded by D4's context bundler). Maps to CrewAI's `role`/`goal`/`backstory`, OpenAI Agents `instructions`, Claude Code subagent system-prompt body.
- `model` / `effort` *(optional)* — capacity hints; honored by Claude Code subagent frontmatter and OpenAI Agents `model`. Furrow can defer to harness defaults but the slot exists.

### Band B — Task scope & contract (what is being asked)

Every framework requires this band and converges on a remarkably small core: a description, a deliverable contract, and constraints.

- `objective` *(required)* — one-paragraph statement of what to do. CrewAI `description`, OpenAI Agents tool description, LangGraph handoff "task description".
- `deliverables` *(required)* — what must be produced and what "done" looks like. CrewAI `expected_output`, OpenAI Agents `output_type` (Pydantic schema), LangGraph state-update keys. **Furrow-specific:** structured list (file ownership + acceptance criteria) because engines write code.
- `constraints` *(required)* — explicit do/don't rules, scope limits, file-ownership boundaries. No framework names this exactly, but every one has it implicitly (system-prompt boilerplate, guardrails, tool restrictions).
- `return_format` *(required)* — schema/shape of the EOS-report. OpenAI Agents `output_type` is the cleanest analog; CrewAI's `output_pydantic`/`output_json` similar. **Critical for Furrow** because drivers parse engine returns.

### Band C — Grounding (what context is provided)

Where prior art splits the most. Some frameworks pass shared mutable state (LangGraph),
some attach a context array (OpenAI Agents `input_filter`/`HandoffInputData`),
some pass nothing beyond the prompt (CrewAI `context`).

- `grounding` *(required)* — references to artifacts, prior decisions, learnings. **Furrow-specific:** the structured context bundle from D4 (`furrow context for-step --target ...`). Replaces ad-hoc skill loading.
- `prior_artifacts` *(optional)* — pointers to upstream-step deliverables (state, summary excerpts, gate evidence). Maps to CrewAI's `context: List[Task]` (dependencies on other task outputs).
- `tools_available` *(implicit, enforced elsewhere)* — Furrow lets D3's layer-policy own this; do not duplicate in the handoff schema.

### Furrow-specific additions (not in any single framework)

- `schema_version` *(required)* — semver-shaped, gates rendering. None of the surveyed frameworks version their handoff schemas — they evolve via SDK releases. Furrow needs this because handoffs are persisted artifacts (`.furrow/rows/{name}/handoffs/{step}-to-{target}.md`).
- `step` *(required)* — Furrow's 7-step ceremony is intrinsic; the receiving driver/engine reasons differently per step.
- `row` *(required)* — addressing context. Cheap to include, expensive to omit.
- `enforcement` *(optional, derived)* — pointer to active layer-policy entries; rendered for visibility, not authority (the hook is authoritative).

### Recommended required core (minimum viable schema)

```
schema_version, target, step, row, objective, deliverables, return_format,
grounding, constraints
```

Nine fields. The original ad-hoc 7 (grounding, direction/persona, goals, constraints,
enforcement, deliverables, EOS-report) **maps cleanly onto this**, with three deltas:
(a) split `direction/persona/specialist/reasoning` into `target` + `persona`
(addressing vs. role); (b) add `schema_version` (persistence); (c) make
`enforcement` optional/derived rather than core (D3 owns authority).

## Q2 — Framing Validity Verdict

**VALID-WITH-CAVEATS.**

The "typed-fields-rendered-to-markdown" framing is structurally appropriate for
Furrow's architecture, but it is **not the only viable primitive in the field**, and
the caveats matter.

### Why VALID

- **OpenAI Agents SDK** uses dataclass-based handoffs (`Handoff` with `agent`, `tool_name_override`, `input_type` Pydantic schema, `input_filter`) — typed fields, validated locally, then surfaced to the LLM as a tool call. Direct prior art for typed-fields-as-handoff. [Primary source]
- **CrewAI** Tasks are typed records (`description`, `expected_output`, `agent`, `context`, `tools`, `output_pydantic`, …) rendered into agent prompts. Closest semantic match to Furrow's intended schema. [Primary source]
- **Claude Code subagents** are the actual runtime Furrow targets. Subagents are configured by markdown-with-YAML-frontmatter (typed fields rendered to markdown). The *invocation* of a subagent today is a free-text Task-tool call, but the agent's static configuration matches Furrow's schema shape exactly. [Primary source]
- **AGENTS.md** (now an open standard donated to the Linux Foundation in Dec 2025) demonstrates that markdown-with-conventional-sections is an industry-accepted format for delivering structured guidance to coding agents — exactly Furrow's rendering target. [Primary source]

### The caveat (LangGraph counter-evidence)

**LangGraph predominantly uses shared graph state, not handoff prompts.** A handoff is `Command(goto="next_node", update={...state-deltas...}, graph=Command.PARENT)`. The "payload" is a state-mutation dict, not a typed prompt; the receiving agent reads the *whole graph state* (filtered to its message window) on entry. [Primary source: docs.langchain.com handoffs page; langchain blog]

This is a different primitive — closer to actor-style message passing on top of a
shared object — and it is the dominant pattern in one of the two largest agent
frameworks. If Furrow were building an in-process orchestrator with a shared
mutable state object, LangGraph's pattern would be the better model.

### Why the caveat does NOT kill the framing for Furrow

Three structural reasons LangGraph's primitive doesn't fit Furrow:

1. **Process boundary.** LangGraph nodes share an in-memory Python state object; Furrow drivers and engines are *separate Claude Code subagents in separate context windows*. There is no shared address space. Whatever crosses the boundary must be serialized — and a typed-fields-rendered-to-markdown artifact *is* the serialization.
2. **Persistence requirement.** Furrow handoffs land in `.furrow/rows/{name}/handoffs/{step}-to-{target}.md` and must be re-readable across sessions. LangGraph state is ephemeral by default (checkpointer is opt-in). Furrow's persistence requirement pushes toward typed artifacts, not graph state.
3. **Subagent transport.** The actual transport (Claude Code Task tool, future SendMessage) accepts a string prompt. Whether that string is "well-formed" or "ad-hoc" is the design choice. Choosing typed-fields-rendered-to-markdown is the disciplined version of the *only* available transport.

### Caveats Furrow must respect

- **Don't simulate shared state in the schema.** If the design starts adding `state_updates` or `delta` fields, that's drift toward LangGraph's primitive on a substrate that doesn't support it. Keep the handoff one-shot and immutable; mutations route through `rws`/`alm`.
- **Tool-as-handoff is the more proven frame.** OpenAI Agents and LangGraph both expose handoffs as *tool calls* the LLM emits, not as documents the orchestrator writes. Furrow's "operator/driver renders a markdown artifact and SendMessages it" is workable but is a third pattern less battle-tested than tool-call-handoffs. **D2 should make the priming-message renderer easy to swap for a tool-call shape later** if the harness adds first-class agent-to-agent tool calls.
- **EOS-report (return contract) is non-negotiable.** Every framework surveyed has *some* return-shape contract (OpenAI `output_type`, CrewAI `output_pydantic`, LangGraph state schema). Skipping this would leave drivers parsing free-form prose.

## Prior-Art Summary

| Framework | Primitive shape | Field-set highlights | Applicable lessons |
|---|---|---|---|
| **LangGraph** (Python/JS) | `Command(goto, update, graph, resume)` returned from a node; receiving agent reads shared graph state | `goto` (target), `update` (state delta dict, typically `{messages: [...], active_agent: ...}`), `graph` (parent/subgraph) | The dominant counter-pattern. Confirms shared-state alternative exists. **Not applicable** to Furrow's cross-process subagent model, but a useful kill-switch check. |
| **OpenAI Agents SDK** (Python) | `Handoff` dataclass; `Agent.handoffs=[...]` exposes them as tools | `agent`, `tool_name_override`, `tool_description_override`, `on_handoff` callback, `input_type` (Pydantic schema for tool args), `input_filter` (transforms `HandoffInputData`), `is_enabled`, `nest_handoff_history` | **Strongest direct prior art.** Confirms typed-schema-for-handoff-payload is industry-standard. The `input_type`/`input_filter` split (what the LLM provides vs. what context flows through) is worth borrowing conceptually. |
| **OpenAI Agent definition** | Agent record | `name`, `instructions`, `model`, `tools`, `handoffs`, `output_type`, `model_settings`, `prompt`, `hooks`, `input_guardrails`, `output_guardrails`, `tool_use_behavior` | `output_type` → Furrow's `return_format`. `instructions` → `persona`. `name` → `target`. |
| **CrewAI** (Python) | `Task` record assigned to an `Agent` | Task: `description` (req), `expected_output` (req), `agent`, `tools`, `context: List[Task]`, `async_execution`, `human_input`, `output_json`/`output_pydantic`, `guardrail`, `callback`, `output_file`. Agent: `role`, `goal`, `backstory`, `allow_delegation` | **Closest semantic match to Furrow's intent.** `description`+`expected_output` ≈ `objective`+`deliverables`. `context: List[Task]` ≈ `prior_artifacts`. Role/goal/backstory triple validates persona-by-reference. |
| **Claude Code subagents** (Furrow's runtime target) | Markdown file with YAML frontmatter; invoked via Task tool with free-text prompt | Frontmatter: `name`, `description`, `tools`, `disallowedTools`, `model`, `permissionMode`, `maxTurns`, `skills`, `mcpServers`, `hooks`, `memory`, `effort`, `isolation`, `color`, `initialPrompt`. Body = system prompt | **Constrains the substrate.** Subagents have their own context window, do not inherit parent's, return a summary string. Confirms cross-process boundary; validates need for serialized handoff. `skills` and `initialPrompt` map onto Furrow's grounding and priming-message concepts. |
| **AGENTS.md** (Linux Foundation open standard, Dec 2025) | Markdown with conventional sections (no required fields) | Project Overview, Dev Environment, Build/Test Commands, Code Style, Testing, Contribution, Security | Validates "structured markdown for agent guidance" as a recognized industry pattern. Section convention discipline matters more than rigid field schemas at the rendered layer. |
| **Aider** (single-agent, informs field set) | Single chat with injected `--read` files and `CONVENTIONS.md` | Repo map, conventions, edit-format spec | Confirms grounding-by-reference (file paths), not grounding-by-inlining, scales better. |
| **Internal `skills/shared/specialist-delegation.md`** | Procedural protocol (scan → consult overrides → select → delegate → record) | Implies fields: scenario match, role, specialist brief, task-specific artifacts, recorded rationale | Current ad-hoc shape; the new schema formalizes "task-specific artifacts" as `grounding`+`prior_artifacts` and "specialist brief" as `persona`. |

## Recommended Schema (provisional, freeze in spec step)

```yaml
# Handoff artifact schema (provisional, v0.1)
# Renders to markdown via templates/handoff.md.tmpl in stable section order.

schema_version: string         # required, semver-shaped, allow-listed
                               # gates rendering; mismatched versions fail closed

# --- Addressing band ---
target:                         # required
  layer: enum                   # operator | driver | engine
  id: string                    # e.g. "driver:research", "engine:specialist:go-specialist"
row: string                     # required; row name (kebab-case)
step: enum                      # required; ideate|research|plan|spec|decompose|implement|review

# --- Persona band ---
persona:                        # optional (required for engine target)
  brief_path: string            # path to specialist brief; loaded by receiver, not inlined
  role: string                  # short label, e.g. "go-specialist"

# --- Task contract band ---
objective: string               # required; one-paragraph problem statement
deliverables:                   # required; non-empty for engine target, may be empty for driver priming
  - name: string                # e.g. "handoff-schema"
    acceptance_criteria: [string]
    file_ownership: [string]
constraints: [string]           # required; do/don't rules, scope limits
return_format:                  # required; the EOS-report contract
  shape: enum                   # eos-report-v1 | phase-result-v1 | free-text (free-text disallowed for engines)
  required_sections: [string]   # e.g. ["findings", "artifacts_written", "blockers", "next-step-recommendation"]

# --- Grounding band ---
grounding:                      # required; structured context bundle from D4
  bundle_ref: string            # path or content-hash; primary delivery via D4's `furrow context for-step`
  inline_refs:                  # optional supplementary pointers
    skills: [path]
    references: [path]
    artifacts: [path]
prior_artifacts:                # optional
  - step: enum
    section: string             # e.g. "key-findings"
    summary_excerpt: string     # bounded length; full content via grounding.bundle_ref

# --- Enforcement band (derived, advisory in artifact; authority is D3's hook) ---
enforcement:                    # optional
  layer_policy_ref: string      # path to .furrow/layer-policy.yaml
  notes: [string]               # human-readable boundary reminders

# --- Operator-only fields when target.layer=driver ---
returning_to_step:              # optional; set when operator transitions backward
  reason: string
  prior_session_artifacts: [path]
```

Notes on the schema:

- `additionalProperties: false` at every level (per Furrow convention from `pre-write-validation-go-first`).
- `grounding.bundle_ref` is the primary channel; `inline_refs` exists for cases where the receiver may not have CLI access to regenerate the bundle (e.g., a subagent without `furrow` binary). Belt-and-braces.
- `return_format.shape` is an enum, not free-text, so D2 drivers can dispatch parsers by shape.
- `target.layer` is duplicative with the schema *as a whole* — it lets D3's hooks make a fast layer decision from the rendered artifact without re-deriving from `target.id`.
- The schema is **smaller than CrewAI's Task** (no `async_execution`, `human_input`, `callback`, `guardrail`, `output_file`) because those concerns belong to the harness (`rws`, `alm`, hooks), not the handoff payload.

## Risks and Open Questions for D1's Spec Step

1. **Inlining vs. referencing grounding.** The schema picks "reference primarily, inline supplementarily" but rendered handoff size could balloon if `inline_refs` is over-used. Spec step should set a byte budget and fail-closed when exceeded.
2. **Round-trippability subset.** The acceptance criterion in `definition.yaml` says round-trip parse-render-parse equality only for the "round-trippable subset." Spec must enumerate which fields are lossy at render (likely `grounding.bundle_ref` content, `prior_artifacts.summary_excerpt` truncation).
3. **Tool-call vs. document handoff.** Current design renders to markdown and ships via SendMessage/Task-tool. If Anthropic adds first-class agent-to-agent tool calls (analogous to OpenAI Agents `transfer_to_X`), Furrow may want to switch transport without a schema break. **Recommendation:** keep the schema transport-neutral; D2 owns the renderer/parser pair, and a future tool-call adapter is a renderer swap.
4. **Operator→driver vs. driver→engine asymmetry.** Operator→driver priming messages need `returning_to_step` and lighter `deliverables` (drivers run ceremony, not domain work). Driver→engine handoffs need full `deliverables` and stricter `constraints`. Spec must decide: one schema with optionals, or two schemas with shared base. **Recommend single schema with required-by-target rules** (e.g., `deliverables` required iff `target.layer == engine`).
5. **`return_format.shape == "eos-report-v1"` is itself a schema reference.** Define EOS-report shape (separate file `schemas/eos-report.schema.json`) in the spec step; the handoff schema points at it. Don't inline.
6. **Schema versioning churn.** D1 ships v0.1; very likely a v0.2 lands during D2 (driver lifecycle adds fields). Plan the allow-list bump path now.
7. **Persona-by-reference assumes brief stability.** `persona.brief_path` resolves at receiver-load time. If specialists are renamed/moved during a row, prior handoff artifacts become unrenderable. **Mitigation:** content-hash the brief at handoff render time and include in the artifact; warn rather than fail when hash drifts.
8. **No primary verification of Claude Code Task-tool subagent persistence semantics** — definition.yaml constraint #19 already flags this; reaffirmed here. The schema is robust to the answer (it's transport-agnostic) but D2's drivers.json design is not.

## Sources Consulted

- **OpenAI Agents SDK — Handoffs page** (`openai.github.io/openai-agents-python/handoffs/`) — primary — `Handoff` dataclass field list (`agent`, `tool_name_override`, `tool_description_override`, `on_handoff`, `input_type`, `input_filter`, `is_enabled`, `nest_handoff_history`) and the tool-call-as-handoff pattern.
- **OpenAI Agents SDK — Agents page** (`openai.github.io/openai-agents-python/agents/`) — primary — Agent fields (`name`, `instructions`, `model`, `tools`, `handoffs`, `output_type`, `model_settings`, `prompt`, `hooks`, `input_guardrails`, `output_guardrails`, `tool_use_behavior`).
- **Claude Code subagents docs** (`code.claude.com/docs/en/sub-agents`) — primary — full frontmatter schema, subagent invocation model, context-window-isolation guarantee, Task-tool delegation. Canonical for Furrow's runtime target.
- **CrewAI Tasks docs** (`docs.crewai.com/concepts/tasks`) — primary — Task field schema (`description`, `expected_output`, `agent`, `tools`, `context: List[Task]`, structured-output options, guardrails, callbacks).
- **CrewAI Agents docs** (`docs.crewai.com/concepts/agents`) — primary — `role`/`goal`/`backstory` triple, `allow_delegation` semantics.
- **LangChain handoffs docs** (`docs.langchain.com/oss/python/langchain/multi-agent/handoffs`) — primary — `Command(goto, update, graph)` shape with full code example showing `update={"active_agent": ..., "messages": [...]}`.
- **LangGraph.js Command class reference** (`langchain-ai.github.io/langgraphjs/reference/classes/langgraph.Command.html`) — primary — Command constructor signature: `goto`, `update` (Record<string, unknown>), `graph`, `resume`.
- **LangGraph blog: Command primitive** (`blog.langchain.com/command-a-new-tool-for-multi-agent-architectures-in-langgraph/`) — secondary (redirected; content via search-result summary) — confirms shared-state primitive vs. typed-handoff distinction.
- **AGENTS.md spec** (`agents.md/`, `agentsmd.net/`, OpenAI Codex docs) — primary — confirms structured-markdown is an open industry standard for agent guidance; donated to Linux Foundation Dec 2025.
- **Furrow internal `skills/shared/specialist-delegation.md`** — primary — current operator→specialist procedural shape; informs the migration target.
- **Furrow internal `definition.yaml`** (this row) — primary — D1 acceptance criteria, constraint #16 (kill-switch), constraint #5 (vertical layering).

**[unverified]:** LangChain blog reached via search-summary post-redirect;
substantive claims corroborated by two other primary sources.
