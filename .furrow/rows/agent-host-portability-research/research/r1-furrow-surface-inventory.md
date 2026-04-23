# R1 — Furrow Current-State Host Surface Inventory

Foundational inventory of every surface on which Furrow depends on its Claude
Code (CC) host. Each surface cites concrete usage sites in the repo at
`/home/jonco/src/furrow`. The goal is to produce a ground-truth reference for
the forthcoming Host Adapter Interface.

Source hierarchy note: all citations are T1 (primary — the Furrow source
repository itself). No external sources consulted.

---

## Surface 1: Namespaced Slash Commands

- **Current CC implementation**: CC discovers markdown files under
  `.claude/commands/*.md` and exposes them as `/name` slash commands. The file
  body becomes the instruction content injected to the conversation when the
  user types the command. CC supports namespacing via filename prefix with a
  colon (e.g., `furrow:work.md` becomes `/furrow:work`). Frontmatter
  (`name`, `description`, `model_hint`, etc.) is recognized for specialist-style
  commands.
- **What Furrow needs**: A way to publish user-invoked entry points — both
  workflow commands (`/furrow:*`) and domain specialists (`/specialist:*`) —
  such that invoking one loads that markdown file as an instruction block into
  the current session. Argument passing via trailing string is assumed.
- **Concrete Furrow usage sites**:
  - `/home/jonco/src/furrow/.claude/commands/furrow:work.md:1` — "# /work
    [description] [--mode research] [--stop-at <step>] [--gate-policy <policy>]
    [--switch <name>]". Parses a free-form argument tail, expects to run bash
    via Bash tool (e.g., `rws init`, `rws focus`, `rws load-step`), and
    explicitly instructs the agent to "Read and follow skills/ideate.md".
  - `/home/jonco/src/furrow/.claude/commands/furrow:status.md:1` — "/status
    [name] [--update] [--all]"; flag parsing described textually.
  - `/home/jonco/src/furrow/.claude/commands/furrow:archive.md:1` — "/archive
    [name]" with optional positional.
  - `/home/jonco/src/furrow/.claude/commands/furrow:review.md:1` — "/review
    [--deliverable <name>] [--re-review]".
  - `/home/jonco/src/furrow/.claude/commands/furrow:checkpoint.md:1` —
    "/checkpoint [--step-end]".
  - `/home/jonco/src/furrow/.claude/commands/furrow:reground.md:1`,
    `furrow:redirect.md:1`, `furrow:triage.md:1`, `furrow:next.md:1`,
    `furrow:work-todos.md:1`, `furrow:init.md:1`, `furrow:doctor.md:1`,
    `furrow:update.md:1`, `furrow:meta.md:1` — each declares its own ad hoc
    argument syntax in a Markdown H1.
  - Specialist commands under `specialist:*.md` (22 files — see
    `.claude/commands/specialist:*.md`), each with YAML frontmatter `name`,
    `description`, `type: specialist`, `model_hint`. Example:
    `/home/jonco/src/furrow/.claude/commands/specialist:harness-engineer.md:1-6`:
    ```
    ---
    name: harness-engineer
    description: Workflow harness infrastructure ...
    type: specialist
    model_hint: sonnet
    ---
    ```
  - Namespacing is established by the installer via symlinks:
    `/home/jonco/src/furrow/bin/frw.d/install.sh:310-314` symlinks
    `commands/*.md` to `$TARGET/commands/${PREFIX}:${_basename}.md`
    (PREFIX defaults to `furrow`); lines 328-335 symlink
    `specialists/*.md` to `$TARGET/commands/specialist:${_basename}.md`.
  - Argument-tail handling is documented in each command body as free-form
    prose; there is no schema. E.g., `furrow:work.md:7-14` describes "Scan
    arguments in order: Extract `--switch <name>` if present..."
- **Coupling strength**: **Medium.** Furrow only needs "markdown file at path
  X becomes invocation /name". Argument parsing is done by the model reading
  the prose spec, not CC. A thin shim that maps the host's "named entry
  point" concept to a file load would work. The `specialist:` prefix is pure
  convention — no host feature depends on it. The namespacing collision-
  avoidance concern (PREFIX in install.sh) is host-specific; other hosts
  might use directories instead of `:`-prefixed filenames.

---

## Surface 2: Hook Registrations (settings.json)

- **Current CC implementation**: `.claude/settings.json` under `hooks.{Event}`
  registers commands for five lifecycle events. Each event takes an array of
  `{ matcher, hooks: [{ type: "command", command: "..." }] }`. CC invokes the
  command at the lifecycle point, passes event-specific JSON on stdin, and
  interprets the exit code (0 = allow, 2 = block with stderr shown, 1 =
  error). The `matcher` filters which tool triggers the event (e.g.,
  `Write|Edit`, `Bash`, empty-string for "any").
- **What Furrow needs**: A host-managed lifecycle with these events:
  PreToolUse (filterable by tool), PostToolUse, Stop (end-of-turn),
  SessionStart, PostCompact. Exit-code semantics: 0 = proceed, 2 = block and
  surface stderr to the model, non-zero other = soft error. Stdin must carry
  tool name + tool input JSON for PreToolUse. PostCompact stdout must be
  re-injected as conversation context.
