# R4 — goose Deep Dive

*Research conducted 2026-04-22. All citations reflect state as of that date.*

## Summary

- **goose is a Rust-core agent** (49.8% Rust, 44.1% TypeScript for UI) with a CLI, desktop app, and embeddable server. It was donated by Block to the **Agentic AI Foundation (AAIF) at the Linux Foundation in November 2025**; the canonical repo is now `aaif-goose/goose`. Latest stable: **v1.31.1 (2026-04-20)**. License Apache-2.0. (T1: github.com/block/goose README; T2: arcade.dev blog)
- **Extension model is MCP-first.** Six extension types (`stdio`, `builtin`, `streamable_http`, `platform`, `frontend`, `inline_python`) — but only `platform` and `builtin` are in-process Rust code compiled into goose; everything else is an MCP server. There is **no Node/TS/shell extension host** analogous to Claude Code's hook subprocesses. (T1: DeepWiki extension-types, T1: GitHub discussion #7675)
- **Recipes + custom slash commands** are the closest analog to Claude Code slash commands: a YAML (or JSON for top-level) file with `instructions`, `prompt`, `parameters`, `extensions`, `response` (json_schema), `retry`, plus a `slash_commands:` map in `config.yaml` that binds `/name` → recipe path. (T1: goose-docs.ai recipes guide, config-files guide)
- **No PreToolUse/PostToolUse/Stop/SessionStart/PostCompact hook surface exists in goose.** Permission gating is done via `GOOSE_MODE` (auto/approve/chat/smart_approve) and per-tool records in `permissions/tool_permissions.json`, not user-defined hook scripts. This is the **single biggest portability gap** for Furrow. (T1: goose-docs.ai config-files; T2: agent-safehouse sandbox analysis; **UNVERIFIED** that no private/experimental hook API exists — requires source read T4)
- **Skills are supported** (inspired by Claude skills) and loaded from `~/.claude/skills`, `~/.config/goose/skills`, and `.goose/skills/` — this covers most of Furrow's "context injection" need without writing an extension. (T1: GitHub discussion #5761)
- **Subagents + subrecipes** give parallel, isolated dispatch with up to **10 concurrent workers**, 5-minute default timeout, summary-or-full return modes. (T1: goose-docs.ai subagents guide; T2: subagents-vs-subrecipes blog)

## Per-surface findings

### 1. Slash commands — **Supported via recipes + `slash_commands:` config**

- **Supported?** Yes.
- **Mechanism:** User authors a recipe YAML (version, title, instructions, prompt, parameters, extensions, response, retry). Then in `~/.config/goose/config.yaml` (or `%APPDATA%\Block\goose\config\config.yaml` on Windows), a `slash_commands:` list maps command names to recipe paths:
  ```yaml
  slash_commands:
    - command: "run-tests"
      recipe_path: "/path/to/recipe.yaml"
  ```
- **Invocation:** `/run-tests` in the Desktop GUI or REPL launches the recipe. Parameters surface as a dialog in Desktop; CLI takes `--params key=value`.
- **Tier / Citation:** T1 — https://goose-docs.ai/docs/guides/config-files/ (config schema); T1 — https://goose-docs.ai/docs/guides/recipes/ (invocation); T2 — https://www.nickyt.co/blog/what-makes-goose-different-from-other-ai-coding-agents-2edc/
- **Gap vs Furrow:** No Markdown-with-frontmatter form. Recipes are YAML-heavy and declarative; Claude Code `.claude/commands/*.md` files map 1:1 to a single user message injection, whereas goose recipes define the entire session contract (instructions, extensions, parameters, structured output). Porting a Furrow command means rewriting it as a recipe, not just dropping a markdown file in a directory.

### 2. Hook events / Lifecycle API — **NOT SUPPORTED (blocking gap)**

- **Supported?** No — no user-authored hook subprocesses fire on PreToolUse / PostToolUse / Stop / SessionStart / PostCompact.
- **Mechanism available instead:**
  - `GOOSE_MODE=approve` prompts the user before every tool call (interactive only; no script gate).
  - `GOOSE_MODE=smart_approve` uses an LLM classifier to decide approvals.
  - `permission.yaml` + `permissions/tool_permissions.json` store per-tool always-allow / always-deny decisions.
  - Platform extensions (in-process Rust) have privileged access to internal APIs and could theoretically intercept tool dispatch — but that requires writing Rust and recompiling goose, not dropping in a script.
