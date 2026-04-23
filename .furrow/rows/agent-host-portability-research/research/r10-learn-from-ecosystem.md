# R10 — Learn-from-Ecosystem Patterns

**Scope**: Mine the Pi coding-agent ecosystem for design ideas Furrow could adopt. Positioning is out of scope. Every pattern ends with an adoption verdict.

---

## Summary

- **The ecosystem has solved three problems Furrow hasn't fully solved**: (1) typed data flow between workflow steps (pi-project-workflows), (2) continuous observer loops (pi-supervisor), and (3) activity-classification monitors with learn-new-patterns feedback (pi-behavior-monitors).
- **Furrow already matches or exceeds the ecosystem on** schema-validated state, multi-dimensional eval scoring, and specialist-as-domain-expert framing. Don't water these down.
- **One pattern is worth urgent adoption**: typed step I/O with `${{ steps.X }}` expression references, because it directly sharpens deliverable AC and eliminates prose-to-structured-data handoffs that currently depend on LLM discipline.
- **One pattern is surprisingly powerful**: WXP XML preprocessing pre-executes deterministic work (arg parsing, shell calls, iteration, conditionals) before the LLM sees the prompt. Furrow's CLI-mediation philosophy is adjacent to this but doesn't pre-resolve prompt-time data.
- **One pattern to skip**: pi-tasks' DAG with non-blocking cycle warnings. Furrow's culture is hard-block-over-auto-correct; storing invalid edges contradicts that.

---

## Pattern 1: WXP XML preprocessor (from pi-gsd)

- **What it does**: A preprocessing engine runs BEFORE the LLM sees the prompt. It evaluates XML elements embedded in skill/command files — `<gsd-arguments>` parses typed args, `<shell command="...">` executes allowlisted commands via `execFileSync`, `<if><condition><then>` branches, `<for-each var="...">` iterates arrays (with optional `<where>` filter), `<json-parse src="...">` extracts scalars from JSON, `<read-file>` / `<write-file>` do controlled I/O, `<gsd-paste name="...">` inlines results. Security: allowlist of commands (`pi-gsd-tools git node cat ls echo find`), `.planning/` paths excluded from preprocessing.
- **Why it's novel**: Most harnesses either (a) inline shell calls that the LLM executes, burning a round-trip per deterministic operation, or (b) template-inject static text. WXP does *deterministic pre-resolution of prompt-time data* with a proper schema (Zod-validated in `src/schemas/wxp.zod.ts`). The model never sees "call bash to get phase number then call bash to get git branch then..." — it sees already-filled values. Result: fewer round-trips, smaller context, less LLM-as-bash-orchestrator pattern.
- **Furrow adoption potential**: **medium** — with caveats.
- **If adopt**: Furrow's skills (`skills/*.md`) and specialist templates currently rely on the LLM invoking `rws status`, `rws update-summary`, `alm …` as sub-agent tool calls. A WXP-like layer could pre-execute these at skill-load time. Concrete change: allow skill files to embed `<frw-state row="current"/>` that the harness replaces with the output of `rws status --json` before the LLM sees the skill. Eliminates the "call status, read it, then act" round-trip that nearly every Furrow step begins with. Risks: adds an XML parser/evaluator to bin/frw.d/; violates the "plain markdown skills" simplicity; breaks portability across hosts that don't preprocess.
- **Furrow already has**: `frw measure-context`, `rws regenerate-summary`, and context layer limits — but these are offline/validation, not prompt-time pre-resolution.
- **Verdict**: Adopt in a narrow form — a `{{ frw.status }}` style template substitution in work-context.md would capture 80% of the value without an XML engine. Skip the full XML DSL.
- **Source (T1)**: `github.com/fulgidus/pi-gsd` README + `src/schemas/wxp.zod.ts` reference.

---

## Pattern 2: Typed project blocks with JSON Schema (from pi-project-workflows)

