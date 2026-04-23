# R8 — Pi Ecosystem & Community Survey

_Research agent, 2026-04-22. All web findings tiered; primary source where reachable._

## Tier legend

- **T1** — primary source (repo README, package.json, maintainer post, npm registry)
- **T2** — secondary synthesis (deepwiki, summary article, gist setup guide)
- **T3** — search-result snippet (may be hallucinated/stale; use only to corroborate T1)
- **T4** — requires experimentation (clone, install, run — out of scope here)

---

## Summary

- A serious Pi user in April 2026 is **almost never running "barebones" Pi**. The npm registry returns **1,559 packages** under the `pi-package` keyword; GitHub shows **130+** repos tagged `pi-extension` and **135+** under `pi-package`. The ecosystem is dense, fast-moving (most repos pushed in the last 30 days), and dominated by single-author "personal pack" repos rather than corporate-maintained libraries. [T1: npm search API, T1: GitHub search API]
- **Two meta-distributions** matter: (1) upstream `@mariozechner/pi-coding-agent` (the `pi` command) and (2) **`can1357/oh-my-pi`** — a hard fork published as `@oh-my-pi/pi-coding-agent` using the command `omp`, which bundles LSP, Python/IPython, browser automation, subagents, MCP, hash-anchored edits, and 65+ themes. Upstream extension compatibility with `omp` is **not explicitly documented**; oh-my-pi has its own hook/skill surface (e.g. `.omp/.../hooks/pre/*`). [T1: github.com/can1357/oh-my-pi README, T1: HN/X threads]
- There is **no official "starter pack"** and Mario Zechner explicitly avoids recommending extensions. His blog post endorses a **file-based, externally-stateful** workflow (`TODO.md`, `PLAN.md`, `AGENTS.md`, tmux for long-running processes, bash-spawned subagents) and warns that **built-in todo lists "confuse models more than they help"** — this is directly relevant to Furrow's positioning. [T1: mariozechner.at/posts/2025-11-30-pi-coding-agent/]
- The community has **already built Furrow-shaped primitives** multiple times: `pi-gsd` (spec-driven 6-phase lifecycle), `omni-pi` (interview → spec → bounded-slice implementation), `pi-superpowers-plus` (TDD-enforcing workflow monitor with RED→GREEN→REFACTOR tracking), `@callumvass/forgeflow-dev` (TDD pipeline), `@davidorex/pi-project-workflows` (schema-driven `.project/` + YAML workflow DAG). Furrow must position clearly against these — **it is not entering a vacuum**. [T1: multiple npm/GitHub READMEs]
- Pi's core gaps (no MCP, no native subagents, no sandbox, no persistent memory) are **all filled** by community extensions, mostly maintained but small (2-50 stars, single authors). A Furrow adapter should **compose with them, not bundle them**.

---

## Load-bearing extensions

Ranked by signal (stars × recency × overlap with harness concerns). "Load-bearing" means a non-trivial fraction of serious Pi users install it; absence is noticeable.

### Extension: `can1357/oh-my-pi` (the fork, not an extension per se)
- **What it does**: Superset of Pi with LSP (40+ languages), Python via IPython kernel, Puppeteer browser with anti-bot, subagents with git-worktree / fuse-overlayfs / ProjFS isolation, MCP, hash-anchored edits (6.7% → 68.3% edit success rate improvement cited), Agent Control Center dashboard, background jobs (up to 100 concurrent), 65+ themes.
- **Furrow relationship**: **foundational** (if Furrow targets oh-my-pi instead of upstream Pi, many gaps disappear); **partially redundant** (its subagent + isolation story is more mature than anything Furrow would build).
- **Maturity**: **production** — v14.1.2, 322 releases, 4,240 commits, dual-copyright Mario Zechner + Can Bölük (2025-2026).
- **Author + last commit**: Can Bölük; last release 2026-04-14.
- **Citation (T1)**: github.com/can1357/oh-my-pi README and releases.

### Extension: `MasuRii/pi-tool-display`
- **What it does**: Collapses/truncates verbose tool output (`read`, `grep`, `bash`, diffs). Three presets: `opencode`, `balanced`, `verbose`. Functional (not cosmetic) — reduces token cost of reviewing history and narrows layout to terminal width.
- **Furrow relationship**: **orthogonal** — UI layer, does not touch state.
- **Maturity**: production — 88 stars, pushed 2026-04-22 (same day as snapshot).
- **Citation (T1)**: github.com/MasuRii/pi-tool-display.

