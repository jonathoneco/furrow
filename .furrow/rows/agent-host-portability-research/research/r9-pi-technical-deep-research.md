# R9 — Pi Technical Deep Research

Scope: five gating technical questions about Pi (`badlogic/pi-mono`), `@tintinweb/pi-subagents`, and `MasuRii/pi-permission-system` that the Furrow agent-host-portability migration plan needs answered before committing.

Method: primary sources only — GitHub contents API + raw source on `main`/`master`, plus `pi.dev` HTML. No repos cloned; WebFetch + `gh api` only. Every factual claim below is tagged with a tier:

- **T1** — primary source (source file, official docs, README in the canonical repo)
- **T2** — secondary synthesis (a synthesis of multiple T1 observations)
- **T3** — snippet-only (partial/paraphrased evidence, needs confirmation)

Research conducted 2026-04-22.

---

## Q-D1 — pi-subagents context isolation

### Process model

- **Same-process, in-memory** — `@tintinweb/pi-subagents` dispatches subagents by directly importing `createAgentSession` from `@mariozechner/pi-coding-agent` and calling `session.prompt(...)` in the same Node.js process as the parent. There is no worker thread, child process, or IPC boundary for execution. **T1**: `github.com/tintinweb/pi-subagents/blob/master/src/agent-runner.ts` imports from `@mariozechner/pi-coding-agent` (`createAgentSession`, `SessionManager`) and invokes `await session.prompt(effectivePrompt)` directly; `SessionManager.inMemory(effectiveCwd)` is used for session storage.
- **Optional git-worktree isolation** for filesystem scope only. With `isolation: worktree` frontmatter set, the extension shells out (via `execFileSync`) to `git worktree add --detach`, points the subagent's cwd at the worktree, and on completion either `git worktree remove` (no changes) or commits to a branch named `pi-agent-<agentId>` (with `-${Date.now()}` suffix on collision) then removes the worktree, leaving the branch. **T1**: `src/worktree.ts` per tintinweb README and file listing. Note: this is still same-process — only the working directory differs.
- **Fallback**: "If the worktree cannot be created (not a git repo, no commits), the agent falls back to the main working directory with a warning." **T1**: tintinweb README.

### System prompt injection

Controlled by the `prompt_mode` frontmatter field on the custom agent definition. Two values:

- `replace` (default): "body is the full system prompt" — parent's system prompt is discarded, agent body is the entire prompt. **T1**: tintinweb README.
- `append`: "body appended to parent's prompt (agent acts as a 'parent twin' with optional extra instructions)". **T1**: tintinweb README.

The bundled `general-purpose` default agent uses `append` mode — it "receives the parent's entire system prompt plus a sub-agent context bridge." **T1**: `src/prompts.ts` per synthesized file listing in tintinweb repo.

### Skill loading

Controlled by the `skills` frontmatter field. Three shapes:

- `skills: true` (default) — inherit all of parent's discovered skills.
- `skills: false` — inherit nothing.
- `skills: "api-conventions, error-handling"` — comma-separated allowlist preloaded from `.pi/skills/` (project) or `~/.pi/skills/` (global); project overrides global.

"Symlinked skill files are rejected for security." **T1**: tintinweb README.

### Return value shape

Two modes:

- **Foreground**: "block until complete and return results inline." Inline return surfaces through Pi's tool result channel to the calling agent. **T1**: tintinweb README.
- **Background**: "return an ID immediately and notify you on completion." Results fetched via the `get_subagent_result` tool, which accepts `agent_id`, `wait` (bool), `verbose` (bool). Completion notifications render as styled boxes with token counts, tool use counts, duration, and conversation logs. **T1**: tintinweb README + `src/index.ts` registers `get_subagent_result` as a tool via `pi.registerTool()`. Concurrency default: 4 background agents; foreground agents bypass the queue. **T1**: tintinweb README.

