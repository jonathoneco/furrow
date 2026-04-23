# R5 — Claude Agent SDK Deep Dive

Evaluation of Anthropic's Claude Agent SDK (`@anthropic-ai/claude-agent-sdk`,
`claude-agent-sdk` Python) as a potential Furrow host adapter. Scored against the
seven Host Adapter Interface surfaces.

---

## Local repo context

### rationale.yaml L241-262 (verbatim)

```yaml
  # --- Agent SDK adapter (W-08) ---
  - path: adapters/agent-sdk/templates/coordinator.py
    exists_because: "Agent SDK programs need a coordinator template for row lifecycle management"
    delete_when: "Agent SDK provides built-in workflow coordinator agents"
  - path: adapters/agent-sdk/templates/specialist.py
    exists_because: "Agent SDK programs need a specialist template for deliverable execution"
    delete_when: "Agent SDK provides built-in specialist agent templates"
  - path: adapters/agent-sdk/templates/reviewer.py
    exists_because: "Agent SDK programs need a reviewer template for two-phase review execution"
    delete_when: "Agent SDK provides built-in review agent templates"
  - path: adapters/agent-sdk/callbacks/gate_callback.py
    exists_because: "Agent SDK needs gate decision callbacks for all three gate policies"
    delete_when: "Agent SDK provides built-in gate decision callbacks"
  - path: adapters/agent-sdk/callbacks/step_transition.py
    exists_because: "Agent SDK needs step transition callbacks with gate validation"
    delete_when: "Agent SDK provides built-in step transition management"
  - path: adapters/agent-sdk/callbacks/state_mutation.py
    exists_because: "Agent SDK needs thread-safe state.json mutation with file locking"
    delete_when: "Agent SDK provides built-in concurrent-safe state management"
  - path: adapters/agent-sdk/config.py
    exists_because: "Agent SDK programs need initialization with schema validation and template loading"
    delete_when: "Agent SDK provides built-in workflow configuration and validation"
```

### Existing adapter code in-tree

Directory: `/home/jonco/src/furrow/adapters/agent-sdk/`

```
adapters/agent-sdk/
├── _meta.yaml                        (178 B)
├── __init__.py                       (45 B)
├── config.py                         (6.8 KB)   — functional: schema validation + auto-discovery
├── callbacks/
│   ├── gate_callback.py              (3.9 KB)   — hardcodes "evaluator" (see isolated-gate-evaluation row)
│   ├── state_mutation.py             (4.5 KB)   — invokes hooks/lib/validate.sh (stale path; flagged in frw-cli-dispatcher row)
│   └── step_transition.py            (3.3 KB)
└── templates/
    ├── coordinator.py                (5.8 KB)   — ~156 lines, 15+ TODO comments (from harness-v2-status-eval narrative)
    ├── specialist.py                 (3.7 KB)
    └── reviewer.py                   (5.7 KB)
```

Status per other rows in the tree:
- `harness-v2-status-eval/narrative-assessment.md` L186: *"coordinator.py is 156 lines with 15+ TODO comments. It can load state but has zero execution intelligence."* (Tier: local-repo, primary source)
- `merge-specialist-and-legacy-todos/research.md` L112: *"26 code-level TODOs are intentional `# TODO: customize` stubs in adapters/agent-sdk/templates/"*
- `frw-cli-dispatcher/research.md` flags stale `hooks/lib/validate.sh` references in `state_mutation.py`

**Bottom line:** the adapter is scaffolding, not a working binding. The scaffolding
was authored before deep investigation of SDK capabilities — several of the
"exists_because" rationales (e.g. *"Agent SDK needs gate decision callbacks"*)
turn out to be half-correct: hook callbacks exist natively, but not for gate
semantics specifically.

---

## Summary

- **The SDK is a credible functional host for Furrow.** It natively provides
  hooks, subagents, slash commands, skills, plugins, MCP, and session
  lifecycle — every primitive Furrow currently uses on Claude Code CLI has a
  direct programmatic analog. The Agent SDK is explicitly described as
  *"Claude Code as a library"* (T1: `code.claude.com/docs/en/agent-sdk/overview`).