### Extension: `tintinweb/pi-gitnexus` (68 stars)
- **What it does**: GitNexus knowledge-graph integration — static code understanding fed into agent context.
- **Furrow relationship**: orthogonal (context enrichment, not workflow).
- **Maturity**: active (pushed 2026-03-25). [T1: github search API]

### Extension: `tintinweb/pi-tasks` (55 stars)
- **What it does**: Claude-Code-style task tracking: 7 LLM-callable tools, file-backed state, DAG dependencies with cycle detection, visual widget, auto-cascade when blockers complete. Tasks have status lifecycle (pending → in_progress → completed), optional `agentType` for subagent spawning.
- **Furrow relationship**: **directly competitive / redundant with Furrow's row state machine**. If Furrow ships on Pi, users will ask "why not just use pi-tasks?" Furrow's differentiator must be **7-step sequence discipline + CLI-mediated mutation + correction limits**, not "we track tasks."
- **Maturity**: active (pushed 2026-03-24, 55 stars).
- **Citation (T1)**: github.com/tintinweb/pi-tasks.

### Extension: `@tintinweb/pi-subagents` (181 stars per npm, separate from GitHub counter)
- **What it does**: Claude-Code-style autonomous subagents. Custom types via `.pi/agents/<name>.md` with YAML frontmatter. Parallel execution (default concurrency 4), live TUI widget, mid-run steering (inject messages into running agents), session resume, graceful shutdown. Defaults: `general-purpose`, `Explore` (read-only, haiku), `Plan` (read-only).
- **Furrow relationship**: **foundational** — if Furrow wants to spawn review/research specialists, use this rather than reimplement.
- **Maturity**: "Early release" self-labeled, but 21 releases, MIT, v0.5.2 (2026-03-26). [T1: github.com/tintinweb/pi-subagents]

### Extension: `tintinweb/pi-supervisor` (36 stars)
- **What it does**: Separate-LLM-session supervisor observes the main agent; injects steering messages on drift. Three sensitivities (end-of-run, every 3 cycles, every cycle). Policies via `SUPERVISOR.md` files (project or global). Hooks: `agent_end`, `turn_end`, `/supervise` command, `start_supervision` tool.
- **Furrow relationship**: **complementary** — Furrow's gate reviews and the supervisor model are conceptually close. A Furrow adapter could register `/supervise` against a row's acceptance criteria.
- **Maturity**: active, 36 stars, pushed 2026-03-11.
- **Citation (T1)**: github.com/tintinweb/pi-supervisor.

### Extension: `arpagon/pi-rewind` (33 stars)
- **What it does**: Git-ref-based checkpoints, one per turn, `/rewind` with diff preview and redo stack. Auto-prunes to 50 per session. Skips when working tree unchanged.
- **Furrow relationship**: **complementary** — Furrow's row-level checkpoint semantics should probably integrate with (not conflict with) pi-rewind's turn-level snapshots.
- **Maturity**: active (pushed 2026-03-31). [T1: github.com/arpagon/pi-rewind]

### Extension: `@samfp/pi-memory` / `jayzeng/pi-memory`
- **What it does**: Persistent memory: learn corrections/preferences/patterns, inject into future conversations. jayzeng's adds daily logs, scratchpad, optional qmd-powered semantic search.
- **Furrow relationship**: orthogonal — context not workflow.
- **Maturity**: both active April 2026. [T1: npm search]

### Extension: `carderne/pi-sandbox` (48 stars)
- **What it does**: OS-level sandboxing — `sandbox-exec` on macOS, `bubblewrap` on Linux. Node-level interception of read/write/edit against filesystem policy. Four-option prompt on block (abort / session / project / global).
- **Furrow relationship**: **foundational** — Furrow's correction-limit and trust-boundary story benefits from composing on top of this rather than reinventing process isolation.
- **Maturity**: active (2026-03-20, 48 stars).
- **Citation (T1)**: github.com/carderne/pi-sandbox.

### Extension: `nicopreme/pi-mcp-adapter` + `mavam/pi-mcporter`
- **What it does**: MCP bridges. `pi-mcp-adapter` is the general adapter (nicopreme is a prolific Pi author). `pi-mcporter` takes a cleaner approach: exposes **one tool** `mcporter` with `search`/`describe`/`call` actions — avoids polluting Pi's tool list with dozens of MCP tools.
- **Furrow relationship**: orthogonal — these fill the MCP gap so Furrow doesn't have to.
- **Maturity**: both active April 2026. `pi-mcporter` is 13 stars, v0.3.0 (2026-03-13). [T1: github.com/mavam/pi-mcporter, npm]