- **Tier / Citation:** T1 — https://goose-docs.ai/docs/guides/config-files/ (GOOSE_MODE); T2 — https://agent-safehouse.dev/docs/agent-investigations/goose (permission file locations); **search for hook events returned only Claude Code results — T1 negative result, T4 confirmation needed from source read**
- **Gap vs Furrow:** Furrow depends on PreToolUse hooks for state-guard (block direct state.json edits), correction-limit enforcement, and Stop hook for session cleanup. None of these has a goose equivalent that doesn't require Rust code. This is the load-bearing capability gap.

### 3. Subagent dispatch — **Supported (subagents + subrecipes)**

- **Supported?** Yes, two flavors.
- **Mechanism:**
  - **Subagents**: one-off, natural-language-spawned agents. Inherit parent context + extensions by default, but run with "restricted tool access" (cannot spawn nested subagents, manage extensions, or modify scheduled tasks). Return modes: *Full Details* (all tool calls + reasoning) or *Summary Only*.
  - **Subrecipes**: pre-authored YAML recipes invoked as subagents. Support typed parameters, can specify a different provider/model per subrecipe, can define their own extension set.
  - **Parallel**: triggered by keywords like "parallel" or "concurrently"; hard cap of **10 concurrent workers** (not user-configurable). Sequential is default.
  - **Timeout**: 5 minutes default; timed-out subagents return no output.
- **Tier / Citation:** T1 — https://goose-docs.ai/docs/guides/subagents/; T2 — https://block.github.io/goose/blog/2025/09/26/subagents-vs-subrecipes/; T2 — https://www.nickyt.co/blog/advent-of-ai-day-11-goose-subagents-2n2/
- **Gap vs Furrow:** Dispatch is **LLM-mediated via natural language**, not a programmatic API. There is no `dispatch_subagent(prompt, tools, timeout) -> result` function call available to extension code — you ask the agent to "run these three tasks in parallel" in prose. For Furrow's review/specialist delegation this is workable at chat level, but cannot be wired into a hook or CLI command without round-tripping through the LLM.

### 4. Context injection — **Supported via Skills + `.goosehints` + Memory extension**

- **Supported?** Yes, multiple mechanisms.
- **Mechanisms:**
  - **Skills** (platform extension, on by default): markdown files with YAML frontmatter. Only the frontmatter stays in context; the body is loaded on-demand when the description matches. Searched in `~/.claude/skills/`, `~/.config/goose/skills/`, and `.goose/skills/` (project-local).
  - **`.goosehints`**: static file loaded with every request — the Claude.md equivalent. (A blog post warns against stuffing too much here.)
  - **Memory extension**: dynamic, append/read. Stored in `~/.goose/memory` (local) or `~/.config/goose/memory` (global).
  - **Recipe `instructions` + `prompt` fields**: injected at session start when the recipe is invoked.
- **Tier / Citation:** T1 — https://github.com/aaif-goose/goose/discussions/5761 (skills design); T2 — https://block.github.io/goose/blog/2025/06/05/whats-in-my-goosehints-file/; T1 — goose-docs recipes guide (instructions field).
- **Gap vs Furrow:** No explicit lifecycle-event injection (PostCompact, SessionStart) — injection points are limited to session start (hints + recipe) or on-demand (skill, memory, MCP sampling). Furrow's "inject skill at step transition" pattern would have to be implemented as: recipe-per-step with a different `instructions` field, or as a custom MCP server that exposes context as a tool the agent is told to call.

### 5. Multi-provider — **Supported (30+ providers, runtime-swappable)**

- **Supported?** Yes — goose is explicitly designed around provider abstraction.
- **Mechanism:** Trait-based provider abstraction in Rust. Provider selected via `GOOSE_PROVIDER` env var (or `config.yaml`). Precedence: env > config > defaults. Secrets in system keyring (`keyring` crate → macOS Keychain / Win Credential Manager / Linux Secret Service) with `secrets.yaml` fallback.
- **Providers (T1 DeepWiki list):** Anthropic, OpenAI, Google Gemini, Azure, Databricks, Ollama, LM Studio, LocalAI, Bedrock, SageMaker, Snowflake, Cursor Agent, OpenRouter, LiteLLM, Venice, Copilot (via ACP), and more. The README claims "15+"; DeepWiki lists "30+"; the discrepancy likely reflects which are first-class vs. community-contributed.
- **Runtime swap:** Yes — change env var or config and restart; multi-model (different models per task) is supported within a single session via subrecipes that declare their own `settings.provider`/`settings.model`.
- **Tier / Citation:** T1 — https://goose-docs.ai/docs/guides/config-files/; T2 — https://deepwiki.com/block/goose/2.2-provider-configuration; T1 — github.com/aaif-goose/goose README.
- **Gap vs Furrow:** None significant. This is a goose strength.