- **It does NOT solve the multi-provider lock-in (Q3-B).** The SDK requires
  Anthropic API credentials (or Bedrock/Vertex/Azure routing of Anthropic
  models). There is no provider swap — OpenAI, Gemini, or local models are
  not supported. Migrating Furrow from CC to the SDK trades one
  Anthropic-only runtime for another.
- **The SDK gives *more* programmatic context control than CC (partial Q3-A
  relief).** `excludeDynamicSections`, `setting_sources` gating, custom
  `systemPrompt` with `preset` + `append`, and explicit resume-by-session-ID
  let an SDK-based Furrow control exactly what enters the context window at
  each step. CC's progressive-loading pattern is filesystem-driven; the SDK
  makes it programmatic.
- **Stability is a real concern.** The TypeScript SDK is at v0.2.117 (as of
  April 2026, T1: npm registry) with breaking changes landing at patch level
  (e.g. v0.2.113 made `options.env` replace rather than overlay `process.env`).
  Release cadence is roughly weekly, tied to Claude Code CLI parity. The
  existing `adapters/agent-sdk/` code already suffers from drift against the
  live SDK — a pattern that will continue.

**Verdict:** SDK belongs in the matrix as a *Tier-1 alternate CC runtime* (same
lock-in, better programmatic control, worse stability). It does NOT belong in
the matrix as an answer to multi-provider portability.

---

## Per-surface findings

### 1. Slash commands
**Supported natively, strong parity with Claude Code CLI.**

- Custom commands live in `.claude/commands/*.md` (legacy) or
  `.claude/skills/<name>/SKILL.md` (recommended). Same markdown + YAML
  frontmatter format as CC. (T1:
  `code.claude.com/docs/en/agent-sdk/slash-commands`)
- Commands are auto-discovered by the SDK when `settingSources` includes
  `"project"` or `"user"`. Filenames become command names; frontmatter can
  declare `allowed-tools`, `description`, `model`, `argument-hint`. (T1)
- Arguments (`$1`, `$2`, `$ARGUMENTS`), bash interpolation (`` !`git status` ``),
  and file references (`@path/file`) all supported — identical to CC. (T1)
- Namespacing via subdirectories works; plugin commands are namespaced as
  `plugin-name:command-name`. (T1: `code.claude.com/docs/en/agent-sdk/plugins`)
- **Dispatch from code:** slash commands are invoked by including the string
  `/cmd args` in the `prompt` parameter passed to `query()`. The SDK reports
  available commands in the `system.init` message's `slash_commands` field.

**Furrow fit:** `frw:work`, `frw:status`, `frw:review` etc. map 1:1. Existing
`.claude/commands/*.md` files would need minimal (or zero) changes.

**Gap vs CC:** None material. If anything, SDK-side is better because you can
programmatically enumerate available commands via the init message.

---

### 2. Hook / lifecycle events
**Supported natively. Broader and more programmatic than CC hooks.**

Hook table (T1: `code.claude.com/docs/en/agent-sdk/hooks`):

| Hook event           | Python | TS    | Notes                                                  |
|----------------------|--------|-------|--------------------------------------------------------|
| `PreToolUse`         | yes    | yes   | Can block, modify input, or allow                      |
| `PostToolUse`        | yes    | yes   | Logging, audit, result transformation                  |
| `PostToolUseFailure` | yes    | yes   | Tool errors                                            |
| `UserPromptSubmit`   | yes    | yes   | Inject context on every turn                           |
| `Stop`               | yes    | yes   | Cleanup / save state                                   |
| `SubagentStart`      | yes    | yes   | Track subagent dispatch                                |
| `SubagentStop`       | yes    | yes   | Aggregate subagent results                             |
| `PreCompact`         | yes    | yes   | Archive transcript before summarization                |
| `PermissionRequest`  | yes    | yes   | Custom approval flow                                   |
| `SessionStart`       | **no** | yes   | TS-only; Python users load via shell-hook `.claude/settings.json` |
| `SessionEnd`         | **no** | yes   | Same                                                   |
| `Notification`       | yes    | yes   | Agent status messages                                  |
| `TeammateIdle`, `TaskCompleted`, `ConfigChange`, `WorktreeCreate/Remove`, `Setup` | no | yes | TS-only advanced hooks |

