# Furrow Philosophy Audit

Date: 2026-04-28

Scope: philosophy and architecture audit only. This document does not implement
recommendations.

## 1. Executive Verdict

Furrow is still serving its original purpose in the places where it forces work
claims to meet evidence: completion evidence, normalized backend decisions,
layer boundaries, handoff isolation, row state, and archive readiness. Those are
real harness functions. They make agents slower in the right way.

Furrow is no longer serving its original purpose cleanly at the project level.
It has accreted a roadmap system, TODO system, adapter migration program,
process-learning archive, command prompt library, shell runtime, Go runtime,
Claude hook set, Pi adapter, driver layer, engine layer, and multiple partially
overlapping vocabularies. The result is not uniformly too strict. It is
unevenly strict: hard gates exist around some real risks, while other surfaces
carry huge process weight without forcing truth.

The project should optimize now for a smaller core:

- CORE: model-agnostic work discipline, row state, evidence, decision points,
  context construction, handoff isolation, and backend-owned validation.
- SUPPORTING: adapters, rendered runtime prompts, thin UX commands, and small
  planning views.
- OVERGROWN: almanac-as-roadmap-product, TODO-as-work-graph, command markdown
  procedures, legacy shell CLIs, always-on shared protocols, and adapter parity
  claims that include paths not wired live.

Furrow should become a truth-preserving work harness, not a self-managing
process operating system.

## 2. First-Principles Purpose

### Core Mission

Furrow's first-principles purpose is:

> Preserve the user's real ask across long-running agent work, force claims to
> meet evidence, expose meaningful human decisions, and carry only the context
> required for the next correct action.

That makes Furrow primarily a workflow/process harness with a context
engineering substrate. Context construction is not the product by itself; it is
the mechanism that keeps work grounded. Runtime adapters are not the product;
they express the same discipline in different hosts. The roadmap is not the
product; it is a source of candidate work.

### Core Responsibilities

- CORE: row lifecycle state with one canonical backend authority.
- CORE: literal ask to real ask analysis.
- CORE: completion evidence and claim surfaces.
- CORE: non-deferrable work classification.
- CORE: human approval at decision boundaries that change scope, claims, or
  irreversible state.
- CORE: context bundles filtered by target and phase.
- CORE: backend-owned normalized events for adapter-neutral enforcement.
- CORE: handoff isolation so engines do useful work without inheriting Furrow
  internals.
- CORE: archive readiness that blocks false completion.

### Non-Core Responsibilities

- SUPPORTING: runtime-specific command names and UI affordances.
- SUPPORTING: rendering Claude agent definitions or Pi extension commands.
- SUPPORTING: storing candidate future work.
- SUPPORTING: learning capture when it changes future prompts, checks, or docs.
- SUPPORTING: merge assistance when it protects row traceability.

### Things Furrow Should Stop Trying To Be

- DELETE / COLLAPSE: a full roadmap/TODO execution system with 177 TODOs,
  82 roadmap nodes, and 15 phases as first-class operating machinery.
- DELETE / COLLAPSE: a second task manager competing with rows and seeds.
- DELETE / COLLAPSE: a prompt-document operating system where command markdown
  scripts tell agents to call old shell CLIs while Go commands own newer truth.
- DELETE / COLLAPSE: a provider-specific philosophy split between Claude,
  Codex, and Pi.
- DELETE / COLLAPSE: a retrospective/audit factory that turns every discomfort
  into more process instead of simpler design.
- REBUILD: process-learning capture as active policy updates, not an archive.

## Historical Pressure And Design Intent

The critique above should be read as a correction to overgrowth, not as a
rejection of Furrow's original purpose. Furrow began as a context-engineering
abstraction: preserve the real ask, make long-running agent work easier to
resume, keep artifacts auditable, and turn process discoveries into better
future work. The architecture docs still show a coherent core worth protecting:
row lifecycle, target-specific context construction, handoff isolation,
operator/driver/engine layering, completion evidence, blocker taxonomy,
document authority, and backend-owned adapter-neutral decisions.