- **What it does**: `.project/*.json` files (issues, decisions, rationale, architecture, conventions, requirements, conformance, domain, tasks, exploration — 13 default block types) are each validated at write-time against a user-defined JSON Schema in `.project/schemas/`. Generic CRUD tools (`append-block-item`, `update-block-item`, `read-block`, `write-block`) require zero code change when you add a new block type — you just add a schema.
- **Why it's novel**: Separates "knowledge container" from "write machinery". Furrow's `.furrow/almanac/{rationale,roadmap,todos}.yaml` are hand-curated YAML files with no schema enforcement and no generic CRUD surface. Each file has bespoke commands (`alm rationale add`, `/furrow:triage`) that encode structure implicitly.
- **Furrow adoption potential**: **high**.
- **If adopt**: Define JSON Schemas for `roadmap.yaml`, `todos.yaml`, `rationale.yaml` in `.furrow/almanac/schemas/`. Let `alm` become schema-generic: `alm append <block> <item-json>`, `alm update <block> <id> <patch>`, `alm read <block>`. Adding a new almanac file (e.g., `decisions.yaml`) then requires only a schema, no new CLI plumbing. Pairs naturally with Furrow's "CLI-mediated state" rule — schema validation is exactly where CLI mediation earns its keep.
- **Furrow already has**: schema validation on `state.json` and `summary.md` sections. It doesn't have this generic pattern for the almanac.
- **Verdict**: Adopt. This is high-leverage cleanup that reduces CLI surface area while increasing safety.
- **Source (T1)**: `github.com/davidorex/pi-project-workflows` README.

---

## Pattern 3: YAML DAG workflow with typed step I/O (from pi-project-workflows)

- **What it does**: `.workflows/*.workflow.yaml` files define a DAG of steps. Each step has an `agent:`, an `input:` (Nunjucks template with `${{ input.X }}` and `${{ steps.Y.output }}` references), and an `output.schema:` that validates what the step produces. DAG parallelism is *inferred* from expression references — no explicit `dependsOn:`. Data flows as typed JSON, not strings, with filters (`| json`, `length`, `keys`, `filter`). Each step runs as a subprocess (`pi --mode json`) with its own context window.

  ```yaml
  steps:
    investigate:
      agent: investigator
      input: "Investigate: ${{ input.target }}"
      output:
        schema: investigation-findings
    synthesize:
      agent: synthesizer
      input: "Findings: ${{ steps.investigate.output | json }}"
  ```

- **Why it's novel**: Two properties are hard to get right and this has both: (a) typed contracts at step boundaries (downstream consumer knows the shape of upstream output), (b) dependency *inference* from data references (no duplicate DAG declaration).
- **Furrow adoption potential**: **high** — directly applicable to deliverables.
- **If adopt**: Furrow's deliverables already have acceptance criteria. Extend definition.yaml to let a deliverable declare `produces:` (typed output schema — e.g., "file paths touched", "tests added", "migration scripts") and let downstream deliverables declare `consumes: [deliverable-name.output.files]`. The decompose step becomes a DAG planner. The implement step validates each deliverable's output against its `produces:` schema before marking complete. This sharpens AC from "prose statements of done" to "JSON-verifiable artifacts."
- **Furrow already has**: deliverables, AC, the decompose step.
- **Verdict**: Adopt in phased form. Start by letting deliverables declare an `output_schema` (what artifacts they produce) and validate at `rws complete-deliverable`. Defer the full `${{ steps.X }}` expression engine until demand is clear.
- **Source (T1)**: `github.com/davidorex/pi-project-workflows` package README.

---

## Pattern 4: Runtime enforcement via tool-result interception (from pi-superpowers-plus)

- **What it does**: The Workflow Monitor extension hooks `tool-result-post` events. After each tool call completes, the monitor inspects it against a state machine (TDD: RED → GREEN → REFACTOR). If the agent writes production code without a failing test, the monitor *injects a warning into the tool result* — the LLM sees an augmented response in its next turn. TUI widget shows live phase: `TDD: RED` / `TDD: GREEN` / `TDD: REFACTOR`. Location: `extensions/workflow-monitor/tdd-monitor.ts`.
- **Why it's novel**: Most enforcement runs at commit-time, test-time, or hook-time (PreToolUse denies the call). Post-result injection lets the tool call succeed but steers the *next* turn — less brittle than hard denial, more responsive than after-the-fact review.
- **Furrow adoption potential**: **medium** — the mechanism is useful, the specific TDD state machine less so.
- **If adopt**: Furrow's `correction-limit` hook currently hard-blocks writes after N attempts. A tool-result-post injection layer could *augment* the hook: instead of only blocking at N, inject "You've made 2 of 3 allowed corrections on this deliverable" after the 2nd write — giving the agent explicit signal before the cliff. Also useful: after `rws update-summary`, inject validation results ("3 of 5 required sections present"). The Plan Tracker pattern is less relevant — Furrow's `summary.md` already plays this role, and `rws status` surfaces live state.
- **Furrow already has**: `correction-limit` hook (hard block), `state-guard` hook (direct-edit denial). The former is PreToolUse; neither is post-result.
- **Verdict**: Adopt the *mechanism* for soft-warning escalation (before the 3rd correction), but keep the hard block at the limit. Don't bring in the TDD state machine — it's opinionated and Furrow's review/eval layer covers test discipline differently.
- **Source (T1)**: `github.com/coctostan/pi-superpowers-plus` README.