Key characteristics:
- Hooks are **Python async functions / TS callbacks** passed in `options.hooks`,
  not shell commands. Shell-command hooks from `settings.json` are also honored
  when `settingSources` is set. (T1)
- Return value is a typed object with `hookSpecificOutput` (decides
  allow/deny/ask, can mutate `tool_input`, can append `additionalContext`) and
  top-level `systemMessage` (inject conversation context) / `continue`. (T1)
- Matchers are regex strings filtering by tool name (`"Write|Edit"`,
  `"^mcp__"`). (T1)
- `deny > ask > allow` priority when multiple hooks contend. (T1)
- **Async mode** (`{async: true, asyncTimeout: 30000}`) lets fire-and-forget
  hooks not block the agent. (T1)

**Furrow fit:** Better than CC for most Furrow needs. State-guard,
correction-limit, validate-definition, and step-transition hooks translate to
`PreToolUse` callbacks. `PostCompact` → `PreCompact`. `SessionStart` has a
**Python asymmetry** — Python SDK lacks it; TS has it. For Furrow's
shell-centric hooks this is a minor issue because shell hooks in
`.claude/settings.json` still execute when `setting_sources=["project"]`.

**Gap vs CC:** No exact `SessionStart` in Python SDK. Workaround documented
(use first message of `receive_response()` as init trigger). TS SDK
has MORE hooks than CC (TeammateIdle, WorktreeCreate, Setup, etc.) —
indicates the SDK is on track to become the more primitive-rich runtime.

---

### 3. Subagent dispatch
**First-class primitive. Programmatic definition + isolated context.**

- Subagents defined inline via `agents={}` option (AgentDefinition with
  `description`, `prompt`, `tools`, `model`, `permissionMode`, `mcpServers`,
  `hooks`, `maxTurns`, etc.) OR from `.claude/agents/*.md` markdown files when
  setting-source enabled. (T1:
  `code.claude.com/docs/en/agent-sdk/overview`, T1:
  `code.claude.com/docs/en/sub-agents`)
- **Isolated context** — each subagent runs in its own context window with
  custom system prompt, tool allowlist, and independent permissions. Returns
  a summary to the parent. (T1)
- **Invocation** — via the built-in `Agent` tool. You must include `Agent` in
  `allowedTools` for the parent to delegate. The parent's LLM decides when to
  delegate based on the subagent's `description`. (T1)
- **Parallel dispatch** — subagents within a single session; for multi-session
  concurrency, separate docs reference "agent teams" at `/en/agent-teams`
  (**UNVERIFIED** — not fetched here). Hook callbacks include
  `parent_tool_use_id` so you can trace which subagent a message belongs to. (T1)
- **Security note** — plugin-delivered subagents cannot override `hooks`,
  `mcpServers`, or `permissionMode` frontmatter (T2: alexop.dev blog via
  WebSearch summary; confirm on plugin docs).

**Furrow fit:** Matches CC's Task tool semantics. Furrow's specialist dispatch
(`specialists/*.md`) maps to `agents/` directory. The SDK actually exposes
dispatch result better than CC by emitting `parent_tool_use_id` in hook input.

**Gap vs CC:** None material. SDK is arguably cleaner because subagent
definitions can be declared in code at session construction, so Furrow could
generate them from `definition.yaml` at runtime rather than writing files.

---

### 4. Context injection
**More control than CC. This is the SDK's strongest advantage over CC.**

Four injection mechanisms (T1:
`code.claude.com/docs/en/agent-sdk/modifying-system-prompts`):

1. **`CLAUDE.md`** — project + user markdown, auto-loaded when
   `settingSources` includes `"project"` / `"user"`. Identical to CC.
2. **Output styles** — persistent markdown configs in
   `~/.claude/output-styles/` or `.claude/output-styles/`. Activate via
   `/output-style`.