Several current pain points were reasonable responses to real failures before
they became stale or too broad. Layer policy and engine handoff isolation came
from the need to stop execution agents from mutating harness state or inheriting
Furrow internals. Completion evidence, claim surfaces, and archive readiness
came from the concrete Phase 1-4 failure mode where artifacts were complete but
the runtime claim was not true. Supervised gates were attractive because the
user needed reliable control over scope, quality, and irreversible decisions.
TODO capture and learnings existed because the user wanted process knowledge
from one row to improve future rows. These are not bad ideas; they became
problematic when their capture surfaces outpaced their disposition paths.

The dual-runtime and Pi work should also not be treated as speculative bloat.
It was a strategic response to Claude quality and availability concerns and to
the risk of vendor-shaped lock-in. The enduring design intent is
adapter-neutral backend semantics with thin runtime adapters. The failure was
not wanting Pi or model-provider optionality; it was allowing adapter parity
wording, future handler fixtures, command markdown, shell hooks, and Go backend
contracts to overlap without strict live-path evidence.

Furrow also dogfooded itself while incomplete. That amplified the very
mechanisms it was trying to invent: rows generated TODOs, TODOs generated
roadmap phases, roadmap phases generated migration shims, and shims generated
more documentation and audits. The resulting sprawl is partly architectural
debt, but partly the cost of using the harness as its own test subject before
cutoffs, source-of-truth boundaries, and promotion/disposition rules were hard
enough.

The fair target is therefore selective preservation:

- Preserve row state, completion evidence, claim surfaces, context bundles,
  handoff isolation, layers, blocker taxonomy, document authority, and
  adapter-neutral backend decisions as core concepts.
- Collapse or delete duplicate implementations, stale shell-era command
  surfaces, broad always-on protocols, unbounded roadmap/TODO machinery, and
  parity claims that are not wired through loaded runtime paths.
- Keep strictness where it protects truth or human control, but tier ceremony
  by risk so small rows do not inherit architecture-migration weight.
- Keep process learning only when it becomes an active prompt, check, doc,
  default, or deliberately scheduled work item; archive-only learning is not a
  harness improvement.
- Treat transitional docs and shims as once-valid migration scaffolding that
  need explicit cutoffs, not as either enduring architecture or worthless
  residue.

This means recommendations such as "collapse roadmap/TODO system" should
preserve the protections those systems were trying to provide: explicit work
identity, dependency visibility, follow-up disposition, roadmap-aligned
defaults with override, and traceability from row outcomes back into planning.
The collapse target is the duplicated authority and hand-maintained sprawl, not
the need for planning memory itself.

## 3. Keep / Collapse / Delete / Rebuild Table