### Extension: `w-winter/dot314` (90 stars — top of topic:pi-extension)
- **What it does**: **Curated 30+ extension "dotfiles"** for one power user — command palette, session management, web search, RepoPrompt integration, notifications, sandboxing, two themes. Individual extensions also publish standalone to npm.
- **Furrow relationship**: reference implementation of "what a loaded Pi looks like" — nothing to depend on directly, but the file layout is the closest thing to a canonical power-user setup.
- **Maturity**: production (same-day push, 90 stars).
- **Citation (T1)**: github.com/w-winter/dot314.

### Extension: `MasuRii/pi-permission-system`
- **What it does**: Centralized permission gates for tool, bash, MCP, skill, and "special" ops. Hooks: `before_agent_start`, `tool_call`, `input`. Explicitly advertises composition with `pi-multi-auth`, `pi-tool-display`, `pi-rtk-optimizer`.
- **Furrow relationship**: **foundational** for a harness with correction limits and deliverable-ownership.
- **Maturity**: 19 stars, but npm published by masurii 2026-04-22. [T1: github.com/MasuRii/pi-permission-system]

### Honorable mentions (active but more specialized)
- `ben-vargas/pi-packages` (57 stars) — 8-package bundle: synthetic provider, Antigravity image-gen, Exa MCP, Firecrawl, ancestor discovery, editor shortcuts, OpenAI fast tier, Claude Code OAuth patch.
- `coctostan/pi-superpowers` / `pi-superpowers-plus` (25 / 62 stars) — 12 workflow skills + 3 active extensions (Workflow Monitor, Plan Tracker, Subagent dispatcher). **Explicit TDD enforcement: RED→GREEN→REFACTOR phase tracking, blocks production code without failing test.**
- `joelhooks/pi-tools` (51 stars) — repo-autopsy, ralph-loop (autonomous background loops), agent-secrets (time-leased credentials), mcp-bridge (OAuth), session-reader (parses pi + Claude Code + Codex sessions).
- `tmustier/pi-agent-teams` (52 stars) — experimental multi-agent swarm, ported from Claude agent-teams-mcp.
- `codexstar69/pi-listen` (48 stars) — Deepgram hold-to-talk voice input.
- `tmustier/pi-ralph-wiggum` — long-running iterative loops.
- `mavam/pi-web-providers` (41 stars) — unified web-access routing across Claude/Codex/Exa/Gemini/Parallel.
- `tintinweb/pi-schedule-prompt` (34 stars) — cron-like prompt scheduling.
- `tintinweb/pi-manage-todo-list` (16 stars) — VSCode Copilot-Chat-style todos with persistence.
- `default-anton/pi-subdir-context` — auto-loads `AGENTS.md` from subdirectories.

---

## Plugin bundles / starter packs

There is **no Mario-endorsed starter pack**. What exists:

| Bundle | Author | Stars | Contents |
|---|---|---|---|
| `w-winter/dot314` | w-winter | 90 | 30+ extensions, skills, prompts, 2 themes (Violet Dawn/Dusk) |
| `ben-vargas/pi-packages` | ben-vargas | 57 | 8 self-contained packages (providers, MCP, scraping, shortcuts) |
| `coctostan/pi-superpowers-plus` | coctostan | 62 | TDD-enforcement: 12 skills, 3 runtime extensions, workflow monitor |
| `MattDevy/pi-extensions` | MattDevy | 28 | continuous-learning + companions |
| `butttons/pi-kit` | butttons | 30 | personal kit |
| `mgabor3141/yapp` | mgabor3141 | 24 | "yet another pi pack" |
| `normful/picadillo` | normful | 9 | personal commands/skills/extensions |

**Pattern**: one-author repos with mixed resources (extensions + skills + prompts + themes). Install mechanism is uniformly `pi install git:github.com/user/repo` or `pi install npm:pkg`. Users **cherry-pick** rather than adopt a whole pack. [T1: GitHub + npm searches]

**Distribution registry**: `pi.dev/packages` (formerly `shittycodingagent.ai/packages`, redirected via `buildwithpi.ai`) is the official browser — UI for filtering by type (extension/skill/theme/prompt/demo), sorted by downloads/recency/alpha. Backed by npm registry queries (the page returned an "npm unreachable" error during this survey — reliability uncertain). [T1: pi.dev redirect chain]

---

