# R2 — Pi Coding Agent Deep Dive

Research date: 2026-04-22. Target package: `@mariozechner/pi-coding-agent` v0.68.1 (published 2026-04-22). Repo: `github.com/badlogic/pi-mono`.

## Summary

- **Pitch**: Pi is a minimal, aggressively extensible terminal coding harness (MIT, TypeScript, Node >=20.6) that deliberately ships a tiny core — read/write/edit/bash only — and pushes everything else (sub-agents, plan mode, MCP, permission gates) into a first-class TypeScript extension system loaded from `~/.pi/agent/extensions/` or project `.pi/extensions/`. Extensions subscribe to a rich lifecycle-event bus, register slash commands, register tools, and can mutate or block tool calls, inject context, and replace the system prompt.
- **Architectural differentiators vs Claude Code**: (1) Hooks are in-process TypeScript (not forked subprocess JSON), so hooks get mutable typed payloads and can modify tool args synchronously; (2) No built-in MCP and no built-in subagent — both must be added as extensions; (3) Provider catalog is much broader (~20 API-key providers plus 5 OAuth subscriptions), swappable per-process via `--provider` flag; (4) System prompt + tools <1000 tokens total (vs ~10k for mainstream agents); (5) Skills follow the external `agentskills.io` spec with XML-in-system-prompt progressive disclosure.
- **Fit for Furrow's Host Adapter Interface**: Strong fit on slash commands, hooks (PreToolUse/PostToolUse/SessionStart/PostCompact equivalents all exist), context injection (three distinct mechanisms), and multi-provider. Weak/gap: subagent dispatch is example-code only (spawn child `pi` process with parallel/chain modes in `examples/extensions/subagent`, not a blessed core primitive), and MCP is explicitly absent — Furrow would need to ship its own subagent extension and accept loss of MCP server interop or build an MCP shim extension.
- **Maturity signal**: 38,660 stars on the monorepo, 4,514 forks, 10 open issues, daily commits, releases near-daily (v0.67.6 → v0.68.1 in the last ~6 days observed), MIT licensed, single primary maintainer (Mario Zechner / badlogic).

## Per-surface findings

### Surface: slash commands
- **Supported**: yes — first-class extension API
- **Mechanism**: `pi.registerCommand(name, { description, handler: async (args, ctx) => …, getArgumentCompletions?(prefix) })`. Commands are invoked as `/name args…`. Duplicate names get numeric suffixes (`/review:1`, `/review:2`). Skills auto-expose as `/skill:name`; prompt templates expose as `/templatename`. Built-ins include `/login`, `/model`, `/compact`, `/fork`, `/resume`, `/reload`, `/tree`, `/share`, `/hotkeys`.
- **Source tier**: T1
- **Citation**: `docs/extensions.md` (94KB, section on command registration); README slash-command list at `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md`
- **Gap from Furrow's need**: None significant. Argument parsing is raw-string (extension parses `args` itself) — Furrow commands using positional args can do the same. Autocompletion is supported via `getArgumentCompletions`. Namespacing is ad-hoc (collision suffix), not a declared namespace like `/furrow:work`; Furrow can prefix its own commands to emulate.

### Surface: hook events — PreToolUse / PostToolUse / Stop / SessionStart / PostCompact equivalents
- **Supported**: yes (all five equivalents present)
- **Mechanism**: event bus via `pi.on(eventName, async (event, ctx) => …)`. Handlers can be async, run sequentially in extension load order, and each can return a partial override object.
  - **PreToolUse equivalent** → `"tool_call"`: payload `{ toolName: string, toolCallId: string, input: Record<string, unknown> }`. Handler can return `{ block: true, reason?: string }` to abort, or directly mutate `event.input` in place to rewrite args. Later handlers see mutations.
  - **PostToolUse equivalent** → `"tool_result"`: payload includes `toolName`, `toolCallId`, `input`, `content`, `details`, `isError`. Can return a replacement `{ content, details, isError }`.
  - Supporting tool lifecycle events: `"tool_execution_start" | "tool_execution_update" | "tool_execution_end"`.
  - **Stop equivalent** → `"agent_end"` (once per user prompt) and `"turn_end"` (per LLM response+tool batch). Session-level stop is `"session_shutdown"` with `reason: "quit" | "reload" | "new" | "resume" | "fork"`.
  - **SessionStart equivalent** → `"session_start"` with `reason: "startup" | "reload" | "new" | "resume" | "fork"` and optional `previousSessionFile`. Plus `"resources_discover"` fires after `session_start` so extensions can contribute skill/prompt/theme paths.
  - **PostCompact equivalent** → `"session_compact"` (after compaction completes, payload contains `compactionEntry`). Pre-compact hook is `"session_before_compact"` — can return `{ cancel: true }` or provide a custom summary object (`{ compaction: { summary, firstKeptEntryId, ... } }`).
  - Other events: `"before_agent_start"`, `"agent_start"`, `"turn_start"`, `"message_start"`, `"message_update"`, `"message_end"`, `"context"` (pre-LLM-call message filter), `"before_provider_request"`, `"after_provider_response"`, `"model_select"`, `"input"`, `"user_bash"`, `"session_before_switch"`, `"session_before_fork"`, `"session_before_tree"`, `"session_tree"`.
