# Research Synthesis — Agent Host Portability

**Row**: `agent-host-portability-research`
**Step**: research
**Date**: 2026-04-22
**Status**: awaiting user input on R7 (pain quantification) and structural decisions

---

## Executive summary

The research produced **three load-bearing insights** that reshape the original framing:

1. **Furrow is 100% provider-agnostic already.** All CC coupling lives in the host layer (`.claude/settings.json`, hook scripts, slash commands, skills). Zero Furrow code is model-dependent. Routing is cheap, and full migration is primarily about the _host layer_, not the harness.

2. **CC has first-class proxy support** (`ANTHROPIC_BASE_URL` — officially documented). A "CC + provider-routing" control case costs **2-3 engineering days** and is reversible by env-var unset. Not a straw-man.

3. **The decision hinges on which pain you're optimizing.** Routing solves rate limits / governance / subagent cost / failover. Routing does _not_ solve CC's ~10k host-layer overhead (system prompt + skills + hook output). Only Pi / opencode's lighter system prompts fix that. **Until we know which pain is yours (R7), the matrix recommends different winners.**

---

## Cross-candidate rollup

|                            | **CC (baseline)** | **CC + routing** | **Agent SDK**                    | **Pi**                 | **opencode**           | **goose**           |
| -------------------------- | ----------------- | ---------------- | -------------------------------- | ---------------------- | ---------------------- | ------------------- |
| Provider swap              | ✗                 | ✓ (proxy)        | ✗ (Anthropic-only)               | ✓✓ (~20)               | ✓✓✓ (75+)              | ✓✓ (30+)            |
| Host-layer overhead relief | —                 | ✗ (same CC)      | partial (excludeDynamicSections) | ✓✓ (<1k sys prompt)    | ✓✓                     | ✓                   |
| Hook system                | ✓ baseline        | ✓                | ✓✓ (typed)                       | ✓✓✓ (25+, mutable)     | ✓✓ (richer than CC)    | ✗ **disqualifying** |
| Subagent primitive         | ✓                 | ✓                | ✓                                | ✗ (example only)       | ⚠ **#5894 unresolved** | ⚠ LLM-mediated      |
| MCP                        | ✓                 | ✓                | ✓                                | ✗ (rejected by design) | ✓✓                     | ✓✓✓ (ref impl)      |
| Slash commands             | ✓                 | ✓                | ✓                                | ✓                      | ✓ (near 1:1 port)      | ✓ (recipes)         |
| Migration cost             | 0                 | 2-3 days         | weeks (adapter drift)            | weeks-months           | weeks-months           | blocked             |
| Reversibility              | —                 | trivial          | moderate                         | hard                   | hard                   | n/a                 |
| Stability                  | stable            | stable           | breaking @ patch                 | 0.x, daily             | daily, 6k issues       | monthly, LF-backed  |

### Quick eliminations

- **goose** — no hook system, conflicts with `hard_block_over_autocorrect` / `deep_not_optional`. Upstream Rust change required.
- **Agent SDK** — Anthropic-only (doesn't solve Q3-B), bundles CC binary (doesn't escape CC overhead).

### Live candidates

- **CC + routing** (2-3 days, reversible) — wins IF pain is rate limits / governance / subagent cost
- **Pi** (weeks, 0.x stability, subagent vendor-fork, MCP gap) — wins IF pain is host-layer overhead AND you value richest hook surface
- **opencode** (weeks, high maturity, subagent-hook-interception unresolved) — wins IF pain is host-layer overhead AND MCP matters AND #5894 resolves favorably

---

## Per-agent findings

### R1 — Furrow's current CC coupling surface

File: `r1-furrow-surface-inventory.md` (~460 lines, 8 surfaces, 63 cited usage sites)