3. **`systemPrompt` = `{type: "preset", preset: "claude_code", append: "..."}`** —
   preserves Claude Code defaults and appends Furrow-specific content per query.
4. **Fully custom `systemPrompt`** string — replaces everything, including CC's
   default tool instructions, style guidelines, safety. Full control.

Key programmatic powers the SDK has that CC's file-based model lacks:

- **`excludeDynamicSections: true`** — removes working-dir / git-status /
  date / memory paths from the system prompt, moves them into first user
  message. Enables prompt-cache hits across sessions on different machines.
  (T1) This is *especially* relevant to Furrow because step-boundary context
  swaps would otherwise wreck caching.
- **`setting_sources` gating** — decide per-query whether to load
  `user`, `project`, or neither. Step-level context budgets become
  enforceable in code, not just by filename hygiene.
- **Hook-based injection** — a `UserPromptSubmit` hook or `PostToolUse` with
  `additionalContext` / `systemMessage` can inject step-specific skills at
  *exactly* the lifecycle moment (step transition), without relying on CC's
  skill-injection-order heuristics.

**Furrow fit:** This is a **real upgrade** over CC. Furrow's
`skill-injection-order.md` architecture currently depends on CC's filename-based
loading. On the SDK, Furrow could replace that with deterministic programmatic
loading — exact line budgets enforced at the API boundary.

**Gap vs CC:** None. SDK is a superset.

---

### 5. Multi-provider (THE CRITICAL QUESTION)
**Not supported. SDK is Anthropic-only.**

Evidence (T1:
`code.claude.com/docs/en/agent-sdk/overview`):
> *"Set your API key ... export ANTHROPIC_API_KEY=your-api-key. The SDK also
> supports authentication via third-party API providers: Amazon Bedrock ...
> Google Vertex AI ... Microsoft Azure ..."*

The "third-party providers" are **all routes to Anthropic models**:
- `CLAUDE_CODE_USE_BEDROCK=1` → Anthropic models on AWS Bedrock
- `CLAUDE_CODE_USE_VERTEX=1` → Anthropic models on Google Vertex
- `CLAUDE_CODE_USE_FOUNDRY=1` → Anthropic models on Azure Foundry

None of these allow swapping in OpenAI, Gemini, local LLMs, or any non-Anthropic
model. The SDK embeds Claude-specific prompting conventions, the `Agent` tool
uses Anthropic's tool-use API shape, and the bundled binary is the Claude Code
native binary. (T1)

Additional terms constraint (T1):
> *"Unless previously approved, Anthropic does not allow third party developers
> to offer claude.ai login or rate limits for their products, including agents
> built on the Claude Agent SDK."*

This even restricts how SDK-based products can be distributed.

**Impact on Q3-B (multi-provider lock-in):** Zero relief. Porting Furrow from
CC to the SDK is moving within the same lock-in boundary.

**This section gates the SDK's matrix entry:** If the Host Adapter Interface
is being designed specifically to enable provider swap, the Agent SDK cannot
satisfy that requirement and should be tracked in the matrix as
*"Anthropic-internal alternate runtime"* rather than as a portability target.

---

## The lock-in question (explicit)

**Q: Would migrating Furrow to Agent SDK solve Q3-B (multi-provider pain)?**

**A: No.**

Evidence:
1. All authentication paths resolve to Anthropic models (API key, Bedrock,
   Vertex, Foundry). (T1 overview)
2. Tool-use loop is hardcoded around Anthropic's Messages API tool-use
   contract. (T1 overview, implicit in examples)