### 6. MCP — **First-class / reference implementation**

- **Supported?** Yes — goose's extension system *is* MCP. Block was MCP's most prominent early adopter; goose often lands new MCP features first as the reference client.
- **Spec version:** As of July 2025 goose was compliant with the March 2025 MCP spec but not the June 2025 revision. The spec released 2025-11-25 adds protocol-native background tasks (FastMCP 2.14 began adopting it). Current compliance level in v1.31.x is **UNVERIFIED** — requires checking the `goose-mcp` crate or release notes (T4).
- **Mechanism:** `goose-mcp` crate implements the MCP client trait. `stdio`, `streamable_http`, and `sse` transports supported. **MCP Sampling** is supported: MCP servers can request LLM completions from goose, enabling "intelligent extensions."
- **Tier / Citation:** T1 — github.com/aaif-goose/goose README ("70+ extensions via MCP"); T1 — https://block.github.io/goose/docs/guides/mcp-sampling/; T2 — https://www.arcade.dev/blog/goose-the-open-source-agent-that-shaped-mcp; T2 — https://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/
- **Gap vs Furrow:** None — Furrow's existing MCP integrations (serena, context7) will work without modification.

### 7. Tool-use metadata to hooks — **NOT SUPPORTED as a user-facing API**

- **Supported?** No user-facing pre-execution metadata callback exists.
- **Mechanism available instead:** Permission gating sees tool name + arguments but only via the **user approval dialog** (interactive) or the LLM-based `smart_approve` classifier. No scriptable pre-exec interception path has been documented.
- **Tier / Citation:** T1 negative (docs survey); T4 — requires reading `crates/goose/src/agents/` dispatch code to confirm no plugin point exists.
- **Gap vs Furrow:** Furrow's correction-limit hook and state-guard hook both need to see `(tool_name, tool_args)` pre-exec and return allow/deny. Without a hook surface this would have to be re-implemented as a wrapping platform extension written in Rust that intercepts dispatch — a major engineering lift.

### 8. System prompt overhead

- **Info:** The default `developer` built-in extension auto-loads. `GOOSE_CONTEXT_LIMIT` defaults to 128k tokens. Specific token count for the base system prompt is **unknown — requires experimentation (T4)**. `available_tools` per extension lets you trim tool schemas to reduce overhead (T1 — config-files guide). `GOOSE_SHOW_FULL_OUTPUT` toggles truncation of tool output (v1.30.0).
- **Tier / Citation:** T1 — goose-docs config-files; T4 — exact token count unverified.

### 9. Packaging / distribution