---

## Pattern 5: Continuous observer (from pi-supervisor)

- **What it does**: A separate LLM session runs in parallel to the main agent, sharing only API credentials — never touching the main agent's context window or system prompt. Three sensitivity levels: Low (end-of-run only), Medium (end-of-run + every 3rd tool cycle, confidence ≥0.90), High (every cycle, confidence ≥0.85). Steering messages injected *between tool calls* or at idle. The supervisor emits strict JSON:
  ```json
  { "action": "continue" | "steer" | "done",
    "message": "...",
    "reasoning": "...",
    "confidence": 0.85 }
  ```
  Policies live in `.pi/SUPERVISOR.md` → `~/.pi/agent/SUPERVISOR.md` → built-in fallback. Steer messages *speak AS the user* ("1–3 sentences, clear, direct, actionable"). Stagnation safeguard: after 5 failed steers, if ≥80% of goal achieved, declare `done` rather than loop.
- **Why it's novel**: Review as a continuous-background process rather than a discrete gate at step-end. The context-isolation discipline (separate session, shared creds only) avoids the usual self-review bias where the agent reviews its own thread.
- **Could Furrow's review step run as continuous observer?** — yes, with trade-offs:
  - **Pro**: catches drift mid-work, not just at step boundary. Furrow's current `/furrow:review` is post-step; a supervisor would catch "this spec contradicts the rationale" in real time.
  - **Pro**: the stagnation safeguard (declare done at 80% after 5 failed nudges) is exactly the failure mode the user hit with "hard block over auto-correct" — it's a principled form of the same thing.
  - **Con**: doubles inference cost (separate LLM session every 3rd cycle at Medium).
  - **Con**: Furrow's review produces multi-dimensional eval scores (correctness/completeness/quality/minimalism) that require deliberate scoring, not drift-detection. These are different primitives; the supervisor does drift, not scoring.
  - **Con**: the gate protocol's evidence objects need structured reasoning, not a steering sentence.
- **Furrow adoption potential**: **medium** — as a *complement* to post-step review, not a replacement.
- **If adopt**: Add an optional "drift observer" that runs between Furrow steps (not during). Emits one of `{continue, steer, done}` after each step with a `SUPERVISOR.md`-style policy. Its `steer` becomes a `review → spec` back-transition with evidence. Its `done` is a pre-checked gate trigger. Keep the main review step for multi-dimensional scoring.
- **Furrow already has**: prechecked gates (auto-advance when step adds no new info), the review step with eval dimensions, gate protocol with evidence objects. What it doesn't have: *continuous* observation between steps.
- **Verdict**: Partial adopt. The `SUPERVISOR.md` policy file is a clean pattern — Furrow could add `.furrow/policies/*.md` for drift-detection rules without changing the review step. The stagnation safeguard is a separate good idea worth porting to the correction-limit.
- **Source (T1)**: `github.com/tintinweb/pi-supervisor` README.

---

## Pattern 6: DAG task tracking with auto-cascade (from pi-tasks)