- **Concrete Furrow usage sites**: All from
  `/home/jonco/src/furrow/.claude/settings.json`:
  - Line 5-12 — `PreToolUse` with matcher `Write|Edit` registers five hooks in
    order: `frw hook state-guard`, `frw hook ownership-warn`, `frw hook
    validate-definition`, `frw hook correction-limit`, `frw hook
    verdict-guard`. Ordering is significant: state-guard blocks first, then
    advisory ownership-warn, etc.
  - Line 14-20 — `PreToolUse` with matcher `Bash` registers `frw hook
    gate-check` and `frw hook script-guard`.
  - Line 22 — `PostToolUse` registered but empty (reserved).
  - Line 23-31 — `Stop` with empty matcher registers `frw hook work-check`,
    `frw hook stop-ideation`, `frw hook validate-summary`.
  - Line 33-39 — `SessionStart` with empty matcher registers `frw hook
    auto-install`.
  - Line 41-47 — `PostCompact` with empty matcher registers `frw hook
    post-compact`.
  - Installer merge logic:
    `/home/jonco/src/furrow/bin/frw.d/install.sh:360-382` copies or jq-merges
    `settings.json` into the target project, using `grep -q "frw hook
    state-guard"` as a presence sentinel (line 364, 173).
  - Drift detection from harness side:
    `/home/jonco/src/furrow/bin/frw.d/scripts/doctor.sh:112-113` verifies each
    expected hook is present by substring-grepping `settings.json`.
- **Coupling strength**: **High.** Furrow depends on (a) the five specific
  event names, (b) matcher semantics to scope PreToolUse, (c) exit code 2
  meaning "block and surface stderr", (d) stdin JSON carrying tool name +
  tool_input with a consistent shape, (e) PostCompact stdout being
  re-injected, and (f) multiple hooks registered for the same event
  executing in order. A port to a different host requires the host to
  offer all five event hooks and the same exit-code contract, or a shim that
  simulates them.

---

## Surface 3: Hook Implementations (stdin/env/exit-code contract)

All hooks live under `/home/jonco/src/furrow/bin/frw.d/hooks/` and are
dispatched by `bin/frw` (sourced via `frw hook <name>`) after sourcing
`bin/frw.d/lib/common.sh`. Each hook is a shell function reading stdin and
returning a numeric code.

Shared dispatcher: `/home/jonco/src/furrow/bin/frw:69-78` sources the hook
script and calls a function `hook_<name with _ for ->`. `FURROW_ROOT` and
`PROJECT_ROOT` env vars are exported by the dispatcher
(`bin/frw:8-12`).

### 3a. `state-guard.sh` (PreToolUse Write|Edit)
- **Host-provided state read**: stdin JSON, `jq -r '.tool_input.file_path //
  .tool_input.path // ""'` at line 10.
- **Exit codes**: 2 to block with stderr "state.json is Furrow-exclusive —
  use frw update-state"; 0 otherwise.
- **CC-specific metadata**: depends on CC's PreToolUse stdin shape
  (`{tool_name, tool_input:{file_path|path}}`).
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/state-guard.sh:7-20`.

### 3b. `ownership-warn.sh` (PreToolUse Write|Edit)
- **Host-provided state read**: stdin JSON `.tool_input.file_path` (line 10).
- **Derived state**: reads `plan.json` wave assignments and `state.json.step`
  (lines 27, 40-42); computes focus via `find_focused_row` from common.sh.
- **Exit codes**: always 0 (advisory); emits `log_warning` to stderr.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/ownership-warn.sh`.

### 3c. `validate-definition.sh` (PreToolUse Write|Edit)
- **Host-provided state read**: stdin JSON `.tool_name` (line 16),
  `.tool_input.file_path // .tool_input.filePath` (line 17).
- **Tool-specific branching**: line 31 — "If it's a Write, definition.yaml
  is being created — skip validation (the content hasn't been written yet
  when PreToolUse fires)". This encodes a specific CC semantic: PreToolUse
  for Write fires before the content is on disk.
- **Exit codes**: 0 valid, 1 usage error, 2 file-not-found, 3 validation
  failure. (Note: the hook uses non-standard non-block codes; only the
  stderr+nonzero behavior is surfaced by CC.)
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/validate-definition.sh:14-134`.

### 3d. `correction-limit.sh` (PreToolUse Write|Edit)
- **Host-provided state read**: stdin `.tool_input.file_path //
  .tool_input.filePath` (line 15).
- **Derived state**: reads `state.json`, `plan.json` wave/deliverable
  file_ownership globs; reads `defaults.correction_limit` from
  `.furrow/furrow.yaml` or `.claude/furrow.yaml`.
- **Exit codes**: 2 (block) when corrections reached; 0 otherwise.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/correction-limit.sh:13-92`.

### 3e. `verdict-guard.sh` (PreToolUse Write|Edit)
- **Host-provided state read**: stdin `.tool_input.file_path //
  .tool_input.path` (line 13).