| Feature or Surface                                                                                       | Current Role                                       | Verdict                     | Reason                                                                                                   | Suggested Direction                                                                                       |
| -------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | --------------------------- | -------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| Row lifecycle (`.furrow/rows/*/state.json`, `furrow row`)                                                | Canonical work unit and progress state             | KEEP / CORE                 | This is the harness spine. It gives work continuity and auditability.                                    | Keep backend-owned. Reduce direct state editing paths.                                                    |
| Completion evidence (`ask-analysis.md`, `claim-surfaces.yaml`, `completion-check.md`, `follow-ups.yaml`) | Blocks false completion and TODO laundering        | KEEP / GOOD STRICTNESS      | Directly addresses the real failure mode: artifacts can pass while the ask is still false.               | Keep, but make templates short and surfaced at archive/checkpoint boundaries.                             |
| Claim surfaces                                                                                           | Tracks where behavior is actually claimed          | KEEP / CORE                 | Caught real Pi parity overclaims.                                                                        | Keep as backend concept. Avoid expanding it into prose-heavy ceremony for trivial rows.                   |
| Normalized `ToolEvent` / `PresentationEvent`                                                             | Adapter-neutral backend decision input             | KEEP / CORE                 | Correct abstraction: backend owns policy, adapters translate runtime events.                             | Expand only for live adapter paths.                                                                       |
| Layer policy (`operator`, `driver`, `engine`)                                                            | Separates user-facing orchestration from execution | KEEP / GOOD STRICTNESS      | Strong boundary; prevents engines from mutating harness state.                                           | Keep semantics, simplify loaded instructions.                                                             |
| Engine handoff isolation                                                                                 | Keeps engines Furrow-unaware                       | KEEP / CORE                 | This is one of Furrow's clearest wins.                                                                   | Keep, but use fewer Furrow terms in driver prompts.                                                       |
| Context builder/strategy/chain                                                                           | Canonical context construction                     | KEEP / SUPPORTING           | Good architecture, but the pattern language risks becoming self-referential.                             | Keep implementation. Compress docs into contract plus examples.                                           |
| Driver step skills                                                                                       | Phase behavior briefs                              | KEEP / REBUILD              | Useful, but now too long and too procedural. Many contain runtime and shell details.                     | Rebuild as compact phase contracts plus on-demand references.                                             |
| Shared skills                                                                                            | Cross-step protocol library                        | COLLAPSE / CONTEXT BLOAT    | Too many shared docs are candidates for always-on injection.                                             | Split into always-on max 1 page plus lazy references.                                                     |
| `skills/orchestrator.md`                                                                                 | Older operator orchestration model                 | COLLAPSE                    | Overlaps with `commands/work.md` and layer protocol.                                                     | Merge useful content into operator bundle, then retire.                                                   |
| Command markdown (`commands/*.md`)                                                                       | Human/agent slash command specs                    | REBUILD / OVERGROWN         | Many commands still call `rws`, `alm`, `sds`, and shell scripts while Go owns newer semantics.           | Generate or rewrite from backend command contracts. Delete stale command specs.                           |
| `/work` command markdown                                                                                 | Operator runtime procedure                         | REBUILD                     | Mixes core philosophy with Claude-specific teams, Pi expectations, `rws transition`, and caching claims. | Make `/work` a thin adapter expression of backend row status/checkpoint actions.                          |
| Pi adapter (`adapters/pi/furrow.ts`)                                                                     | Runtime UX and live command integration            | KEEP / SUPPORTING           | Mostly backend-driven and pragmatic. But it is large and shells to `go run`.                             | Keep as adapter. Build binary once; keep policy out of TS.                                                |
| `.pi/extensions/furrow.ts`                                                                               | Pi auto-discovery shim                             | KEEP                        | Thin compatibility path.                                                                                 | Keep until Pi packaging has a better canonical path.                                                      |
| `.claude/settings.json` hooks                                                                            | Claude runtime enforcement                         | COLLAPSE / TRANSITIONAL     | Mixes old `frw hook` shell hooks with new `furrow hook` Go hooks.                                        | Cut over hook by hook to normalized Go backend, then delete shell hooks.                                  |
| `bin/frw`, `bin/rws`, `bin/alm`, `bin/sds`                                                               | Legacy shell CLIs and wrappers                     | COLLAPSE / DUPLICATED       | They still carry major behavior and vocabulary while Go CLI is the future.                               | Freeze feature work. Port only truth-critical paths. Delete by explicit cutoff.                           |
| `furrow` Go CLI                                                                                          | Backend semantic authority                         | KEEP / CORE                 | Best direction for adapter-neutral behavior.                                                             | Finish real subcommands before adding new concepts.                                                       |
| Stub Go commands (`gate`, `seeds`, `merge`, some row leaves)                                             | Contract placeholders                              | VAPORWARE                   | Advertised command surface exists without implementation.                                                | Either implement or remove from help until real.                                                          |
| Roadmap YAML                                                                                             | Current phase planning and migration queue         | COLLAPSE / OVERGROWN        | 3201 lines, 82 nodes, 21 roadmap rows. Useful but too central.                                           | Keep as optional planning view, not harness operating input.                                              |
| TODO YAML                                                                                                | Candidate work backlog                             | REBUILD / OVERGROWN         | 4660 lines and 177 entries. Encourages deferral and process multiplication.                              | Convert to seeds/work graph or sharded lightweight backlog. Archive stale items aggressively.             |
| Seeds                                                                                                    | Intended future work primitive                     | REBUILD                     | Direction is coherent but dual-source period is risky.                                                   | Pick one canonical work-source deadline. Do not add features until cutover.                               |
| `todos.yaml` + `seeds.jsonl` duality                                                                     | Transitional source split                          | BAD STRICTNESS / DUPLICATED | Forces agents to reason about two task systems.                                                          | Collapse to one source; derive views.                                                                     |
| `roadmap.yaml` + `todos.yaml` graph                                                                      | Planning graph                                     | COLLAPSE                    | It is becoming a project manager inside the harness.                                                     | Keep only enough to choose next row and explain dependencies.                                             |
| Process learnings JSONL                                                                                  | Captures lessons                                   | REBUILD                     | Stored learnings are not consistently converted into future behavior.                                    | Promote only learnings that change a check, prompt, doc, or default.                                      |
| Rationale inventory                                                                                      | File ownership/deletion rationale                  | COLLAPSE                    | Valuable during migration, heavy as permanent ceremony.                                                  | Keep for core harness files only or move to architecture docs.                                            |
| Merge protocol                                                                                           | Protects worktree reintegration                    | KEEP / SUPPORTING           | Good when merging long-lived harness rows.                                                               | Keep as separate command/skill; do not inject into normal row work.                                       |
| Presentation protocol                                                                                    | Prevents artifact dumping and enables scanning     | KEEP / SUPPORTING           | Good strictness at user-facing boundary.                                                                 | Keep normalized backend scan; make adapter hooks honest about coverage.                                   |
| Cross-model review                                                                                       | Outside voice                                      | SUPPORTING / OPTIONAL       | Useful for high-risk decisions, expensive as default.                                                    | On-demand by risk, not a mandatory ritual.                                                                |
| Dual outside voice in ideate/plan/spec                                                                   | Review ceremony                                    | COLLAPSE / CEREMONY DRAG    | Strong agents can be slowed into checklist behavior before the problem warrants it.                      | Trigger by risk labels: migration, public API, security, architecture, unclear user ask.                  |
| `team-plan.md`                                                                                           | Retired parallel plan artifact                     | DELETE                      | Docs say retired but historical files and references remain.                                             | Delete from active concepts; migrate old rows lazily only if read.                                        |
| `branch` vs `branch_name`                                                                                | Branch identity fields                             | COLLAPSE / DUPLICATED       | Multiple names appear across scripts/tests/docs.                                                         | Backend schema should expose one field and adapters render aliases only if needed.                        |
| `source_todo` vs `source_todos`                                                                          | Work-source linkage                                | COLLAPSE / DUPLICATED       | Legacy singular and newer plural both survive.                                                           | Canonicalize to one array field; read legacy only in migration code.                                      |
| `rows` vs `work_units`                                                                                   | Work item vocabulary                               | COLLAPSE                    | Old vocabulary leaks in tests and scripts.                                                               | Use `row` externally; reserve compatibility names only in migration tests.                                |
| `drivers`, `specialists`, `agents`, `engines`                                                            | Delegation vocabulary                              | REBUILD                     | The conceptual model is good; names leak runtime assumptions and older designs.                          | Core: operator, driver, engine. Adapter: agent/subagent names. Specialist is a brief, not a runtime type. |