## Gap-filler extensions (ecosystem patches for Pi core gaps)

### MCP bridge
- **Gap**: Pi core explicitly has no MCP.
- **Fillers (multiple, mature-enough)**:
  - `mavam/pi-mcporter` — single-tool proxy design, v0.3.0, 13 stars. [T1]
  - `nicopreme/pi-mcp-adapter` — general adapter (author is prolific Pi contributor). [T1: npm]
  - `joelhooks/pi-tools/mcp-bridge` — OAuth-enabled remote MCP. [T1]
  - `tintinweb/pi-messenger-bridge` — bridges Telegram/WhatsApp/Slack/Discord as MCP-style surfaces (different axis). [T1]
  - oh-my-pi has **native MCP** (not an extension). [T1]
- **Maturity**: good enough for non-critical MCP use; no single dominant bridge.

### Subagent dispatch
- **Gap**: Pi ships only a 34KB example subagent extension.
- **Fillers**:
  - `@tintinweb/pi-subagents` (181 npm stars) — closest to dominant, parallel + queueing + steering.
  - `mjakl/pi-subagent` — minimal "spawn vs fork" context-control alternative.
  - `@ifi/pi-extension-subagents` — full-featured, builds on nicobailon/pi-subagents.
  - `coctostan/pi-superpowers-plus`'s Subagent dispatcher — bundled with TDD workflow.
  - `tmustier/pi-agent-teams` — Claude-agent-teams-mcp port.
  - oh-my-pi's **native task tool** with git-worktree/FUSE/ProjFS isolation (most sophisticated).
- **Maturity**: multiple competing patterns; no single extension has "won". Isolation semantics vary wildly (process, worktree, FUSE, none).

### Persistent memory
- **Fillers**: `@samfp/pi-memory`, `jayzeng/pi-memory`, `MattDevy/pi-extensions/pi-continuous-learning`. Multiple viable.

### Sandbox / permission
- **Fillers**: `carderne/pi-sandbox` (OS-level, 48 stars), `MasuRii/pi-permission-system` (in-process gates), `dtmirizzi/pi-governance` (RBAC/audit/DLP/HITL, 10 stars).
- No single dominant solution; tension between OS-level (pi-sandbox) and Pi-lifecycle-hook (pi-permission-system) approaches.

### Checkpoint / rewind
- **Filler**: `arpagon/pi-rewind` (33 stars) is effectively canonical — git-ref snapshots, redo stack, sensitive-dir protection.

### LSP / language intel
- **Gap in core**: none documented.
- **Fillers**: `pi-lens` (real-time LSP/lint/typecheck), oh-my-pi native LSP (40+ languages, 11 operations).

### Long-running / background loops
- **Fillers**: `joelhooks/pi-tools/ralph-loop`, `tmustier/pi-ralph-wiggum`, `juanibiapina/pi-gob` (gob daemon monitoring).

### Observability / cost tracking
- **Fillers**: `imran-vz/pi-observability` (live footer bar + dashboard), `nicopreme/pi-powerline-footer`, `mavam/pi-fancy-footer`.

---

## Install + distribution patterns

Uniform across the ecosystem. From `docs/extensions.md` [T1]:

1. **`settings.json` with `resources.packages`** — `npm:@foo/bar@1.0.0` or `git:github.com/user/repo@v1`.
2. **CLI install**: `pi install npm:<pkg>` or `pi install git:<url>` — writes into settings.
3. **One-shot eval**: `pi -e npm:<pkg>` — load for single session.
4. **Autodiscovery**:
   - `~/.pi/agent/extensions/*.ts` (user global)
   - `.pi/extensions/*.ts` (project local)
   - Subdirectories with `index.ts`.
5. **TypeScript compiled on-the-fly via jiti** — no build step required for extensions.
6. **Extensions export default `(pi: ExtensionAPI) => void`** — register tools, commands, shortcuts, flags, hooks.

**Skills distribution** (agentskills.io spec):
- Frontmatter: `name` (64 chars, lowercase+hyphens), `description` (1024 chars).
- Loading locations: `~/.pi/agent/skills/`, `.pi/skills/`, packages, settings, CLI flag.
- `enableSkillCommands: true` registers `/skill:<name>` commands.
- **No explicit registry** — Anthropic skills and Pi skills mentioned as reference bundles only. [T1: docs/skills.md]

**Project override**: settings merge nested objects (not replace). `.pi/settings.json` layers over `~/.pi/agent/settings.json`. [T1: docs/settings.md]