3. The TypeScript SDK *bundles the Claude Code native binary* as an optional
   dependency — the SDK is effectively an FFI wrapper around the same binary
   Furrow already targets. (T1 overview: *"The TypeScript SDK bundles a native
   Claude Code binary for your platform as an optional dependency, so you
   don't need to install Claude Code separately."*)
4. Commercial terms restrict how SDK-based products can be re-distributed.
   (T1 overview)

**Conclusion:** the SDK and CC share the same Anthropic dependency. The Furrow
adapter split between `adapters/claude-code/` and `adapters/agent-sdk/` is
real, but it's a split between *two interfaces to the same provider*, not a
split between *different providers*.

**Action for the matrix:** mark the Agent SDK row with a
`provider_coverage = "anthropic-only"` column, same as CC. The
"dual-runtime abstraction" W-08 is a hedge against *CC CLI going away*, not
against *Anthropic pricing/availability going away*.

---

## Context-limits angle (Q3-A)

**Does the SDK give users MORE control over context than CC, such that it'd
address Q3-A even while staying Anthropic-only?**

**Yes — materially.** (T1 modifying-system-prompts + T1 hooks)

Specific wins over CC:

| Context concern | CC mechanism | SDK mechanism | Improvement |
|-----------------|--------------|---------------|-------------|
| Step-boundary skill swap | Filesystem conventions + `skill-injection-order.md` | `UserPromptSubmit` hook + `setting_sources` gating + `systemPrompt.append` | Programmatic, deterministic, per-query |
| Cache reuse across sessions | None — dynamic sections always embedded | `excludeDynamicSections: true` | Explicit cache-hit control |
| Compaction control | Automatic on token ceiling; `/compact` manual | `PreCompact` hook + `/compact` dispatchable + `compact_boundary` system message | Programmatic: archive transcript, reject compaction, measure pre/post tokens |
| Context budget enforcement | Line-counting scripts external to CC | Hook callbacks can measure token counts and return `continue: false` | Runtime enforcement |
| Subagent context isolation | Task tool's default behavior | `AgentDefinition` with explicit tools, system prompt, maxTurns | Per-subagent budgets |

This is the genuine case *for* the SDK: if Furrow's Q3-A (context-limit) pain
is the dominant driver, migrating to the SDK provides mechanisms CC doesn't.
Furrow's current context discipline (work-context.md, step skills, references
on-demand) would become code-enforceable rather than convention-enforced.

**Caveat:** this gain assumes Furrow stays Anthropic-only. If Q3-B is the
dominant constraint, this relief is irrelevant.

---

## Stability + community

**Stability: POOR — rapidly evolving, breaking changes at patch level.**

(T1: npm `@anthropic-ai/claude-agent-sdk` version history, T1: TS CHANGELOG
summary)

- Current TS version: **v0.2.117** (April 2026)
- Current Python version: `claude-agent-sdk` (corresponding — exact version
  **UNVERIFIED** at this moment)
- Release cadence: roughly weekly, tied to Claude Code CLI releases
  ("parity with Claude Code v2.1.X" noted in many changelog entries)
- Known breaking changes at patch level:
  - v0.2.113: `options.env` now **replaces** `process.env` (was overlay)
  - v0.2.69: Agent tool name churn (`Task` → `Agent`, then reverted)
  - v0.2.0: major restructure — removed default system prompt, removed
    filesystem settings by default, merged `customSystemPrompt` +
    `appendSystemPrompt` → `systemPrompt`
  - v0.1.72: V2 session API renamed `receive()` → `stream()`
- Unstable features explicit in API surface: `sessionStore` (alpha),
  `unstable_v2_createSession`, `unstable_v2_resumeSession`
- Name change precedent: the SDK was previously the "Claude Code SDK" —
  renamed to "Claude Agent SDK". Migration guide exists. (T1 overview)

**Implications for Furrow:**
- Cannot use semver ranges in dependency pinning — must pin exact version.
- An SDK-based Furrow adapter would need a CI job that re-pins weekly and
  runs the full Furrow test suite against each bump.