## 4. Context Bloat Findings

### Always-On Context That Should Be Lazy

- CONTEXT BLOAT: shared protocols are too large to be treated as ambient:
  `gate-evaluator.md`, `merge-protocol.md`, `specialist-delegation.md`,
  `context-isolation.md`, `eval-protocol.md`, and `summary-protocol.md` should
  not travel with every step.
- CONTEXT BLOAT: step skills exceed the "brief" concept. Most are about 90-117
  lines and include model defaults, shell commands, runtime behavior, ceremony,
  references, dispatch, and EOS assembly.
- CONTEXT BLOAT: `.claude/CLAUDE.md` still advertises `bin/frw`, `bin/rws`,
  `bin/alm`, `bin/sds` as the command table while new backend commands exist.
- CONTEXT BLOAT: command markdown is procedural context masquerading as
  command implementation. It should be reference material, not the live source
  of truth.
- CONTEXT BLOAT: roadmap and TODO prose is too large to be directly injected.
  It should be queried by row/TODO id, summarized, or derived into handoff
  prompts.

### Repeated Process Text That Should Be Compressed

- "Read shared references when relevant" appears across multiple step briefs.
  Replace with a backend context bundle that includes reference ids, not full
  reminders.
- Driver return/EOS language repeats in each step skill. Put it in one return
  contract and make step skills specify only step-specific fields.