**Zero-compile, npm-first, layered-config** — matches what Claude Code does for its own extensions and is the most permissive hosting model surveyed.

---

## oh-my-pi investigation

**Identity**: Hard fork of `badlogic/pi-mono` by Can Bölük. Dual copyright Mario Zechner + Can Bölük (2025-2026). Command is **`omp`**, not `pi`. Package is `@oh-my-pi/pi-coding-agent`. 322 releases, 4,240 commits, v14.1.2 (2026-04-14).

**What it bundles natively** (not extensions — *core features*):
- Hash-anchored edits (claimed 6.7% → 68.3% edit-success on benchmarked models)
- LSP (40+ languages, 11 operations, auto-formatting, diagnostics)
- Python via IPython kernel with streaming
- Browser automation via Puppeteer + anti-bot stealth
- Git-powered commits with AI-generated conventional-commit messages
- Subagents with **git-worktree / fuse-overlayfs / Windows ProjFS** isolation
- Web search (Exa, Brave, Jina, others)
- SSH tool
- **Native MCP** (no adapter needed)
- 65+ themes with auto dark/light
- Agent Control Center dashboard
- Async background jobs, up to 100 concurrent

**Hook system**: uses its own `.omp/.../hooks/pre/*` shell-style hook layout (different from upstream Pi's TypeScript-module hooks). Mario's X post emphasized that upstream Pi hooks are "stateful TS modules not CLIs (cause we like types, debugging, and state)" — oh-my-pi goes the other direction with file-based shell hooks. [T1: oh-my-pi/docs/hooks.md; X post by badlogicgames 2025-12]

**Compatibility with upstream extensions**: **not documented**. There's a filed discussion (pi-mono#1452) where a user tried to port GSD and settled on oh-my-pi's native Claude-skills support instead. Extensions written against the `@mariozechner/pi-coding-agent` ExtensionAPI are **probably** compatible in principle (same TS types) but this is **UNVERIFIED** and requires T4.

**Adjacent fork**: `az9713/oh-my-pi` — further fork adding telemetry, MCP resilience, test infrastructure, compaction metrics. Indicates active derivative work. [T1]

**Recommendation for Furrow**: picking a target is **load-bearing**:
- If Furrow targets upstream Pi (`pi` command), the user gets a sparse harness + composes community extensions.
- If Furrow targets oh-my-pi (`omp` command), many Furrow-adjacent features (subagent isolation, git commits, MCP) are already native — but Furrow has to live with **shell-style hooks**, a different default tool set, and less certain upstream-extension compatibility.
- The explicit user directive ("pi is rarely used barebones") suggests **testing on both**, and documenting which extensions Furrow expects.

---

## Maintainer recommendations

Mario Zechner publishes **no curated list** and actively resists prescribing extensions. What he endorses (from his Nov 30, 2025 blog post, [T1]):

1. **Externally stateful workflow** — state in files, not in the agent's head.
2. **`TODO.md`** for task lists. Explicit claim: *"to-do lists generally confuse models more than they help"* — **critical for Furrow** because Furrow's core value-prop is workflow state. The harness must demonstrate that its state aids rather than confuses the model. This is the single most important maintainer signal in the corpus.
3. **`PLAN.md`** for plans (shareable across sessions, version-controlled).
4. **`AGENTS.md`** hierarchy (global → project → subdirectory concatenation) for system-prompt customization.
5. **Tmux** for long-running processes (dev server, debugger) — *not* pi's background bash. Cites "observability" advantage.
6. **Bash-spawned subagents** for code review with full visibility (not extension-based subagents).
7. **Restricted tool access during planning**: `pi --tools read,grep,find,ls`.
8. **YOLO mode** acknowledged: *"Everybody is running in YOLO mode anyways to get any productive work done."*

Mario's own production bundle is the `mom` package (Slack bot that delegates to pi) — referenced in the README but not held up as a general template.

**Implication**: Furrow's design already aligns with Mario's "externally stateful" thesis (row state in `.furrow/rows/`, definition/summary as markdown, CLI-mediated mutation). This is a **strategic alignment** worth foregrounding in any Furrow-on-Pi positioning.

---

## Ecosystem competitors for Furrow-shaped functionality

These are workflow/harness-like extensions that overlap with Furrow's value-prop. Furrow must have a clear answer to "why not use X?":

### `fulgidus/pi-gsd` (Get-Shit-Done port)
- **Six-step lifecycle**: new-project → discuss-phase → plan-phase → execute-phase → verify-work → validate-phase. Slash commands per phase. Git-committed `.planning/` directory.
- **57 skills, 18 specialized subagents, background hooks, 4 model profiles (quality/balanced/budget/inherit).**
- **WXP preprocessing engine** — XML preprocessor evaluates commands/conditions/iterations *before* the LLM sees messages. Eliminates round-trips.
- **Overlap with Furrow**: major — both are "impose discipline via a fixed phase sequence". Furrow's edge is CLI-mediated mutation + correction limits + gate protocol.
- [T1: github.com/fulgidus/pi-gsd; also eirondev/pi-gsd, Maleick/gsd-pi exist]

### `omni-pi`
- **Interview → spec → bounded-slice implementation** workflow. `.omni/` directory migrates on first turn. Bundles skill-creator and brainstorming. Maintains runtime repo map in `.pi/repo-map/`. Discovers standards from AGENTS.md/CLAUDE.md/GEMINI.md/Cursor/Windsurf/Continue rules.
- Requires Node 22+.
- **Overlap**: direct (spec-first, phased). Broader source-of-truth discovery than Furrow.
- [T1: npm + github.com/EdGy2k/Omni-Pi]

### `coctostan/pi-superpowers-plus`
- **12 workflow skills** (Brainstorm → Plan → Execute → Verify → Review → Finish).
- **3 runtime extensions**: Workflow Monitor (RED→GREEN→REFACTOR phase tracking, blocks non-TDD edits), Plan Tracker, Subagent dispatcher.
- Injects warnings via pi's tool-result interception. "Skills teach what to do, extensions enforce it in real time."
- **Overlap**: closest to Furrow's spirit — runtime enforcement of a discipline, not advisory. Differs in scope (TDD-specific vs. Furrow's general 7-step + gate protocol).