- **Pre-existing `adapters/` tree** (with `claude-code/` and `agent-sdk/` subdirs) — partial Host Adapter Interface already in-tree. Must reconcile with this row's interface deliverable rather than re-derive.
- **Stdin shape drift**: Furrow hooks accept `.tool_input.file_path` OR `.filePath` OR `.path` interchangeably — CC schema drift the adapter must normalize.
- **`frw hook gate-check` is a registered no-op** — deletion candidate regardless of migration outcome.
- Adapter boundary is clean: ~70% of `frw` subcommands are host-invariant. Only `frw hook`, `install`, `launch-phase`, `run-gate`, `cross-model-review` touch the host.
- **`PostCompact` stdout re-injection** is the one irreducible host behavior — any replacement host MUST replicate it verbatim.
- **3 rationale entries** don't map to any observed usage site — likely dead code.
- **High-coupling surfaces**: settings.json hook registration, hook stdin/exit-code contract, subagent dispatch.
- **Low-coupling**: skills loading (agent-mediated), context budget (tuning not contract), MCP (effectively zero).

### R2 — Pi (pi-mono/coding-agent)

File: `r2-pi-deep-dive.md` | Verdict: strongest hook surface of any candidate, but subagent and MCP gaps.

- v0.68.1, MIT, 38k★, TypeScript, single maintainer (Mario Zechner), 0.x semver, near-daily releases. **Pin exact version.**
- **Hook events (25+, typed, mutable, blockable)** — richer than CC.
- **Multi-provider widest** of any candidate: ~20 API-key providers + 5 OAuth subscriptions.
- **Context injection via 3 mechanisms**: skills (agentskills.io spec), `before_agent_start` hook, `context` message filter.
- **<1k-token system prompt verified** (T2 — author's blog). Compare CC's ~10k.
- **Slash commands first-class** (`pi.registerCommand`, autocomplete).
- **GAP — Subagent dispatch**: no core primitive. 34KB example extension provides Single/Parallel (cap 4)/Chain via child processes — Furrow would have to vendor/fork it.
- **GAP — MCP**: explicitly absent by design ("No MCP"). Biggest portability tax.
- Tool metadata: no re-validation after mutation (feature + footgun).

### R3 — opencode (anomalyco/opencode)

File: `r3-opencode-deep-dive.md` | Verdict: highest-fit structurally, but one unresolved issue could kill it.

- Confirmed rename `sst/opencode` → `anomalyco/opencode`.
- v1.14.20, MIT, 147k★, 455 contributors, daily patches, TypeScript.
- `.claude/` → `.opencode/` migration is **near-1:1** — commands are markdown with frontmatter.
- **Hooks richer than CC**. Abort via `output.abort = "reason"`.
- **Multi-provider best-in-class: 75+ providers**, runtime swap via `/models`.
- **MCP native** (local + remote, OAuth + DCR).
- Context injection: AGENTS.md cascade + on-demand SKILL.md + `experimental.chat.system.transform`.
- **CRITICAL UNRESOLVED GAP (issue #5894)**: `tool.execute.before` may not intercept tool calls inside subagents. If true, breaks Furrow's deliverable-ownership + correction-limit enforcement across the Task boundary. **T4 experimentation required.**
- Stability concerns: 6,115 open issues, 1GB+ RAM baseline, cloud telemetry on by default, experimental.\* hooks unstable.

### R4 — goose (aaif-goose/goose) — ELIMINATED

File: `r4-goose-deep-dive.md` | Verdict: no hook system, conflicts with your enforcement preferences.

- Moved to Linux Foundation (AAIF) Nov 2025 — governance upgrade.
- v1.31.1, Apache-2.0, Rust core, MCP-first extension model (reference MCP implementation).
- **DISQUALIFYING**: no PreToolUse/Stop/SessionStart/PostCompact exposed to user scripts. Gating is interactive / LLM-classified / stored permissions.
- Conflicts with `hard_block_over_autocorrect` and `deep_not_optional`.
- Subagents exist but are LLM-mediated natural language, not programmatic.
- ~60% surface ports cleanly; remaining 40% is the enforcement layer.

### R5 — Claude Agent SDK — ELIMINATED

File: `r5-claude-agent-sdk-deep-dive.md` | Verdict: doesn't solve lock-in; bundles CC binary.

- v0.2.117, weekly releases, breaking changes at patch level.
- **Native for every Furrow surface** including typed hooks (more events than CC), but...
- **TS SDK literally bundles the CC native binary as a dependency.** Migrating CC → SDK = trading one interface to one provider for another interface to the same provider.
- **Anthropic-only** — fails Q3-B.
- Python SDK asymmetry: no `SessionStart`/`SessionEnd` (requires shell hooks).
- **In-tree `adapters/agent-sdk/`** has drift: stale paths, 26 `# TODO: customize` stubs, `gate_callback.py` hardcodes "evaluator".

### R6 — CC + provider-routing (control case) — LIVE

File: `r6-cc-provider-routing.md` | Verdict: the sleeper winner if pain is provider/rate-limits.

- **`ANTHROPIC_BASE_URL` + `ANTHROPIC_AUTH_TOKEN`** officially documented. LiteLLM, Vercel AI Gateway, Bedrock, Vertex, Foundry named.
- **Per-subagent provider override via model names** (`CLAUDE_CODE_SUBAGENT_MODEL` + frontmatter `model:`). Cannot use different `BASE_URL`s per subagent in one session.
- **Translation breaks**:
  - LiteLLM multi-point `cache_control` → Gemini is "First-Found" (issue #17201 closed "not planned")
  - Web-search not translated to Gemini (issue #16962)
  - Token counting intermittently broken
  - CC's edit heuristics degrade ~10% on GPT-5.4, more on Gemini
- **Solves**: rate limits, governance, subagent cost, provider failover
- **Does NOT solve**: CC's host-layer overhead (system prompt + skills + hook output)
- **Zero Furrow changes**. **2-3 engineering days**. **Reversible via env-var unset.**
- Three sub-options: governance-only / failover / cost-tiered.

---

## Open questions

### For you — R7 pain quantification (required before axis lock + decision memo)

Fill in your answers inline. One-liners fine.

**Q7.1 — Which Furrow ceremony hits context ceiling first?**
Options: ideate (6-part walk + dual reviewers) / implement (multi-specialist parallel) / review (evaluator + dimensions) / something else.

> YOUR ANSWER:

> It's not really about any given ceremony, nor about session limits, but about claude max usage limits shrinking over the last two months. OpenAI Subscription limits are still very generous so I want to take advantage of those, but I don't like codex as a harness, hence my wanting to switch to Pi so I can use openai models, in a claude-code like manner / harness preferences, picking right up from where my furrow artifacts left off

**Q7.2 — "Context limits getting ridiculous" maps to which?**

- (a) auto-compaction firing mid-step, losing context you care about
- (b) CC's own model limit (200k / 1M / whichever)
- (c) subagent returns feel lossy (summary loses detail)
- (d) can't run N parallel specialists without hitting ceilings
- (e) something else

> YOUR ANSWER: Weekly / 5h usage limits, not any given session or step

**Q7.3 — CC↔Codex switching pain — which component?**
session cold-start / auth friction / pricing unpredictability / other

> YOUR ANSWER: Harness preferences, I don't like the codex harness, it's sandboxing, or it's approach to work

**Q7.4 — Subscription economics**
one Max/Team plan with CC / per-token API / both / other

> YOUR ANSWER: One max plan with CC, per-token, and a openai subscription

**Q7.5 — Migration session budget**
if answer is Pi or opencode, how much session time are you willing to sink into the migration itself (separate from this research)?

> YOUR ANSWER: Indefinite, whatever it takes

**Q7.6 — Anti-goal — what would make you regret migrating?**
e.g., "if Pi's ecosystem dies," "if I lose Max-plan Opus access," "if opencode's extension API churns," etc.

> YOUR ANSWER: Nothing really, as long as I keep claude code functional throughout this serves at worst as an interesting exploration

### From research — T4 open questions (require a spike to answer)

- **opencode #5894** — does `tool.execute.before` intercept subagent tool calls? Gates whether opencode is viable at all.
- **Pi subagent-example maturity** — is the 34KB example robust enough to vendor as-is, or does it need stabilization work?
- **Pi `--bare`-equivalent** — does Pi have isolated subagent invocation matching CC's context-isolation guarantees?
- **PostCompact replication** — can Pi's `session_compact` hook actually re-inject stdout the way CC's post-compact does? Load-bearing.
- **opencode subagent return-value shape** — undocumented; does it preserve structured output or stringify?

### Structural / strategic decisions for you

**S1 — Adapter interface drafting approach**
Should the Host Adapter Interface (deliverable D1) be drafted against the existing `adapters/` tree scaffolding, or start fresh? In-tree scaffolding has drift but has done design work.
Options: (a) reconcile with existing, (b) start fresh and delete existing, (c) start fresh and keep existing as reference.

> YOUR ANSWER: Whatever ends up the cleanest, we haven't really used the adapters for anything but claude code, and pi is a very different framework

**S2 — Matrix row disposition for eliminated candidates**
Drop Agent SDK + goose from matrix entirely, or keep as eliminated-for-cause rows for completeness? Lean: keep, mark `eliminated` with one-line blocker.

> YOUR ANSWER: Agreed, honestly I'm only interested in Pi

**S3 — Does "CC + routing" make the Pi spike unnecessary?**
If the 2-3 day control case solves your pain (see R7.2), the Pi spike becomes academic. Option: rescope to drop spike, expand matrix depth on routing sub-options instead.

> YOUR ANSWER: We've already done some routing work, this is a anthropic issue running up against compute limitations, not a personal issue, everyone is complaining about these usage limits

**S4 — Reframe objective?**
Given R6, the objective could narrow to "decide between routing vs full migration," which is a smaller, crisper memo. Keep current framing or narrow?

> YOUR ANSWER: Honestly I'm pretty clear on what I want

### Low-priority (can defer to plan step)

- Pi's single-maintainer risk vs opencode's 455 contributors / governance — how much does this matter?
- opencode stability: 6k+ open issues and daily patches — healthy or churning?
- Agent SDK in-tree scaffolding — delete if SDK rejected, or keep as hedge?

---

## Sources consulted (synthesis-level)

All research docs include per-topic `Sources Consulted` sections with T1-T5 tiering. High-value primary sources across agents:

- **T1 repo reads**: `github.com/badlogic/pi-mono`, `github.com/anomalyco/opencode`, `github.com/aaif-goose/goose`, `github.com/anthropics/claude-agent-sdk-typescript`, local `/home/jonco/src/furrow/` tree
- **T1 official docs**: `docs.claude.com/en/docs/claude-code/`, `code.claude.com/docs/en/llm-gateway`, `block.github.io/goose/`, `opencode.ai/docs`, `docs.litellm.ai`, `vercel.com/docs/ai-gateway`
- **T2 vetted secondary**: `mariozechner.at/posts/2025-11-30-pi-coding-agent/`, `dev.to/theoklitosbam7/pi-coding-agent-a-self-documenting-extensible-ai-partner-dn`, XDA, Grigio, Grokipedia
- **T1 local**: `.furrow/almanac/rationale.yaml`, `adapters/claude-code/`, `adapters/agent-sdk/`

---

## Next steps (pending your R7 + S answers)

1. Lock matrix axes based on R7 pain ranking
2. Update `definition.yaml` if S1-S4 produce scope changes
3. Write final `candidate-host-matrix.md` (deliverable D2)
4. Decide spike disposition (S3) — proceed with Pi spike as-defined, rescope, or drop
5. Draft `host-adapter-interface.md` (deliverable D1) per S1 reconciliation choice
6. Transition research → plan

**Session budget check**: ~1 session used for ideate, ~1 session for research dispatch + synthesis. 2 sessions remaining before the session-4 abort constraint triggers.

> Another note, pi is largely used by people with various plugins / community resources, rarely is it used barebones, do community research to identify powerful setups / common patterns so we're building upon something that makes sense not something barebones where we need to re-implement functionality that exists out there