Return shape is a **structured object** (token counts, durations, tool use counts, logs) on the result-retrieval path; the model-visible tool result is text rendered from that object. **T2** — inferred from rendering description + get_subagent_result verbose flag.

### Parent-state mutation risk

- Parent session state is **not shared** with subagent. Each subagent gets its own `AgentSession` instance, its own conversation buffer, its own tool state. **T1**: `agent-runner.ts` creates a fresh `createAgentSession(...)` per dispatch.
- Parent conversation is **opt-in inherited** via the `inherit_context: true` tool parameter — "forks parent conversation into the agent." Default is fresh context. **T1**: pi-subagents `src/index.ts` tool schemas.
- Subagent **extension hooks do not fire into parent** — the event bus emits custom events (`subagents:created`, `subagents:started`, `subagents:completed`) on a shared event bus (`src/cross-extension-rpc.ts`) for observability, but these are namespaced events, not parent lifecycle hooks. **T1**: tintinweb `src/cross-extension-rpc.ts` file listing and `src/index.ts` hook registrations (`session_start`, `session_switch`, `tool_execution_start`, `session_shutdown` are registered on the parent — none of these fire from inside a subagent's execution).
- **Filesystem mutation scope**: subagents can write to the same working directory as the parent unless `isolation: worktree` is set. There is no process-level filesystem sandbox. The only write-gating mechanism is the agent's `disallowed_tools` frontmatter (e.g., `disallowed_tools: write, edit` denies those tools for that subagent specifically). Read-only memory is automatic when `write`/`edit` are absent. **T1**: tintinweb README.

### Verdict (for Furrow)

**Needs wrapping** — but not because of subagent-to-parent leakage; that part is clean. The concerns for Furrow:

1. Since subagents run in the same Node process and write to the same cwd by default, a subagent dispatched from within a Furrow row could write to `.furrow/rows/<other-row>/state.json` unless the state-guard hook (Q-D2) fires for subagent-originated tool calls. **UNVERIFIED** — whether Pi's `tool_call` hook fires inside subagent execution needs experiment. The runner.ts quote shows `tool_call` short-circuits on `{block: true}` but it's not stated whether the extension runner in a subagent session inherits the parent's registered handlers.
2. Setting `isolation: worktree` would break Furrow entirely since Furrow state lives under `.furrow/` and the worktree wouldn't have the active row's state. Do not use worktree isolation for Furrow-aware subagents.
3. For cross-model review (currently `claude -p --bare`), Furrow should dispatch a subagent with `prompt_mode: replace`, `skills: false`, `inherit_context: false`, `disallowed_tools: write, edit, bash` to keep it read-only and context-clean. This replicates `--bare` semantics.

**Source tier**: tintinweb README (T1) + `src/*.ts` filenames-only via gh contents API (T2 — file existence verified, exact internal code not read verbatim for every file).

---

## Q-D2 — state-guard options

Furrow's CC-era state-guard: PreToolUse hook reads `tool_input.file_path` from stdin JSON, exits 2 with a message when the path resolves to a protected file, CC surfaces the block to the model.

### Option 1: `pi.on('tool_call')` handler

- **API support: yes.** Pi emits `tool_call` events fired "after `tool_execution_start`, before the tool executes. **Can block.**" Handler receives `{ toolName, toolCallId, input }` and can return `{ block: true, reason?: string }`. **T1**: `packages/coding-agent/docs/extensions.md`.
- **Pre-execution block: yes.** The docs explicitly state the event fires before execution and blocking is supported.
- **Model-visible message quality**: the `reason` string is returned to the model as part of the block — clean, not a stack trace. **T1**: `extensions.md` type signature `{ block: true, reason?: string }`. Exact framing of the message in the assistant's tool-result channel is **UNVERIFIED** but the contract is explicit that a reason string is passed.
- **Call-order semantics**: "Extensions are called sequentially in the order they appear in the `extensions` array... For `tool_call` events, returning `{block: true}` short-circuits immediately." **T1**: `packages/coding-agent/src/core/extensions/runner.ts` (quoted in research). So registration order matters; first blocker wins; subsequent extensions don't see the event.
- **Mutation side-channel**: "Mutations to `event.input` affect the actual tool execution." **T1**: `extensions.md`. This means the hook can *also* rewrite tool input (e.g., redirect a write to a safe path) — a superset of what CC PreToolUse offers.

### Option 2: `MasuRii/pi-permission-system`

- **API support: yes, but declarative only.** Rules live in a `pi-permissions.jsonc` file at `~/.pi/agent/extensions/pi-permission-system/` or project equivalent. Sections: `tools`, `bash`, `mcp`, `skills`, `special`. Values per entry: `"allow"`, `"deny"`, `"ask"`. **T1**: MasuRii/pi-permission-system README.
- **No programmatic registration API.** "No direct API exists. Rules are declarative JSON/JSONC objects. No programmatic registration method is documented." **T1**: README synthesis.
- **Pre-execution block: yes.** Uses two hooks: `before_agent_start` (filters tool list, sanitizes system prompt) and `tool_call` (enforces at call time). "Hides disallowed tools from the agent before it starts (reduces 'try another tool' behavior)." **T1**: README.
- **Model-visible message quality**: excellent for complete denies — the tool is absent from the system prompt entirely, so the model doesn't know to try it. For path-conditional denies (e.g., "deny write to `.furrow/rows/*/state.json`" but allow other writes), this model breaks down — you can't express path predicates declaratively; it's tool-level only.
- **Call-order semantics**: "If multiple patterns match, the **last matching rule wins**" for wildcard sections (`bash`, `mcp`, `skills`). **T1**: README. `tools` section appears to be flat allow/deny, no patterns.
- **Furrow fit**: poor for state-guard use case. Furrow needs path-scoped denies (block writes to `state.json` but allow writes to `summary.md` sections and other files). The permission-system is tool-scoped, not path-scoped. It can enforce "bash: `git push --force` = deny" well, but cannot say "write: path starts with `.furrow/rows/` and ends with `state.json` = deny."

### Option 3: Tool wrapping via `pi.registerTool`

- **API support: yes.** `pi.registerTool()` is the documented mechanism (pi-subagents uses it to register `Agent`, `get_subagent_result`, `steer_subagent`). **T1**: pi-subagents `src/index.ts` synthesis.
- **Shadowing built-in tools: UNVERIFIED.** The pi-mono issue #3553 ("Extension tools overriding built-in tools") in the recent issues list suggests this is a known pattern/bug area but the resolution status wasn't fetched. **T3** — issue title only, no body read.
- **Pre-execution block**: yes trivially — your wrapping function can just `throw` or return an error before invoking the inner tool.
- **Downsides**: must reimplement or proxy Write/Edit semantics (path resolution, atomic write, permission checks). Pi's Write/Edit have non-trivial behavior (encoding, newline handling) — reimplementing would drift. Shadow-and-delegate is theoretically possible but no documented way to invoke the built-in implementation from an extension.

### Recommendation for Furrow

**Use Option 1** — register a `tool_call` handler. Reasons:

1. Native Pi API, documented, stable-shaped (`{ toolName, input, toolCallId }` → `{ block: true, reason }`).
2. Path-predicate expressiveness: your handler is arbitrary JS, so path-based rules are trivial.
3. Input mutation option gives a clean upgrade path (auto-rewrite-to-safe-path correction for deliverables that hit their correction limit).
4. Short-circuit semantics mirror CC PreToolUse exit-2 closely enough that the Furrow docs copy will barely change.
5. Does not depend on a third-party extension (`pi-permission-system`) — one less supply-chain risk.

Keep `pi-permission-system` as a separate layer for *coarse* agent-wide rules (e.g., deny `bash: rm -rf *`) that aren't row-specific. The two compose cleanly since both hook `tool_call` sequentially.

**Source tier**: `extensions.md` + `runner.ts` synthesis — T1 for the API surface, T2 for the recommendation.

---

## Q-D3 — session_compact timing

Pi emits **two** compact-related events, not one. This is the key finding:

### `session_before_compact` — fires BEFORE compaction

> "Fired on compaction." (docstring — ambiguous)
> Location: `packages/coding-agent/src/core/agent-session.ts` around line 1,850 (in `compact()` method) and around line 2,050 (in `_runAutoCompaction()` method).

Event shape (**T1**, `packages/coding-agent/src/core/extensions/types.ts`):

```typescript
export interface SessionBeforeCompactEvent {
  type: "session_before_compact";
  preparation: CompactionPreparation;
  branchEntries: SessionEntry[];
  customInstructions?: string;
  signal: AbortSignal;
}
```

Handler return options (**T1**, `extensions.md`):

- `{ cancel: true }` — abort compaction entirely.
- Custom summary object with `compaction`, `summary`, `firstKeptEntryId`, `tokensBefore` — **extension supplies its own summary** in place of the LLM-generated one. This is the preservation point.

This is stronger than CC's post-compact hook: extensions can directly author the compacted summary, meaning Furrow can inject state recovery content into the preserved context rather than hoping a post-compact replay survives.

### `session_compact` — fires AFTER compaction

Location: same file, around line 1,900 (manual) and line 2,100 (auto). **T1**, `agent-session.ts` per gh code-search + WebFetch extraction.

Event shape (**T1**, `types.ts`):

```typescript
export interface SessionCompactEvent {
  type: "session_compact";
  compactionEntry: CompactionEntry;
  fromExtension: boolean;
}
```

No return value is processed — this event is informational/observational only. `fromExtension` tells you whether the preceding `session_before_compact` supplied the summary.

### Stdout contract

**Neither event has a "stdout re-injection" contract like CC's post-compact hook.** Pi extensions are in-process Node modules, not subprocesses — there is no stdout to capture. Instead, context injection happens via:

1. **`session_before_compact`**: return a `compaction` object with summary content — that text *is* the post-compaction context.
2. **`before_agent_start`**: return `{ message: "..." }` to inject a persistent message sent to the LLM, or `systemPrompt: "..."` to modify the prompt. **T1**: `extensions.md`. This is the mechanism for "re-inject context at next turn" semantics.

### Exact source file

- Emitter: `packages/coding-agent/src/core/agent-session.ts` — `compact()` method (manual) and `_runAutoCompaction()` method (auto-compaction). Both emit `session_before_compact` first, then `session_compact` after. **T1**: WebFetch extraction, line estimates ~1850/~1900 (manual) and ~2050/~2100 (auto-compact).
- Type defs: `packages/coding-agent/src/core/extensions/types.ts`. **T1**.
- Runner: `packages/coding-agent/src/core/extensions/runner.ts` — sequential, short-circuits on `{cancel: true}` for `session_before_*` events. **T1**.

### Verdict

**Furrow's post-compact replication is feasible — and arguably improved.** Map CC's PostCompact hook to Pi's `session_before_compact` (not `session_compact`): author the summary directly with state-recovery content woven in. Use `session_compact` only for logging/telemetry. Falling back to `before_agent_start` on session resume also works if `session_before_compact` hook isn't desired.

**Source tier**: T1 throughout — type defs read, emit-site locations confirmed by code-search + WebFetch.

---

## Q-D5 — RPC mode

### What it is

`pi --mode rpc` starts Pi in a JSONL request/response loop over stdin/stdout. Clients send JSON command objects (one per line, strict `\n` framing — "Node's built-in `readline` module is specifically called out as non-compliant because it treats Unicode separators as line breaks"), Pi replies with `{ type: "response", ... }` objects and streams events. **T1**: `packages/coding-agent/docs/rpc.md`.

Full command surface (**T1**, `docs/rpc.md`):

- Prompting: `prompt`, `steer`, `follow_up`, `abort`, `new_session`
- State: `get_state`, `get_messages`
- Model: `set_model`, `cycle_model`, `get_available_models`
- Thinking: `set_thinking_level`, `cycle_thinking_level`
- Queue modes: `set_steering_mode`, `set_follow_up_mode`
- Compaction: `compact`, `set_auto_compaction`
- Retry: `set_auto_retry`, `abort_retry`
- Bash: `bash`, `abort_bash`
- Session: `get_session_stats`, `export_html`, `switch_session`, `fork`, `clone`, `get_fork_messages`, `get_last_assistant_text`, `set_session_name`
- Commands: `get_commands`

### Extension loading in RPC mode

**Yes — extensions load in RPC mode by default**, but with degraded UI affordances. **T1**: `docs/rpc.md` explicitly describes an "extension UI sub-protocol" where dialog methods (`select`, `confirm`, `input`, `editor`) emit `extension_ui_request` events on stdout and block until the client sends `extension_ui_response`; fire-and-forget methods (`notify`, `setStatus`, `setWidget`, `setTitle`) also emit requests but don't wait for replies.

Degraded in RPC mode (**T1**, `docs/rpc.md`):

- `custom()` returns `undefined`
- `setWorkingMessage()`, `setWorkingIndicator()`, `setFooter()`, `setHeader()`, `setEditorComponent()`, `setToolsExpanded()` → no-ops
- `getEditorText()` returns `""`
- `getToolsExpanded()` returns `false`

Disabling extensions in RPC mode (**T1**, `src/cli/args.ts`):

- `--no-extensions, -ne` — "Disable extension discovery (explicit -e paths still work)"
- `--extension, -e <path>` — load specific extension
- `--no-skills, -ns` — disable skills
- `--no-context-files, -nc` — disable AGENTS.md/CLAUDE.md loading
- `--no-prompt-templates, -np` — disable templates

**There is no `--bare` flag in Pi.** That is a Claude Code concept. The Pi equivalent (minimal load, no persistent session) is `pi -p --no-session --no-extensions --no-skills --no-context-files`. **T1**: gh code-search for `--bare` returned zero hits in pi-mono; `--no-session`, `--no-extensions`, `--no-skills`, `--no-context-files` all confirmed in `cli/args.ts`.

### Hook firing in RPC mode

**UNVERIFIED for `tool_call`, `session_start`, `session_compact` specifically.** The `docs/rpc.md` file describes extension UI context behavior in RPC mode but does not enumerate which lifecycle hooks fire. However, multiple indirect signals suggest hooks do fire:

1. The extension UI sub-protocol is described as operating "on top of the base command/event stream" — implying the normal event stream flows in RPC mode, just with a specific UI response channel overlaid.
2. `types.ts` notes that UI context is "false in print/RPC mode" for availability, but handlers themselves are not declared inoperative.
3. `session_start` is emitted on session creation/reload regardless of mode (it's emitted inside `AgentSession` which is the same class RPC mode instantiates). **T2** — inferred, not verified by running the code.
4. The pi-subagents extension registers `session_start`, `tool_execution_start`, `session_shutdown` handlers and is expected to work in programmatic contexts. **T2** — inferred from extension's design.

**Recommendation for Furrow**: assume hooks fire in RPC mode, but confirm with a one-line experiment (`pi --mode rpc -e ./test-ext.js` where the test extension logs every hook it receives) before committing the migration.

### Stability

**No explicit stability guarantee.** **T1**: `docs/rpc.md` makes no protocol-version or compatibility statement. The pi-mono repo root README + coding-agent README also make no API stability promises. **T1**: coding-agent README synthesis.

This is a real risk: Pi is pre-1.0 in spirit (even if npm version number is higher) and Mario Zechner iterates fast (see CHANGELOG size: `packages/coding-agent/CHANGELOG.md` is 326,927 bytes — a lot of churn). **T1**: gh contents API reports CHANGELOG size.

### Verdict

**Usable for `frw cross-model-review`-equivalent: yes, partial.** Replace `claude -p --bare` with either:

- **Option A (shell subprocess)**: `pi -p --no-session --no-extensions --no-skills --no-context-files --model <cross-model> --system-prompt <review-prompt>` piped stdin. Preserves Furrow's current shell-script shape. **T1** — all flags confirmed in `args.ts`.
- **Option B (SDK in-process)**: import `createAgentSession` from `@mariozechner/pi-coding-agent` and run a one-shot review session. Lower latency but couples Furrow's shell scripts to Node. **T1** — `docs/sdk.md` confirms `createAgentSession` is the programmatic entry.
- **Option C (RPC mode)**: overkill for a one-shot review (RPC is for long-lived programmatic clients).

Prefer Option A for minimum migration churn.

**Source tier**: T1 for all CLI flags and RPC commands; T2 for hook-firing inference; T1 for stability silence.

---

## Q-D6 — Registry reliability

### Current status

**Down or degraded as of 2026-04-22.** `https://pi.dev/packages` displays the page header ("browsing extensions, skills, themes, and prompts") but shows **"Couldn't reach the npm registry."** with a Retry button. No packages load. **T1**: WebFetch of `https://pi.dev/packages` on research date.

`https://pi.dev` root loads normally — describes Pi as "a minimal terminal coding harness", lists providers, links to `/packages`. **T1**: WebFetch of `https://pi.dev`.

### Backend

**The `pi.dev/packages` gallery is a thin client over the public npm registry.** It browses packages tagged `pi-package` on npm. The install path (`pi install npm:<pkg>`) also goes direct to npm, not through pi.dev. Per `docs/packages.md`:

> "The [package gallery](https://pi.dev/packages) displays packages tagged with `pi-package`. This is purely for browsing and sharing packages."
> "Global installs use `npm install -g`" — customizable via the `npmCommand` setting.

**T1**: `packages/coding-agent/docs/packages.md`.

This means the gallery site being down does **not** block `pi install`. The install path runs local `npm` against npm's registry directly.

### Direct-npm fallback

**Yes — native, not a fallback.** `pi install npm:<pkg>` invokes `npm install` under the hood. No dependency on pi.dev. **T1**: `docs/packages.md`.

### Offline mode

**Not documented for `pi install`.** There is a `--offline` CLI flag on `pi` itself: "Disable startup network operations." **T1**: `src/cli/args.ts`. This gates *Pi's* network calls at launch (e.g., model-list refresh), not npm install.

`pi install` depends on `npm`, which has its own `--offline` / cache-first semantics — you could work around with `npm_config_offline=true pi install npm:...` but this is **UNVERIFIED** as tested with Pi's invocation shape.

### Recent outages

**No open or recent issues about `pi.dev/packages` outages on GitHub.** Checked `github.com/badlogic/pi-mono/issues?q=registry` — recent open issues are about provider configs, model selection, extension tool overrides, Bedrock credentials, settings lock deadlock, OpenRouter rankings. Nothing registry-related. **T1**: WebFetch of issues page.

Possible explanations: (a) registry went down very recently (after the last issue cutoff); (b) users hit the broken gallery, shrug, use `npm search pi-package` directly; (c) outage is transient and resolves without issue traffic.

**UNVERIFIED**: Twitter/X handles (`badlogicgames`, `Can Bölük`/Bölük) — web search not performed in this pass.

### Install-script guidance

For Furrow's install script:

1. **Do not depend on `pi.dev` being reachable.** Always use `pi install npm:<pkg>` (or `npm install -g <pkg>`) which bypasses the gallery.
2. **Pin versions** (e.g., `pi install npm:@tintinweb/pi-subagents@x.y.z`) — pi-mono has heavy CHANGELOG churn (see Q-D5), and `@tintinweb/pi-subagents` + `MasuRii/pi-permission-system` are single-maintainer extensions with their own release cadence. **T2** — CHANGELOG size observation.
3. **Add a preflight check**: `pi --version` + `pi -p --no-session "echo alive"` (or just `pi --version`) to verify Pi is installed and runnable before doing extension installs. No pi.dev probe.
4. **Offline install path**: document that users can `npm pack @tintinweb/pi-subagents` on a network-connected machine and copy the tarball, then `pi install npm:/path/to/tarball.tgz` on the target. **UNVERIFIED** — tarball-path syntax not confirmed in `docs/packages.md`.
5. **Graceful degradation**: if extension install fails (registry unreachable, version yanked), fall back to core Pi without the extension and surface a one-line warning. Furrow's core (state-guard, checkpoints, reviews) should function without subagent dispatch.

**Source tier**: T1 for all install-path claims; T2 for the install-script recommendations.

---

## Sources Consulted (tiered)

### T1 — primary

- `https://github.com/badlogic/pi-mono` (repo root)
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/extensions.md` — full hook catalog, return shapes
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/compaction.md` — compaction lifecycle
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/rpc.md` — RPC command surface, extension UI sub-protocol
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/sdk.md` — `createAgentSession`, DefaultResourceLoader
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/docs/packages.md` — install semantics
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/cli/args.ts` — full flag list
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/core/agent-session.ts` — compact event emission sites (~lines 1850/1900/2050/2100)
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/core/extensions/types.ts` — event type definitions
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/core/extensions/runner.ts` — sequential execution, short-circuit semantics
- `https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/README.md` — user-facing CLI usage
- `https://raw.githubusercontent.com/tintinweb/pi-subagents/master/README.md` — extension contract, frontmatter fields, worktree semantics
- `https://raw.githubusercontent.com/tintinweb/pi-subagents/master/src/agent-runner.ts` — same-process execution via `createAgentSession`
- `https://raw.githubusercontent.com/tintinweb/pi-subagents/master/src/worktree.ts` — git worktree isolation implementation
- `https://raw.githubusercontent.com/tintinweb/pi-subagents/master/src/index.ts` — extension entry point, hook registrations
- `https://github.com/MasuRii/pi-permission-system` — declarative permission rules, last-match-wins wildcards
- `https://pi.dev/packages` — gallery state on research date (npm-registry-unreachable error)
- `https://pi.dev` — site copy, package install story
- `https://github.com/badlogic/pi-mono/issues?q=registry` — no registry outage issues
- `gh api repos/tintinweb/pi-subagents/contents/src` — file listing
- `gh api repos/badlogic/pi-mono/contents/packages/coding-agent/docs` — doc listing

### T2 — synthesis

- Process-model conclusion (same-process, in-memory) for pi-subagents: inference from `agent-runner.ts` imports + `SessionManager.inMemory` usage, not from an explicit architectural doc.
- RPC-mode hook-firing assumption: inferred from extension UI sub-protocol being built "on top of" the base event stream, plus `AgentSession` being the shared runtime class.
- Install-script recommendations (pinning, preflight, offline tarball path): synthesis of CHANGELOG churn + packages.md direct-npm model.
- Model-visible block message quality for Option 1 (`tool_call`): inferred from `{ reason?: string }` type signature + sequential short-circuit but not verified by running the hook.

### T3 — snippet-only

- pi-mono issue #3553 ("Extension tools overriding built-in tools") — title-only, body not read. Referenced to note that tool-shadowing via `pi.registerTool` is a known area.
- `docs/compaction.md` line number estimates (1850/1900/2050/2100) for emit sites — WebFetch returned approximate positions, not exact line numbers from raw file inspection.
- Twitter/X outage reports for `pi.dev/packages` — not searched this pass. If registry reliability becomes a Furrow-install blocker, a secondary sweep of `badlogicgames` posts would be warranted.