- **Exit codes**: 2 on any write inside `gate-verdicts/`.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/verdict-guard.sh:11-23`.

### 3f. `gate-check.sh` (PreToolUse Bash)
- **Currently a no-op**: gate validation was folded into `rws transition`
  (file notes it would be circular to pre-check). Always returns 0.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/gate-check.sh:9-16`.

### 3g. `script-guard.sh` (PreToolUse Bash)
- **Host-provided state read**: stdin `.tool_input.command` (line 15).
- **Behavior**: blocks commands that reference `bin/frw.d/` unless they match
  a read-only verb allowlist (`cat`, `grep`, `rg`, `head`, `tail`, `less`,
  etc.). Exit 2 on block with stderr.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/script-guard.sh:12-46`.

### 3h. `work-check.sh` (Stop)
- **Host-provided state read**: none from stdin; walks `.furrow/rows/*/state.json`
  itself.
- **Side effect**: bumps `updated_at` on every active row via
  `frw_update_state` (line 68).
- **Exit codes**: always 0 (advisory warnings via `log_warning`).
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/work-check.sh:6-73`.

### 3i. `stop-ideation.sh` (Stop)
- **Host-provided state read**: none from stdin; reads focused row
  state.json + definition.yaml.
- **Exit codes**: 2 to block session end if ideation step is active but
  `definition.yaml` lacks required fields (objective, deliverables,
  context_pointers, constraints, gate_policy) under non-autonomous policy.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/stop-ideation.sh:18-88`.
- **Note from file (line 6)**: "Hooks cannot read conversation history, so
  field presence is the enforcement mechanism." This is an explicit
  architectural workaround for CC's hook isolation.

### 3j. `validate-summary.sh` (Stop; optionally callable with step arg)
- **Host-provided state read**: optional positional `$1` for step name
  (called from `rws transition`).
- **Exit codes**: 2 to block if summary.md missing required sections.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/validate-summary.sh:13-77`.

### 3k. `auto-install.sh` (SessionStart)
- **Behavior**: detects if `.furrow/furrow.yaml` or `.claude/furrow.yaml`
  exists, runs `frw install --check`, and self-heals via `frw install
  --project` on drift. Emits info to stderr only on drift/repair. Exit 0.
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/auto-install.sh:7-30`.

### 3l. `post-compact.sh` (PostCompact)
- **Stdout is re-injected**: this hook writes a "=== Post-Compaction Context
  Recovery ===" block to stdout including task name, step, status, mode,
  deliverable progress, and full contents of `summary.md` (lines 39-59).
  Relies on CC re-injecting stdout into the conversation after compaction.
- **Exit codes**: 0 on success, 1 on state corruption (after emitting
  STATE CORRUPTION log_error).
- File: `/home/jonco/src/furrow/bin/frw.d/hooks/post-compact.sh:7-62`.

Summary table of host-dependent hook signals:

| Hook | Event | Reads from host | Depends on |
|------|-------|-----------------|------------|
| state-guard | PreToolUse | stdin `.tool_input.file_path\|.path` | exit 2 blocks |
| ownership-warn | PreToolUse | stdin `.tool_input.file_path\|.path` | — advisory only |
| validate-definition | PreToolUse | stdin `.tool_name`, `.tool_input.file_path\|.filePath` | exit 2/3 surfaces stderr; Write-before-content-on-disk semantic |
| correction-limit | PreToolUse | stdin `.tool_input.file_path\|.filePath` | exit 2 blocks |
| verdict-guard | PreToolUse | stdin `.tool_input.file_path\|.path` | exit 2 blocks |
| gate-check | PreToolUse Bash | (no-op) | — |
| script-guard | PreToolUse Bash | stdin `.tool_input.command` | exit 2 blocks |
| work-check | Stop | — (walks fs) | runs at end-of-turn |
| stop-ideation | Stop | — (walks fs) | exit 2 blocks end-of-turn |
| validate-summary | Stop | — (walks fs) | exit 2 blocks end-of-turn |
| auto-install | SessionStart | — | runs once per session |
| post-compact | PostCompact | — | stdout re-injected as context |

- **Coupling strength**: **High** overall. The stdin JSON schemas
  (`tool_input.file_path`/`.path`/`.filePath`/`.command`, `tool_name`), the
  exit-code semantics (especially 2=block), and the PostCompact stdout
  re-injection convention are all CC-native. A port must replicate all
  three or provide a shim translating them.

---

## Surface 4: Skills / Context Injection

- **Current CC implementation**: CC supports two injection mechanisms
  Furrow exercises:
  1. **Ambient context** via `.claude/CLAUDE.md` (auto-loaded per session)
     and `.claude/rules/*.md` (Furrow's install.sh symlinks these per-
     project).
  2. **Instruction-to-load pattern**: a command or hook emits a directive
     like `"Read and follow skills/{step}.md"`, and the agent uses its Read
     tool to load that file. Furrow never relies on CC auto-injecting step
     skills — it relies on the agent reading them on demand.
- **What Furrow needs**: (a) an ambient, always-loaded instruction file
  (CLAUDE.md + rules), (b) a project-rooted files layout the agent can
  Read on instruction, and (c) the PostCompact re-injection hook
  (Surface 3l) to restore context after compaction.
- **Concrete Furrow usage sites**:
  - Layered context budget declared in
    `/home/jonco/src/furrow/.claude/CLAUDE.md` (see rendered in system
    reminder): Ambient <=150 lines, Work <=150, Step <=50, Reference ~600.
  - Ambient layer: `/home/jonco/src/furrow/.claude/CLAUDE.md` + `.claude/
    rules/*.md` (`cli-mediation.md`, `step-sequence.md`). Installer
    symlinks these:
    `/home/jonco/src/furrow/bin/frw.d/install.sh:347-352`.
  - CLAUDE.md Furrow block injection:
    `/home/jonco/src/furrow/bin/frw.d/install.sh:402-445` writes a
    `<!-- furrow:start --> ... <!-- furrow:end -->` block into the target
    project's CLAUDE.md with the command table.
  - Work layer: `/home/jonco/src/furrow/skills/work-context.md` — referenced
    in rationale.yaml line 15 ("Models need step sequence and file
    conventions when a row is active"). Note that nothing auto-injects
    this; skills are loaded on instruction.
  - Step skills: `/home/jonco/src/furrow/skills/{ideate,research,plan,
    spec,decompose,implement,review}.md` — all <=50 lines (budget-enforced
    by `measure-context.sh`).
  - Instruction-to-load mechanism:
    `/home/jonco/src/furrow/bin/rws:2046` — `rws load-step` prints `"Read
    and follow skills/${_ls_step}.md"` and `"Read ${_ls_work_dir}/summary.md
    for context from previous steps."` The agent is expected to act on this
    instruction.
  - Commands that call `rws load-step`:
    - `/home/jonco/src/furrow/.claude/commands/furrow:work.md:25` ("run
      `rws load-step "{name}"` to inject current skill")
    - `furrow:work.md:73` — Continuation path
    - `furrow:reground.md:16` — "run `rws load-step [name]`"
  - Shared skill blocks (`skills/shared/*.md`, 10 files) — referenced on
    demand from step skills, counted in Reference layer by
    `measure-context.sh:65-71`.
  - Context budget enforcement:
    `/home/jonco/src/furrow/bin/frw.d/scripts/measure-context.sh:33-154` —
    computes ambient (`.claude/CLAUDE.md` + `rules/`), work
    (`skills/work-context.md`), step (max of `skills/{step}.md`), and
    reference (`references/` + `skills/shared/`); enforces 120 / 150 / 50
    line budgets and emits FAIL on overage.
  - Post-compact recovery: Surface 3l; also referenced at
    `/home/jonco/src/furrow/skills/work-context.md:68-73` ("After
    compaction or session break, read ONLY: state.json, summary.md,
    Current step's skill").
  - `.claude/rules/cli-mediation.md` and `step-sequence.md` are symlinked
    project-wide by the installer; the model reads them as part of its
    rules layer.
- **Coupling strength**: **Low to medium.** Furrow delegates most skill-
  loading to the agent itself via the "Read and follow" pattern — this
  works on any host with a file-Read tool. The critical host dependency is
  (a) ambient context loading (CLAUDE.md + rules/) and (b) PostCompact
  stdout-injection for recovery. The budget file sizes assume CC's
  injection cost model, but that's tuning, not contract.

---

## Surface 5: Subagent Dispatch

Furrow exercises two subagent mechanisms, both CC-specific.

### 5a. In-process Agent tool dispatch
- **Current CC implementation**: an `Agent(prompt=..., model=...)` tool
  call (sometimes shown as subagent_type, Task, or general-purpose agent)
  spawns an isolated subagent. Per Furrow's notes (see below), these
  subagents do NOT see parent conversation history or prior tool results,
  but DO inherit system context (CLAUDE.md, memory files, MCP tools).
- **What Furrow needs**: a way to spawn a child agent with (i) a curated
  prompt, (ii) a model selector, (iii) isolation from parent conversation
  history, (iv) a return value (structured text/JSON) back into the parent.
  Furrow assumes the parent can dispatch multiple in parallel.
- **Concrete Furrow usage sites**:
  - `/home/jonco/src/furrow/skills/implement.md:62-100` — explicit pseudocode
    `Agent(prompt="""... {deliverable_name} ...""", model="{resolved_model}")`
    with required fields enumerated. Line 69: "The block below is pseudocode
    showing prompt composition structure, not literal tool syntax."
  - `/home/jonco/src/furrow/skills/implement.md:120-130` — Dispatch Checklist
    step 3a: "Spawn the agent. Pass `model` using the model resolution order."
  - `/home/jonco/src/furrow/skills/orchestrator.md:14-26` — "Agent tool with
    curated prompt, model, file_ownership scope"; dispatch table assigns
    agents per step (ideate: fresh reviewer sonnet; research: parallel topic
    investigators opus; etc.).
  - `/home/jonco/src/furrow/skills/shared/context-isolation.md:30-40` —
    "Pass the resolved model as the Agent tool's `model` parameter (valid
    values: `sonnet`, `opus`, `haiku`)."
  - `/home/jonco/src/furrow/skills/shared/gate-evaluator.md:30-35` —
    empirical isolation claim: "Agent tool subagents do NOT receive
    conversation history or prior tool results from the spawning session.
    They DO inherit system context (CLAUDE.md, memory files, MCP tools)."
  - `/home/jonco/src/furrow/skills/shared/gate-evaluator.md:111-128` —
    subagent invocation protocol: shell prepares prompt file, exits with
    signal, in-context agent reads prompt, spawns via Agent tool seeded
    with gate-evaluator.md + prompt, receives structured output.
  - Parallelism expectation:
    `/home/jonco/src/furrow/skills/implement.md:118-131` — "For each
    deliverable in this wave (concurrently)" then "Wait for all agents in
    this wave to complete."
  - Research dispatch: `/home/jonco/src/furrow/skills/research.md:48-54`
    Agent Dispatch Metadata: "Parallel agents per research topic ... opus".

### 5b. Fresh-process isolation via `claude -p --bare`
- **Current CC implementation**: the `claude` CLI is assumed to be on PATH
  and accept `-p` (print mode, one-shot), `--bare` (strips MCP, hooks,
  CLAUDE.md, memory), `--tools`, `--model`, `--system-prompt-file`,
  `--json-schema`, `--max-budget-usd`, `--no-session-persistence`,
  `--output-format json`.
- **What Furrow needs**: a fully-isolated evaluator — zero inherited
  context, bounded budget, JSON-schema-constrained structured output.
- **Concrete Furrow usage sites**:
  - `/home/jonco/src/furrow/.claude/commands/furrow:review.md:52-65` — full
    claude invocation:
    ```
    claude -p \
      --bare \
      --tools "Read,Glob,Grep,Bash" \
      --model opus \
      --system-prompt-file "${prompt_file}" \
      --json-schema "${schema}" \
      --max-budget-usd 2.00 \
      --no-session-persistence \
      --output-format json \
      "Review deliverable: ${deliverable_name}"
    ```
  - Response parsing expectations:
    `/home/jonco/src/furrow/.claude/commands/furrow:review.md:66-70` —
    "Check `is_error` field ... If budget exceeded (`subtype:
    "error_max_budget_usd"`)... Extract `structured_output`..." — an
    implicit response schema.
  - `/home/jonco/src/furrow/skills/review.md:17` — "Runs via `claude -p
    --bare` as an isolated process with no conversation context."
  - `/home/jonco/src/furrow/skills/plan.md:86-88` — "**Fresh Claude
    reviewer** — `claude -p --bare` with plan artifacts, definition.yaml
    ACs, and `evals/dimensions/plan.yaml` dimensions."
  - `/home/jonco/src/furrow/skills/spec.md:75-78` — same for spec.
  - `/home/jonco/src/furrow/skills/ideate.md:35` — `frw
    cross-model-review --ideation <name>` (delegates to a separate cross-
    model binary, but same spawn pattern).
  - `/home/jonco/src/furrow/skills/shared/gate-evaluator.md:35-37` — "For
    maximum isolation (e.g., final review Phase B), use `claude -p --bare`
    which additionally strips system context."
  - Cross-model variant:
    `/home/jonco/src/furrow/bin/frw.d/scripts/cross-model-review.sh`
    dispatched via `frw cross-model-review` (see `bin/frw:144-147`).

- **Coupling strength**: **High.** Furrow's review architecture depends on
  both Agent-tool subagents (for gate evaluation) and a `claude -p --bare`
  CLI (for final review Phase B). The "Agent tool inherits system context
  but not conversation history" is a CC-specific trust boundary that
  informs the separation of gate vs. review. A port would need equivalent
  primitives for (a) in-process isolated spawn and (b) zero-inheritance
  out-of-process spawn with structured output.

---

## Surface 6: MCP Integration

- **Current CC implementation**: CC supports MCP servers via `settings.json`
  (or `~/.claude.json`). MCP tools appear as `mcp__<server>__<tool>` in the
  available tool list.
- **What Furrow needs**: explicitly **nothing**. Furrow ships no MCP
  servers, registers no MCP tools, and treats MCP inheritance as a
  property of the isolation model (gate evaluators inherit MCP; `--bare`
  strips it).
- **Concrete Furrow usage sites**:
  - `/home/jonco/src/furrow/skills/shared/gate-evaluator.md:30-34` — only
    substantive MCP reference: "They DO inherit system context (CLAUDE.md,
    memory files, MCP tools). This isolation level is adequate for gate
    evaluation".
  - `/home/jonco/src/furrow/skills/review.md:17` — "`--bare` strips MCP,
    hooks, CLAUDE.md, memory" (property observed about CC, not something
    Furrow registers).
  - `grep -rn "mcp__" /home/jonco/src/furrow/{bin,skills,.claude,specialists}`
    returns no hits in Furrow's own source.
- **Coupling strength**: **Low.** Furrow only observes that CC can strip
  MCP via `--bare`. No MCP-specific integration is registered. A port
  host need only supply an equivalent "isolated evaluator" primitive;
  MCP itself is out of Furrow's contract.

---

## Surface 7: Harness CLI Dispatcher (host-invariance analysis)

- **What it is**: `/home/jonco/src/furrow/bin/frw` is a pure POSIX shell
  dispatcher that routes subcommands to modules under `bin/frw.d/`. Sister
  CLIs are `bin/rws` (rows), `bin/alm` (almanac), `bin/sds` (seeds).
- **Host-invariant subcommands** (pure shell, no CC assumptions beyond
  local fs):
  - `frw init` (bin/frw:79-81), `frw install` (82-85), `frw root` (163),
    `frw measure-context` (136-139), `frw update-state` (92-95),
    `frw update-deliverable` (96-99), `frw validate-definition` (128-131),
    `frw validate-naming` (132-135), `frw generate-plan` (123-127),
    `frw run-integration-tests` (156-158), `frw merge-to-main` (148-151),
    `frw migrate-to-furrow` (152-155), `frw doctor` (87-91).
  - All of the above depend only on filesystem, `jq`, `yq`, `git`, and
    standard POSIX utilities.
- **Host-integrated subcommands** (assume CC environment):
  - `frw hook <name>` (68-78) — only meaningful when invoked by CC's hook
    lifecycle. Sources `bin/frw.d/hooks/<name>.sh` and calls
    `hook_<name>`.
  - `frw install` writes CC-specific artifacts: symlinks under
    `.claude/commands/`, merges `.claude/settings.json`, injects into
    `.claude/CLAUDE.md`. See install.sh:307-445.
  - `frw launch-phase` (159-161) — shells out to `tmux` and spawns
    `claude` CLI. Depends on the `claude` binary being on PATH.
  - `frw cross-model-review` (144-147) — spawns external model CLI
    (`codex` or `claude`) per `furrow.yaml:cross_model.provider`.
  - `frw run-gate` (106-110) — prepares a prompt file expected to be
    consumed by a CC Agent tool subagent (see gate-evaluator.md
    invocation pattern). Exits with signal codes that the in-context
    agent is supposed to translate into subagent spawns.
- **Concrete citations**:
  - `/home/jonco/src/furrow/bin/frw:1-177` — full dispatcher.
  - `/home/jonco/src/furrow/bin/frw.d/install.sh:113-252` (check mode),
    `307-513` (install mode) — heavy CC coupling.
  - `/home/jonco/src/furrow/bin/frw.d/scripts/launch-phase.sh:24-28` —
    preflight requiring tmux/yq/claude.
  - `/home/jonco/src/furrow/bin/frw.d/hooks/auto-install.sh:19` — runs
    `frw install --check .` to verify CC integration drift.
- **Coupling strength**: **Mixed.** ~70% of frw subcommands are host-
  invariant state/schema/validation operations that operate on `.furrow/`
  files and need no host adapter. The CC-integrated subcommands (hook
  dispatch, install, launch-phase, run-gate, cross-model-review) are the
  adapter boundary. A port would keep bin/frw.d/lib, scripts/update-*,
  scripts/validate-*, scripts/generate-plan, scripts/measure-context,
  scripts/check-artifacts, scripts/select-*, scripts/run-integration-tests,
  scripts/merge-to-main unchanged, and replace only the install/hooks/
  launch-phase/run-gate/cross-model-review layer.

---

## Surface 8: Context Budget Machinery

- **What Furrow assumes about the host**: The host injects three layers
  into every model turn — ambient (CLAUDE.md + rules/), work
  (work-context.md loaded when a row is focused), and step (current step's
  skills/{step}.md). The agent is expected to Read the work- and step-
  layer files on instruction; only the ambient layer is auto-injected by
  the host. The host can compact the conversation and will re-inject from
  the PostCompact hook's stdout.
- **What Furrow needs**: (a) ambient file auto-loading, (b) a file-read
  tool the agent uses for work/step layers, (c) a PostCompact
  re-injection pathway, (d) loose adherence to the documented line
  budgets (120 ambient, 150 work, 50 step, ~600 reference).
- **Concrete Furrow usage sites**:
  - `/home/jonco/src/furrow/.claude/CLAUDE.md` (Context Budget table, in
    the file shown in the system reminder) — budget specification.
  - `/home/jonco/src/furrow/bin/frw.d/scripts/measure-context.sh:33-120` —
    counts lines per layer and enforces budgets.
  - `/home/jonco/src/furrow/skills/work-context.md:66-73` — context
    recovery protocol specifying what to read after compaction.
  - `/home/jonco/src/furrow/bin/frw.d/hooks/post-compact.sh:39-59` —
    emits recovery context to stdout.
  - `/home/jonco/src/furrow/.furrow/almanac/rationale.yaml:78-80` —
    `post-compact.sh` rationale: "Claude Code compaction loses injected
    context; re-injection is needed".
  - `/home/jonco/src/furrow/skills/shared/context-isolation.md:50-83` —
    between-wave context curation protocol assumes agent-controlled
    prompt construction (not host-managed).
- **Coupling strength**: **Low.** The budget numbers are model-compute
  tuning, not a host contract. The only hard host dependency is PostCompact
  (already captured under Surface 3l). Work- and step-layer loading is
  done by the agent reading files, portable to any host with a Read tool.

---

## Cross-reference to rationale.yaml

Entries in `/home/jonco/src/furrow/.furrow/almanac/rationale.yaml` mapped to
surfaces above. Every mentioned `exists_because` that hints at a CC
dependency is captured.

| Rationale entry (path) | rationale.yaml line | Maps to Surface |
|-----------------------|---------------------|-----------------|
| `.claude/CLAUDE.md` | 4-7 | 4, 8 |
| `.claude/settings.json` | 8-10 | 2 |
| `.claude/furrow.yaml` | 11-13 | 7 (furrow config) |
| `skills/work-context.md` | 15-17 | 4 |
| `skills/ideate.md` (and each step skill 22-39) | 19-39 | 4 |
| `skills/shared/red-flags.md` | 41-43 | 4 |
| `skills/shared/eval-protocol.md` | 44-46 | 4 |
| `skills/shared/learnings-protocol.md` | 47-49 | 4 |
| `skills/shared/git-conventions.md` | 50-52 | 4 |
| `skills/shared/context-isolation.md` | 53-55 | 4, 5a (wave isolation) |
| `bin/frw.d/lib/common.sh` | 61-62 | 3 (shared hook utilities) |
| `bin/frw.d/lib/validate.sh` | 63-65 | 7 (host-invariant) |
| `bin/frw.d/hooks/state-guard.sh` | 66-68 | 3a |
| `bin/frw.d/hooks/gate-check.sh` | 69-71 | 3f |
| `bin/frw.d/hooks/ownership-warn.sh` | 72-74 | 3b |
| `bin/frw.d/hooks/work-check.sh` | 75-77 | 3h |
| `bin/frw.d/hooks/post-compact.sh` | 78-80 | 3l, 8 |
| `bin/frw.d/scripts/measure-context.sh` | 82-84 | 8 |
| `bin/frw.d/scripts/doctor.sh` | 85-87 | 7 |
| `install.sh` | 89-91 | 1, 2, 4 (installer wires CC) |
| `bin/frw.d/scripts/run-gate.sh` | 92-94 | 5a (subagent orchestration) |
| `bin/frw.d/scripts/check-artifacts.sh` | 95-97 | 7 (invariant) |
| `bin/frw.d/scripts/select-gate.sh` | 98-100 | 7 (invariant) |
| `bin/frw.d/scripts/update-deliverable.sh` | 101-103 | 7 (invariant) |
| `bin/frw.d/scripts/update-state.sh` | 104-106 | 7 (invariant) |
| `bin/frw.d/scripts/validate-definition.sh` | 107-109 | 7 (invariant) |
| `bin/frw.d/scripts/validate-naming.sh` | 110-112 | 7 (invariant) |
| `schemas/*.schema.json` | 114-119 | 7 (invariant) |
| `references/*.md` | 121-147 | 4 (on-demand Reference layer) |
| `skills/shared/gate-evaluator.md` | 168-170 | 5a |
| `adapters/*` (claude-code, agent-sdk) | 172-262 | (pre-existing adapter layer — see Unknowns #1) |
| `evals/gates/ideate.yaml`, `evals/gates/review.yaml` etc. | 164-167, 264-266, 397-399 | 5a (dimensions consumed by isolated evaluator) |
| `bin/frw.d/hooks/validate-definition.sh` | 267-269 | 3c |
| `bin/frw.d/hooks/stop-ideation.sh` | 270-272 | 3i |
| `bin/frw.d/hooks/validate-summary.sh` | 274-276 | 3j |
| `commands/lib/validate-learning.sh`, `append-learning.sh`, `promote-learnings.sh`, `promote-components.sh` | 278-289 | 1 (invoked from slash commands) |
| `bin/frw.d/hooks/auto-install.sh` | 294-296 | 3k |
| `bin/frw.d/scripts/launch-phase.sh` | 298-300 | 7 (host-integrated; spawns claude+tmux) |
| `bin/frw.d/scripts/run-ci-checks.sh` | 302-304 | 7 (invariant) |
| `bin/frw.d/scripts/merge-to-main.sh` | 305-307 | 7 (invariant) |
| `commands/*.md` (work, checkpoint, archive, status, review, reground, redirect, furrow, next) | 315-341 | 1 |
| `bin/frw.d/scripts/cross-model-review.sh` | 368-370 | 5b |
| `bin/frw.d/scripts/evaluate-gate.sh` | 371-373 | 5a, 7 |
| `bin/frw.d/scripts/generate-plan.sh` | 374-376 | 7 (invariant) |
| `bin/frw.d/scripts/select-dimensions.sh` | 383-385 | 7 (invariant) |
| `bin/frw.d/hooks/correction-limit.sh` | 387-389 | 3d |
| `bin/frw.d/hooks/verdict-guard.sh` | 390-392 | 3e |
| `bin/alm`, `bin/rws`, `bin/sds` | 401-409 | 7 (invariant) |
| `specialists/*.md` (22 entries) | 182-186, 411-464 | 1, 5a |

### Entries that do NOT map to a Surface (flagged as interface gaps)

- `adapters/` tree (lines 172-262 in rationale.yaml) — an existing
  dual-runtime adapter scaffold for Claude Code + Agent SDK. This tree
  predates the Host Adapter Interface work but is conceptually the same
  concern. **Interface gap candidate**: reconcile/replace this with the
  proposed HAI.
- `.furrow/_meta.yaml` (line 176-178) — row-template metadata. Pure
  filesystem convention, no host dependency.
- `schemas/plan.schema.json`, `review-result.schema.json`,
  `gate-record.schema.json` (lines 213-221 under
  `adapters/shared/schemas/`) — schemas consumed by host-invariant code,
  no host dependency.

---

## Unknowns / flagged as ambiguous

1. **Pre-existing `adapters/` tree vs. the proposed HAI**: the repo
   already contains `/home/jonco/src/furrow/adapters/` with `claude-code/`
   and `agent-sdk/` subdirectories and rationale entries at lines 172-262.
   Its relationship to the forthcoming Host Adapter Interface is not
   stated in the source — it may be a stale attempt at the same concern.
   Confirm whether HAI subsumes/replaces it or coexists.
2. **`frw hook gate-check` no-op**: the hook exists in settings.json and
   rationale.yaml but its implementation is a no-op explained by
   inline comment (gate-check.sh:9-16) as "folded into rws transition".
   It still occupies a PreToolUse Bash slot; a port could drop it. Flag:
   is registration of no-op hooks part of the contract, or dead wood?
3. **Stdin JSON schema variation**: hooks accept
   `.tool_input.file_path`, `.tool_input.filePath`, or `.tool_input.path`
   interchangeably (see state-guard.sh:10, validate-definition.sh:17,
   correction-limit.sh:15). This suggests CC has had/has multiple
   schemas over time. The adapter should either normalize these or
   document which are authoritative.
4. **`Agent()` pseudocode vs. real tool syntax**: implement.md:69
   explicitly says the block is pseudocode. The actual CC tool name
   and parameter shape (Agent, Task, subagent_type, …) is not pinned in
   Furrow's own source. Confirm the exact CC tool name and whether it
   accepts a `model` parameter directly, versus routed via subagent
   definition.
5. **PreToolUse-on-Write semantic**: validate-definition.sh:31 encodes
   "on Write, PreToolUse fires before content is on disk; skip
   validation". This should be stated as part of the host contract. For
   other hosts (e.g., an SDK host), write lifecycles may differ.
6. **`.focused` sidecar file**: Furrow maintains `.furrow/.focused` as
   cross-session "which row is active" state (common.sh:210-227,
   furrow:work.md:51-66). This is pure filesystem state, but Furrow
   assumes single-writer — concurrent sessions on the same repo could
   race. Ambiguous whether the host is expected to enforce single-
   session-per-project.
7. **PostToolUse registered empty**: settings.json:22 registers an
   empty PostToolUse array. Signals intent to occupy but currently
   does nothing. Flag whether the interface must expose it.
8. **`frw install`'s merge contract**: install.sh:369-372 jq-merges the
   existing `settings.json` by concatenating `hooks` entries from Furrow
   into the project's existing map. Behavior under conflicting existing
   hook commands is undefined; may over-install. A port needs a hook-
   registration semantic that doesn't require a user-level JSON merge.

---

## Sources Consulted

- T1: `/home/jonco/src/furrow/.claude/commands/` — 14 furrow:* command
  files and 22 specialist:* files enumerated (Bash `ls` output).
- T1: `/home/jonco/src/furrow/bin/frw.d/hooks/` — 12 hook scripts read
  in full (state-guard, ownership-warn, validate-definition,
  correction-limit, verdict-guard, gate-check, script-guard, work-check,
  stop-ideation, validate-summary, auto-install, post-compact).
- T1: `/home/jonco/src/furrow/skills/` — work-context.md, orchestrator.md,
  ideate.md, research.md, plan.md, spec.md, decompose.md, implement.md,
  review.md, and shared/{context-isolation,gate-evaluator,
  specialist-delegation}.md read in full; other shared/*.md enumerated.
- T1: `/home/jonco/src/furrow/.furrow/almanac/rationale.yaml` — 464
  lines read in full.
- T1: `/home/jonco/src/furrow/.claude/settings.json` — full file.
- T1: `/home/jonco/src/furrow/.claude/rules/{cli-mediation,
  step-sequence}.md`.
- T1: `/home/jonco/src/furrow/bin/frw` — full dispatcher (177 lines).
- T1: `/home/jonco/src/furrow/bin/frw.d/install.sh` — install/check
  functions read (lines 1-252 execution-safe, 100-513 via Read).
- T1: `/home/jonco/src/furrow/bin/frw.d/lib/common.sh` — full file.
- T1: `/home/jonco/src/furrow/bin/frw.d/scripts/measure-context.sh`,
  `launch-phase.sh` — read.
- T1: `/home/jonco/src/furrow/bin/rws:2025-2065` — `load-step` subcommand
  body.
- T1: `/home/jonco/src/furrow/install.sh` — bootstrap symlink script.
- T1: `/home/jonco/src/furrow/.claude/furrow.yaml` — project config
  template.

Inventory complete — 8 surfaces, 63 usage sites cited.
