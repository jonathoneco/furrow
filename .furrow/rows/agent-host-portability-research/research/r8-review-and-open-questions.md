# R8 Review & Open Questions

**Row**: `agent-host-portability-research`
**Step**: research (end-of-step review)
**Date**: 2026-04-22
**Purpose**: user review of R8 ecosystem findings + answer open questions that gate plan-step decisions

Source document: `r8-pi-ecosystem-survey.md` (~430 lines). This file summarizes + extracts decisions for your answer.

---

## R8 — full summary

### Ecosystem scale & shape

- **1,559 npm packages** under `pi-package`, **130+ GitHub repos** tagged `pi-extension`, **135+** tagged `pi-package`. Most pushed in the last 30 days.
- Dominated by **single-author "personal pack" repos**, not corporate libraries. Highest-starred: `w-winter/dot314` (30+ extensions, 90 stars), `coctostan/pi-superpowers-plus` (62), `ben-vargas/pi-packages` (57).
- Distribution uniform and simple: `pi install npm:<pkg>` / `pi install git:<url>` / `resources.packages` in settings.json. Auto-discovery from `~/.pi/agent/extensions/*.ts` and `.pi/extensions/*.ts`. TypeScript compiled on-the-fly (no build step).
- Official browser: `pi.dev/packages` (was `shittycodingagent.ai/packages`). **Registry returned npm-unreachable during survey** — reliability is an open concern.

### Two distinct migration targets

**Upstream `@mariozechner/pi-coding-agent` (command: `pi`)**

