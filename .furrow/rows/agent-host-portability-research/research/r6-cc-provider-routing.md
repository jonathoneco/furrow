# R6 — CC + Provider-Routing Viability (Control Case)

**Date:** 2026-04-22
**Scope:** Evaluate the minimum-change option — keep Claude Code (CC) as the agent host, insert a provider-routing proxy between CC and the Anthropic API, and route some or all traffic to non-Anthropic providers (OpenAI, Google Gemini, Bedrock, Vertex, local models).
**Posture:** Fair evaluation. This is the baseline that any full-host migration must beat.

---

## Summary

- **Viability: High for Anthropic-native routing, degraded for cross-provider routing.** CC officially supports LLM gateways via `ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN`. The official docs page (`code.claude.com/docs/en/llm-gateway`) explicitly documents LiteLLM, Vercel AI Gateway, Bedrock, Vertex, and Foundry as target gateways. Routing Anthropic traffic through a proxy (for auth centralization, cost control, observability) is a first-class, production-sanctioned path.
- **Practical ceiling when routing to non-Anthropic models: moderate to poor.** Translation to Gemini or OpenAI is functional for basic messages + tool calls, but prompt caching, multi-point `cache_control`, web-search tool declarations, and token counting all have known translation defects at LiteLLM (and by extension any format-translating proxy). CC's edit heuristics were tuned for Claude output and degrade ~10% on GPT-5.4 and more on Gemini (T2).
- **What routing solves:** Anthropic rate limits / quota exhaustion, auth centralization, per-team cost allocation, observability, subscription-vs-API mixing, provider failover.
- **What routing does NOT solve:** CC's own context-window overhead (system prompt, skills, hook output all still traverse CC), per-session context-budget ceilings, subagent-dispatch mechanics, CC-imposed latency.
- **Furrow-specific implication: hooks and CLI-mediation survive a routing swap unchanged.** Furrow's integration surface is entirely at the CC host layer (hooks in `.claude/settings.json`, commands in `.claude/commands/`, CLIs invoked via Bash). The model provider is invisible to Furrow. A routing change is transparent to Furrow.

---

## Q1 — CC base URL / proxy support

**CC officially supports proxying.** The canonical page is `https://code.claude.com/docs/en/llm-gateway` (T1). It documents that a gateway must expose at least one of three API formats:

1. **Anthropic Messages** (`/v1/messages`, `/v1/messages/count_tokens`) — must forward `anthropic-beta` and `anthropic-version` headers.
2. **Bedrock InvokeModel** (`/invoke`, `/invoke-with-response-stream`) — must preserve `anthropic_beta`, `anthropic_version` body fields.
3. **Vertex rawPredict** (`:rawPredict`, `:streamRawPredict`, `/count-tokens:rawPredict`) — must forward `anthropic-beta`, `anthropic-version` headers.

Quote (T1, llm-gateway):
> "Failure to forward headers or preserve body fields may result in reduced functionality or inability to use Claude Code features."
> "Claude Code determines which features to enable based on the API format. When using the Anthropic Messages format with Bedrock or Vertex, you may need to set environment variable `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1`."

**Environment variables** (T1, settings + llm-gateway pages):

| Var | Purpose |
| --- | --- |
| `ANTHROPIC_BASE_URL` | Override the base API endpoint (primary hook for proxying) |
| `ANTHROPIC_AUTH_TOKEN` | Sent as `Authorization` header |
| `ANTHROPIC_API_KEY` | Sent as `X-Api-Key`. CC checks this first — must be empty string when using `ANTHROPIC_AUTH_TOKEN` with a gateway (T1, Vercel CC guide) |
| `ANTHROPIC_CUSTOM_HEADERS` | Add arbitrary headers (e.g., gateway-specific auth) |
| `ANTHROPIC_BEDROCK_BASE_URL` | Pass-through base URL when using Bedrock format |
| `ANTHROPIC_VERTEX_BASE_URL` | Pass-through base URL when using Vertex format |
| `CLAUDE_CODE_USE_BEDROCK` | Switch CC to Bedrock API format |
| `CLAUDE_CODE_USE_VERTEX` | Switch CC to Vertex API format |
| `CLAUDE_CODE_SKIP_BEDROCK_AUTH` / `CLAUDE_CODE_SKIP_VERTEX_AUTH` | Delegate auth to the gateway |
| `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` | Required for some Bedrock/Vertex gateway configurations |