### `@davidorex/pi-project-workflows` (pi-project + pi-workflows + pi-behavior-monitors)
- **`.project/`** directory — typed JSON blocks validated against user-defined JSON Schemas. "Add a schema, get a block type with tools, validation, derived state." Generic CRUD (issues, decisions, tasks, architecture).
- **`.workflows/`** — YAML DAG workflows with typed input/output per step, `${{ steps.X }}` data flow, `contextBlocks` for injecting project-state into prompts.
- **`pi-behavior-monitors`** — autonomous watchdogs classifying agent activity (similar to pi-supervisor).
- **Outcome-agnostic** — explicitly positioned as workflow-as-a-platform.
- **Overlap**: **deepest** — this is the most direct competitor to a generic Furrow-on-Pi adapter. Differences: pi-workflows uses YAML DAGs, Furrow uses 7-step linear with gate protocol.
- [T1: github.com/davidorex/pi-project-workflows]

### `@callumvass/forgeflow-dev` + `@callumvass/forgeflow-pm`
- Dev pipeline (TDD implementation, code review, architecture, Datadog) + PM pipeline (PRD refinement, issue creation). Two-package split.
- **Overlap**: role-oriented pipelines, narrower than Furrow. [T1: npm]

### `@wizdear/atlas-code`
- "AI Atlas Code Engineering System — Multi-agent orchestration for pi-coding-agent." [T1: npm description only]

### `@a5c-ai/babysitter-pi`
- "Babysitter package" — likely supervision (vague). [T1: npm]

---

## Negative space — what the ecosystem has NOT built

These are gaps a Furrow-on-Pi adapter would need to fill itself (based on absence from the searched corpus):

1. **Formal multi-step gate protocol** — nothing in the corpus implements "advance only on `pass`/`pass-with-fixups`/`fail`" with structured evidence objects. pi-supervisor has a binary steer/complete; pi-gsd has phase commands but no gate evidence contract.
2. **Correction limit with per-deliverable ownership** — pi-permission-system gates *tool calls*, pi-superpowers-plus blocks on TDD violations, but **none track "this deliverable has had N correction attempts, block further writes"** as a first-class concept.
3. **Typed deliverable → test → AC mapping** — superpowers has TDD phase tracking but not explicit AC-to-test mapping.
4. **Row / work-unit archive with review artifacts** — pi-rewind is turn-level, not work-unit-level. Nothing archives a completed work unit with attached reviews.
5. **State-guard hook equivalent** — no ecosystem extension specifically forbids agent edits to a state file via a pre-write hook contract.
6. **Schema-validated CLI-mediated summary updates** — `rws update-summary [name] <section>` has no analogue.
7. **"Eval dimensions" scoring** — no extension ships explicit, multi-dimensional review scoring (correctness, completeness, quality, minimalism).
8. **Prechecked gate / skip-with-record** — no ecosystem equivalent for "this step adds no new information, auto-advance but still record."
9. **Roadmap triage / todos extraction** — `/furrow:triage` and `/furrow:work-todos` have no analogue.
10. **Install-script drift detection** — `install.sh --check` pattern is absent.