- Sparse core; compose with community extensions. Hooks are **stateful TypeScript modules** (Mario's explicit design choice — "we like types, debugging, and state").
- Philosophically aligned with Furrow's external-state approach.

**`can1357/oh-my-pi` fork (command: `omp`, package `@oh-my-pi/pi-coding-agent`)**

- **Different codebase, different command, different hook style** (shell-style `.omp/.../hooks/pre/*`).
- v14.1.2, 322 releases, 4,240 commits, dual copyright. **Batteries-included**: native LSP (40+ languages), Python via IPython, Puppeteer browser, subagents with **git-worktree / fuse-overlayfs / ProjFS isolation** (most sophisticated in corpus), native MCP, hash-anchored edits (6.7% → 68.3% edit success), Agent Control Center.
- **Extension compatibility with upstream is UNVERIFIED** — README silent, one discussion thread ambiguous, requires T4.
- Further fork exists (`az9713/oh-my-pi`) adding telemetry and MCP resilience — fragmentation risk.

> I want to go with pi-coding-agent and compose with community extensions

### Mario's endorsements (maintainer signal)

From his Nov 30, 2025 blog post — **he publishes no curated extension list, actively resists prescribing**. What he does endorse:

1. Externally stateful workflow — state in files, not in the agent's head
2. `TODO.md`, `PLAN.md`, `AGENTS.md` hierarchy (global → project → subdir, auto-concatenated)
3. **Tmux for long-running processes** — not pi's background bash, cites observability advantage
4. **Bash-spawned subagents for code review with full visibility** — not extension-based
5. Restricted tool access during planning: `pi --tools read,grep,find,ls`
6. **"Everybody runs YOLO mode anyway to get productive work done"**

**His one warning that lands on Furrow's core**: _"to-do lists generally confuse models more than they help."_ Furrow's counter: `state.json` is hook-guarded and never model-facing; `summary.md` is bounded to ≤150 lines. **Untested at Pi workload.** R8 flags this as load-bearing for positioning.

> I think this is also a problem with naive todo lists, we are not prescribing specific implementation steps but reasoning about and breaking down deliverables, and using seeds / work-items to understand dependencies and such, so I'm not sure this warning applies to furrow's approach

### Ecosystem competitors that overlap with Furrow's value prop

| Competitor                          | Shape                                                                                                     | Overlap                                                           | Depth                   |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------- | ----------------------- |
| `fulgidus/pi-gsd` (+ clones)        | 6-phase lifecycle, 57 skills, 18 subagents, WXP XML preprocessor                                          | major — fixed phase sequence                                      | deep                    |
| `@davidorex/pi-project-workflows`   | Typed `.project/` blocks + YAML DAG `.workflows/` + behavior-monitors                                     | **deepest** — generic workflow-as-platform                        | deep                    |
| `omni-pi`                           | Interview → spec → bounded-slice implementation, auto-discovers AGENTS.md/CLAUDE.md/Cursor/Windsurf rules | direct — spec-first, phased                                       | moderate                |
| `coctostan/pi-superpowers-plus`     | 12 skills + 3 runtime extensions, TDD RED→GREEN→REFACTOR enforcement via tool-result interception         | closest to Furrow's spirit (runtime enforcement) but TDD-specific | moderate                |
| `@tintinweb/pi-tasks`               | Claude-Code-style tracking: 7 LLM-callable tools, DAG deps, cycle detection, auto-cascade                 | direct with Furrow's row state machine                            | narrow but load-bearing |
| `@callumvass/forgeflow-dev` + `-pm` | Role-oriented pipelines (TDD + PM)                                                                        | narrower, role-split                                              | shallow                 |

**Strategic implication**: Furrow enters a competitive niche, not a vacuum. Positioning must name what Furrow is _not_.

> I am not worried about positioning, this is personal tooling derived from he way I like to work and I like my approach, but I am interested in what I can learn from / integrate from these competitors to augment my work

### Gap-fillers for Pi core gaps

| Pi core gap         | Ecosystem fillers                                                                                                                                          | Winner?                                                                      |
| ------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------- |
| Subagent dispatch   | `@tintinweb/pi-subagents` (181★, parallel/queueing/steering), `mjakl/pi-subagent` (minimal), `@ifi/pi-extension-subagents`, oh-my-pi native (git-worktree) | **no single winner** — isolation semantics vary (process/worktree/FUSE/none) |
| MCP                 | `mavam/pi-mcporter` (single-tool proxy, 13★), `nicopreme/pi-mcp-adapter` (general), `joelhooks/pi-tools/mcp-bridge` (OAuth), oh-my-pi native               | multiple viable; no dominant                                                 |
| Sandbox             | `carderne/pi-sandbox` (OS-level, 48★)                                                                                                                      | canonical                                                                    |
| Permission gates    | `MasuRii/pi-permission-system` (in-process hooks, 19★), `dtmirizzi/pi-governance` (RBAC/DLP/HITL)                                                          | tension between OS-level and lifecycle-hook paradigms                        |
| Checkpoint / rewind | `arpagon/pi-rewind` (git-ref snapshots, redo stack, 33★)                                                                                                   | canonical                                                                    |
| Persistent memory   | `@samfp/pi-memory`, `jayzeng/pi-memory`, `MattDevy/pi-continuous-learning`                                                                                 | multiple viable                                                              |
| LSP                 | `pi-lens`, oh-my-pi native                                                                                                                                 | oh-my-pi native dominates                                                    |
| Observability       | `imran-vz/pi-observability`, `nicopreme/pi-powerline-footer`, `mavam/pi-fancy-footer`                                                                      | multiple, stylistic                                                          |

> One thing I remember is a distancing from MCP towards cli and more explicit tooling, is MCP portability really the right move or is it round peg square hole

### Furrow's defensible negative space

What R8 did NOT find in the ecosystem — Furrow's legitimate differentiators:

1. **Formal multi-step gate protocol** with `pass`/`pass-with-fixups`/`fail` + structured evidence objects
2. **Correction limit with per-deliverable ownership** (not just tool-level gating)
3. **Typed deliverable → test → AC mapping**
4. **Row/work-unit archive with attached review artifacts**
5. **State-guard hook forbidding agent edits to state files via pre-write contract**
6. **Schema-validated CLI-mediated summary updates** (no `rws update-summary` analogue)
7. **Multi-dimensional eval scoring** (correctness/completeness/quality/minimalism)
8. **Prechecked gate / skip-with-record**
9. **Roadmap triage / todos extraction** (`/furrow:triage`, `/furrow:work-todos`)
10. **Install-script drift detection** (`install.sh --check`)

> furrow is not a competitor, I'm not worried about market positioning, I want to understand how to get furrow, working well with pi and it's ecosystem, for **me** and my friends who have liked furrow

### Compose-list recommendations

| Compose with (do not rebuild)                      | Pattern                                                                        |
| -------------------------------------------------- | ------------------------------------------------------------------------------ |
| `@tintinweb/pi-subagents` or oh-my-pi native       | specialists run as pi-subagents; Furrow provides row-aware system prompt + ACs |
| `pi-mcporter` / `pi-mcp-adapter` / oh-my-pi native | let users pick; Furrow has no MCP layer                                        |
| `pi-sandbox`                                       | each row = sandbox scope                                                       |
| `pi-rewind`                                        | coexist; rewind is turn-level, Furrow row-commits at transition                |
| Memory extensions                                  | Furrow namespaces memory to `.furrow/` instead of owning                       |
| `pi-permission-system`                             | register Furrow gates through its hook API                                     |
| `pi-tool-display`                                  | zero touch; styles what Furrow emits                                           |

> Explain the memory extensions as well

### Patterns the Furrow-on-Pi adapter MUST respect

1. `export default function (pi: ExtensionAPI) { ... }` — extension entry shape
2. `/furrow:*` commands via `pi.registerCommand` (matches our convention)
3. TypeBox schemas if tools are LLM-facing; else stay shell CLIs invoked via `bash`
4. AGENTS.md hierarchy — split across `~/.pi/agent/AGENTS.md` + `.pi/AGENTS.md` (Pi auto-concatenates)
5. Skills frontmatter: `name` (≤64 lowercase+hyphens), `description` (≤1024 chars)
6. settings.json merge is nested-object not replace
7. **Row state outside Pi's session state** — `.furrow/rows/**/state.json` stays independent
8. Programmatic driving uses `pi --mode rpc --no-session`, not the TUI

---

## Open questions

Answer any subset inline. One-liners fine. Grouped by decision weight.

### Target decision (plan-step blocker)

**Q-A1 — Upstream Pi vs oh-my-pi**
Upstream aligns with Mario + widest extension compatibility but no batteries. oh-my-pi is batteries-included and has best subagent isolation story (git-worktree/FUSE) but different hook style, different command name, and extension compat UNVERIFIED.

- (a) Target upstream only; document oh-my-pi as unsupported
- (b) Target both; fork adapter if needed
- (c) Target oh-my-pi; accept hook-model divergence and bet on feature superset

> YOUR ANSWER: Option A

**Q-A2 — Subagent filler**
If upstream: which subagent filler standardize on? `@tintinweb/pi-subagents` (181★, dominant) vs `mjakl/pi-subagent` (minimal) vs vendor Pi's 34KB example? Isolation semantics diverge.

> YOUR ANSWER: the dominant one

**Q-A3 — Sandboxing/permission paradigm**
`pi-sandbox` (OS-level, mature) vs `pi-permission-system` (in-process hooks, composable with Pi lifecycle)? Different enough that choosing affects correction-limit architecture.

> YOUR ANSWER: I'd like more info to make an informed decision here

### Composability & positioning

**Q-B1 — `pi-tasks` overlap**
`pi-tasks` (DAG task tracking with 7 LLM-callable tools) is a direct competitor to Furrow's row state machine. Position Furrow as enforcement/gate-oriented (not tracking), or find a way to compose?

> YOUR ANSWER: I don't care about positioning, is there anything I can learn from tasks to improve furrow

**Q-B2 — `pi-gsd` differentiation**
`pi-gsd` is a 6-phase spec-driven port with 57 skills + 18 subagents. Effectively Furrow-shaped. R8's suggestion: lead with gate-evidence protocol + CLI-mediated state. Agree, or different positioning?

> YOUR ANSWER: Same answer

**Q-B3 — `@davidorex/pi-project-workflows` differentiation**
Deepest competitor — generic workflow-as-platform with typed JSON Schema blocks + YAML DAG workflows. R8 recommends Furrow **not** try to become a DAG engine. Agree?

> YOUR ANSWER: Same answer

**Q-B4 — TDD profile**
Should Furrow ship a TDD profile (specialist + gate dimensions) as explicit compose target with `pi-superpowers-plus`? Closes overlap without competing head-on.

> YOUR ANSWER: Same Answer

### Mario-signal handling

**Q-C1 — Empirical validation of "to-do lists confuse models"**
Do we validate this empirically during migration (measure model-facing context on Pi vs Mario's lean-setup)? R8 flags this as the single most important maintainer signal. Proposal: add a measurement deliverable to the gap-analysis.

> YOUR ANSWER: What is Mario's lean setup? I answered by initial thoughts above

**Q-C2 — Tmux integration**
Mario endorses tmux for long-running processes over pi's background bash. Furrow need a tmux integration pattern for implementation-step parallel specialists, or does `pi-subagents` cover it?

> YOUR ANSWER: I already use tmux and there are some existing integrations i.e. via furrow:next, what more specifically is being asked here?

**Q-C3 — Subagent paradigm: extension vs bash-spawn**
Mario endorses bash-spawned subagents for code review with full visibility — different from extension-based. R8's compose recommendation is `pi-subagents`, but Mario's blog prefers bash-spawn. Two paradigms; pick one per specialist type?

> YOUR ANSWER: Give me more context to provide an informed answer

### Technical T4 open questions (require experimentation)

**Q-D1** — Does `@tintinweb/pi-subagents` correctly preserve context isolation when a Furrow specialist is spawned with a custom system prompt + skill set?

> YOUR ANSWER: Research this, and any other such tooling answer, all of this is open-source

**Q-D2** — Can Furrow's `state-guard` be implemented via `pi.on('tool_call', ...)` with early return, OR is a `pi-permission-system` integration cleaner?

> YOUR ANSWER: Research

**Q-D3** — Does Pi's `session_compact` hook fire BEFORE compaction (can inject) or AFTER (can only repair)? Furrow's `post-compact.sh` relies on former.

> YOUR ANSWER: Check

**Q-D4** — Upstream-Pi extensions installed into oh-my-pi — do they load? If yes, targeting both hosts with one adapter feasible. If no, Q-A1 option (b) is off the table.

> YOUR ANSWER: Not worried

**Q-D5** — Does `pi --mode rpc --no-session` support the full extension lifecycle, or only a subset? Determines whether Furrow can drive Pi programmatically from shell scripts.

> YOUR ANSWER: Check

**Q-D6** — `pi.dev/packages` registry reliability — if flaky, Furrow's install script needs an npm-direct fallback.

> YOUR ANSWER: Check

### Structural gaps

**Q-E1 — Specialist packaging surface**
Does Furrow ship specialists as **skills** (Pi loads from `~/.pi/agent/skills/`), **extensions** (Pi loads from `extensions/`), or **bash-CLI prompts**? Each has different composability. Lean: skills for model-facing specialists; extensions only for hook infrastructure.

> YOUR ANSWER: Check what the community tends to do

**Q-E2 — Supervisor integration**
`pi-behavior-monitors` (davidorex) and `pi-supervisor` both implement "separate-LLM observer steers main agent." Compose with supervisor for row-level review gates, or keep reviews in our own process?

> YOUR ANSWER: What can we learn from these for our reviews / observer / orchestrator pattern

**Q-E3 — AGENTS.md hierarchy split**
Furrow's CLAUDE.md content needs to port. Pi auto-concatenates global → project → subdir. Does ambient rule set split cleanly across three levels, or need restructuring?

> YOUR ANSWER: Give me more context

---

## Note

**None of these block the research → plan transition** — they're all appropriate to resolve in the plan step. Answering here means plan step opens with pre-loaded decision queue rather than discovering them mid-flight. Skip any you want to defer to plan.