- **What it does**: Seven tools (`TaskCreate`, `TaskList`, `TaskGet`, `TaskUpdate`, `TaskOutput`, `TaskStop`, `TaskExecute`) expose task CRUD + subagent execution. Tasks have `blockedBy:` edges forming a DAG. When a task completes, auto-cascade triggers execution of all unblocked dependents (transitively through the DAG, like a build system). Storage modes: `memory` (none), `session` (`.pi/tasks/tasks-<sessionId>.json`), `project` (`.pi/tasks/tasks.json`). File locking + stale-lock detection for concurrency. **Cycle detection is non-blocking**: cycles, self-deps, dangling refs are *stored* but produce warnings.
- **Why it's novel**: Auto-cascade integrates task tracking with subagent spawning — completion of task N *automatically launches* task N+1's subagent if prerequisites are met. Very declarative.
- **Furrow adoption potential**: **low** for cascade, **medium** for DAG dependencies in almanac.
- **If adopt**: `.furrow/almanac/todos.yaml` and `roadmap.yaml` could gain explicit `blocked_by:` edges today expressed in prose. `/furrow:triage` and `/furrow:next` would then produce a topologically-sorted next-item list. But auto-cascade execution (spawn a sub-agent when a blocker completes) violates Furrow's step-sequence invariant — a row is a bounded unit of human-gated work, not a self-dispatching pipeline.
- **Non-blocking cycle warnings**: directly contradicts Furrow's "hard block over auto-correct" principle. Furrow should *refuse* to store an invalid edge.
- **Furrow already has**: roadmap prioritization, todos extraction, `/furrow:next` for picking the next work item.
- **Verdict**: Adopt typed dependency edges in todos/roadmap with hard validation (no storing invalid edges). Skip auto-cascade. Skip the 7-tool CRUD surface — `alm` already covers almanac mutations.
- **Source (T1)**: `github.com/tintinweb/pi-tasks` README.

---

## Pattern 7: Behavior monitors (from pi-behavior-monitors)

- **What it does**: Classifies agent activity into bundled categories: **Fragility** (leaves broken state, TODO-instead-of-fix, empty catch blocks), **Hedge** (deviates from what the user said, rephrases questions, assumes intent), **Work-quality** (trial-and-error, not reading before editing, fixing symptoms not causes). Classification pipeline: (1) side-channel LLM call against a JSON *pattern library*, (2) route verdict to `steer` (inject correction) / `write` (append JSON findings) / `learn` (auto-add new patterns to the library). Config format:
  ```
  .pi/monitors/
    fragility.monitor.json       # definition
    fragility.patterns.json      # known patterns
    fragility.instructions.json  # user corrections
  ```
  User commands: `/monitors <name> rules add <text>`, `/monitors <name> patterns`, `/monitors <name> dismiss`.
- **Why it's novel**: The `learn` action — patterns *accumulate* from observed behavior, turning one-off corrections into durable rules. This is the memory loop Furrow's review step lacks.
- **Furrow adoption potential**: **medium to high**.
- **If adopt**: Furrow's eval dimensions (correctness/completeness/quality/minimalism) are fixed-taxonomy. A monitor layer would let *rows accumulate patterns* — e.g., after a review finds "added a sed call when `rws update-summary` exists", that becomes a pattern in a fragility library that future rows check against. This is exactly the "learn from past work" loop that rationale.yaml gestures at but doesn't operationalize. File structure maps cleanly: `.furrow/monitors/fragility.patterns.json`.
- **Furrow already has**: rationale.yaml (rationale snapshots), review step with evidence. Neither feeds forward as auto-checked patterns.
- **Verdict**: Adopt in a narrow form. Introduce `.furrow/patterns/{fragility,hedge,work-quality}.patterns.yaml` as an accumulating library that the review step consults. Skip the side-channel LLM classification for now (cost, latency) — start with pattern-matching rules and let humans add patterns via `alm pattern add`.
- **Source (T1)**: `github.com/davidorex/pi-behavior-monitors` README.

---

## Pattern 8: Personal pack structure (from dot314 + pi-packages)

- **File layout — dot314**:
  ```
  dot314/
  ├── AGENTS-prefaces/
  ├── agents/
  ├── assets/
  ├── extensions/        (~30 modules)
  ├── packages/          (npm-exported)
  ├── prompts/
  ├── scripts/
  ├── shell/
  ├── skills/
  ├── themes/
  ```
  Extensions marked: `●` original, `◐` fork, `○` unmodified republish.
- **File layout — pi-packages**:
  ```
  pi-packages/
  ├── .github/workflows/
  ├── packages/            (one dir per extension)
  ├── AGENTS.md
  ├── SECURITY.md
  ├── biome.json, tsconfig.json, vitest.config.ts
  ```
  Each package has its own `package.json` + README. No shared build; independent npm publishing.
- **Distribution mechanism** (both):
  ```
  pi install git:github.com/<user>/<repo>      # bulk
  pi install npm:<package-name>                # per-extension
  pi -e git:github.com/<user>/<repo>           # ephemeral trial
  ```