**This negative space is Furrow's defensible surface.** Everything else is table stakes the ecosystem already provides.

---

## Composability implications for Furrow

### Compose with (do not reimplement)
- **Subagent dispatch**: target `@tintinweb/pi-subagents` or oh-my-pi's native task tool. Furrow's review/research specialists should run *as* these, with Furrow providing only the row-aware system prompt and acceptance criteria.
- **MCP**: let users pick `pi-mcporter` / `pi-mcp-adapter` / oh-my-pi native. Furrow should not ship an MCP layer.
- **Sandbox**: integrate with `pi-sandbox` at the row boundary — each row becomes a sandbox scope.
- **Checkpoint**: coexist with `pi-rewind` — Furrow row transitions commit; pi-rewind does turn-level.
- **Memory**: integrate at the `.furrow/` namespace — don't manage memory.
- **Permission**: register Furrow gates through `pi-permission-system` where available.
- **Tool display**: zero touch — `pi-tool-display` styles what Furrow emits.

### Patterns a Furrow-on-Pi adapter must respect
1. **Extension entry shape**: `export default function (pi: ExtensionAPI) { ... }`. No custom loading.
2. **Command prefix**: `/furrow:*` commands register via `pi.registerCommand` — this is already the project's convention and remains intact on Pi.
3. **Tool registration via typebox**: custom `frw` / `rws` / `alm` tools must use `@sinclair/typebox` schemas if exposed to the LLM directly — or (preferred) stay as shell CLIs invoked via `bash` tool.
4. **AGENTS.md hierarchy**: Furrow's CLAUDE.md equivalent must be AGENTS.md-compatible. Pi auto-concatenates, so splitting Furrow's ambient layer across `~/.pi/agent/AGENTS.md` and `.pi/AGENTS.md` is natural.
5. **Skills load locations**: if Furrow ships specialists as skills, publish under `~/.pi/agent/skills/` or via `resources.packages` reference.
6. **settings.json merge semantics**: nested-object merge. Furrow can ship a global settings fragment under `resources.extensions` / `resources.skills` without overwriting user config.
7. **Extension compatibility with oh-my-pi is UNVERIFIED**: requires T4. For the initial Furrow-on-Pi release, **target upstream Pi** and mark oh-my-pi as experimental.
8. **Skills spec conformance**: Furrow specialists as skills need `name` (<=64 lowercase+hyphens) and `description` (<=1024 chars) frontmatter.
9. **Row state outside Pi's session state**: `.furrow/rows/**/state.json` should remain independent of Pi's session mechanism — do **not** try to store row state inside Pi's session store. Pi's session is for conversation; Furrow's state is for work units. This matches Mario's "externally stateful" endorsement.
10. **SDK vs TUI entry**: Pi supports `pi --mode rpc --no-session` for subprocess-based integration. If Furrow ever needs to drive Pi programmatically (e.g. from a shell workflow), RPC mode is the documented path — **do not** shell out to the TUI.

### Positioning against Furrow-shaped competitors
- vs **pi-gsd**: Furrow's 7-step is smaller than GSD's 6-phase + 57 skills. Differentiator: **gate evidence protocol + CLI-mediated state**. Pitch Furrow as "leaner GSD with audit trail."
- vs **omni-pi**: omni-pi is interview-first; Furrow starts from a description and can opt into research. Differentiator: **step sequence invariant, correction limits, deliverable ownership.**
- vs **pi-superpowers-plus**: superpowers enforces TDD specifically. Furrow is domain-general. Furrow should ship a TDD profile (specialist + gate dimensions) to close the overlap.
- vs **@davidorex/pi-project-workflows**: davidorex is YAML DAG; Furrow is linear 7-step. Differentiator: **simpler mental model, opinionated review methodology, eval dimensions.** Furrow should not try to become a DAG engine.
- vs **pi-tasks**: pi-tasks is a to-do model; Furrow is a work-unit + gate model. Name the difference loudly in onboarding.

### Concrete do-not-ship list
- Do not ship a subagent dispatcher.
- Do not ship MCP.
- Do not ship sandbox/permission enforcement.
- Do not ship a TUI collapser or theme.
- Do not ship a memory layer.
- Do not ship an LSP bridge.
- Do not ship provider-routing.