- **Extension sharing:** Two distribution channels. (a) **MCP server** — anything in the MCP ecosystem (70+ listed in the goose extensions directory) installs via `goose://extension` deep-link or by editing config.yaml. (b) **Recipes** — shareable YAML files; goose has a Recipe Cookbook and Recipe Generator tool for producing shareable URLs. There is also a **Hacktoberfest 2025 goose Recipes Hub** (issue #4755) for community recipes.
- **Security:** Deep-link install restricted to an allowlist of binaries (`npx`, `uvx`, `docker`, `goosed`). External extensions automatically scanned for known malware before activation.
- **Custom distros:** `CUSTOM_DISTROS.md` allows building branded goose distributions with preconfigured providers/extensions.
- **Tier / Citation:** T1 — github README; T1 — DeepWiki extension-types; T2 — agent-safehouse.

### 10. Stability + version + cadence

- **Current version:** v1.31.1 (2026-04-20) per GitHub releases.
- **Cadence:** Roughly monthly minor releases (v1.27 2026-03-05 → v1.28 2026-03-18 → v1.29 2026-03-31 → v1.30 2026-04-08 → v1.31 2026-04-17), weekly-ish patch releases.
- **Breaking changes:** Not explicitly called out in release notes reviewed; architectural shifts are migrating built-in extensions to the platform-extension pattern (see GitHub discussion #7675).
- **Tier / Citation:** T1 — https://github.com/aaif-goose/goose/releases.

### 11. License + community signals

- **License:** Apache-2.0.
- **Governance:** Donated to AAIF (Linux Foundation) in Nov 2025. `GOVERNANCE.md` in repo.
- **Community:** ~29K GitHub stars (T2 Effloow), active Discord, YouTube, monthly releases, Hacktoberfest-level community engagement.
- **Tier / Citation:** T1 — github README; T2 — https://effloow.com/articles/goose-open-source-ai-agent-review-2026.

## Extension-model note — how Furrow would map

Goose's extension model splits into two disjoint populations, and **the split is exactly where Furrow's portability pain lives**:

### Native (in-process Rust) — `platform` and `builtin` extension types

- Compiled into the goose binary. Written in **Rust**, against goose's internal trait APIs (`McpClientTrait`, `PlatformExtensionContext`).
- These get privileged access: can see tool dispatch, modify session state, inject context at any point. Skills, subagents, recipes, memory are all platform extensions.
- **This is where Furrow's hooks would have to live** if they needed pre-tool-exec gating — but:
  - Requires Rust (Furrow is shell-heavy, TypeScript-hopeful).
  - Requires forking/rebuilding goose, or upstreaming a PR to add generic hook dispatch.
  - There is no stable ABI for out-of-process plugins at this layer.

### MCP-based (out-of-process) — `stdio`, `streamable_http`, `sse`, `frontend`, `inline_python`

- Any language that can speak MCP over stdio/HTTP. Python/Node dominant (FastMCP is the idiomatic toolkit).
- Configured declaratively in `config.yaml` under `extensions:`.
- **This is where Furrow's MCP integrations, skill loaders, and custom tool servers fit cleanly** — it's a 1:1 port from Claude Code MCP usage.
- Limitations: MCP servers expose *tools*, not *hooks*. They cannot gate other tools, observe the agent loop, or run on lifecycle events. `inline_python` lets a recipe embed Python via `uvx`, but it's invoked by the agent as a tool — not a pre-exec callback.

### The awkward middle — what doesn't map

Three Furrow capabilities fall into neither bucket cleanly:

1. **PreToolUse gating (state-guard, correction-limit)** — MCP can't do it (wrong abstraction); native-Rust would require compiling into goose. **Workaround:** require `GOOSE_MODE=approve` and delegate gating to the interactive approval dialog, which a human (or automation wrapper around the CLI) handles. Loses the deterministic programmatic guarantee Furrow relies on.

2. **Stop-hook (session cleanup, checkpoint-on-exit)** — no equivalent; the closest is recipe `retry.on_failure.cleanup_command`, but that only fires on retry-loop failure, not session end. Could be approximated by a recipe that ends with an explicit "run cleanup" step in `instructions`, but it's prose-level, not guaranteed.

3. **SessionStart / PostCompact context re-injection** — skills + `.goosehints` cover initial load. There is **no documented mechanism to re-inject context after compaction**. Auto-compaction summarizes in-place; a skill could be re-pulled on demand if the agent re-reads its frontmatter, but this is emergent behavior, not a guarantee.

**Bottom line for Furrow:** roughly 60% of the host surface ports cleanly (MCP tools, recipes-as-slash-commands, skills-as-context, subagent dispatch, multi-provider). The remaining ~40% — all the deterministic harness-enforcement hooks — has **no first-class solution in goose today** and would require either (a) a Rust plugin upstream to goose that adds a generic hook-dispatch trait, (b) an external wrapping process that sits between the user and `goose` CLI intercepting commands, or (c) accepting that goose-hosted Furrow is "advisory" rather than "enforced." Given user feedback `feedback_deep_not_optional.md` and `feedback_hard_block_over_autocorrect.md`, option (c) conflicts with stated product values.

## Open questions

1. **Is there an unlisted hook API in the Rust source?** The `crates/goose/` or `crates/goose-cli/` source may expose an internal trait that could be wired to an external process. Requires `git clone && grep -r 'hook\|intercept\|pre_tool' crates/`. (T4)
2. **Does the ACP (Agent Client Protocol) provide tool-use pre-exec metadata to the client?** goose ACP could conceivably let an external ACP client observe+gate tools. Discussion #7309 mentions ACP; implementation status unclear. (T4)
3. **Exact MCP spec version in v1.31.x.** July 2025 status was March-spec-compliant; the November-25 2025 spec adds background tasks. (T4, check CHANGELOG or `Cargo.toml` of `goose-mcp`)
4. **Can inline_python extensions observe other tools' calls?** Unlikely given MCP semantics, but worth verifying. (T4)
5. **Does `GOOSE_MODE=smart_approve` use a hook-like classifier that could be user-customized?** Would give a semi-hook surface. (T4)
6. **Does the Desktop Electron app have a JS plugin layer that the CLI doesn't?** UI is ~44% TypeScript; there may be frontend-only extension types with richer lifecycle. (T4)
7. **System prompt token count for developer extension** — unmeasured; affects context budget calculations for Furrow. (T4)

## Stability + community

- **Project health:** Strong. ~29K stars, monthly releases, now under AAIF/Linux Foundation governance as of Nov 2025 — more durable than single-vendor projects.
- **Breaking-change posture:** Architectural consolidation underway (discussion #7675 proposes collapsing platform + builtin into one, moving skills/recipes to core) suggests some churn in extension surface over the next few minor releases. Recipe YAML schema has been stable at v1.0.0 through 2026.
- **Reference implementation status** for MCP means goose tends to **lead** rather than follow spec changes — good for early access, risky if you want conservative stability.
- **Commercial backing:** Block (originator) + Linux Foundation (governance) + broad provider partnerships. Not at-risk.

## Sources Consulted (tiered)

### T1 — Primary (official repos and docs)
- https://github.com/aaif-goose/goose (README, structure) — current canonical repo
- https://github.com/block/goose (legacy, redirects)
- https://goose-docs.ai/ (official docs, current)
- https://block.github.io/goose/ (legacy docs site)
- https://goose-docs.ai/docs/getting-started/using-extensions
- https://goose-docs.ai/docs/guides/recipes/
- https://goose-docs.ai/docs/guides/recipes/session-recipes/
- https://goose-docs.ai/docs/guides/subagents/
- https://goose-docs.ai/docs/guides/config-files/
- https://goose-docs.ai/docs/guides/mcp-sampling/
- https://github.com/aaif-goose/goose/discussions/5761 (Skills design discussion)
- https://github.com/aaif-goose/goose/discussions/7675 (Extension consolidation proposal)
- https://github.com/aaif-goose/goose/discussions/4389 (Unify agent execution)
- https://github.com/aaif-goose/goose/discussions/3319 (Roadmap July 2025)
- https://github.com/aaif-goose/goose/discussions/7309 (ACP discussion)
- https://github.com/aaif-goose/goose/releases (version history)

### T2 — Secondary (close-to-source blogs, wikis)
- https://deepwiki.com/block/goose/2.2-provider-configuration
- https://deepwiki.com/block/goose/5.3-extension-types-and-configuration
- https://deepwiki.com/block/goose/4.3-session-management
- https://block.github.io/goose/blog/2025/09/26/subagents-vs-subrecipes/
- https://block.github.io/goose/blog/2025/06/05/whats-in-my-goosehints-file/
- https://block.github.io/goose/blog/2025/03/31/securing-mcp/
- https://www.arcade.dev/blog/goose-the-open-source-agent-that-shaped-mcp
- https://blog.modelcontextprotocol.io/posts/2025-11-25-first-mcp-anniversary/
- https://agent-safehouse.dev/docs/agent-investigations/goose (sandbox analysis)
- https://www.nickyt.co/blog/what-makes-goose-different-from-other-ai-coding-agents-2edc/
- https://www.nickyt.co/blog/advent-of-ai-day-10-understanding-arguments-in-goose-recipes-2obg/
- https://www.nickyt.co/blog/advent-of-ai-day-11-goose-subagents-2n2/
- https://dev.to/nickytonline/advent-of-ai-2025-day-15-goose-sub-recipes-3mnd
- https://dev.to/lymah/deep-dive-into-gooses-extension-system-and-model-context-protocol-mcp-3ehl
- https://www.pulsemcp.com/building-agents-with-goose/part-4-configure-your-agent-with-goose-recipes
- https://effloow.com/articles/goose-open-source-ai-agent-review-2026

### T3 — Tertiary (aggregators, used only for corroboration)
- https://aitoolly.com/ai-news/article/2026-04-06-goose-an-open-source-and-extensible-ai-agent-designed-to-automate-complex-engineering-tasks
- https://www.openaitoolshub.org/en/blog/goose-ai-agent-block-review
- https://crates.io/crates/goose
- https://www.mintlify.com/block/goose/api/cli/recipe

### T4 — Not consulted (requires experimentation / source read)
- Actual Rust source of `crates/goose/src/agents/` to confirm no private hook trait
- `crates/goose-mcp/` Cargo.toml for exact MCP spec version
- Runtime measurement of system prompt token count with default extensions
- ACP protocol spec for tool-use metadata surface

---

*End of R4 deep dive. Score recommendation: goose is a strong MCP host and provider abstractor, but a weak hook host. Porting Furrow costs roughly 60% drop-in / 40% rewrite-or-accept-degradation, with the 40% concentrated on deterministic enforcement hooks.*
