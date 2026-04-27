# Subagent Semantics Verification (T2)

## Verdict Summary

- **Assumption A** (named-subagent persistence within session): **VERIFIED (with caveats)**
- **Assumption B** (PreToolUse hook inheritance): **VERIFIED**
- **Overall**: **GO** — with two caveats the project must absorb into the design:
  1. `SendMessage` requires the experimental flag `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
  2. Hooks identify the subagent via the JSON field **`agent_type`** (and `agent_id`), **not** an env var, and **not** a field literally named `agent_name`. The project's hook-side lookup must read JSON-on-stdin, not `$CLAUDE_AGENT_NAME`.

## Findings

### Q1 — Named-subagent persistence

**Verified.** Subagents spawned via the Agent tool retain their full conversation history and can be re-engaged within the same session. Direct quote from the subagents docs:

> "Each subagent invocation creates a new instance with fresh context. To continue an existing subagent's work instead of starting over, ask Claude to resume it. Resumed subagents retain their full conversation history, including all previous tool calls, results, and reasoning. The subagent picks up exactly where it stopped rather than starting fresh."
>
> "When a subagent completes, Claude receives its agent ID. Claude uses the `SendMessage` tool with the agent's ID as the `to` field to resume it."
> — `code.claude.com/docs/en/sub-agents`, "Resume subagents"

The primitive backing persistence is the **agent transcript file** at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`. Each `SendMessage` to a stopped subagent **auto-resumes it in the background without a new `Agent` invocation**:

> "If a stopped subagent receives a `SendMessage`, it auto-resumes in the background without requiring a new `Agent` invocation."

**Caveat — experimental flag required.** `SendMessage` is only available when agent teams are enabled:

> "The `SendMessage` tool is only available when [agent teams](/en/agent-teams) are enabled via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`."

So Furrow's `drivers.json` design is sound only on a host that has flipped this experimental flag. If the flag is not set, the only way to "re-engage" a subagent is through Claude's natural-language continuation ("Continue that code review and now…"), which is not a programmatic handle and is unsuitable for an orchestration contract.

### Q2 — Reconnection by name

**Verified, with a vocabulary correction.** The addressable handle is `agent_id` (a string like `subagent_123`), not the human-readable `name`/`agent_type`. From the agent-teams docs:

> "The lead assigns every teammate a name when it spawns them, and any teammate can message any other by that name. To get predictable names you can reference in later prompts, tell the lead what to call each teammate in your spawn instruction."
> — `code.claude.com/docs/en/agent-teams`, "Context and communication"

> "The team config contains a `members` array with each teammate's name, agent ID, and agent type. Teammates can read this file to discover other team members."

So in practice: the **lead can assign a stable name at spawn time** ("call this teammate `driver:research`"), and the team config (`~/.claude/teams/{team-name}/config.json`) maps name → agent_id. Furrow's `drivers.json` should mirror this pattern — store the spawn-time name **and** the returned `agent_id`, and address subsequent `SendMessage` calls by `agent_id` since that is the field `SendMessage` consumes (`to: <agent_id>`).

Note the **session-resume hazard** (from agent-teams "Limitations"):

> "**No session resumption with in-process teammates**: `/resume` and `/rewind` do not restore in-process teammates. After resuming a session, the lead may attempt to message teammates that no longer exist."

This means a long-lived row that spans `/resume` cycles cannot reliably re-attach to its phase drivers — the `drivers.json` registry must treat `agent_id` as ephemeral-per-CLI-invocation and be ready to **re-spawn** drivers on session resume.

### Q3 — Hook inheritance

**Verified.** Subagent tool calls fire the same `PreToolUse` / `PostToolUse` hooks as the parent. From the hooks docs:

> "When running with `--agent` or inside a subagent, two additional fields are included" in the JSON input to hooks.

> "For subagents, `Stop` hooks are automatically converted to `SubagentStop` since that is the event that fires when a subagent completes."

Plus a dedicated `SubagentStart` hook fires when a subagent is spawned. There is **no** separate `SubagentPreToolUse` event — the same `PreToolUse` matcher fires for both contexts, with extra fields telling the hook it is running inside a subagent.

**Implication**: `bin/frw.d/hooks/layer-guard.sh` configured as a `PreToolUse` hook in user/project `settings.json` will fire on tool calls made by any spawned driver. No new hook plumbing is needed.

### Q4 — Agent identity in hooks

**The mechanism is JSON-on-stdin, not env vars.** From the hooks docs:

> "When running with `--agent` or inside a subagent, two additional fields are included" in the JSON input:
>
> - `agent_id`: Unique identifier for the subagent. Present only when the hook fires inside a subagent call.
> - `agent_type`: Agent name (for example, `"Explore"` or `"security-reviewer"`).

Example payload:
```json
{
  "session_id": "abc123",
  "hook_event_name": "PreToolUse",
  "tool_name": "Bash",
  "tool_input": { "command": "npm test" },
  "agent_id": "subagent_123",
  "agent_type": "security-reviewer"
}
```

Other env vars available to hook scripts (for completeness): `$CLAUDE_PROJECT_DIR`, `$CLAUDE_PLUGIN_ROOT`, `$CLAUDE_PLUGIN_DATA`, `$CLAUDE_ENV_FILE`. **There is no `$CLAUDE_AGENT_NAME` env var.**

**Action for D2/D3**: `layer-guard.sh` must read stdin JSON and extract `.agent_type` (the human-readable name like `driver:research`) for the per-agent layer-context lookup. Pseudocode:

```sh
input="$(cat)"
agent_type="$(echo "$input" | jq -r '.agent_type // "main"')"
ctx_file=".furrow/.layer-context.${agent_type}"
```

The convention for `agent_type` is whatever string is registered in the subagent's frontmatter `name:` field (or for the main thread, the field is absent — so `// "main"` fallback is needed).

### Q5 — Compaction interaction

**Subagents survive parent compaction.** From the docs:

> "Subagent transcripts persist independently of the main conversation:
> - **Main conversation compaction**: When the main conversation compacts, subagent transcripts are unaffected. They're stored in separate files.
> - **Session persistence**: Subagent transcripts persist within their session. You can resume a subagent after restarting Claude Code by resuming the same session."

Subagents themselves auto-compact at ~95% (configurable via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`). Compaction events are logged in the agent transcript with `subtype: "compact_boundary"`.

**Implication**: The orchestrator's compaction event does **not** kill drivers. However, a driver's own internal compaction can drop early instructions — Furrow should ensure the layer-context contract is **re-asserted** in driver prompts on each `SendMessage`, not assumed to be remembered from spawn time.

### Q6 — Concurrency limits

**No documented hard limit on concurrent subagents per session.** The agent-teams "Choose an appropriate team size" section states:

> "There's no hard limit on the number of teammates, but practical constraints apply: token costs scale linearly… coordination overhead increases… diminishing returns. Start with 3-5 teammates for most workflows."

Subagents themselves have a soft warning:

> "When subagents complete, their results return to your main conversation. Running many subagents that each return detailed results can consume significant context."

For Furrow's seven phase drivers (`ideate`, `research`, `plan`, `spec`, `decompose`, `implement`, `review`) — only one or two are typically live at a time per row, so the documented "3-5" guidance is comfortably satisfied.

### Q7 — Pi parity

Out of scope and not addressed by these primary docs. Local `adapters/pi/furrow.ts` was not inspected because the user marked Q7 skip-if-not-mentioned, and Anthropic's docs do not discuss Pi. **[unverified — recommend a follow-up audit on the Pi adapter side]**

## Implications for D2 / D3

1. **`drivers.json` design holds** — the registry concept (mapping driver-name → handle) maps directly onto the agent-teams `members` array. Store both the spawn-time `name` and the runtime `agent_id`; address `SendMessage` calls by `agent_id`.

2. **Add an experimental-flag preflight.** `bin/frw doctor` (or row-spawn time) should verify `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` is set. Without it, `SendMessage` is unavailable and the orchestration contract degrades to in-prompt continuation. This is a **definition.yaml prerequisite** that must land before spec.

3. **`layer-guard.sh` enforcement mechanism is sound** — drop the env-var approach and code it against stdin JSON. Read `.agent_type`, not `$CLAUDE_AGENT_NAME`. The matcher must be `PreToolUse` (not a hypothetical `SubagentPreToolUse`).

4. **Layer-context filename convention**: `.furrow/.layer-context.${agent_type}` works, with a `main` fallback for hook calls outside a subagent. Validate `agent_type` against the allowlist of registered drivers in `drivers.json` to prevent path injection.

5. **Add a session-resume recovery path.** Because `/resume` does not restore in-process teammates, Furrow must detect "lead resumed but `drivers.json` references stale agent_ids" and **re-spawn** affected drivers, replaying any pending phase work. This is a new acceptance criterion.

6. **Re-assert layer-context on every SendMessage.** Driver internal auto-compaction can drop spawn-time instructions. The orchestrator should prepend a one-line reminder ("Layer: research-driver. See `.furrow/.layer-context.driver:research`.") to every `SendMessage` body.

7. **Hook event for spawn lifecycle**: register `SubagentStart` to write `.furrow/.layer-context.{agent_type}` on spawn, and `SubagentStop` to either remove it or mark the driver complete in `drivers.json`. This pairs cleanly with the `PreToolUse` enforcement.

## Sources Consulted

- **`code.claude.com/docs/en/sub-agents`** — primary — definitive source for subagent persistence (`SendMessage`, transcript storage at `~/.claude/projects/{project}/{sessionId}/subagents/`, compaction independence). Confirmed Assumption A.
- **`code.claude.com/docs/en/hooks`** (via WebFetch summary) — primary — confirmed `PreToolUse` fires for subagent tool calls; documented `agent_id` / `agent_type` JSON fields, `SubagentStart` / `SubagentStop` events, and absence of an `$CLAUDE_AGENT_NAME` env var. Confirmed Assumption B.
- **`code.claude.com/docs/en/agent-teams`** — primary — surfaced the `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` requirement, team-config storage layout (`~/.claude/teams/{team-name}/config.json` with `members` array), session-resume hazard, soft concurrency guidance.
- **Local `bin/frw.d/hooks/state-guard.sh`** — secondary — confirmed the project's existing hook idiom (read JSON on stdin via `jq`, return 2 to block). The proposed `layer-guard.sh` should follow the same pattern, with the addition of `agent_type` extraction.
- **Local `git log --all --oneline | head -50`** — tertiary — no prior commits surface "subagent" or "hook" learnings relevant to this question; recent work is on validation and pre-write hooks against the main thread, not subagents.
- **`docs.anthropic.com/en/docs/claude-code/sdk/sdk-overview`** — not fetched — the live docs at code.claude.com superseded this for current behavior; the SDK overview was not needed once primary subagent + hooks docs answered the questions directly. **[unverified that SDK overview adds nothing — flag for follow-up if SDK-driven orchestration is contemplated]**