---

## Sources Consulted (tiered)

### T1 — primary
- `github.com/badlogic/pi-mono` — repo overview, packages list.
- `github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md` — extensibility philosophy, package discovery.
- `github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md` — Extension API, lifecycle events, loading, distribution.
- `github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/sdk.md` — `createAgentSession`, RPC mode, programmatic entry.
- `github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/skills.md` — agentskills.io spec, skill loading, frontmatter requirements.
- `github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/settings.md` — settings.json layout, resource loading.
- `mariozechner.at/posts/2025-11-30-pi-coding-agent/` — maintainer's workflow endorsement (TODO.md, PLAN.md, AGENTS.md, tmux, YOLO).
- `github.com/can1357/oh-my-pi` — fork, native features, command name `omp`.
- `github.com/can1357/oh-my-pi/blob/main/docs/hooks.md` — shell-style `.omp/.../hooks/pre/*` hook layout.
- `github.com/w-winter/dot314`, `github.com/ben-vargas/pi-packages`, `github.com/coctostan/pi-superpowers-plus` — top starter-pack repos.
- `github.com/tintinweb/pi-subagents`, `github.com/tintinweb/pi-supervisor`, `github.com/tintinweb/pi-tasks`, `github.com/tintinweb/pi-gitnexus`, `github.com/tintinweb/pi-messenger-bridge`, `github.com/tintinweb/pi-schedule-prompt` — tintinweb's prolific cluster.
- `github.com/mjakl/pi-subagent`, `github.com/arpagon/pi-rewind`, `github.com/carderne/pi-sandbox`, `github.com/mavam/pi-mcporter`, `github.com/MasuRii/pi-tool-display`, `github.com/MasuRii/pi-rtk-optimizer`, `github.com/MasuRii/pi-permission-system` — specific extensions verified individually.
- `github.com/fulgidus/pi-gsd` — GSD port README.
- `github.com/davidorex/pi-project-workflows` — schema-driven workflow competitor.
- `github.com/joelhooks/pi-tools` — power-tools bundle.
- `npm registry search (keyword:pi-package, text:pi-coding-agent)` — 1,559 and 73,243 hits respectively; top 80+ enumerated.
- `GitHub search (topic:pi-extension, topic:pi-package)` — 130 and 135 repos respectively.
- `github.com/badlogic/pi-mono/discussions/1452` — maintainer thread on porting GSD.

### T2 — secondary
- Summary by Mario's video "I Hated Every Coding Agent, So I Built My Own" (YouTube) — project positioning.
- `gist.github.com/schpet/85531b6a05a5d8119e859bdec6b0e0b8` — Pi setup guide (no single canonical config).
- `gist.github.com/dabit3/e97dbfe71298b1df4d36542aceb5f158` — "How to Build a Custom Agent Framework with PI" by Nader Dabit.
- DeepWiki entry for oh-my-pi.
- Hacker News thread id=46847867 (Mario on the "shitty" naming).
- X posts: badlogicgames/status/1998562079138082917 (hooks announcement), 1999534755256074354 (skills announcement).

### T3 — corroborative only
- `jprokay.com/post/018-pi-coding-agent` — community setup narrative.
- `atalupadhyay.wordpress.com/2026/02/24/pi-agent-revolution-...` — community narrative.
- `januschka.com/pi-coding-agent.html` — switching to Pi post.
- `rywalker.com/research/pi` — research note.
- npm search snippet descriptions for packages not individually fetched.

### T4 — requires experimentation (NOT done in this survey)
- Whether upstream extensions load cleanly in oh-my-pi.
- Actual runtime behavior of `pi-subagents` + `pi-sandbox` when composed.
- Whether `pi-permission-system` hook ordering interacts with a hypothetical Furrow permission extension.
- Live reliability of `pi.dev/packages` registry (returned an npm-unreachable error during this survey).
- Install-success rate of the top 10 extensions on a clean Pi install.

### UNVERIFIED claims in this survey
- The exact extension-compatibility contract between upstream Pi and oh-my-pi — README silent, discussion thread ambiguous.
- Whether `MasuRii/pi-MUST-have-extension` exists as named (referenced by pi-permission-system README but not found in search).
- Popularity ordering via npm download counts — the pi.dev registry was unreachable during survey; ordering here is by GitHub stars + commit recency, which undercounts skills-only or private packages.