- **Lessons for Furrow's shipping format**:
  1. **Dual distribution**: a "bulk install" URL + per-component npm publishing. Furrow currently ships as a single `install.sh`. Could ship individual specialists as standalone entries (e.g., `install.sh --specialist go` or `npm:@furrow/specialist-go`).
  2. **Provenance markers**: dot314's `●/◐/○` legend for original/fork/republish is a lightweight practice Furrow could adopt for specialists that are third-party adaptations vs. original.
  3. **SECURITY.md + AGENTS.md at root** is a ship-ready practice Furrow doesn't currently have.
  4. **Independent package versioning**: when a single specialist changes, only that one bumps — avoids monolith-bump friction.
- **Verdict**: Adopt SECURITY.md and provenance markers now; defer per-specialist packaging until there's demonstrated external reuse.
- **Source (T1)**: `github.com/w-winter/dot314` README, `github.com/ben-vargas/pi-packages` README.

---

## Specialist packaging surface (Q-E1)

**Survey across projects:**

| Project | Specialist delivery format |
|---------|----------------------------|
| pi-gsd | 57 markdown skills (`gsd-*` slash commands); 18 "subagents" routed by model profile |
| pi-project-workflows | `.pi/agents/*.agent.yaml` (typed agent contracts with `contextBlocks`); templates in `.pi/templates/` |
| pi-superpowers-plus | 12 skills as markdown (2 files each: `SKILL.md` + `how-it-works.md`); bundled subagent definitions in `agents/*.md`; 3 TypeScript extensions |
| pi-tasks | TypeScript extension exposing 7 LLM-callable tools; agents spawned via `TaskExecute` subagent |
| pi-supervisor | Policy via `SUPERVISOR.md` markdown (project or global); supervisor itself is a TS extension |
| pi-behavior-monitors | `.monitor.json` + `.patterns.json` + `.instructions.json` triplet per monitor; extension code dispatches |
| dot314 | Mix: skills in `skills/`, extensions in `extensions/`, prompts in `prompts/`, agents in `agents/` |
| pi-packages | Pure extensions — 8 TypeScript packages, each a self-contained npm module |

**Dominant ecosystem pattern:** markdown files with frontmatter for *descriptive* specialists (skills, agent prompts, policies) + TypeScript extensions for *behavioral* capabilities (tools, hooks, dispatchers). The split is: **markdown for prompts, TS for runtime**.

**Trade-offs:**