- **Source tier**: T1
- **Citation**: `docs/extensions.md` (lifecycle-events section); source files `src/core/extensions/types.ts` (53KB), `src/core/extensions/runner.ts` (31KB), `src/core/event-bus.ts`. Hook types re-exported at `dist/core/hooks/index.js` per `package.json` exports.
- **Gap from Furrow's need**: None. This is arguably Pi's strongest surface — the hook taxonomy is richer than Claude Code's, and hooks see mutable typed payloads rather than stdin JSON. Furrow's `PreToolUse`→`tool_call`, `Stop`→`agent_end`/`session_shutdown`, `SessionStart`→`session_start`, `PostCompact`→`session_compact` mapping is clean.

### Surface: subagent dispatch
- **Supported**: partial — no built-in primitive; example extension ships as reference implementation
- **Mechanism**: The reference extension at `examples/extensions/subagent/index.ts` (34KB) registers a `subagent` tool that spawns a child `pi` process for each invocation, giving it an isolated context window via dedicated stdio pipes. Three invocation shapes:
  - **Single**: `{ agent: "name", task: "..." }`
  - **Parallel**: `{ tasks: [{ agent, task }, ...] }` with `MAX_CONCURRENCY = 4`
  - **Chain**: `{ chain: [{ agent, task: "... {previous} ..." }, ...] }` with `{previous}` substitution between steps.
  - Results stream back with usage stats (`input`, `output`, `cacheRead`, `cacheWrite`, `cost`). Agent personas live in `examples/extensions/subagent/agents/` as markdown files (the `agents.ts` loader reads the dir).
  - Generic process-spawn primitive is also available: `pi.exec(command, args, options?)` plus `pi.sendUserMessage(..., { deliverAs: "steer" | "followUp" })` for in-process message injection.