- Gate and review instructions repeat shell-era mechanics. Put gate semantics
  in backend status/checkpoint output.
- Runtime return phrasing repeats "Claude: SendMessage; Pi: agent return value."
  That belongs in adapter docs, not every phase.

### Missing Context That Should Surface Only At Decision Points

- Human gates should surface the exact claim being approved, the evidence, and
  the cost of deferral at checkpoint time. They should not force agents to carry
  all gate theory throughout the step.
- Adapter parity limitations should appear when a row claims cross-runtime
  behavior, not in ordinary implementation rows.
- TODO/source-work context should appear when creating or closing a row, not in
  every phase prompt.
- Learnings should appear only when tags match the current row's domain or
  failure mode. "Read project learnings at session start" is too broad unless
  filtered mechanically.

## 5. Strictness Findings

### Good Strictness

- GOOD STRICTNESS: archive readiness blocks `required_for_truth` deferrals that
  would make the real ask false.
- GOOD STRICTNESS: claim surfaces prevent "tested the backend" from becoming
  "the adapter works."
- GOOD STRICTNESS: normalized backend events keep policy out of Claude/Pi
  payloads.
- GOOD STRICTNESS: layer policy blocks engines from reading or mutating
  `.furrow` internals.
- GOOD STRICTNESS: direct state mutation guards force canonical row changes
  through backend-mediated commands.
- GOOD STRICTNESS: almanac validation now catches missing references instead
  of leaving roadmap lies in place.

### Bad Strictness

- BAD STRICTNESS: mandatory multi-phase ceremonies for small or obvious tasks
  turn strong agents into checklist executors.
- BAD STRICTNESS: requiring dual outside voice by default in ideate/plan/spec
  overfits every row to high-risk architecture work.
- BAD STRICTNESS: summary-section validation can reward filling sections over
  answering the user's real ask.
- BAD STRICTNESS: TODO extraction at archive can become permission to defer
  truth-critical work unless completion evidence stays dominant.
- BAD STRICTNESS: command specs that require old shell commands force agents to
  obey transitional machinery rather than current backend truth.

### Where Discipline Is Helping

Discipline is helping where the harness asks: "What claim are you making, what
surface proves it, and who must approve the next irreversible step?" It is also
helping where engines are isolated from Furrow internals and where adapters must
translate into backend-owned normalized decisions.

### Where Discipline Has Become Ceremony

Discipline has become ceremony where the harness asks agents to produce or
update artifacts because the process says so, not because the artifact changes
the decision. The clearest examples are oversized step briefs, roadmap/TODO
maintenance, repeated summary mechanics, command markdown procedures, and
multi-review defaults applied before risk is known.

## 6. Surface-Area Findings

### Duplicated Concepts

- DUPLICATED: `row`, `work unit`, `task`, `branch`, and roadmap row are not
  cleanly separated.
