# R3 — opencode Deep Dive

**Target**: evaluate opencode (github.com/anomalyco/opencode, opencode.ai) against
Furrow's Host Adapter Interface (HAI).

**Date**: 2026-04-22

**Repo confirmation (step 0)**: `gh repo view sst/opencode` and `gh repo view
anomalyco/opencode` both return identical metadata (same `pushedAt`, identical
stargazer count 147,649, same description and default branch `dev`). GitHub
redirects sst/opencode → anomalyco/opencode; anomalyco is the canonical active
repository. The `sst/opencode-sdk-go` URL still resolves as a legacy alias.
[T1: `gh api repos/anomalyco/opencode`]

---

## Summary (4 bullets)

- **Strong fit on almost every HAI surface.** opencode has a first-class
  TypeScript plugin API with rich hook coverage (`tool.execute.before/after`,
  `session.created`, `session.compacted`, `chat.params`, `permission.ask`,
  `experimental.chat.system.transform`), native MCP (local + remote with OAuth),
  75+ providers with runtime `/models` switching, and markdown-defined slash
  commands and subagents stored under `.opencode/`. The plugin surface is
  broader than Claude Code's hook surface in several places (system-prompt
  transform, compaction hooks, permission interception).
- **Tool-use gating is supported with an `output.abort` signal**, but reports
  exist that plugin hooks do not reliably intercept *subagent* tool calls
  (issue #5894), which is a critical gap for Furrow's deliverable-scoped
  correction-limit hook.
- **Subagent return-value contract is undocumented.** opencode has
  subagent dispatch (Task tool, @mentions, `mode: subagent` frontmatter) with
  permission isolation, but the return-value shape passed back to the primary
  agent is not specified in T1 docs — a Furrow-facing gap because Furrow needs
  a predictable handoff envelope from review/specialist agents.
- **Velocity and stability concerns.** 147k stars, 455+ contributors, MIT,
  very active (last push on the day of research, daily patch releases,
  v1.14.20 as latest). HN consensus flags rapid release cadence with weak
  regression testing, 1GB+ RAM use, undocumented behavioral drift, and
  defaults-to-cloud telemetry for session-title generation. Breaking-change
  policy is not formally documented.

---

## Per-surface findings

### Surface 1: Slash commands

- **Supported**: yes
- **Mechanism**: Markdown files with YAML frontmatter in
  `.opencode/commands/` (project) or `~/.config/opencode/commands/` (global).
  Filename becomes the command name (`test.md` → `/test`). Also definable
  via JSON in `opencode.jsonc` under `command`. Supports: `$ARGUMENTS`
  (whole string), positional `$1`/`$2`/…, shell injection via `` !`cmd` ``,
  file references via `@filename`. Frontmatter keys: `template` (required),
  `description`, `agent`, `subtask` (boolean, forces subagent), `model`.
  Custom commands override built-ins of the same name.
- **Source tier**: T1
- **Citation**: https://opencode.ai/docs/commands/ (WebFetch 2026-04-22)
- **Gap from Furrow's need**: None structural. Furrow's existing
  `.claude/commands/*.md` files migrate near-1:1 (directory rename plus
  reviewing that Furrow's bash-substitution syntax `!`git status`` maps onto
  opencode's same syntax — it does). Worth noting: opencode also supports
  JSON-only command definitions, which gives Furrow a second registration
  path if the markdown layer is ever insufficient.

### Surface 2: Hook events

- **Supported**: yes — richer than Claude Code in several dimensions,
  partially gapped in one.
- **Mechanism**: Async TypeScript/JavaScript plugins export a `Hooks` object.
  From `packages/plugin/src/index.ts` the full `Hooks` interface includes:
  - `event` (catch-all on the SDK event stream),
  - `config`,
  - `chat.message`, `chat.params` (temperature/topP/topK/maxOutputTokens/options),
    `chat.headers`,
  - `permission.ask` (mutate output `{status: "ask"|"deny"|"allow"}`),
  - `command.execute.before`,
  - `tool.execute.before` (input: `{tool, sessionID, callID}`, output: `{args}`),
  - `tool.execute.after` (input: `{tool, sessionID, callID, args}`, output:
    `{title, output, metadata}`),
  - `tool.definition` (mutate description/parameters per tool),
  - `shell.env`,
  - `experimental.chat.messages.transform` (rewrite messages before send),
  - `experimental.chat.system.transform` (rewrite system prompt),
  - `experimental.session.compacting` (modify compaction prompt or replace
    it),
  - `experimental.compaction.autocontinue`,
  - `experimental.text.complete`.
  Additionally the docs list session lifecycle events on the broader event
  stream consumable via the `event` hook: `session.created`,
  `session.compacted`, `session.deleted`, `session.diff`, `session.error`,
  `session.idle`, `session.status`, `session.updated`, plus `file.edited`,
  `file.watcher.updated`, `lsp.*`, `todo.updated`, `tui.*`,
  `permission.asked`, `permission.replied`, `installation.updated`,
  `server.connected`, `message.*`, `command.executed`.
  Abort pattern: `output.abort = "reason"` inside `tool.execute.before`
  prevents execution.
- **Source tier**: T1 (source + docs), T2 (abort pattern writeup)
- **Citation**:
  - Source: `gh api repos/anomalyco/opencode/contents/packages/plugin/src/index.ts` (verbatim `Hooks` interface)
  - Docs: https://opencode.ai/docs/plugins/
  - Abort pattern: https://gist.github.com/zeke/1e0ba44eaddb16afa6edc91fec778935 (T2) and https://dev.to/einarcesar/does-opencode-support-hooks-a-complete-guide-to-extensibility-k3p (T2)
- **Mapping to Furrow's four required events**:
  | Furrow need | opencode equivalent | Fit |
  |---|---|---|
  | PreToolUse (intercept Write/Edit, exit-code gate) | `tool.execute.before` → `output.abort` | Direct |
  | Stop | `session.idle` event via `event` hook; also `session.deleted` | Adequate (idle ≈ stop) |
  | SessionStart | `session.created` event | Direct |
  | PostCompact | `experimental.session.compacting` **before** compaction; `experimental.compaction.autocontinue` **after**; session.compacted on event stream | Partial — no single "PostCompact" gate, but compacting + compaction.autocontinue give pre+post seams (experimental status) |
- **Gap from Furrow's need**:
  1. **Subagent interception**: issue #5894 reports `tool.execute.before` does
     **not** fire for tool calls made inside subagents. This breaks
     deliverable-ownership and correction-limit enforcement for any work
     Furrow delegates to a subagent. **UNVERIFIED** in current source — needs
     experimentation (T4) or reading the subagent dispatch code path.
     [T2: https://github.com/anomalyco/opencode/issues/5894]
  2. **Experimental namespace**: the compaction/system-transform hooks are
     marked `experimental.*` in the exported types — no stability guarantees.
  3. **No PostToolUse exit-code gating semantics**: opencode's hook is
     promise-resolution-based (throw or set `output.abort`), not an exit-code
     shell gate. This is an interface shift, not a capability gap — Furrow's
     shell-based hooks would need to be wrapped as plugin TS or invoked via
     `$` (Bun shell) from within the plugin.

### Surface 3: Subagent dispatch

- **Supported**: yes — partial on return-value contract
- **Mechanism**: Subagents are defined as markdown files with `mode: subagent`
  frontmatter in `.opencode/agents/` (project) or `~/.config/opencode/agents/`
  (global), or inline in `opencode.json`. Frontmatter fields:
  `description` (required), `mode` (`primary` / `subagent` / `all`),
  `model`, `temperature`, `top_p`, `permission` (nested `edit` / `bash`
  with glob / `webfetch` / `task`), and deprecated `tools`.
  Dispatch:
  - Manual via `@subagentname` mentions in the prompt
  - Programmatic via the built-in `Task` tool (primary agents call it based
    on subagent descriptions, with permission.task glob-gating which
    subagents are allowed)
  - Programmatic via the SDK's "create child sessions" API
    (`@opencode-ai/sdk`)
  Isolation: each subagent has its own permission scope (edit/bash/webfetch/
  task). Child sessions render in the TUI and users can navigate parent↔
  child with keybinds. The `General` subagent is described as able to "run
  multiple units of work in parallel"; default execution is sequential with
  configurable `steps` limit.
- **Source tier**: T1
- **Citation**:
  - https://opencode.ai/docs/agents/
  - https://opencode.ai/docs/sdk/
  - Source type `Plugin` in `packages/plugin/src/index.ts` (ProjectContext exposes `client` for programmatic dispatch)
- **Gap from Furrow's need**:
  1. **Return-value shape is undocumented.** Furrow's review/specialist
     agents need a predictable handoff envelope (pass/fail, findings list,
     artifacts). opencode subagents appear to communicate back via chat
     messages only — no typed return. Marked **UNVERIFIED** — requires
     experimentation (T4) or source read of the Task tool impl.
  2. **Parallelism is ad-hoc** — no explicit `Promise.all`-style primitive
     from the primary agent other than "general subagent can parallelize
     internally". Furrow's need for three-reviewer parallel dispatch would
     have to be implemented at the plugin layer using
     `client.session.create` + `Promise.all` against the SDK.
  3. **Subagent hook interception gap** (see Surface 2, point 1) directly
     impacts subagent dispatch reliability.

### Surface 4: Context injection

- **Supported**: yes (multiple mechanisms)
- **Mechanism**: Three layers.
  1. **AGENTS.md / CLAUDE.md cascade** — opencode walks up from cwd
     collecting `AGENTS.md`, then loads global
     `~/.config/opencode/AGENTS.md`, with Claude-Code `CLAUDE.md` as
     fallback. Custom instruction files (local + remote URLs) are listed
     in `opencode.json` under `instructions`. Note: "opencode doesn't
     automatically parse file references in `AGENTS.md`" — includes must
     be explicit.
  2. **Agent Skills** — on-demand markdown skills discovered from
     `.opencode/skills/<name>/SKILL.md` (also `.claude/skills/` and
     `.agents/skills/` compat paths). Loaded via the `skill` tool: only
     name + description initially listed; full body loads on agent
     request. This is lighter than wholesale `AGENTS.md` injection.
  3. **Plugin-driven injection** — `experimental.chat.system.transform`
     allows a plugin to rewrite/append to the system prompt with
     arbitrary strings at each turn (output: `{ system: string[] }`).
- **Source tier**: T1
- **Citation**:
  - https://opencode.ai/docs/rules/
  - https://opencode.ai/docs/skills/
  - `packages/plugin/src/index.ts` — `experimental.chat.system.transform` signature
- **Token cost**: unknown — requires experimentation (T4). Docs warn MCP
  servers consume context tokens but don't quantify AGENTS.md overhead.
- **Gap from Furrow's need**: None structural. The combination of
  (a) AGENTS.md cascade for ambient Furrow context, (b) Skills for
  opt-in reference docs loaded on demand (strong match for Furrow's
  `references/` layer which is explicitly "on demand, NOT injected"), and
  (c) `experimental.chat.system.transform` for step-boundary context
  swaps maps cleanly onto Furrow's four-layer budget (ambient / work /
  step / reference). The Skills model is an especially good fit for
  Furrow's lazy-load reference strategy.

### Surface 5: Multi-provider

- **Supported**: yes
- **Mechanism**: 75+ providers including Anthropic, OpenAI, Google Vertex,
  AWS Bedrock, Azure OpenAI, Groq, DeepSeek, Ollama, llama.cpp, LM Studio,
  NVIDIA NIM, GitHub Copilot, GitLab Duo, OpenRouter, HuggingFace, Together.
  Auth models:
  - API keys (most providers) stored in `~/.local/share/opencode/auth.json`
    via `/connect` command
  - OAuth for ChatGPT Plus/Pro, Claude Pro/Max, GitHub Copilot
  - Env-var auth for Bedrock/Vertex (`AWS_PROFILE`,
    `GOOGLE_APPLICATION_CREDENTIALS`)
  - Hybrid: many providers accept either
  Runtime swap: `/models` slash command mid-session, or per-command
  `model:` frontmatter, or per-agent `model:` frontmatter. `small_model`
  config key lets plugins delegate non-reasoning work to a cheaper model.
  Plugins can also register providers via `ProviderHook` and
  authentication flows via `AuthHook` (both types visible in
  `packages/plugin/src/index.ts`).
- **Source tier**: T1
- **Citation**:
  - https://opencode.ai/docs/providers/
  - `packages/plugin/src/index.ts` — `ProviderHook`, `AuthHook`
- **Gap from Furrow's need**: None. Covers Anthropic + OpenAI + Google +
  local (Ollama, llama.cpp) with runtime swap. Probably the strongest
  provider story of any evaluated host.

### Surface 6: MCP

- **Supported**: yes — native, not plugin-dependent
- **Mechanism**: `mcp` top-level object in `opencode.json` keyed by
  server name. Two server types:
  ```json
  { "mcp": {
    "my-local-mcp": {"type":"local","command":["npx","-y","pkg"],"environment":{"K":"V"}},
    "my-remote-mcp": {"type":"remote","url":"https://...","headers":{"Authorization":"Bearer X"}}
  }}
  ```
  MCP tools auto-register alongside built-ins; can be scoped per-agent
  via glob. OAuth with Dynamic Client Registration supported for
  remote servers.
- **Source tier**: T1
- **Citation**: https://opencode.ai/docs/mcp-servers/
- **MCP spec version**: unknown — requires experimentation (T4); the docs
  don't pin a version. Dynamic Client Registration support implies
  reasonably current MCP auth spec compliance.
- **Gap from Furrow's need**: None structural. Furrow's present MCP
  consumers (Serena, context7, etc.) should register verbatim with
  `"type":"local"` + command array.

### Surface 7: Tool-use metadata to hooks

- **Supported**: yes
- **Mechanism**: `tool.execute.before` receives input
  `{tool: string, sessionID: string, callID: string}` and mutable output
  `{args: any}`. The hook sees the tool *name* and its *arguments* before
  execution and can mutate them or abort via `output.abort = "reason"`.
  `tool.execute.after` receives the executed args plus
  `{title, output, metadata}` in the output slot. `tool.definition`
  allows pre-registration rewriting of the schema the LLM sees.
- **Source tier**: T1
- **Citation**: verbatim signature from
  `packages/plugin/src/index.ts` (lines ~230–270):
  ```ts
  "tool.execute.before"?: (
    input: { tool: string; sessionID: string; callID: string },
    output: { args: any },
  ) => Promise<void>
  "tool.execute.after"?: (
    input: { tool: string; sessionID: string; callID: string; args: any },
    output: { title: string; output: string; metadata: any },
  ) => Promise<void>
  ```
- **Gap from Furrow's need**:
  1. Furrow's existing hooks rely on **exit-code gating** (exit 2 blocks
     the write; the `state-guard` and `correction-limit` hooks both use
     this). opencode's plugin layer uses a **promise + abort-field**
     contract. Adapter work: a `furrow-opencode-adapter` plugin shells
     out to the existing hook scripts via `$` (Bun shell) and maps their
     exit code to `output.abort`. Straightforward, ~20 LOC.
  2. The untyped `args: any` puts tool-schema awareness on Furrow. Not a
     blocker — Furrow already knows the Write/Edit arg shape.
  3. **Subagent tool calls not intercepted** (see Surface 2, point 1):
     this is the single most serious gap if confirmed.

---

## Open questions (things that need experimentation — T4)

1. **Does `tool.execute.before` fire for tool calls made inside subagents?**
   Issue #5894 says no. Needs an empirical test: spawn a subagent, have it
   call Write, observe whether the plugin hook fires. **Critical** for
   Furrow — if it doesn't, deliverable ownership can't be enforced across
   the main agent + Task-tool boundary.
2. **What is the return-value contract from a subagent back to the
   primary agent?** Undocumented. Read the Task tool source
   (`packages/opencode/...`) or test with an instrumented subagent.
3. **MCP spec version.** Not pinned in docs.
4. **Token cost of AGENTS.md injection.** Furrow's context budget
   (ambient ≤150 lines, total injected ≤350 lines) requires measuring
   baseline opencode system-prompt overhead before adding Furrow rules.
5. **Stability of `experimental.*` hooks.** The compaction and
   system-transform hooks are the most important ones for Furrow's
   step-boundary context swap; their `experimental.` prefix is a
   stability warning. Ask the maintainers or track the type definitions
   across minor versions.
6. **Can `tui.command.execute` / SDK `client.session.command` programmatically invoke slash commands?** This would let a plugin (e.g. on `session.idle`) trigger `/furrow:checkpoint` automatically. Signature looks promising in source but behavior isn't in the docs.

---

## Stability + community

**Stars / forks / contributors** (T1, `gh api` 2026-04-22):
- Stars: **147,649**
- Forks: **16,863**
- Contributors: **455** (count via contributors API pagination)
- Watchers (subs): 583
- Open issues: **6,115** (very high — velocity signal)
- License: **MIT**
- Created: 2025-04-30
- Last push: 2026-04-22 (same day as research)
- Default branch: `dev`

**Release cadence** (T1, `gh api releases`):
- v1.14.20 — 2026-04-21
- v1.14.19 — 2026-04-20
- v1.14.18 — 2026-04-19
- v1.14.17 — 2026-04-19
- Daily patch releases; no strict semver — patch bumps carry behavior
  changes (per HN reports).

**Community signal** (T2, HN id=47460525):
- Praise: flexible, provider-agnostic, stable *when* it works
- Concern: high release cadence without regression testing, 1GB+ RAM for
  a TUI, cloud-by-default for session title generation (privacy surprise),
  TUI hijacks copy-paste and deviates from standard terminal conventions,
  incomplete changelogs, occasional undocumented behavioral changes
- Maturity mixed: "daily driver for months" vs "constantly broken"
- Security: a GitHub issue flagged RCE-class concerns (unverified in
  this research)

**Breaking-change policy**: not formally documented. The `experimental.*`
prefix is the only signal. Type-level deprecations exist
(`AuthOuathResult` → `AuthOAuthResult`, `tools` frontmatter key
deprecated in favor of `permission`), so the project does mark
deprecations. No SemVer guarantee documented.

**Packaging / distribution of extensions** (T1):
- Plugins load from `.opencode/plugins/`, `~/.config/opencode/plugins/`,
  or npm packages listed in `opencode.json` under `plugin` (supports
  `string | [string, options]`).
- No first-party plugin registry/marketplace documented — npm is the de
  facto registry; discovery is "put it on npm, document it on GitHub".
- Slash commands and subagents distribute as plain markdown files under
  the same `.opencode/` / `~/.config/opencode/` pattern — trivially
  copyable (strongly matches Furrow's current `.claude/commands/*.md`
  distribution model).

**System-prompt / ambient overhead**: unknown — requires experimentation
(T4). The baseline system prompt is not surfaced in docs.

**Licensing**: MIT across repo; `@opencode-ai/plugin` and
`@opencode-ai/sdk` published to npm (inferred from the source
`import type ... from "@opencode-ai/sdk"`).

---

## Fit verdict (editorial)

opencode is **the highest-fit host** for Furrow's adapter surface that
has been evaluated so far, with one critical caveat:

- **Everything Furrow currently does via `.claude/` maps 1:1** onto
  `.opencode/` (commands, skills, agents, plugins), with the added
  benefit of a typed plugin SDK in TypeScript instead of JSON-plus-shell.
- **The single blocking unknown** is whether `tool.execute.before`
  fires for subagent tool calls. If it doesn't, Furrow's deliverable
  ownership and correction-limit enforcement leak through the Task
  boundary. This needs T4 verification before adopting as a primary
  target.
- **Runtime provider swap** via `/models` is better than any other host
  evaluated — directly enables Furrow's "swap provider mid-row" use case
  without adapter work.
- **Release velocity** is the main operational risk — Furrow would need
  to pin a minor version and test each bump.

---

## Sources consulted (tiered)

### T1 — Primary (repo source, official docs, GitHub API)

- `gh api repos/anomalyco/opencode` — repo metadata (stars, license,
  default branch, push timestamp, contributors)
- `gh api repos/anomalyco/opencode/contents/packages/plugin/src/index.ts`
  — verbatim `Hooks`, `Plugin`, `PluginInput`, `AuthHook`,
  `ProviderHook` type definitions
- `gh api repos/anomalyco/opencode/contents/packages/plugin/src/example.ts`
  — canonical plugin example
- `gh api repos/anomalyco/opencode/contents/` — top-level structure,
  AGENTS.md, LICENSE (MIT), multilingual READMEs
- `gh api repos/anomalyco/opencode/contents/packages` — package list
  (app, console, containers, desktop-electron, desktop, docs, enterprise,
  extensions, function, identity, opencode, plugin, script, sdk, shared,
  slack, storybook, ui, web)
- https://opencode.ai/docs — intro
- https://opencode.ai/docs/plugins/ — plugin API, hook list, abort
  pattern, custom tools
- https://opencode.ai/docs/agents/ — subagent frontmatter schema,
  permission.task glob gating, Task tool
- https://opencode.ai/docs/mcp-servers/ — MCP config, local+remote,
  OAuth w/ DCR
- https://opencode.ai/docs/custom-tools/ — tool file layout, naming,
  namespacing
- https://opencode.ai/docs/commands/ — slash command frontmatter,
  `$ARGUMENTS`/`$N`/`!shell`/`@file` parsing, agent/subtask/model
- https://opencode.ai/docs/providers/ — 75+ providers, auth models,
  runtime swap via `/models`
- https://opencode.ai/docs/rules/ — AGENTS.md cascade, CLAUDE.md
  fallback, `instructions` key
- https://opencode.ai/docs/skills/ — SKILL.md on-demand loading
- https://opencode.ai/docs/sdk/ — `@opencode-ai/sdk` capabilities,
  child-session creation, SSE events
- https://opencode.ai/docs/config/ — top-level config schema
- `gh api repos/anomalyco/opencode/releases` — release cadence data

### T2 — Secondary (community analysis, issues)

- https://github.com/anomalyco/opencode/issues/5894 — "Plugin hooks
  (tool.execute.before) don't intercept subagent tool calls - security
  policy bypass"
- https://github.com/anomalyco/opencode/issues/20387 — feature request:
  "Plugin hooks should support reactive sub-agent spawning"
- https://gist.github.com/zeke/1e0ba44eaddb16afa6edc91fec778935 —
  OpenCode vs Claude Code Hooks Comparison
- https://dev.to/einarcesar/does-opencode-support-hooks-a-complete-guide-to-extensibility-k3p
  — hook capabilities, abort pattern
- https://gist.github.com/johnlindquist/0adf1032b4e84942f3e1050aba3c5e4a
  — OpenCode Plugins Guide
- https://gist.github.com/rstacruz/946d02757525c9a0f49b25e316fbe715 —
  Opencode plugin development guide
- https://lushbinary.com/blog/opencode-plugin-development-custom-tools-hooks-guide/
  — plugin development walk-through
- https://github.com/KristjanPikhof/OpenCode-Hooks — community plugin
  that translates YAML hook definitions to opencode plugin hooks
- https://news.ycombinator.com/item?id=47460525 — HN thread: release
  velocity, RAM usage, privacy defaults, stability mixed

### T3 — Tertiary (training-data cross-check only)

- Grokipedia "OpenCode" page — used only to corroborate MIT license and
  anomalyco provenance
- `https://grigio.org/opencode-vs-pi-which-ai-coding-agent-should-you-use/`
  — corroborates terminal-first positioning

### T4 — Requires experimentation (not executed in this research)

- Verify subagent tool-call interception (issue #5894 reproducer)
- Measure MCP spec version empirically
- Measure AGENTS.md + baseline system-prompt token cost
- Observe experimental.* hook stability across v1.14.x → next minor
- Confirm `output.abort` on `tool.execute.before` propagates as a user-
  visible error (vs silent skip)
- Confirm slash-command programmatic invocation via SDK/TUI events