CC also forwards an `X-Claude-Code-Session-Id` header on every request so proxies can aggregate by session (T1, llm-gateway).

**Verdict:** Yes — proxying is a supported, documented, first-class deployment mode.

---

## Q2 — Per-subagent provider override

**Partial support.** CC distinguishes between the main model, subagent model, and "small/fast" (Haiku-class) model.

From the model-config docs (T1):

| Var | Controls |
| --- | --- |
| `ANTHROPIC_DEFAULT_OPUS_MODEL` | What `opus` alias resolves to |
| `ANTHROPIC_DEFAULT_SONNET_MODEL` | What `sonnet` alias resolves to |
| `ANTHROPIC_DEFAULT_HAIKU_MODEL` | What `haiku` alias resolves to; also background functionality |
| `CLAUDE_CODE_SUBAGENT_MODEL` | Model for subagents |
| `ANTHROPIC_SMALL_FAST_MODEL` | Deprecated — replaced by `ANTHROPIC_DEFAULT_HAIKU_MODEL` |

Subagents defined in `~/.claude/agents/` or `.claude/agents/` can specify their own `model` in frontmatter (T1). The model-config page explicitly notes the `agent` start-mode:
> "**agent**: Run the main thread as a named subagent. Applies that subagent's **system prompt, tool restrictions, and model**."

**Key constraint** (T2, from search result summary of GitHub issue 25546 + 19174):
> "`CLAUDE_CODE_SUBAGENT_MODEL` only affects agents without an explicit model defined — it doesn't override the built-in agents' model settings. If you need to override a built-in subagent's model, you must create your own agent file that completely replaces the built-in agent."

**Routing implication:** You can run main + subagents on the same `ANTHROPIC_BASE_URL` but *select different model names per subagent* via frontmatter. A gateway like LiteLLM can then route `model: "gpt-5-mini"` to OpenAI while `model: "claude-opus-4-7"` goes to Anthropic — all in the same CC session. **This is the single strongest point in favor of the control case.**

**What you cannot do:** Point different subagents at different `BASE_URL`s within one CC session. `ANTHROPIC_BASE_URL` is process-global. If you need per-subagent *gateways*, you need one gateway fronting them all (which is the LiteLLM / Vercel AI Gateway / Portkey model anyway).

---

## Q3 — Candidate proxies

### LiteLLM

- **CC compatibility:** **Officially documented** (T1, llm-gateway page dedicates a section). Setup is 2 env vars plus a `config.yaml` with `model_list`.
- **Anthropic Messages translation:** Provides both unified endpoint (`/`) and pass-through (`/anthropic`). Unified endpoint is recommended for load balancing, fallbacks, consistent cost tracking (T1).
- **Tool-use translation:** Works for basic tools, but tool-name preservation across providers is imperfect. Web-search tool declarations are NOT translated to Gemini's `web_search_options` parameter (T1, GitHub issue 16962).
- **Streaming:** Supported, but 3rd-party notes report "LiteLLM, W&B or the combo of both are not handling streaming responses correctly" in some configurations (T2, olafgeibig gist).
- **Prompt caching:** **Broken for Anthropic→Gemini translation.** LiteLLM uses "First-Found" cache_control strategy; all but the first `cache_control` tag are dropped. Issue closed as "not planned" (T1, GitHub issue 17201). Cache remains stuck at system-prompt level; growing conversation history is never cached. For Anthropic→Anthropic pass-through, caching works normally. LiteLLM has a separate "Claude Code Prompt Cache Routing" guide (T2) for the Anthropic-native path.
- **Security:** LiteLLM PyPI v1.82.7 and v1.82.8 were compromised with credential-stealing malware (T1, CC llm-gateway page warning, BerriAI/litellm issue 24518). CC docs explicitly disclaim: *"LiteLLM is a third-party proxy service. Anthropic doesn't endorse, maintain, or audit LiteLLM's security or functionality."*
- **Source:** `https://docs.litellm.ai/docs/tutorials/claude_non_anthropic_models`, `https://code.claude.com/docs/en/llm-gateway`