- **Source tier**: T1
- **Citation**: `examples/extensions/subagent/{README.md,index.ts,agents.ts}`; philosophy statement in main README: *"No sub-agents. There's many ways to do this. Spawn pi instances via tmux, or build your own with extensions."*
- **Gap from Furrow's need**: Moderate. Furrow needs parallel + sequential + chain modes with return values — the example extension covers all three. BUT it's *example code*, not a stable core API; Furrow would need to either fork the example as a vendored extension or contribute it upstream as a blessed primitive. Context isolation is process-level (heavier than Claude Code's Task tool but genuinely isolated). No declarative agent registry outside the markdown files in `agents/`.

### Surface: context injection (skills / markdown files into model context)
- **Supported**: yes — three distinct mechanisms
- **Mechanism**:
  1. **Skills** (agentskills.io spec): loaded from `~/.pi/agent/skills/`, `~/.agents/skills/`, `.pi/skills/`, `.agents/skills/`, plus `skills/` in installed packages. Discovery scans at startup, extracts names+descriptions, injects as XML into the system prompt. Full SKILL.md bodies load on-demand (progressive disclosure) or via explicit `/skill:name` invocation.
  2. **Agent memory files**: `AGENTS.md` or `CLAUDE.md` loaded at startup from project + ancestor dirs and global `~/.pi/agent/`.
  3. **System prompt control**: `.pi/SYSTEM.md` replaces default; `APPEND_SYSTEM.md` appends. CLI flag `--system-prompt <text>` replaces at process level.
  4. **Programmatic injection from extensions** (the key one for Furrow):
     - `pi.on("before_agent_start", …)` — return `{ systemPrompt: event.systemPrompt + "\n\n..." }` to append, or `{ message: { customType, content, display } }` to insert a persisted message.
     - `pi.on("context", …)` — return `{ messages: filtered }` to non-destructively rewrite the message list sent to the LLM.
     - `pi.appendEntry(customType, data)` to persist structured entries that survive session restart; rehydrate on `session_start`.
- **Source tier**: T1
- **Citation**: `docs/skills.md`, `docs/extensions.md` (context-injection section), `src/core/skills.ts`, `src/core/resource-loader.ts`, `src/core/system-prompt.ts`.
- **Gap from Furrow's need**: None material. Furrow needs step-boundary and post-compact injection — both achievable: step-boundary via `before_agent_start` or `input` hook, post-compact via `session_compact` hook. Token cost is minimal because skills are progressive-disclosure by default (only names+descriptions in system prompt; full bodies on-demand).

### Surface: multi-provider (runtime swap between Anthropic / OpenAI / Google / local)
- **Supported**: yes — broadest provider catalog of any agent host reviewed
- **Mechanism**: Process-level `--provider <name> --model <id>`, interactive `/model` and `/scoped-models` commands, and `auth.json` at `~/.pi/agent/auth.json`. Provider resolution order: CLI flags → auth.json → env vars → custom-provider keys. OAuth and API key both supported.
  - **OAuth subscription providers**: Anthropic Claude Pro/Max, OpenAI ChatGPT Plus/Pro, GitHub Copilot, Google Gemini CLI, Google Antigravity
  - **API-key providers**: Anthropic, OpenAI, Azure OpenAI, Google Gemini, Google Vertex, Amazon Bedrock, Mistral, Groq, Cerebras, xAI, OpenRouter, Vercel AI Gateway, ZAI, OpenCode Zen, OpenCode Go, Hugging Face, Fireworks, Kimi For Coding, MiniMax
  - **Local/custom**: Ollama, LM Studio, vLLM via `~/.pi/agent/models.json` if the endpoint speaks OpenAI, Anthropic, or Google API shape. Fully custom providers via extension (`pi.registerProvider(name, spec)`) — see `examples/extensions/custom-provider-{anthropic,gitlab-duo,qwen-cli}`.
- **Source tier**: T1
- **Citation**: `docs/providers.md`, `docs/models.md`, `docs/custom-provider.md` (20KB), `src/core/model-registry.ts` (28KB), `src/core/model-resolver.ts` (20KB).
- **Gap from Furrow's need**: None. Per-request swap via `/model` is instant; per-process swap via `--provider` is a relaunch. Extensions can hook `"model_select"` to react. Furrow can either assume per-process config or ship a command that wraps `/model`.

### Surface: MCP (Model Context Protocol) server compatibility
- **Supported**: no (explicit design choice)
- **Mechanism**: None built in. Philosophy from README: *"No MCP. Build CLI tools with READMEs (see Skills), or build an extension that adds MCP support."* The examples directory ships no MCP extension as of v0.68.1.
- **Source tier**: T1
- **Citation**: main README philosophy section at `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md`; confirmed absent from `examples/extensions/README.md`.
- **Gap from Furrow's need**: Significant if Furrow users rely on existing MCP servers (Linear, Notion, Sentry, etc.). Workarounds: (a) build an MCP-client extension that registers each MCP tool as a Pi tool via `pi.registerTool`, (b) have users wrap MCP servers as CLI bash tools. This is the biggest portability tax in the Pi adapter.

### Surface: tool-use metadata exposed to hooks (name, args, result)
- **Supported**: yes — all three visible
- **Mechanism**: `"tool_call"` event payload: `{ toolName: string, toolCallId: string, input: Record<string, unknown> }` with `input` **mutable** — hooks can directly modify it pre-execution. `"tool_result"` event payload adds `content` (array of content blocks), `details`, `isError`. Typed narrowing helper: `isToolCallEventType<"my_tool", MyToolInput>("my_tool", event)` for type-safe access to extension-defined tool schemas.
- **Source tier**: T1
- **Citation**: `docs/extensions.md` (tool-call section with TypeScript signatures); source at `src/core/extensions/types.ts`. Example hook from docs: *"if (event.toolName === 'bash' && event.input.command?.includes('rm -rf')) { const ok = await ctx.ui.confirm(…); if (!ok) return { block: true, reason: 'Blocked by user' }; }"*
- **Gap from Furrow's need**: None — arguably better than Claude Code. Matcher-based gating is trivial because `toolName` is a plain string on a typed event. Pi does **not** re-validate args after mutation (documented), which is a feature for Furrow (rewrite-and-proceed) but a footgun if a hook produces schema-invalid args.

## Open questions (what primary sources couldn't fully answer)

1. **Subagent stability**: the subagent example is 34KB of working code but lives under `examples/` — is the author willing to promote it to a first-party extension, or does Furrow vendor it? No roadmap signal found.
2. **MCP extension in the wild**: no community MCP-client extension was discoverable via the repo or gallery (`pi.dev/packages`) at the time of this research. Unknown whether one exists — requires experimentation (T4).
3. **Correction/retry semantics**: Pi hooks can block a `tool_call` but the docs don't describe how the model is informed of the block (is the `reason` surfaced as a synthetic tool result?). Source tier: unknown — requires experimentation (T4).
4. **Hook error handling**: if a hook throws, does the tool proceed, fail, or crash the agent? Not documented. Requires experimentation (T4).
5. **Session persistence across process restart**: `pi.appendEntry` + JSONL sessions handle custom state, but the exact guarantee (append-only? corruption recovery?) needs source read of `src/core/session-manager.ts` (43KB) — not done in this pass.
6. **Multiple-extension ordering**: docs say "sequential in load order" but no explicit priority or cancellation propagation rules are given for the case where two extensions both register handlers for the same event.

## Stability + community

- **Current version**: `@mariozechner/pi-coding-agent` **0.68.1** (published 2026-04-22, same day as this research)
- **Release cadence**: near-daily — v0.67.6 on 2026-04-16, v0.68.0 on 2026-04-20, v0.68.1 on 2026-04-22 (5 releases in 7 days observed). Semver is still 0.x, so breaking changes are possible on any minor bump; the CHANGELOG is 327KB, indicating a long and active change history.
- **Monorepo stars/forks**: 38,660 stars / 4,514 forks on `badlogic/pi-mono`
- **Open issues**: 10 (very low for a repo this size, suggests fast triage)
- **License**: MIT
- **Maintainer**: Mario Zechner (badlogic) — primarily single-maintainer activity in recent commits
- **Node requirement**: >=20.6.0
- **Recent commit sample (2026-04-22)**: `feat(coding-agent,tui): add stacked autocomplete providers`, `fix(coding-agent): chain system prompt in before_agent_start`, `fix(ai): synthesize trailing orphaned tool results` — active development on exactly the surfaces Furrow cares about.
- **Breaking-change risk for a Furrow adapter**: high-to-moderate. 0.x versioning + near-daily releases + single maintainer means the adapter should pin to an exact version and ship with a compat-test suite. Event names, payload shapes, and extension API signatures have evidence of ongoing refinement (the 2026-04-22 `before_agent_start` system-prompt chaining fix is evidence of active API shape work).

## Sources Consulted

### T1 — Primary (repo, official docs)
- `https://github.com/badlogic/pi-mono/tree/main/packages/coding-agent` — directory listing, confirmed layout (src, docs, examples, test)
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/README.md` — philosophy, built-in command list, provider list, skills/AGENTS.md/SYSTEM.md behavior, "No MCP"/"No sub-agents" statements
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/package.json` — version 0.68.1, MIT, bin, exports (including `./dist/core/hooks/index.js`)
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/extensions.md` (94KB) — **the authoritative source** for event names, payload shapes, `registerCommand`/`registerTool`/`registerProvider` signatures, tool-call block/mutate semantics, context injection mechanisms, async support
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/skills.md` — skills discovery, directory tiers, progressive disclosure
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/compaction.md` — `session_before_compact` / `session_compact` events, trigger condition (`contextTokens > contextWindow - reserveTokens`, default 16384)
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/packages.md` — npm/git/local install, `pi.extensions/skills/prompts/themes` manifest
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/providers.md` — provider catalog, OAuth vs API key, `auth.json` resolution order
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/examples/extensions/README.md` — confirms MCP absence; lists subagent/plan-mode/permission-gate/custom-provider examples
- `https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/examples/extensions/subagent/index.ts` — Single/Parallel (MAX_CONCURRENCY=4)/Chain modes, process-level isolation, `{previous}` substitution
- GitHub REST API via `gh api repos/badlogic/pi-mono` — stars 38660, forks 4514, open issues 10, license MIT, last push 2026-04-22T17:42:06Z
- GitHub REST API releases endpoint — v0.68.1 (2026-04-22), v0.68.0 (2026-04-20), v0.67.68 (2026-04-17), cadence evidence
- GitHub REST API commits endpoint — recent commits touching `before_agent_start` chaining, stacked autocomplete, tool-result synthesis

### T2 — Secondary (blog posts, author essays)
- `https://mariozechner.at/posts/2025-11-30-pi-coding-agent/` — author's essay containing the **<1000-token system prompt claim**: *"Pi's system prompt and tool definitions together come in below 1000 tokens… there does not appear to be a need for 10,000 tokens of system prompt."* Also source for the YOLO-mode default posture and the "frontier models have been RL-trained up the wazoo" rationale.
- `https://dev.to/theoklitosbam7/pi-coding-agent-a-self-documenting-extensible-ai-partner-dn` — covers extension architecture at a higher level; confirmed TypeBox param schemas, `~/.pi/agent/extensions/` location, three-tier model priority (tool input → agent frontmatter → main agent); did **not** cover hooks, MCP, subagents, or system-prompt size.
- `https://www.npmjs.com/package/@mariozechner/pi-coding-agent` — registry confirmation of version 0.68.1 and MIT license.

### T3 — Tertiary
- Not required — T1 sources covered every surface except the system-prompt-size claim, which T2 (author blog) verified.

### T4 — Experimentation needed (not done)
- Error-propagation behavior when a hook throws
- Whether `block: true` surfaces `reason` as a synthetic tool result to the model
- Existence of any community MCP-client extension in `pi.dev/packages`
- Whether the subagent example extension is considered stable enough to depend on or will be promoted to core