- DUPLICATED: `source_todo` and `source_todos`.
- DUPLICATED: `todos.yaml` and planned `seeds.jsonl` authority.
- DUPLICATED: `branch` in Go row state and `branch_name` in shell/test flows.
- DUPLICATED: `furrow`, `frw`, `rws`, `alm`, and `sds` command surfaces.
- DUPLICATED: shell hooks and Go hooks.
- DUPLICATED: Claude agent definitions, driver YAML, step skills, and render
  output all express similar driver policy.
- DUPLICATED: `commands/work.md` and Pi adapter `/work` implement overlapping
  work-loop behavior.
- DUPLICATED: specialist as skill brief vs specialist as agent type appears in
  older docs and newer architecture notes.

### Optional Paths That Should Collapse

- COLLAPSE: shell CLIs should not receive new semantic behavior. They should be
  compatibility wrappers or disappear.
- COLLAPSE: command markdown should not be a second implementation. Backend
  command contracts should generate or constrain command docs.
- COLLAPSE: roadmap and TODO views should not both be hand-maintained sources.
- COLLAPSE: adapter parity tests should not count future-handler stubs as live
  support.

### Transitional Paths With Real Cutovers

- KEEP TEMPORARILY: Claude hooks using `frw hook` while Go replacements land,
  but each hook needs a named cutover target.
- KEEP TEMPORARILY: `.pi/extensions/furrow.ts` as a compatibility shim.
- KEEP TEMPORARILY: singular source fields as read-only migration fallbacks.
- KEEP TEMPORARILY: legacy row artifacts for archived rows.

### Transitional Paths With No Honest Cutover

- VAPORWARE: Go CLI help advertises stub groups (`gate`, `seeds`, `merge`) that
  return `not_implemented`.
- VAPORWARE: roadmap phases that say future systems will collapse TODOs/seeds
  while new TODO and roadmap features continue to be added.
- VAPORWARE: Pi presentation scanning as a parity claim before a comparable Pi
  lifecycle event is wired.
- VAPORWARE: future-handler parity branches that test normalized fixtures but
  not live adapter behavior.

## 7. Adapter / Runtime Findings

### What Belongs In Backend

- CORE: row state mutations.
- CORE: archive readiness.
- CORE: gate/checkpoint readiness.
- CORE: blocker taxonomy and remediation hints.
- CORE: normalized event schemas.
- CORE: layer policy decisions.
- CORE: context bundle assembly and target filtering.
- CORE: handoff schema validation.
- CORE: claim-surface evidence rules.

### What Belongs In Adapters

- SUPPORTING: runtime command registration.
- SUPPORTING: UI rendering and status line.
- SUPPORTING: translating runtime event payloads into normalized backend events.
- SUPPORTING: runtime-specific spawn/message/return primitives.
- SUPPORTING: fast local UX affordances that call backend commands.
- SUPPORTING: runtime capability exploitation after backend semantics are stable.

### Pi / Provider-Switchable Runtime Direction

Furrow's core philosophy is close to model-agnostic in the newer backend docs:
the core describes layers, evidence, events, and claims rather than provider
personalities. That is the right direction for Pi or any provider-switchable
runtime.

The leak is not mostly "Claude-specific philosophy"; it is shell-era and
runtime-era mechanics mixed into core prompts. `commands/work.md` contains
Claude teams details and `rws transition`; shared docs repeatedly name Claude
and Pi return primitives; `.claude/settings.json` still carries many `frw hook`
commands; Pi has separate command behavior in TypeScript. The philosophy should
say: preserve ask, assemble target context, run phase, surface evidence, ask at
decision boundary. Adapters decide how to spawn and message.

### Runtime-Specific Assumptions Leaked Into Core

- Claude `Agent` / `SendMessage` details appear in general work command docs.
- Pi subagent behavior appears in architecture references that drivers may read.
- Shell command names (`rws`, `alm`, `sds`, `frw`) are used as if they are core
  semantics.
- `model_default: sonnet` in driver skills is provider-specific. Core should
  express capability/effort needs, not model names.
- Cross-model review is described through `frw cross-model-review`, not a
  backend-neutral review capability.