- **Markdown skills** (pi-gsd, pi-superpowers-plus): portable, human-readable, no install step beyond file placement. But no type checking on frontmatter, no ability to declare structured I/O.
- **YAML agent contracts** (pi-project-workflows): typed `contextBlocks`, `inputSchema`, `outputSchema`. Requires a runtime that understands the schema. More rigorous, less portable.
- **TypeScript extensions** (pi-tasks, pi-superpowers-plus): real behavior — tools, hooks, state. Portability bound to the host runtime.
- **Policy markdown** (pi-supervisor's `SUPERVISOR.md`): pattern matches Furrow's `CLAUDE.md` / `.claude/rules/*.md` layering exactly.

**Recommendation for Furrow on Pi**: ship specialists as **markdown-with-frontmatter skills** (portable, matches both Claude Code and Pi's skill conventions) with an optional **YAML contract** layer for specialists that need typed I/O (e.g., `specialist:migration-strategist.yaml` declares `consumes: [rationale, spec]`, `produces: [migration-plan]`). Runtime behavior (hooks, CLI mediation) stays in `bin/frw.d/` shell — not bundled into the specialist.

---

## Top 3 "adopt now" patterns

### 1. Typed project-block schemas in the almanac (Pattern 2)
**Implementation sketch**:
- Add `.furrow/almanac/schemas/{rationale,roadmap,todos,decisions}.json` as JSON Schemas.
- Generalize `alm` to a schema-driven CLI: `alm read <block>`, `alm append <block> <item>`, `alm update <block> <id> <patch>`.
- On write, validate against schema; reject invalid (hard block, consistent with Furrow's culture).
- Migrate existing files in-place; keep YAML on disk, validate semantically.

### 2. Typed deliverable outputs with `produces:` schema (Pattern 3)
**Implementation sketch**:
- Extend `definition.yaml` deliverable entries with `produces:` — a JSON Schema or enum like `{files_touched: [path], tests_added: [path], migrations: [path]}`.
- At `rws complete-deliverable`, validate the claimed output against the schema.
- Downstream `/furrow:review` consumes typed artifacts, not prose AC.
- Phase 1: schema optional. Phase 2: required for new rows. Phase 3: enable `${{ deliverables.X.produces.files }}` expression substitution in summary.md templates.

### 3. Accumulating pattern library via behavior monitors (Pattern 7)
**Implementation sketch**:
- Add `.furrow/patterns/{fragility,hedge,work-quality}.patterns.yaml`.
- During `/furrow:review`, if a specific issue is found (e.g., "used sed to edit state.json"), the reviewer proposes a new pattern entry.
- Future rows' review step checks against the pattern library automatically.
- Start with pattern-matching rules (grep-style); defer LLM classification.

---

## Top 3 "don't copy" patterns

### 1. Non-blocking cycle warnings (pi-tasks)
Storing invalid dependency edges and emitting a warning contradicts Furrow's "hard block over auto-correct" principle (from `feedback_hard_block_over_autocorrect.md`). Invalid state should be refused at write, not stored with advisory output.

### 2. Auto-cascade subagent execution (pi-tasks)
Automatically spawning a subagent when a blocker completes violates the step-sequence invariant. Furrow's steps are bounded, gate-protocol-traversed, and human-checkpointed. Auto-cascade turns workflow into a pipeline and loses the deliberate-progress property.

### 3. Full XML preprocessor DSL (pi-gsd WXP)
The mechanism is valuable; the XML DSL is not. Furrow skills are plain markdown for a reason — contributors don't need to learn a custom XML dialect. If pre-resolution is wanted, use targeted `{{ frw.status }}` mustache substitution in a handful of skill templates. Don't adopt the 8-element XML vocabulary, the Zod-typed schema, or the shell-allowlist runtime.

---

## Additional observations (not patterns per se)

- **Pi-supervisor's "stagnation safeguard"** — after 5 failed nudges, declare done at ≥80% — is a clean expression of a principle Furrow hasn't formalized. The correction-limit blocks after N writes but has no 80%-done escape hatch. Worth considering for the review step: "if correctness ≥ 0.8 and minimalism is the blocker, mark pass-with-fixups rather than fail."
- **Every ecosystem project uses file-backed state with per-session vs. per-project isolation modes**. Furrow only has per-project (`.furrow/rows/`). Worth considering: session-scoped "scratch rows" for exploratory work that don't need permanent roadmap entries.
- **pi-project-workflows' `message_end` / `turn_end` / `agent_end` event taxonomy** is a richer interception surface than Furrow's hooks (which fire on tool use / session stop). If Furrow expands its hook surface, these three event points are well-proven.

---

## Sources Consulted (tiered)

**T1 — primary (repo READMEs fetched directly)**:
- `github.com/fulgidus/pi-gsd` — README content via WebFetch; `src/schemas/wxp.zod.ts` referenced
- `github.com/davidorex/pi-project-workflows` — README + `packages/pi-workflows/README.md` via WebFetch
- `github.com/coctostan/pi-superpowers-plus` — README via WebFetch; `extensions/workflow-monitor/` referenced
- `github.com/tintinweb/pi-tasks` — README via WebFetch
- `github.com/tintinweb/pi-supervisor` — README via WebFetch (raw fetch failed; rendered HTML succeeded)
- `github.com/davidorex/pi-behavior-monitors` — README via WebFetch
- `github.com/w-winter/dot314` — README via WebFetch
- `github.com/ben-vargas/pi-packages` — README via WebFetch

**T2 — synthesis**:
- Cross-project taxonomy of specialist packaging formats (derived from T1 surveys)
- Mapping of ecosystem patterns onto Furrow's existing primitives (derived from Furrow CLAUDE.md + user background)

**T3 — snippets embedded above**:
- pi-gsd WXP XML example (verbatim from README)
- pi-gsd phase-flow diagram (verbatim from README)
- pi-project-workflows YAML step example (verbatim from packages README)
- pi-supervisor response schema (verbatim from README content summary)
- pi-tasks visual widget display (verbatim from README)
- pi-superpowers-plus Plan Tracker API (verbatim from README)

**Gaps**: Full enumerations of pi-gsd's 57 skills and 18 subagents were not available from the README; repo file-tree fetch returned 404. A full `gh api` enumeration would close this gap but wasn't required for pattern extraction.