### OpenRouter

- **CC compatibility:** Yes, via `ANTHROPIC_BASE_URL="https://openrouter.ai/api"` + `ANTHROPIC_AUTH_TOKEN=<or-key>` (T2, multiple blog posts). Not in CC's official docs page, but widely used.
- **Anthropic Messages translation:** OpenRouter advertises an Anthropic-compatible endpoint. Actual fidelity across non-Anthropic models follows the same translation-cost pattern as LiteLLM.
- **Tool-use / streaming:** Supported in principle; same cross-provider caveats.
- **Prompt caching:** Anthropic native caching flows through for Claude models on OpenRouter. Cross-provider caching story is not as developed as LiteLLM's attempted translation.
- **Operational posture:** SaaS, no self-host. Good for "try a different provider for one session" flows, worse for enterprise governance.
- **Source:** T2 (blog posts, gists — official OpenRouter docs page 404'd when fetched at `/docs/api-reference/overview`).

### Vercel AI Gateway

- **CC compatibility:** **First-class.** Vercel has a dedicated CC setup page at `/docs/agent-resources/coding-agents/claude-code` (T1). Setup:
  ```bash
  export ANTHROPIC_BASE_URL="https://ai-gateway.vercel.sh"
  export ANTHROPIC_AUTH_TOKEN="your-ai-gateway-api-key"
  export ANTHROPIC_API_KEY=""
  ```
- **Anthropic Messages translation:** Advertised as Anthropic-compatible (`/docs/ai-gateway/sdks-and-apis/anthropic-messages-api`, T1). Also offers OpenAI Chat Completions compat.
- **Claude Code Max subscription routing:** Uniquely, can route your Anthropic subscription traffic through the gateway for observability while keeping subscription billing (T1). Uses `ANTHROPIC_CUSTOM_HEADERS`.
- **Tool use / streaming:** Works with CC out of the box per docs; no explicit degradation warnings. Cross-provider translation fidelity **unverified** for tool schemas.
- **Fast mode:** Supported via `CLAUDE_CODE_SKIP_FAST_MODE_ORG_CHECK=1` (T1).
- **Pricing:** "No markup on tokens" claimed (T1).
- **Caveat:** Must set `ANTHROPIC_API_KEY=""` explicitly or CC prefers it over `ANTHROPIC_AUTH_TOKEN` and bypasses the gateway (T1).
- **Source:** `https://vercel.com/docs/agent-resources/coding-agents/claude-code`, `https://vercel.com/docs/ai-gateway`.

### Portkey

- **CC compatibility:** Anthropic-format gateway exposed at `https://api.portkey.ai`. Works with `ANTHROPIC_BASE_URL` in principle. **No dedicated CC setup page found** — treat as less battle-tested for CC than LiteLLM or Vercel.
- **Multi-provider support:** Advertises "Anthropic, Bedrock, Vertex" translation (T1, Portkey docs), plus OpenAI/Gemini via its general gateway.
- **Tool use / streaming / caching:** Docs claim support for all three, including Anthropic prompt caching. Caching fidelity across non-Anthropic providers is **unverified**.
- **Source:** `https://portkey.ai/docs/integrations/llms/anthropic`.

### Honorable mentions (T2)

- **claude-code-proxy** (`github.com/1rgs/claude-code-proxy`, `github.com/ariangibson/claude-code-proxy`) — purpose-built Anthropic-format shims for running CC on OpenAI/Gemini. Community-maintained.
- **claude-code-ollama-proxy** — local-model routing.
- **Morph** — commercial wrapper advertising CC+LiteLLM setup.
- **DeepSeek** — offers an Anthropic-compatible endpoint (`https://api.deepseek.com/anthropic`) that works with CC directly via `ANTHROPIC_BASE_URL` (T2).

---

## Q4 — Does routing address the context / scale pain?

This depends on which failure mode is the actual pain. Let me decompose.

### Pain mode A — "Anthropic API rate limits / quota exhaustion"
**Routing helps: YES.** Provider failover (LiteLLM/Vercel AI Gateway) moves overflow traffic to OpenAI/Gemini/Bedrock transparently. This is the single best-fit use case.

### Pain mode B — "Per-model context window too small (200K feels tight)"
**Routing helps: PARTIALLY.** CC already supports 1M-context Opus 4.7 and Sonnet 4.6 natively via `opus[1m]` / `sonnet[1m]` aliases (T1, model-config). On Max/Team/Enterprise, 1M Opus is included; on Pro/API, it's extra usage. So for Anthropic alone, CC reaches 1M. Routing to Gemini 2.5 Pro (2M context) would add ~2× headroom but at the cost of prompt-caching fidelity (Q3 LiteLLM bug, T1). **Net: small win, likely not worth the translation risk unless Gemini-quality reasoning is acceptable for the workload.**

### Pain mode C — "CC's own system prompt + skills + hook output eat the budget"
**Routing helps: NO.** The system prompt, skill injections, hook outputs, and tool-result buffers are all generated at the CC host layer before any request is built. Swapping the provider downstream doesn't shrink them. If Furrow's ambient context budget (≤150 lines) is itself under pressure, provider routing is irrelevant.

### Pain mode D — "Cost of Anthropic tokens"
**Routing helps: PARTIALLY.** Gemini 2.5 Flash and GPT-5-mini are substantially cheaper per token. But: (a) prompt caching is where Anthropic saves you real money on long sessions, and translation breaks it (T1, issue 17201); (b) CC's edit heuristics produce more failed edits on non-Claude models (~10% failure rate on GPT-5.4 per T2, morphllm), which re-runs inflate token spend. The effective cost differential narrows.

### Pain mode E — "Subagent cost — I don't need Opus for mundane explore-agents"
**Routing helps: YES, and this is the cleanest win.** `CLAUDE_CODE_SUBAGENT_MODEL` + gateway routing lets you send main-agent traffic to Opus 4.7 and explore-agent traffic to Haiku or Gemini Flash. Lets you keep premium reasoning where it matters while cutting subagent costs ~10×.

### Decision table

| Pain | Routing helps? | Confidence |
| --- | --- | --- |
| Rate limits | Yes | High |
| Context window | Partially (small win) | Medium |
| CC host overhead | No | High |
| Token cost | Partially | Medium |
| Subagent cost | Yes | High |
| Governance / audit | Yes | High |
| Provider lock-in | Yes | Medium |

---

## Q5 — Feature degradation matrix

"Anthropic-native" means proxy passes through to Anthropic unchanged. "Translated" means the proxy converts to another provider's wire format.

| Feature | Anthropic pass-through | Translated to OpenAI | Translated to Gemini | Source |
| --- | --- | --- | --- | --- |
| Basic messages | Works | Works | Works | T1 (Vercel, LiteLLM docs) |
| Tool use (basic) | Works | Works (schema usually preserved) | Works (schema usually preserved) | T1 (LiteLLM anthropic_unified) |
| Tool use (web_search) | Works | Partial (not mapped) | **Broken** (not translated to `web_search_options`) | T1 (issue 16962) |
| Streaming | Works | Works | Works, some 3rd-party reports of edge-case breakage | T1 + T2 |
| Prompt caching (single) | Works | N/A (OpenAI no native equiv) | Partial (first `cache_control` only) | T1 (issue 17201) |
| Prompt caching (multi-point) | Works | N/A | **Broken** — only first tag honored | T1 (issue 17201) |
| Extended thinking | Works | Not supported by target | Not equivalent | T1 (model-config) |
| Interleaved thinking | Works | Not supported | Not supported | T1 (model-config) |
| Effort levels (`xhigh`, `max`) | Works | Not supported | Not supported | T1 (model-config) |
| 1M context (`[1m]` suffix) | Works | N/A | Gemini native 2M, but addressed differently | T1 (model-config) |
| Computer Use | Anthropic-only | Not supported | Not supported | T3 (general knowledge — **UNVERIFIED** for proxy behavior) |
| Token counting (`/v1/messages/count_tokens`) | Works if gateway forwards | Partial | **Broken** (TypeError reports on Gemini in LiteLLM) | T1 (issue 16962) |
| Fast mode ($30/$150) | Works via gateway flag | N/A | N/A | T1 (Vercel CC guide) |
| `anthropic-beta` features | Works **if gateway forwards headers** | Likely stripped | Likely stripped | T1 (llm-gateway requirements) |
| CC edit-diff format | Tuned for Claude | ~10% more failures on GPT-5.4 | More than GPT-5.4 | T2 (morphllm) |

**Headline finding:** Anthropic pass-through is essentially lossless. Cross-provider translation loses caching precision, thinking, effort levels, Computer Use, and some tool translations. **Any workload that relies on prompt caching across a growing context (long coding sessions, Furrow's use case) will see material degradation on non-Anthropic backends.**

---

## Q6 — Furrow-layer compatibility

**Short answer: Furrow is unaffected by provider routing.**

Furrow's entire integration surface is at the CC host layer:

| Furrow surface | Location | Depends on model provider? |
| --- | --- | --- |
| Hooks | `.claude/settings.json` → `frw hook *` commands | No (fire on CC tool events, not model responses) |
| CLI mediation | `bin/rws`, `bin/frw`, `bin/alm`, `bin/sds` | No (invoked via Bash tool) |
| Commands | `.claude/commands/*.md` | No (prompt scaffolding, model-agnostic) |
| Rules | `.claude/rules/*.md` | No (context injection) |
| Skills / specialists | `references/specialist-template.md`, `specialists/` | No (prompt-layer) |
| Row state | `.furrow/rows/{name}/state.json` | No (mutated by `rws`, not by model) |
| Context budget | `frw measure-context` | No (counts lines, not tokens) |

**Mechanism confirmation:** `.claude/settings.json` wires all hooks as `{ "type": "command", "command": "frw hook <name>" }` against CC tool events (`PreToolUse` on Write/Edit/Bash, `Stop`, `SessionStart`, `PostCompact`). These fire on CC lifecycle events, completely independent of which provider CC's model lives on.

Relevant file paths:
- `/home/jonco/src/furrow/.claude/settings.json` — hook wiring
- `/home/jonco/src/furrow/.claude/rules/cli-mediation.md` — all state mutations go through CLIs, not model output
- `/home/jonco/src/furrow/.claude/rules/step-sequence.md` — enforcement via `rws transition`, not model

**Subtle failure surface:** Hooks rely on CC's hook protocol (exit codes 0/1/2, stdin JSON, stderr text). Hooks are CC-host behavior, not model behavior — swapping to Gemini-backed CC leaves them intact. However:

- If CC's subagent dispatch machinery behaves differently when the subagent model is non-Anthropic (e.g., degraded tool-use reliability → more retries → more hook firings), Furrow's **correction-limit** hook could trip more often on Gemini-backed subagents. This is an indirect quality-of-model effect, not a hook-compatibility issue. **UNVERIFIED** in practice — speculative.
- Furrow's `frw hook post-compact` runs after `/compact`. Compact summarization is done by CC (calling the configured model). A weaker model produces weaker summaries and may require reground. Again, indirect.

**Net:** Hooks, skills, CLIs, and state machinery are provider-agnostic. Row / state files never touch the model. Furrow survives a provider swap unchanged.

---

## Migration cost estimate (control case implementation)

If the recommendation is "stay on CC + route through a gateway":

| Work item | Surfaces changed | Effort |
| --- | --- | --- |
| Stand up LiteLLM or Vercel AI Gateway | 1 deploy target (docker-compose, Vercel project, or managed SaaS) | 0.5–1 day |
| Gateway config (`config.yaml` with model list + API keys) | 1 config file | 0.5 day |
| CC env var wiring (`ANTHROPIC_BASE_URL`, `ANTHROPIC_AUTH_TOKEN`, empty `ANTHROPIC_API_KEY`) | User shell config + optionally project `.claude/settings.json` `env` block | 0.25 day |
| Per-subagent model frontmatter (optional, for tiered routing) | `.claude/agents/*.md` or specialist defs | 0.5 day |
| Smoke tests — basic prompt, tool use, long-session caching, subagent dispatch | eval scripts | 0.5–1 day |
| Rollback plan (unset env vars → direct Anthropic) | docs | 0.1 day |
| **Total** | | **~2–3 engineering days** |

**Zero Furrow code changes required.** No CLI changes, no hook changes, no schema changes, no row-layout changes.

For **Bedrock/Vertex routing specifically**, add 1 day for IAM/service-account plumbing and `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` fallout testing.

---

## Open questions

1. **Does the caching bug matter for Furrow's actual sessions?** Furrow rows typically have bounded context (≤350 lines injected). Long-running implementation steps may or may not be long enough to feel Gemini cache degradation. Empirical test needed.
2. **Can Computer Use be emulated through a proxy?** Likely no — it requires Anthropic's tool-result schema and screen-snapshot protocol, not something LiteLLM translates. Furrow doesn't use Computer Use today, so this is moot.
3. **Does `ANTHROPIC_CUSTOM_HEADERS` leak correctly through LiteLLM?** Vercel's setup uses it for subscription auth. LiteLLM behavior **UNVERIFIED**.
4. **How do CC's `anthropic-beta` features degrade in practice when the gateway is LiteLLM?** Docs say "may result in reduced functionality." No concrete matrix found.
5. **Is there a CC setting to *require* proxy usage (for enterprise governance)?** `availableModels` and `modelOverrides` exist; `modelOverrides` is the closest thing to routing enforcement. **Worth re-reading** for R7 if the recommendation pushes toward enterprise posture.
6. **What's the actual quality gap on Furrow's workload specifically for GPT-5 / Gemini 2.5 Pro vs Claude Opus 4.7?** The 10% edit-failure figure is anecdotal (T2). A real eval on Furrow rows would settle this.

---

## Sources Consulted (tiered)

### T1 — Official primary sources

- Claude Code LLM gateway docs — `https://code.claude.com/docs/en/llm-gateway` — authoritative on gateway requirements, header/body forwarding, LiteLLM recommended config, Bedrock/Vertex pass-through env vars, `X-Claude-Code-Session-Id`, security warning about LiteLLM compromised versions.
- Claude Code model configuration docs — `https://code.claude.com/docs/en/model-config` — authoritative on `ANTHROPIC_DEFAULT_{OPUS,SONNET,HAIKU}_MODEL`, `CLAUDE_CODE_SUBAGENT_MODEL`, `ANTHROPIC_CUSTOM_MODEL_OPTION`, prompt-caching disable vars, `modelOverrides`, `availableModels`, effort-level capability matrix.
- Claude Code settings docs — `https://code.claude.com/docs/en/settings` — env var reference.
- LiteLLM Anthropic unified endpoint docs — `https://docs.litellm.ai/docs/anthropic_unified` — confirms `/v1/messages` translation target for OpenAI/Gemini/Bedrock/Vertex, tool and streaming support.
- LiteLLM Claude Code tutorial — `https://docs.litellm.ai/docs/tutorials/claude_non_anthropic_models` — exact env-var setup, master-key pattern, `model_list` config.
- LiteLLM Claude Code Quickstart — `https://docs.litellm.ai/docs/tutorials/claude_responses_api`.
- LiteLLM Claude Code prompt cache routing — `https://docs.litellm.ai/docs/tutorials/claude_code_prompt_cache_routing` (surfaced via search, not deep-fetched).
- Vercel AI Gateway CC integration — `https://vercel.com/docs/agent-resources/coding-agents/claude-code` — first-class CC setup, Max-subscription routing, fast-mode flag, `CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS` note.
- Vercel AI Gateway overview — `https://vercel.com/docs/ai-gateway`.
- Portkey Anthropic integration — `https://portkey.ai/docs/integrations/llms/anthropic` — Anthropic-compatible base URL, multi-provider claim.
- LiteLLM GitHub issue 17201 — multi-point cache translation broken, closed "not planned".
- LiteLLM GitHub issue 16962 — Claude Code + Gemini caching, token-counting, web-search tool bugs.

### T2 — Community / third-party

- Search surface for CC proxy patterns (blog posts, gists, community proxies).
- `github.com/1rgs/claude-code-proxy` — OpenAI routing.
- `github.com/ariangibson/claude-code-proxy` — multi-provider via LiteLLM.
- `github.com/mattlqx/claude-code-ollama-proxy` — local-model routing.
- Medium: "My Claude Code Gemini Setup Broke" (Prince Arora, Mar 2026) — confirms setup friction, light on runtime failure modes.
- Morph: "How to Use a Different LLM with Claude Code (2025 Guide)" — source for ~10% GPT-5.4 edit-failure estimate.
- Morph: "Claude Code LiteLLM Setup".
- Medium: "Connecting Claude Code to Local LLMs" (Hannecke) — two proxy approaches.
- Gist: spideynolove "Claude Code Multi-Provider Setup".
- Gist: olafgeibig — LiteLLM proxy for W&B inference; notes streaming issues.
- Maxim blog: "Top Enterprise AI Gateways to Use Non-Anthropic Models in Claude Code".

### T3 — Training-data knowledge

- General concepts of Anthropic Messages API vs OpenAI Chat Completions vs Gemini native format.
- General understanding of prompt caching mechanics.
- Computer Use: Anthropic-specific, unlikely to survive translation — **UNVERIFIED** via direct proxy behavior test.

---

## Recommendation framing (not a recommendation — framing for the larger decision)

The control case has three distinct sub-options, each with different risk/value:

1. **Route-for-governance (pass-through only).** Put LiteLLM or Vercel AI Gateway in front of CC, keep 100% of traffic on Anthropic, gain auth centralization + observability + cost tracking. Zero feature degradation. ~2 engineering days. **Low risk, medium value.**
2. **Route-for-failover (Anthropic primary, others as fallback).** Same as #1 plus fallback to OpenAI/Bedrock on Anthropic rate-limit or outage. Feature degradation only kicks in during fallback. **Low–medium risk, medium–high value when Anthropic quota is the pain.**
3. **Route-for-cost (mixed-provider, subagents cheaper).** Main agent on Opus, subagents on Haiku or GPT-5-mini or Gemini Flash. Caching translation degradation affects subagents. **Medium risk, high value if subagent volume is the cost pain.**

Full migration off CC is NOT a prerequisite for any of these. A full-host migration (R1–R5 alternatives) must beat option #2 or #3 on some axis — cost, latency, context, control — that routing alone cannot deliver. The most likely "routing can't deliver this" axis is pain mode C above: **CC's own host overhead and prompt architecture**. If that's the true pain, routing is a distraction and migration is justified. If the pain is rate limits, cost, or governance, routing wins on change cost.