## 8. Process-Learning Findings

### What Learnings Are Actually Encoded

- Completion evidence encoded a concrete learning: TODO capture cannot hide
  truth-critical work.
- Normalized `ToolEvent` and `PresentationEvent` encoded a concrete learning:
  backend contracts cannot parse provider payloads directly.
- Layer policy encoded a concrete learning: agent layers need mechanical
  boundaries, not prompt-only trust.
- Focused row and direct-state guards encode concrete operational lessons.

### What Learnings Are Just Archived

- Many almanac TODOs are stored as future intentions rather than changed
  behavior.
- Process learnings JSONL files are promoted or archived, but not reliably
  transformed into checks, smaller prompts, or defaults.
- Roadmap phases preserve migration ambitions, but the presence of 177 TODOs
  shows capture is outpacing closure.
- Rationale inventory can become a museum of why files exist instead of a
  deletion driver.

### How TODO Capture Should Change Philosophically

TODO capture should stop being the default escape valve. A TODO is acceptable
only when one of these is true:

- It is outside the user's real ask.
- It is discovered-adjacent and does not affect the current completion claim.
- The current row explicitly downgrades its claim and updates visible planning
  surfaces in the same changeset.

TODO capture should require a disposal path: delete, merge, schedule, or encode
as policy. If a TODO survives multiple roadmap regenerations without becoming a
row or a check, it is probably backlog noise.

## 9. Recommended Next Moves

### Immediate Deletions / Collapses

- COLLAPSE: freeze new work on `bin/frw.d`, `rws`, `alm`, and `sds` except for
  migration support.
- COLLAPSE: remove stub Go commands from advertised user-facing help or label
  them explicitly as reserved.
- DELETE: `team-plan.md` as an active concept.
- COLLAPSE: `source_todo` / `source_todos` into one canonical field.
- COLLAPSE: `branch` / `branch_name` into one backend field.
- COLLAPSE: command markdown references to `rws transition`, `rws status`, and
  `alm validate` where Go backend commands now exist.
- DELETE / ARCHIVE: stale roadmap/TODO entries that describe already superseded
  migrations or speculative product ideas.

### Short Redesign Sessions

- REBUILD: define the Furrow core contract in one page:
  row, real ask, evidence, context bundle, layer, handoff, checkpoint, archive.
- REBUILD: create a risk-tiered row model:
  patch row, normal row, architecture/migration row. Strictness scales with risk.
- REBUILD: context loading policy:
  always-on minimum, phase bundle, decision-point references, archive references.
- REBUILD: adapter boundary:
  backend semantic commands; adapter UX commands; no provider policy in core.
- REBUILD: process learning:
  a learning must become a prompt change, check, doc update, or be discarded.

### Roadmap Changes

- Reduce roadmap from a comprehensive migration/product plan to the next 3-5
  concrete rows.
- Make `todos.yaml` or seeds a backlog input, not an always-consulted operating
  surface.
- Add an explicit "delete process" phase before adding more adapter or roadmap
  features.
- Stop adding almanac features until the source-of-truth cutover is complete.

### Things To Explicitly Not Do Yet

- Do not build more roadmap/TODO UX before deciding whether the almanac is core.
- Do not add more adapter-specific philosophy.
- Do not expand Pi parity claims beyond live loaded paths.
- Do not make every row use the full architecture-row ceremony.
- Do not add more review layers to compensate for unclear core purpose.
- Do not implement a TUI/dashboard until the conceptual surface is smaller.

## 10. Final Stance

Furrow should become a compact, model-agnostic truth harness: it preserves the
real ask, builds the right context for the next actor, isolates execution from
orchestration, forces claims to meet evidence, and asks humans only at decisions
that matter. Everything else should be supporting machinery or deleted. The
project does not need more process. It needs fewer core concepts, harder truth
gates, lazier context, thinner adapters, and a ruthless cutover away from legacy
shell-era and roadmap-era sprawl.

PHILOSOPHY_AUDIT_COMPLETE