- The existing `adapters/agent-sdk/` scaffolding already has drift
  (state_mutation.py's stale path reference) that will only get worse.

**Community:**
- Official demos: `github.com/anthropics/claude-agent-sdk-demos` (T1)
- Third-party wrappers emerging (Promptfoo provider integration — T2)
- GitHub issues tracked per SDK (TS and Python each have their own repo) (T1)
- Not yet 1.0 — messaging is pre-stable.

---

## Open questions

1. **Agent teams** (`/en/agent-teams`) are referenced in the subagent docs as
   the mechanism for multi-session parallel agents. Not fetched here. Might
   change the subagent-dispatch story. **UNVERIFIED**.
2. **V2 TypeScript interface** (`typescript-v2-preview`) appeared in search
   results. If this is the forward path, current `query()`-based API may be
   deprecated. Adds stability risk. **UNVERIFIED** — worth a follow-up fetch.
3. **Custom MCP tool SDKs** — how do SDK-defined tools interact with MCP server
   tools under hooks? The `matcher: "^mcp__"` example works, but whether
   in-process custom tools (`tool()` helper) support same lifecycle hooks is
   **UNVERIFIED** here.
4. **Session persistence model** — `resume=<session_id>` works across queries
   (T1), but the storage backend (local file, Anthropic server?) is
   **UNVERIFIED**. Matters for Furrow rows that span days.
5. **Can the SDK be driven without the Claude Code binary?** — TS docs say
   binary is bundled. Python path is **UNVERIFIED**. If the SDK secretly
   shells out to `claude`, the `adapters/claude-code` vs `adapters/agent-sdk`
   split is thinner than it appears.
6. **Cost model for `setting_sources` loading** — does loading `.claude/`
   files on every `query()` add latency or token overhead? Not documented
   explicitly. **UNVERIFIED**.

---

## Sources consulted (tiered)

### T1 — Anthropic official docs
- `https://code.claude.com/docs/en/agent-sdk/overview` — primary reference for
  capabilities, auth, Claude-Code-vs-Client-SDK comparison
- `https://code.claude.com/docs/en/agent-sdk/hooks` — hook events, callback
  signatures, output schemas, examples
- `https://code.claude.com/docs/en/agent-sdk/slash-commands` — custom command
  file format, arguments, namespacing, SDK dispatch
- `https://code.claude.com/docs/en/agent-sdk/plugins` — plugin structure,
  loading, namespacing
- `https://code.claude.com/docs/en/agent-sdk/modifying-system-prompts` — four
  injection methods, `excludeDynamicSections`, comparison table
- `https://code.claude.com/docs/en/sub-agents` — subagent semantics, isolated
  context, delegation via Agent tool
- `https://www.npmjs.com/package/@anthropic-ai/claude-agent-sdk` — version
  metadata (v0.2.117 current)
- `https://github.com/anthropics/claude-agent-sdk-typescript` (CHANGELOG
  403'd; summary derived from search snippets — treat version-specific
  breakage claims as T1/T2 hybrid)

### T2 — third-party guides / blog posts
- `alexop.dev` — Claude Code customization walkthrough (referenced via
  WebSearch result, not fetched full)
- `nader.substack.com` — "Complete Guide to Building Agents with the Claude
  Agent SDK" (WebSearch snippet only)
- `datacamp.com` — Claude Agent SDK tutorial (WebSearch snippet only)
- `promptfoo.dev/docs/providers/claude-agent-sdk` — third-party wrapper
- `samuellawrentz.com/blog/claude-code-hooks-subagents/` — advanced hooks
  walkthrough (WebSearch snippet only)

### Local repo (tier: primary)
- `/home/jonco/src/furrow/.furrow/almanac/rationale.yaml` L241-262 — adapter
  scaffolding manifest
- `/home/jonco/src/furrow/adapters/agent-sdk/` — existing adapter code (config
  functional, templates are stubs)
- `/home/jonco/src/furrow/.furrow/rows/harness-v2-status-eval/narrative-assessment.md`
  L186 — status of coordinator.py
- `/home/jonco/src/furrow/.furrow/rows/merge-specialist-and-legacy-todos/research.md`
  L112 — confirms 26 "# TODO: customize" stubs in templates
- `/home/jonco/src/furrow/.furrow/rows/frw-cli-dispatcher/research.md` L33,
  L58 — stale `hooks/lib/validate.sh` path in `state_mutation.py`

### T3 — training-data facts treated as given
- Anthropic Messages API tool-use contract (standard knowledge)
- General npm / Python packaging semantics (semver-aware pinning)
- MCP is a protocol shared across Anthropic clients (well established)
