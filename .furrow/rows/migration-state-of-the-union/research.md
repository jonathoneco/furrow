# Migration State of the Union — Research

Read-only diagnosis of two coupled migrations. Citation format: `path:line`. Doc disagreements are surfaced, not silently resolved.

**Migrations under review:**
- **A — CLI substrate**: shell (`bin/frw`, `bin/rws`, `bin/alm`, `bin/sds`, `bin/frw.d/hooks/`, `commands/lib/*.sh`) → Go binaries.
- **B — Harness substrate**: Claude Code adapter (`.claude/commands/`, `.claude/hooks/`, `.claude/CLAUDE.md`, `skills/`) → Pi (the new operating layer).

**Top-line finding (preview, revised after parity audit §7 and empirical audit §8):** The migration is materially more complete than initial analysis suggested. Pi *does* have a `tool_call` interceptor for state mutations (`adapters/pi/furrow.ts:883-899`), and the empirical record confirms it fires 8+ times across 11 sessions with no workarounds attempted — state-guard works in production. **The user's pain is real but narrower than "Pi has no enforcement":** it is the gap between *state-correctness parity* (which Pi has) and *operator-experience parity* (which Pi lacks for adjacent guards — backend validates at transition time, so the agent burns tokens producing work that gets blocked only at the boundary). Empirical audit ranks the worst-pain gaps: **(1) `validate-definition` (~670 mentions, 10 backend error codes)**, **(2) `ownership-warn` (136 mentions)**, **(3) `post-compact` recovery (no Pi equivalent at all; multi-session rows broken)**. `validate-summary` rated highest in the predictive audit but had **zero empirical incidents** in the transcripts and drops out. `correction-limit` is real friction but cleaner as Pi-visibility (footer widget) than Pi-side block. Recommended next move (revised, empirically grounded): **archive `pi-adapter-foundation` as superseded; `/work` a fresh row scoped to the empirical top-3** — `validate-definition`, `ownership-warn`, `post-compact`. Validation logic stays backend-canonical (`frw hook <name>` shell-out); the win is in *event timing and recovery UX*, not bespoke logic.

---

## 1. Intended End-State (per migration)

### Migration A — CLI substrate (shell → Go)

The Go binary becomes the single canonical backend; shell scripts retire to thin delegation shims or are removed.

> "Go owns domain logic" (`docs/architecture/go-cli-contract.md:16`)
> "shell wraps or delegates" (`docs/architecture/core-adapter-boundary.md:140`)
> "the future canonical binary should be `furrow`, with legacy wrappers preserved during migration" (`docs/architecture/go-cli-contract.md:38-39`)

The boundary is drawn at the `.furrow/` filesystem:

> "Go CLI owns domain logic, `.furrow/` remains canonical state, runtime adapters call the CLI through stable JSON interfaces" (`docs/architecture/go-cli-contract.md:16-18`)
> "No direct state mutation outside the CLI" (`docs/architecture/go-cli-contract.md:23`)
> "shell becomes migration shims, not long-term core" (`docs/architecture/core-adapter-boundary.md:137-138`)

By end of Migration A, shell entrypoints are pass-through wrappers or removed; no shell domain logic survives.

### Migration B — Harness substrate (Claude Code → Pi)

Pi (`adapters/pi/furrow.ts` / Pi extension layer) becomes the primary orchestration host; Claude Code adapter reduces to a thin teammate-compatibility layer.

> "Pi is allowed to be better" (`docs/architecture/dual-runtime-migration-plan.md:96`)
> "Pi becomes the primary authoring workflow" (`docs/architecture/dual-runtime-migration-plan.md:213-214`)
> "Single primary work entrypoint: Pi must converge toward one primary `/work`-like entrypoint concept" (`docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:68-69`)
> "Adapters stay thin: registration, hook/event wiring, host-native rendering, host-specific invocation shims" (`docs/architecture/dual-runtime-migration-plan.md:88-92`)

Claude compatibility persists only for teammate participation:

> "Claude-compatible for teammate participation" (`docs/architecture/dual-runtime-migration-plan.md:23`)
> "preserve Claude compatibility where cheap and non-distorting" (`docs/architecture/dual-runtime-migration-plan.md:99-101`)

By end of Migration B, Pi's `/work` loop, skills, system-prompt shaping, and extensions form the operational surface; Claude Code remains for limited use via the same Go backend.

---

## 2. Per-Row Status (8 rows)

Row-status format: **name** | step | step_status | deliverables (done/total) | last gate | archived?

### CC→Pi rows

**pi-adapter-foundation** | implement | not_started | **0/3** | decompose→implement (pass) | active, focused
- *Promised* (`definition.yaml`): "row-model-continuation" (advance roadmap row without spawning a todo-row), "evaluator-grade-review-semantics" (richer backend review validation), "archive-disposition-signals" (review-derived follow-up candidates).
- *Shipped vs promised*: **Phantom row.** Spec.md names backend changes (`furrow review status --json`, `furrow review validate --json`, enriched archive signals); the actual code for "richer backend review validation, gate evidence files, blocker taxonomy, archive checkpoints" landed in `pi-step-ceremony-and-artifact-enforcement` (commit `e4adef5`, `internal/cli/`). The row's own `handoff.md:29` says "continue in a new in-scope row rather than reopening this archived one" — the row is inviting its own replacement.

**pi-adapter-promotion** | review | completed | **3/3** | implement→review (pass) | archived 2026-04-24T17:19:03Z
- *Promised*: move Pi adapter from `.pi/extensions/furrow.ts` into repo-owned `adapters/pi/furrow.ts` while keeping it thin/backend-driven.
- *Shipped vs promised*: **Met cleanly.** `adapters/pi/furrow.ts` exists; shim re-export at `.pi/extensions/furrow.ts`; `/furrow-overview`, `/furrow-next`, `/furrow-transition`, `/furrow-complete` validated in temp repo (commit `c05edaf`).

**pi-furrow-operating-layer** | review | completed | **5/5** | implement→review (pass) | archived 2026-04-24T17:19:03Z
- *Promised*: first usable Pi-side Furrow operating layer (`furrow-overview/-next/-transition`), backend-mediated guidance, lightweight discipline (refuses to bluff, blocks direct `.furrow` edits), durable artifacts.
- *Shipped vs promised*: **Met cleanly.** Surfaced one gap (final-bookkeeping required state edits) and explicitly handed it off to `backend-mediated-row-bookkeeping`.

**pi-step-ceremony-and-artifact-enforcement** | review | completed | **0/3 in state.json** (recording gap) | review→archive (pass) | archived 2026-04-24T22:15:55Z
- *Promised*: backend-work-loop-support (artifact validation, blocker taxonomy, gate evidence files, `row archive`), Pi `/work` command with supervised checkpoints, validation across go test + headless Pi.
- *Shipped vs promised*: **Delivered, but the state.json deliverables map is empty.** Handoff and validation files prove delivery (`internal/cli/` hardened in `e4adef5`, `furrow row archive` exists, blocker taxonomy in place, Pi `/work` consumes archive checkpoint). Archival backfill failed to record formal deliverable completion in `state.json`. **This is a recording gap, not a delivery gap — but it is exactly the kind of accounting drift that downstream rows then mistake for missing work.**

### shell→Go rows

**go-backend-slice** | review | completed | **5/5** | implement→review (pass) | archived 2026-04-24T19:24:51Z
- *Promised*: minimum shared Go backend slice — `furrow almanac validate --json`, `furrow row list/status/transition --json`, `furrow doctor --json`, atomic writes, unknown-field preservation, durable artifacts, `go test ./...` passing.
- *Shipped vs promised*: **Met cleanly.** Code lives at `cmd/furrow/main.go`, `internal/cli/{almanac,row,doctor,review,row_semantics,row_workflow,app}.go` (commit `b75d60a`). Spec explicitly defers artifact validation, gate-policy enforcement, seed sync, summary regen, review/archive — all later picked up by `pi-step-ceremony`.

**frw-cli-dispatcher** | review | completed | **6/6** | implement→review (pass) | archived 2026-04-03T18:53:39Z
- *Promised*: `bin/frw` POSIX-sh dispatcher, all 10 hooks + 17 scripts migrated to `bin/frw.d/{hooks,scripts}/`, `frw init/install`, ~100 file references updated, old `hooks/` and `scripts/` deleted.
- *Shipped vs promised*: **Met cleanly.** `bin/frw` is operational; old dirs deleted; install check passes. **Note:** this row was a *shell consolidation*, not a Go migration. It is sometimes mistaken for shell→Go work because the row name precedes `go-backend-slice` in time.

**backend-mediated-row-bookkeeping** | review | completed | **3/3** | implement→review (pass) | archived 2026-04-24T17:19:03Z
- *Promised*: one narrow backend command for Pi bookkeeping; atomic state updates; Pi-flow exercise without state-file edits.
- *Shipped vs promised*: **Met cleanly.** Added `furrow row complete <name> --json` to `internal/cli/row.go` (commit `c05edaf`). **Anomaly:** `state.json.base_commit` is the literal string "unknown" — suggests manual creation outside standard seed machinery. Not a delivery problem, but it's a procedural smell consistent with the `pi-step-ceremony` recording gap.

**namespace-rename** | review | completed | **2/2** | implement→review (pass) | archived 2026-04-03T01:30:00Z
- *Promised*: rename project namespace `harness`→`furrow`, audit shell scripts for macOS/WSL portability.
- *Shipped vs promised*: **Met.** Wave 1: 100-file rename (commit `e2e268e`). Wave 2: `readlink -f` BSD fallback, `expr` comparison fix, shellcheck clean (commit `9d37dc6`). **Gap:** `spec.md` was never produced — research.md + summary.md substitute. This is a low-impact procedural exception, not a content gap.

### Summary table (counts)

| Row | Migration | Step | Deliverables | Archived |
|-----|-----------|------|--------------|----------|
| pi-adapter-foundation | B (CC→Pi) | implement | 0/3 | **No (focused)** |
| pi-adapter-promotion | B | review | 3/3 | Yes |
| pi-furrow-operating-layer | B | review | 5/5 | Yes |
| pi-step-ceremony-and-artifact-enforcement | B | review | 0/3 (recording gap) | Yes |
| go-backend-slice | A (shell→Go) | review | 5/5 | Yes |
| frw-cli-dispatcher | A* | review | 6/6 | Yes |
| backend-mediated-row-bookkeeping | A (Go extension) | review | 3/3 | Yes |
| namespace-rename | A (precursor) | review | 2/2 | Yes |

*`frw-cli-dispatcher` is a shell-consolidation row that paved the way for Go but did not itself migrate to Go.

---

## 3. Dependency Graph

### Roadmap-declared edges (`.furrow/almanac/roadmap.yaml`)

Phase 2 (contract freeze) gates Phase 3 (Pi):

```
dual-runtime-target-architecture (roadmap.yaml:69, active)
        │
        ├─→ go-cli-contract-v1 (roadmap.yaml:73, active)
        │         │
        │         └─→ cli-architecture-overhaul (roadmap.yaml:61, active)
        │                   │
        └─→ migration-operating-mode (roadmap.yaml:79, active)
                            │
                            ↓
                  pi-adapter-package (roadmap.yaml:91, active, depends on cli-architecture-overhaul + go-cli-contract-v1)
                            │
                            ├─→ workflow-power-preservation (roadmap.yaml:98)
                            │           │
                            │           └─→ pi-step-ceremony-and-artifact-enforcement (roadmap.yaml:104, COMPLETED)
                            │                       │
                            │                       └─→ work-loop-boundary-hardening (roadmap.yaml:111, active)
                            │
                            └─→ backend-mediated-row-bookkeeping (roadmap.yaml:125, COMPLETED)
                            │
                            ↓ (Phase 7 gate)
                  dual-runtime-parity-validation (roadmap.yaml:131)
                            │
                            └─→ pi-native-capability-leverage (roadmap.yaml:138)
```

### Row-level edges (from `definition.yaml`/`spec.md` cross-references)

- `pi-furrow-operating-layer` → `backend-mediated-row-bookkeeping` (`pi-furrow-operating-layer/spec.md:29-30` — handed off the manual-bookkeeping gap).
- `pi-step-ceremony-and-artifact-enforcement` → `pi-adapter-foundation` (`pi-step-ceremony.../handoff.md:29` — directs continuation to a "new in-scope row").
- `pi-adapter-foundation/handoff.md` → "new in-scope row" (forward-deferring to a row that does not yet exist).
- `backend-mediated-row-bookkeeping/definition.yaml:25` → `pi-furrow-operating-layer/summary.md` (closing a gap that row identified).
- `pi-adapter-promotion` and `namespace-rename` are **standalone** — no row-level cross-references in/out.

### Architecture-doc anchors

- All four CC→Pi rows cite `docs/architecture/dual-runtime-migration-plan.md`, `core-adapter-boundary.md`, and `pi-parity-ladder.md`.
- `pi-step-ceremony-and-artifact-enforcement` self-references `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` (`spec.md:16`).
- `cli-architecture.md` is implicitly orphaned vs the rows: it documents the *shell-era* three-CLI model that is being replaced; no row points at it as canonical guidance.

### Orphans

- **No row-side orphans found.** All 8 rows map to roadmap nodes.
- **One doc orphan**: `cli-architecture.md` describes the pre-migration topology and is retrospective; nothing in-flight points at it as authority.
- **One forward-orphan edge**: `pi-adapter-foundation/handoff.md:27-29` defers continuation to a row that does not yet exist — the dangling edge is the symptom this research row is investigating.

---

## 4. Gap Matrix

### Migration A — shell → Go

| Cell | Artifact / Citation |
|------|---------------------|
| **Documented intent** | "Go owns domain logic" (`docs/architecture/go-cli-contract.md:16`); "shell becomes migration shims, not long-term core" (`docs/architecture/core-adapter-boundary.md:137-138`); 5-command Slice 1 (`docs/architecture/go-cli-contract.md:239-254`); CLI overhaul "single Go module per CLI: `cmd/{frw,rws,alm,sds}`" (`.furrow/almanac/roadmap.yaml:61` and `todos.yaml:982-1041`, status `active`). |
| **Landed** | Slice 1 complete: `furrow almanac validate/row list/row status/row transition/doctor --json` + `furrow row complete --json` (rows `go-backend-slice`, `backend-mediated-row-bookkeeping`, both archived). Code at `cmd/furrow/main.go`, `internal/cli/*.go`. `bin/frw` POSIX-sh dispatcher with modular `bin/frw.d/{hooks,scripts}/` (row `frw-cli-dispatcher`, archived). Project rename to `furrow` (row `namespace-rename`, archived). |
| **In-flight** | Roadmap node `cli-architecture-overhaul` (`roadmap.yaml:61`, status `active`) and TODO `cli-architecture-overhaul` (`todos.yaml:982-1041`, status `active`) — *Go rewrite of `frw`/`rws`/`alm`/`sds` themselves*, not just Slice 1. **No row currently carries this work.** |
| **Not started** | Retirement of `bin/rws` and `bin/alm` shell binaries (still POSIX sh — confirmed by row sweep). Retirement of `bin/frw.d/hooks/*.sh` and `commands/lib/*.sh` shell modules. Unification of `frw <cmd>` and `furrow <cmd>` entrypoints under one canonical CLI. |
| **Contradicted / superseded** | None observed. Row `frw-cli-dispatcher` is sometimes misread as Go-migration work but was scoped to shell consolidation only. |

### Migration B — Claude Code → Pi

| Cell | Artifact / Citation |
|------|---------------------|
| **Documented intent** | "Pi becomes the primary authoring workflow" (`docs/architecture/dual-runtime-migration-plan.md:213-214`); "Single primary work entrypoint: Pi must converge toward one primary `/work`-like entrypoint" (`docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:68-69`); "preserve Claude compatibility where cheap and non-distorting" (`docs/architecture/dual-runtime-migration-plan.md:99-101`); Pi parity ladder Levels 1-3 (`docs/architecture/pi-parity-ladder.md:52-127`). |
| **Landed** | Pi adapter promoted to `adapters/pi/furrow.ts` (row `pi-adapter-promotion`, archived). Pi `/work` minimum slice with `/furrow-overview`, `/furrow-next`, `/furrow-transition`, `/furrow-complete` (rows `pi-furrow-operating-layer`, `pi-step-ceremony-and-artifact-enforcement`, archived). Backend-mediated transitions, blocker enforcement, supervised checkpoints, archive ceremony (row `pi-step-ceremony-and-artifact-enforcement`). Pi parity at **Level 2** (`docs/architecture/pi-parity-ladder.md:121-127`). |
| **In-flight** | Roadmap node `work-loop-boundary-hardening` (`roadmap.yaml:111`, active). Row `pi-adapter-foundation` is the *nominal* carrier — but see "contradicted/superseded" below. |
| **Not started** | Roadmap node `parallel-orchestration-and-launch-surfaces` (`roadmap.yaml:118`). `dual-runtime-parity-validation` (Phase 7, `roadmap.yaml:131`). `pi-native-capability-leverage` (Phase 7, `roadmap.yaml:138`). Reduction of `.claude/commands/`, `.claude/hooks/`, `skills/` to true Claude-compat thin layer. Phases 4-8 of the roadmap (worktree pipeline, seeds primitive, artifact UX, post-seeds re-triage). |
| **Contradicted / superseded** | **`pi-adapter-foundation` deliverables are largely satisfied by `pi-step-ceremony-and-artifact-enforcement`.** Spec promises "evaluator-grade review semantics" (`pi-adapter-foundation/spec.md`) — code for richer review validation, gate evidence files, blocker taxonomy, archive checkpoints landed in `pi-step-ceremony` (commit `e4adef5`, `internal/cli/`). The row's own `handoff.md:29` instructs continuation in a "new in-scope row." |

---

## 5. Friction Diagnosis

Six hypotheses tested against evidence. Verdicts: **accepted / partial / rejected**.

### H1: Scope creep / row proliferation without a single critical path — **PARTIAL**

The critical path *is* documented (`roadmap.yaml` Phases 1→2→3→…) and rows do map to roadmap nodes. But the row-to-deliverable accounting has drifted: `pi-step-ceremony-and-artifact-enforcement` shipped backend changes that satisfied `pi-adapter-foundation`'s deliverables without being attributed to that row, then got archived with **0/3 deliverables in its own state.json** (a recording gap). The result is two adjacent rows that both think the work is "still to do" — visible scope creep is small, but accounting drift creates phantom-row stalls.

Evidence: `pi-adapter-foundation/state.json` shows `0/3, implement/not_started`; `pi-step-ceremony.../state.json.deliverables = {}` despite `handoff.md` proving full delivery; `pi-step-ceremony.../handoff.md:29` instructs forward-handoff into a non-existent row.

### H2: Documentation drift / no canonical source — **REJECTED**

Authority is explicit and binding:
> "For migration work, use this authority order" (`docs/architecture/migration-stance.md:172`) — followed by a hierarchy of `repo implementation reality > row validation > row slice spec > roadmap and todos` (`migration-stance.md:170-182`).
> "Canonical architecture docs must not become a dumping ground for row-local migration residue" (`docs/architecture/documentation-authority-taxonomy.md:28-29`).

The single doc tension found (`cli-architecture.md:42-46` vs `pi-step-ceremony-and-artifact-enforcement.md:315-324` on adapter scope) is reconcilable: backend owns *semantics*, Pi owns *presentation of orchestration*. No live contradiction is forcing readers to guess which doc to follow.

### H3: Coupled migrations — progress on one blocks the other — **PARTIAL**

The roadmap explicitly couples them (`pi-adapter-package` `depends_on: [cli-architecture-overhaul, go-cli-contract-v1]`, `roadmap.yaml:91-97`). But the coupling has been *managed*: Slice 1 of the Go contract was deliberately scoped narrow (`docs/architecture/go-cli-contract.md:239-254`) so Pi could begin consuming it before the full shell→Go rewrite. Pi reached parity Level 2 against an incomplete backend without blocking. The hybrid CLI substrate (shell `frw`/`rws`/`alm` + Go `furrow`) is a *feature*, not a stall — it's what `migration-stance.md:195-203` calls for.

The friction is real only at the rim: **Migration A's outer ring (full Go rewrite of `rws`/`alm`/`sds`) has no row carrying it.** `cli-architecture-overhaul` is `active` in both roadmap and todos but unattached to any row.

### H4: Premature abstraction — **REJECTED**

The adapter boundary was not defined before either runtime existed. By the time `core-adapter-boundary.md` and `host-strategy-matrix.md` were authored, `cmd/furrow/main.go` had real commands and `adapters/pi/furrow.ts` was a real extension. Pi parity is at Level 2 (`docs/architecture/pi-parity-ladder.md:121-127`); shipped commands listed in `go-cli-contract.md:256-266` are the same commands cited as backing parity in `pi-parity-ladder.md:52-58`. No abstraction is floating untethered.

### H5: Hybrid/half-state aversion vs clean-swap preference forcing larger steps — **PARTIAL**

The user has a documented "clean swap preference" (auto-memory). The architecture docs explicitly *embrace* hybrid for the duration:

> "shell wraps or delegates" (`docs/architecture/core-adapter-boundary.md:140`)
> "preserve Claude compatibility where cheap and non-distorting" (`docs/architecture/dual-runtime-migration-plan.md:99-101`)
> "use the existing Furrow Pi adapter in `adapters/pi/furrow.ts`, … avoid parallel adapter paths" (`docs/architecture/migration-stance.md:195-203`)

The current observable state *is* hybrid: shell `bin/frw` + Go `cmd/furrow` coexist; Pi `/work` and Claude `/furrow:*` commands coexist. The architecture says this is correct *during* migration. The friction shows up when the focused row is asked to deliver "the next step" without a clean cutover semantic — `pi-adapter-foundation` cannot be cleanly closed because there is no clean swap to anchor it on. This is partial-acceptance: the friction is real but it's a *tension* between user preference and architecture, not a process failure.

### H6: Harness ↔ CLI dependency cycles — **REJECTED**

No cycle observed. The dependency direction is consistent: shell hooks → Go backend → Pi adapter. Pi consumes Go via subprocess (`go run ./cmd/furrow ... --json`); Go has no inbound dependency on Pi or Claude. `cli-architecture-overhaul` is not blocked on Pi; Pi work has not been blocked on full Go rewrite (Slice 1 was sufficient).

### H7 (user-reported, added post-initial-analysis): Pi has no structural enforcement layer — **ACCEPTED, DOMINANT**

User signal: "when using Pi, it is not following the Furrow experience / enforcement and that is causing me great headache." Verified against codebase and docs.

**Claude-side enforcement (current, working):**
- 16 shell hooks in `bin/frw.d/hooks/` invoked via `frw hook <name>` from `.claude/settings.json`:
  - `PreToolUse / Write|Edit`: `state-guard`, `ownership-warn`, `validate-definition`, `correction-limit`, `verdict-guard`, `append-learning`
  - `PreToolUse / Bash`: `gate-check`, `script-guard`
  - `Stop`: `work-check`, `stop-ideation`, `validate-summary`
  - `SessionStart`: `auto-install`
  - `PostCompact`: `post-compact`
- Two `.claude/rules/` files (`cli-mediation.md`, `step-sequence.md`) carry the **must-not** / **must** rules into the agent's ambient context.

**Pi-side enforcement (current, gap):**
- `adapters/pi/furrow.ts` (1480 lines) is a *renderer of backend signal*, not an *enforcer*. It surfaces blockers from `furrow row status --json`, refuses to advance when the backend reports blocked, refuses to fabricate state — this is "lightweight discipline" per `pi-furrow-operating-layer/spec.md`.
- **No equivalent hook layer**: no Pi-side `PreToolUse` → `state-guard`, no `Stop` → `validate-summary`, no `Bash` → `script-guard`, no `PostCompact` recovery, no correction-limit.
- The Pi adapter has no `.pi/rules/` equivalent shipping `cli-mediation` / `step-sequence` discipline as ambient rules.

**Architecture acknowledgement of the gap:**
> "Warnings are not enough. Some Furrow value comes from structural enforcement. The migration should preserve or rebuild enforcement around: …" (`docs/architecture/workflow-power-preservation.md:204-205`)
> "continued blocker/enforcement taxonomy alignment across Pi and Claude-compatible flows" (`docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:407` — listed under *fast follow after this slice*)

The docs explicitly say enforcement must be preserved or rebuilt and that taxonomy alignment is a fast-follow. Neither was carried by any of the 8 rows in scope.

**Where this slipped through:**
- `pi-step-ceremony-and-artifact-enforcement` is named "artifact enforcement" but its actual scope was *backend* artifact validation surfaces (`furrow row status --json` exposing validation data, gate evidence files, blocker taxonomy) — i.e., it shipped what enforcement should *measure*, not what *executes* enforcement on the Pi side.
- `pi-furrow-operating-layer` shipped "lightweight discipline" inside the adapter (refuses to bluff, blocks direct `.furrow/.focused` and `state.json` edits via the adapter's own logic, `pi-furrow-operating-layer/summary.md`), but that is a single softguard inside one TypeScript file, not the multi-event hook surface that Claude has.
- No row promised, scoped, or shipped Pi-native equivalents of the 14 enforcement-event hooks (excluding `auto-install` and `post-compact`, which are infrastructure).

### Composite verdict

The original analysis identified two friction sources (H1 accounting drift, H5 clean-swap tension). The user's reported pain points to a **third, dominant** source: **H7 enforcement-parity gap.**

Revised friction priority:
1. **H7 — enforcement asymmetry between Claude and Pi adapters** (DOMINANT). Pi shipped the loop without the guardrails; the docs anticipated this would need to follow but no row is carrying it.
2. H5 — clean-swap tension (PARTIAL). Real but secondary to H7.
3. H1 — scope-accounting drift (PARTIAL). Real but downstream: `pi-adapter-foundation` looks stuck because (a) its scope was satisfied elsewhere AND (b) the row that should follow it (Pi enforcement parity) has not been authored.
4. H2/H3/H4/H6 — rejected as before.

The composite story: Pi reached Level 2 parity *as measured by the parity ladder* (commands available, supervised checkpoints surfaced) but Level 2 parity per `pi-parity-ladder.md` does not include hook-level enforcement. The user is operating at a parity level the docs describe as not-yet-shipped, and feeling exactly the gap the docs warned about.

---

## 6. Recommended Next Move (revised after user pain signal)

### **Archive `pi-adapter-foundation` as superseded; `/work` a fresh row scoped to Pi enforcement parity.**

This is option (c) at the row-accounting layer combined with a (b)-style pivot in *what the next focus should be*. The brief asked for one of (a/b/c/d); the closest single label is **(c)**, but the successor row is materially different from what the original recommendation sketched, so it deserves separate framing.

**Why this, in order of weight:**

1. **It addresses the user's actual pain.** `pi-adapter-foundation` cannot fix "Pi doesn't enforce" because its spec is about *evaluator-grade review semantics* and *archive disposition signals*, not enforcement. Resuming it (option a) leaves the headache untouched.
2. **It targets the dominant friction (H7).** The enforcement asymmetry is real, the docs anticipate it (`workflow-power-preservation.md:204-205`, `pi-step-ceremony.../md:407`), and no row is carrying it.
3. **It exits the phantom-row state cleanly.** The original analysis already showed `pi-adapter-foundation` is satisfied/superseded; closing it is correct independent of the new pain signal.
4. **(d) is wrong — freezing locks in the headache.** The current "hybrid" state isn't a stable rest point if Pi is the user's preferred host and Pi has no enforcement. Stabilizing here means accepting the pain.

### Concrete successor-row sketch (for user to ratify)

**Working name (suggested):** `pi-enforcement-parity` or `pi-hook-surfaces` — user picks.

**Scope (strawman, to refine in the row's ideate step):**

| Claude hook | Pi-side equivalent target | Why structural enforcement (not just rendering) |
|-------------|---------------------------|--------------------------------------------------|
| `state-guard` (PreToolUse Write/Edit) | Pi extension intercepts `Write`/`Edit` to `state.json`, hard-blocks | Today: backend refuses out-of-band, but agent can still write the file in-session and confuse subsequent reads |
| `validate-summary` (Stop) | Pi extension runs on stop / before next user turn, hard-fails on missing sections | Today: stop hook ran on this very row and saved us — no Pi equivalent |
| `correction-limit` (PreToolUse Write/Edit) | Pi extension tracks per-deliverable correction count, blocks at limit | Today: agent can grind on a deliverable indefinitely in Pi |
| `gate-check` (PreToolUse Bash) | Pi extension intercepts shell with row-context filtering | Today: agents can run `rws transition` out of order |
| `verdict-guard`, `ownership-warn`, `script-guard`, `validate-definition`, `append-learning`, `work-check`, `stop-ideation` | Per-hook decision: port, rebuild, or fold into Pi-native primitives | Some are good ports; some (`auto-install`, `post-compact`) are infrastructure and may not need Pi parity |

**Explicit non-scope:**
- Reimplementing the hooks *in TypeScript*. They can stay shell — the Pi extension can shell out to `frw hook <name>` the same way Claude does today (`.claude/settings.json` calls `frw hook state-guard`). What changes is the *event wiring*, not the hook body.
- Inventing new enforcement. Parity = the existing 14 enforcement hooks (excluding `auto-install`, `post-compact` which are infrastructure).
- Pi-native UX work beyond what's needed to wire events.

**Roadmap anchor:** Existing node `dual-runtime-parity-validation` (`roadmap.yaml:131`, Phase 7) is the right *validation* anchor; but the *delivery* needs a new node or an extension of `work-loop-boundary-hardening` (`roadmap.yaml:111`). User should decide whether to update the roadmap as part of this work or after.

**Mode:** `code` (this is a build, not a research row). Gate policy `supervised`.

### Why not other options

- **(a) Resume `pi-adapter-foundation`:** Spec is contaminated, doesn't address the pain, and the row's own handoff says "continue in a new in-scope row."
- **(b) Pivot to a different *existing* row:** No existing row carries enforcement-parity. `work-loop-boundary-hardening` is the closest fit but it's a roadmap node, not a row.
- **(d) Freeze:** Locks in the headache. Pi is the user's preferred host; freezing means accepting Pi without enforcement.

### Procedural cleanup to bundle (low-cost, high-clarity)

These are adjacent and worth packaging into the new row's first commits or a parallel cleanup pass:

1. **Backfill `pi-step-ceremony-and-artifact-enforcement.state.json.deliverables`** to close the recording gap.
2. **Rewrite or remove `pi-adapter-foundation/handoff.md:27-29`** so it stops aiming future work at a phantom successor.
3. **Decide the placement of `cli-architecture-overhaul`** (Migration A outer ring — full Go rewrite of `rws`/`alm`/`sds`/`bin/frw.d/hooks/`). It is `status: active` in both `roadmap.yaml:61` and `todos.yaml:982-1041` but has no row. **Note the cross-cutting tension:** if `bin/frw.d/hooks/` is rewritten in Go, the Pi enforcement-parity row may be able to call those Go hooks directly instead of shelling out to `frw hook <name>`. This argues for sequencing enforcement-parity *after* the Go-hook port — or scoping enforcement-parity narrowly so it doesn't have to be redone post-Go-rewrite.

### One sequencing decision the user must make

The enforcement-parity work and the Migration A outer ring (Go-hook rewrite) interact. Two paths:

- **Path 1 (recommended): Pi enforcement parity first, against current shell hooks.** Port event wiring; let Pi shell out to `frw hook <name>` as Claude does. Migration A outer ring follows when the user has appetite. **Pro:** kills the headache fastest. **Con:** the Pi-side wiring will need a small re-pass when shell hooks become Go.
- **Path 2: Migration A outer ring first; Pi enforcement parity against the Go contract.** **Pro:** cleaner final state; no re-pass. **Con:** delays the headache fix by however long the Go-hook rewrite takes (and that work has no row, no scope, no estimate).

Path 1 trades a small re-pass for fast pain relief. Recommended.

---

## 7. Four-Axis Parity Audit (added after user request)

The user requested confirmation that each migration axis has parity (implemented or planned), with divergences accounted for as either explicit improvements or philosophical choices. Four parallel audit sweeps were run. **Headline:** the migration is materially more complete than §1-6 framed it, but a real friction zone survives at "operator-experience parity" — specifically *when* enforcement fires, not whether it exists.

### Axis A — shell → Go CLI

| Status bucket | Count | Notes |
|---|---|---|
| Implemented | 8 commands | `furrow row init/list/status/transition/focus/scaffold/archive/complete` + `furrow doctor` + `furrow almanac validate` (Slice 1 + extensions). Code at `cmd/furrow/main.go`, `internal/cli/*.go`. |
| Stubs declared | ~9 | `furrow seeds {create,list,show,update,close}`, `furrow row summary/validate/checkpoint`, `furrow almanac todos/rationale list`. |
| Planned (no row) | `cli-architecture-overhaul` | `roadmap.yaml:61` and `todos.yaml:982-1041`, `status: active`. The full Go rewrite of `rws`/`alm`/`sds`/`bin/frw.d/hooks/` is not yet attached to any row. |
| Explicit-divergence | 3 | (a) merge 5-phase shell → 3-phase Go (`go-cli-contract.md:138-146`); (b) `sds init` merged into `furrow row init` (`go-cli-contract.md:47`); (c) worktree-summary commands deliberately punted to Pi-adapter (`roadmap.yaml:118-124`). All three are *improvements*, doc-sanctioned. |
| Implicit-gap | ~50 commands | `rws complete-deliverable`, `rws update-summary`, `rws complete-step`, `rws add-user-action`, `frw run-gate`, `frw evaluate-gate`, `frw cross-model-review`, `frw normalize-seeds`, `alm extract`, `alm triage`, `alm next`, `alm rationale`, `alm learn`, `sds search`, `sds dep`, etc. **Most of these are real shell-only commands with no Go counterpart and no row plan.** |

**Verdict on Axis A:** *partial implementation, partial planning, large implicit-gap surface*. Slice 1 is real. The outer ring (`cli-architecture-overhaul`) is named but unattached. The 50+ implicit-gap commands fall into two buckets — workflow (complete-deliverable, add-user-action, triage, next) which need to be promoted to backend OR remain shell, and utilities (normalize, migrate-from-beans, rescue) which are lower priority. **No doc explicitly resolves this triage.**

### Axis B — Claude ↔ Pi adapter

| Status bucket | Examples | Notes |
|---|---|---|
| Implemented | `/work`, `/furrow-overview`, `/furrow-next`, `/furrow-transition`, `/furrow-complete`; `tool_call` interceptor at `adapters/pi/furrow.ts:883-899` (state-guard equivalent); `session_start` at `:879`; `ctx.ui.confirm` / `ctx.ui.select` dialogs at `:1024, :1113, :1423`; status footer at `:864`; custom message renderer at `:871-877` | Real interception verified. Pi *does* have hook-event handlers, contrary to my earlier claim. |
| Planned | Specialist registration as Pi agent types (`roadmap.yaml:300`, `sub-agent-normalization`); review parity (`pi-parity-ladder.md:194-209`, deferred to Level 3); package surface (`pi-native-capability-leverage.md:198-220`) | All deferred-by-design per ladder ordering. |
| Explicit-divergence (Pi-better-by-design, sanctioned) | Pi embeds checkpoint/archive/init/doctor *inside* `/work` rather than standalone commands; `/furrow-overview` and `/furrow-complete` are Pi-only convenience surfaces; richer dialogs and footer widget; thinner `session_start` (refresh, not install) | Sanctioned by `host-strategy-matrix.md:32-37` ("Hook/event mechanism: no, yes, enough"; "TUI/footer/status/widgets: no, yes, no"). |
| Explicit-divergence (Claude-only by design) | `/furrow:meta` (self-modification), `/furrow:review` Phase B (cross-model fresh evaluator), specialist `Task` dispatch | Claude has features Pi doesn't and isn't supposed to. |
| Implicit-gap | `/furrow:reground`, `/furrow:redirect`, `/furrow:triage`, `/furrow:work-todos`, `/furrow:update`, phase-level `/furrow:next` | None are doc-warned; all are real Pi gaps. |

**Verdict on Axis B:** *materially more parity than the §5 H7 finding implied*. Pi has real interception and supervised UX. The remaining gaps are concentrated in phase-level operations (triage, roadmap regen, multi-row coordination) and recovery commands (reground, redirect).

### Axis C — Furrow functionality (capabilities)

29 capabilities audited:
- **10 parity-implemented** (row lifecycle: creation, continuation, transitions, completion, archival, doctor, init, checkpoint, etc.)
- **10 parity-planned** (deferred to Phases 3-7: review, merge, seeds-backed planning, parallel dispatch, worktree, etc.)
- **4 explicit-divergence (Claude-only by design)**: specialist delegation, `/furrow:meta`, `/furrow:review`, cross-model evaluation
- **4 implicit-gap**: `/furrow:work-todos` (TODO extraction), `/furrow:triage` (roadmap regen), `/furrow:reground` (different model — Pi regrounds implicitly), parallel agent dispatch
- **1 not-yet-attempted**: user actions (deferred to Phase 7)

**Critical finding:** Pi is **row-focused**. Phase-level lifecycle — triage, multi-phase next, roadmap regen — is **Claude-only with no row carrying its Pi port**. `roadmap.yaml` Phase 5 (seeds-backed planning) is supposed to subsume this but has no row.

**Verdict on Axis C:** *Pi has Level 2 single-row parity but cannot drive multi-row or phase-level work*. The user can complete one row in Pi end-to-end; navigating between rows or regenerating the roadmap requires Claude.

### Axis D — Furrow enforcement (the user's pain axis)

11 enforcement mechanisms (10 hooks + 2 rules) audited:

| Status bucket | Mechanisms |
|---|---|
| Implemented natively in Pi | `state-guard` (Pi `tool_call` interceptor at `adapters/pi/furrow.ts:883-899`); `cli-mediation` rule (encoded in interceptor reason text at `:894-898`); `step-sequence` rule (enforced via `RowStatusData.row.next_valid_transitions` whitelist at `:129`) |
| Partial — *backend validates at transition, not at write* | `ownership-warn`, `validate-definition`, `correction-limit`, `validate-summary`, `stop-ideation`, `append-learning`, `work-check` |
| Not-applicable to Pi by design | `verdict-guard` (Pi ≠ evaluator); `script-guard` (Pi has no Bash tool); `auto-install` (Pi has no install lifecycle); `post-compact` (Pi has no compaction) |
| Pre-commit (orthogonal, both runtimes) | `pre-commit-bakfiles`, `pre-commit-script-modes`, `pre-commit-typechange` — git-layer guards, not adapter parity concern |

**The crucial observation the parity audit understates:**

The "partial — backend validates at transition" verdict is *technically* parity (state correctness is preserved) but operationally a real gap. Concretely:

- `validate-summary` in Claude: blocks **stop** when summary sections are empty. *This hook fired on this very row mid-conversation and forced me to populate sections.* In Pi: backend blocks transition. **But the user can stop Pi without transitioning** — leaving the next session to pick up a broken summary.
- `correction-limit` in Claude: blocks `Write`/`Edit` to a deliverable's files after N retries. In Pi: backend blocks `row complete`. **But the agent can grind on the deliverable indefinitely between completions** — burning tokens on wrong work that gets rejected only at the boundary.
- `validate-definition` in Claude: blocks save of invalid `definition.yaml`. In Pi: backend blocks at next backend call. **But the agent has already shipped the invalid file to the working tree.**
- `ownership-warn` in Claude: warns at `Write`/`Edit` outside file_ownership. In Pi: backend will surface at transition. **But the violation is already in the working tree by then.**
- `append-learning` in Claude: blocks invalid `learnings.jsonl` lines at write. In Pi: backend rejects at archive. **But the file is already corrupted and the user must clean up retroactively.**
- `work-check` and `stop-ideation`: stop-event guards with no Pi equivalent.

**The pattern:** "backend validates at transition" preserves *state correctness* (Pi cannot record an invalid transition) but loses *operator experience* (the agent can produce wrong work locally without being interrupted). The doc claims this is parity per `pi-parity-ladder.md:110-112`. **The user's pain is the gap between state-correctness parity and operator-experience parity.**

The doc anticipates this almost exactly: `workflow-power-preservation.md:204-205` — "*Warnings are not enough. Some Furrow value comes from structural enforcement.*" — and lists the Pi-side rebuild as a fast-follow at `pi-step-ceremony-and-artifact-enforcement.md:407` ("continued blocker/enforcement taxonomy alignment across Pi and Claude-compatible flows"). **No row is carrying this.**

### Cross-axis synthesis

| Axis | Implemented | Planned (rowed) | Planned (no row) | Explicit divergence | Implicit gap |
|---|---|---|---|---|---|
| A — shell→Go CLI | Slice 1 (8 cmds) + 9 stubs | none | `cli-architecture-overhaul` (active, unrowed) | merge 5→3, sds-init merge, worktree-cmds → adapter | ~50 shell commands |
| B — Claude↔Pi adapter | /work loop, tool_call interceptor, dialogs, footer | review parity Level 3, package surface | specialist normalization | embedded-vs-standalone commands; Pi-better dialogs; Claude-only specialist/meta/review | reground, redirect, triage, work-todos, update, phase-level next |
| C — capabilities | 10 (row lifecycle) | 10 (Phases 3-7, mostly unrowed) | parallel dispatch, seeds-backed planning, worktree | specialist, meta, review, cross-model (Claude-only by design) | todo extraction, triage/roadmap regen, reground model, parallel dispatch |
| D — enforcement | state-guard, cli-mediation, step-sequence | dual-runtime-parity-validation (Phase 7, unrowed) | none | verdict-guard, script-guard, auto-install, post-compact (n/a by design) | 7 mechanisms with operator-experience gap (validate-summary, correction-limit, validate-definition, ownership-warn, append-learning, work-check, stop-ideation) |

### Are divergences explicit improvements / philosophical, or accidental?

**Explicit / philosophical (sanctioned by docs):**
- All UX divergences (`host-strategy-matrix.md:22-37` — UX parity not required)
- Pi richer dialogs / footer / status widget (`pi-native-capability-leverage.md`)
- Merge 5→3 phase consolidation, sds-init merger, worktree-cmds-to-adapter (Axis A)
- Claude-only specialist, meta, review-Phase-B, cross-model (Axis C)
- 4 enforcement mechanisms (verdict-guard, script-guard, auto-install, post-compact) excluded by design (Axis D)

**Accidental / unrowed (no plan or no row):**
- `cli-architecture-overhaul` — Axis A outer ring; active but unrowed
- 7 enforcement mechanisms with backend-validates-at-transition timing — *technically* sanctioned, *operationally* the user's pain
- Pi phase-level lifecycle (`/furrow:triage`, phase-level `/furrow:next`, multi-row navigation) — no row
- Pi `/furrow:work-todos` equivalent — no row
- Pi `/furrow:reground` and `/furrow:redirect` — no row
- ~50 shell-only commands not in Go contract — no per-command decisions

### What this means for the recommendation

The §6 recommendation stands directionally — archive `pi-adapter-foundation`, scope a successor row — but the successor's scope should be sharper than either the strawman (all 14 hooks) or steelman (full Pi-native leverage). It should target the **operator-experience gap specifically**:

1. The 7 enforcement mechanisms where backend-at-transition ≠ hook-at-write, prioritized by which kill the user's tightest pain. Top three: `validate-summary` (stop-event), `correction-limit` (pre-tool-use), `validate-definition` (pre-tool-use during ideate).
2. Address the unrowed phase-level lifecycle gap as a separate decision (not in the same row): Pi cannot drive multi-row work without `/work-todos`, `/triage`, phase-level `/next`. This is bigger and cleanly separable.
3. Punt the shell→Go outer ring (`cli-architecture-overhaul`) to its own decision — it's not what's causing the headache.



### Primary (architecture docs in `docs/architecture/`, all 13 read in full by subagent)

| Doc | Authority | Stance | Contribution |
|-----|-----------|--------|--------------|
| `dual-runtime-migration-plan.md` | Transitional | Aspirational | Phases A/B/C ordering; backend-canonical/Pi-early/Claude-compat |
| `migration-stance.md` | Transitional | In-flight | Authority hierarchy: impl > planning |
| `core-adapter-boundary.md` | Canonical | Enduring | Backend semantics (Go) vs adapter UX (Claude/Pi); `.furrow/` canonical |
| `cli-architecture.md` | Implied canonical | Retrospective | Shell-era three-CLI model (sds/rws/alm) being replaced |
| `go-cli-contract.md` | Canonical contract | Aspirational + in-flight | Slice 1 commands; JSON-stable contract; what's implemented |
| `host-strategy-matrix.md` | Implied canonical | Enduring | What Pi/Claude must share vs may diverge |
| `pi-parity-ladder.md` | Transitional | In-flight | Level 1/2/3; current = Level 2 reached |
| `pi-native-capability-leverage.md` | Proposed | Aspirational | Post-parity Pi-native exploitation |
| `pi-almanac-operating-model.md` | Canonical operating model (proposed) | Aspirational | `/work` primary; seeds canonical; Phase 3→Phase 5 |
| `pi-step-ceremony-and-artifact-enforcement.md` | Canonical operating-shape spec | Implemented (min slice) | `/work` ceremony preservation; minimum slice landed |
| `self-hosting.md` | Implied canonical | Retrospective/enduring | Source-repo sentinel via `.claude/SOURCE_REPO` |
| `workflow-power-preservation.md` | Canonical | Normative | Non-negotiables: stage ceremony, artifacts, HITL |
| `documentation-authority-taxonomy.md` | Canonical | Normative | Canonical / transitional / planning / historical |

### Primary (row artifacts, all 8 rows read by subagents)

| Row | Artifacts read |
|-----|---------------|
| pi-adapter-foundation | definition.yaml, state.json, spec.md, handoff.md, validation.md, implementation-plan.md, gates/*, summary.md |
| pi-adapter-promotion | definition.yaml, state.json, spec.md, gates/*, summary.md |
| pi-furrow-operating-layer | definition.yaml, state.json, spec.md, gates/*, summary.md |
| pi-step-ceremony-and-artifact-enforcement | definition.yaml, state.json, spec.md, handoff.md, validation.md, implementation-plan.md, gates/*, summary.md |
| go-backend-slice | definition.yaml, state.json, spec.md, summary.md, gates/* |
| frw-cli-dispatcher | definition.yaml, state.json, research.md, gates/* |
| backend-mediated-row-bookkeeping | definition.yaml, state.json, spec.md, summary.md, gates/* |
| namespace-rename | definition.yaml, state.json, summary.md, research.md, gates/* |

### Primary (almanac)

- `.furrow/almanac/roadmap.yaml` (8 phases, lines 401-915; per-node citations throughout §3)
- `.furrow/almanac/todos.yaml` (66 active, 32 done; key citation `todos.yaml:982-1041` for `cli-architecture-overhaul`)
- `.furrow/almanac/observations.yaml` (one open: `re-evaluate-dispatch-enforcement`, lines 1-22)
- `.furrow/almanac/rationale.yaml` (lines 1-478, migration-adjacent rationale signals)

### Primary (codebase reality, per row sweeps)

- `cmd/furrow/main.go`, `internal/cli/{almanac,row,doctor,review,row_semantics,row_workflow,app}.go`
- `bin/frw` (POSIX sh, `#!/bin/sh`), `bin/rws` (POSIX sh), `bin/alm` (POSIX sh)
- `bin/frw.d/{hooks,scripts,lib}/`
- `adapters/pi/furrow.ts` (48KB, last touched 2026-04-24)
- Git commits cited: `b75d60a` (go-backend-slice), `e2e268e` + `9d37dc6` (namespace-rename), `b16b38b` + `2cae190` (frw-cli-dispatcher), `c05edaf` (pi adapter + bookkeeping), `fcb901f` (pi `/work` loop), `e4adef5` (work-loop-boundary hardening)

### Doc disagreements surfaced (1, reconcilable)

- **Adapter scope**: `docs/architecture/cli-architecture.md:42-46` vs `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:315-324`. Reconcilable as backend=semantics, Pi=presentation. Surfaced, not silently resolved.

### Spec-vs-delivered mismatches surfaced (3 findings)

1. **`pi-adapter-foundation`**: spec promises shipping; state.json shows 0/3 not_started; the work was de facto delivered by an adjacent row. **Phantom row.**
2. **`pi-step-ceremony-and-artifact-enforcement`**: state.json `deliverables: {}` despite handoff/validation proving delivery. **Recording gap, not delivery gap.**
3. **`namespace-rename`**: no `spec.md` artifact produced; research.md + summary.md substitute. **Procedural exception, low impact.**

---

## 8. Empirical Audit of Pi Conversation History (added after second user request)

User-requested follow-up: 11 Pi session transcripts at `/home/jonco/.pi/agent/sessions/--home-jonco-src-furrow--/` (~12MB JSONL, 2026-04-23 → 2026-04-24) mined for empirical evidence of the gap categories predicted in §7. **Result: predictions were directionally correct but priority ranking was wrong.** Three findings reshuffle the §6 recommendation.

### What the empirical record shows

**State-guard is confirmed working in production.** The Pi `tool_call` interceptor at `adapters/pi/furrow.ts:883-899` fires in practice — 8+ "Blocked direct mutation of canonical Furrow state" notifications observed across sessions. No workaround attempts; agents pivot to backend CLI as instructed. This validates the `tool_call`-interceptor model as a template for further hooks.

**Empirical top-3 highest-friction gaps** (from frequency × severity in transcripts):

1. **Validate-definition timing — ~670 mentions, 10 distinct backend error codes** (`definition_yaml_invalid`, `definition_deliverable_name_missing`, `definition_acceptance_criteria_placeholder`, etc.). Agents write `definition.yaml`, ship the artifact, and discover schema problems only when backend rejects at transition. **Highest-volume gap by a wide margin.**
2. **Ownership-warn timing — 136 mentions, 4+ incident codes** (e.g., `focused_row_archived` 13 incidents). Edits to files outside `file_ownership` go unwarned at write time; backend catches at transition only after work has shipped.
3. **Post-compact recovery — gap, not just timing**. Pi has no `PostCompact` equivalent at all (no log evidence of recovery, no auto-reground). Multi-session rows must rediscover context manually. The §7 audit classified this "n/a by design" — empirically that classification is wrong; the cost is real.

**Empirical fourth-place: correction-limit grinding** — 104–289 mentions across large sessions; 26 `artifact_scaffold_incomplete` and 22 `markdown_section_too_thin` cycles observed. Confirms §7 prediction; addressable through Pi *visibility* (footer widget showing remaining budget) rather than Pi-side blocking.

**Empirical fifth-place: phase-level navigation gap** — Pi has zero implementations of triage, work-todos, multi-row navigation, roadmap regen. Medium-high severity. Cleanly separable from enforcement work.

### What the empirical record contradicts in §6/§7

- **`validate-summary` was rated #1 priority in §6. Empirically it is low.** Zero evidence of stops with broken summary sections in the transcripts. The very hook fired on this conversation's stop — but on a Claude session, not Pi. Lacking empirical evidence of pain in Pi sessions, this drops from the priority list.
- **`post-compact` was rated "n/a by design" in §7's parity audit.** Empirically it is high-priority. Multi-session work is a real use case and recovery friction is real.
- **My initial framing "Pi has no enforcement layer" was wrong.** Pi has *one* working enforcement (`state-guard`) — the empirical record confirms it fires and is accepted. The pain is the gaps adjacent to it, not absence.

### What the empirical record confirms

- **§7 finding that backend-validates-at-transition is real:** 150+ "blocked"/"gate_blocked" mentions, 11 backend codes for late-stage rejection. Agents cannot see gate readiness before attempting transition.
- **§7 finding that "state-correctness parity" ≠ "operator-experience parity":** the empirical record is dominated by validation-rework cycles where the state was never actually corrupted (backend caught it) but tokens were burned producing work that had to be redone.
- **§5 H6 (cycles) and H4 (premature abstraction) rejections hold.**

### Categories with zero empirical evidence

- `step-sequence` violations — backend prevents upstream; no Pi-side need.
- `append-learning` corruption — not observed; backend catches at archive.
- Explicit user frustration phrases — no "no wait, stop" / "had to fix manually" patterns. Either users tolerate the rework cycles silently, or transcripts don't capture user-side dialogue well.

### Updated empirical-evidence-ranked priority for the successor row

Revised top-3 (replaces §6 sketch which drew from prediction, not evidence):

1. **`validate-definition` as Pi `tool_call` pre-write hook** — highest empirical volume (670 mentions, 10 codes). Pi extension intercepts `Write`/`Edit` to `definition.yaml`, validates against schema before allowing write, surfaces structured error in `ctx.ui.notify` with remediation hint. Reuse hook body via shell-out to `frw hook validate-definition`.
2. **`ownership-warn` as Pi `tool_call` pre-write hook with `confirm` dialog** — second-highest (136 mentions). Pi extension intercepts `Write`/`Edit`, extracts `file_ownership` from active deliverable's `definition.yaml`, blocks (or `ctx.ui.confirm`s with override) if target is outside scope.
3. **`post-compact` as Pi compaction handler** — empirically high impact, architecturally clean (per `pi-native-capability-leverage.md:76` "custom compaction or summarization that respects Furrow artifacts"). Pi compaction hook invokes equivalent of `/furrow:reground` — reads `state.json`, summary.md, current-step skill, injects as session preamble.

Drop from top-3 (revised from §6): `validate-summary` (empirically low) and `correction-limit` as a *block* (real pain but cleaner as Pi visibility — footer widget showing remaining budget — not a Pi-side hard block; backend already tracks the count).

### Constraint the successor row must honor

The empirical recommendation ("upstream validation from backend to Pi") has an anti-pattern the docs warn against:

> "Do not let critical Furrow semantics live **only** in prompt text. System-prompt shaping should reinforce and operationalize backend/state-driven behavior, not replace it." (`pi-native-capability-leverage.md:113-116`)
> "Skills should not be the only place a hard invariant exists. If violating a rule would corrupt Furrow semantics, it still needs backend/adapter enforcement." (`pi-native-capability-leverage.md:144-146`)

The successor row must respect this: **the validation logic stays backend-canonical**; Pi's role is to *call the backend validator at write time* rather than at transition time.

---

## 9. Final Locked Scope (after user decisions)

User decisions in conversation:
- **Option Y selected**: validate-definition + ownership-warn as the row's primary scope.
- **Track post-compact and correction-limit** as deferred follow-ups in almanac todos (not in this row).
- **Go-first, not shell-out**: validation bodies port from shell to Go as part of this row. No `frw hook <name>` shell-out from Pi. The Go shell migration becomes a first-class citizen.

### Row name

Suggested: `pre-write-validation-go-first` (29 chars) — outcome-oriented, captures both the validation focus and the Go-first stance. Alternatives: `go-validators-and-pi-pre-write-hooks` (40 chars), `pi-upstream-validation-via-go`. User picks at row-creation time.

### Scope: 4 deliverables, 2 waves

**Wave 1 (Go validators — first-class CLI commands):**

- **D1 — `furrow-validate-definition`**: Go implementation of definition.yaml schema validation, callable as `furrow validate definition --json [--path <file>]` (or shape per `go-cli-contract.md` precedent). Replicates `bin/frw.d/hooks/validate-definition.sh` semantics in Go. JSON-stable contract for adapter consumption. `go test ./...` passes. Lives in `internal/cli/validate.go` or extends `internal/cli/almanac.go`.
- **D2 — `furrow-validate-ownership`**: Go implementation of file_ownership validation. Callable as `furrow validate ownership --json --row <name> --path <target>`. Replicates `bin/frw.d/hooks/ownership-warn.sh` semantics. JSON output includes verdict + remediation hint. `go test ./...` passes.

**Wave 2 (Pi event wiring — no shell-out):**

- **D3 — `pi-validate-definition-on-write`**: Pi extension `tool_call` handler intercepts `Write`/`Edit` to `definition.yaml` files, calls `runFurrowJson<ValidateDefinitionData>()` to D1, surfaces error in `ctx.ui.notify` with remediation, returns `{block: true, reason}` on invalid. Reuses the existing `runFurrowJson<T>()` pattern at `adapters/pi/furrow.ts:313-346`.
- **D4 — `pi-ownership-warn-on-write`**: Pi extension `tool_call` handler intercepts `Write`/`Edit`, calls `runFurrowJson<ValidateOwnershipData>()` to D2 with target path + active deliverable, on out-of-scope: `ctx.ui.confirm` with `"This file is outside the deliverable's file_ownership. Proceed anyway?"` matching Claude's warn-not-block semantic. Override allowed; refuse blocks the write.

Dependency edges: D3 depends on D1; D4 depends on D2. Wave 1 ships before Wave 2.

### Procedural cleanup bundled into row's first commits

- Backfill `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json.deliverables` so the recording gap stops generating phantom-row symptoms.
- Rewrite or remove `.furrow/rows/pi-adapter-foundation/handoff.md:27-29` — the dangling-successor instruction.
- Archive `pi-adapter-foundation` with reason "superseded by pi-step-ceremony-and-artifact-enforcement; residual scope reframed in successor row [name]."

### Deferred to almanac todos (added to `.furrow/almanac/todos.yaml`, not in this row)

- **`pi-correction-limit-visibility`** (urgency: low, impact: medium) — Pi footer widget showing remaining correction budget per deliverable; backend already tracks `correction_count`. Not a hard block, just visibility. Empirically high-friction (104-289 mentions in transcripts) but user does not yet feel it as conscious pain. Promote to a row when user identifies the grinding pattern.
- **`pi-session-resume-reground`** (urgency: medium, impact: medium-to-high) — Pi compaction handler + session-start handler injecting step skill, summary.md, and recent decisions into session preamble; equivalent of Claude's `frw hook post-compact` plus `/furrow:reground`. Empirical evidence shows 9-of-11 Pi sessions touched the same row across multiple resumes — the pain is real but absorbed as background clumsiness. Promote to a row after `pre-write-validation-go-first` archives, then re-evaluate with fresh observation.

### Why Go-first changes the calculation

The shell-out approach (`frw hook validate-definition`) trades a small re-pass cost for fast pain relief. Go-first adds upfront work (port two hooks to Go) but:

1. **Avoids the re-pass.** When `cli-architecture-overhaul` eventually rewrites all hooks to Go, this row's Pi wiring already calls Go and needs no rewire.
2. **Establishes the pattern.** Two hooks ported to Go = a working template for the rest of `cli-architecture-overhaul`. Each subsequent enforcement-parity row contributes its own Go port. The outer ring gets done incrementally, by demand, instead of as a single mega-row.
3. **Honors clean-swap preference** (per auto-memory: "User wants complete transitions, not incremental migrations that leave hybrid states"). Pi calls Go directly — no temporary bridge.
4. **Creates a JSON contract** that future hooks consume identically. `furrow validate <kind> --json` becomes the family signature.

### Why Go-first does not blow up the row

- The two hook bodies are small. `validate-definition.sh` is ~137 lines, `ownership-warn.sh` is ~67 lines. Porting to Go is mechanical.
- The Go contract precedent exists (`furrow almanac validate --json` already validates YAML schemas; `internal/cli/almanac.go` is the template).
- The Pi side is one new event handler per hook + the existing `runFurrowJson<T>()` plumbing.
- Total estimated scope: 4 deliverables, 2 specialists at most (`go-specialist` for D1/D2, `typescript-specialist` for D3/D4), ~2 waves. Moderate-shape row per `references/definition-shape.md`.

### Out of scope, explicit

- Other 13 enforcement hooks (state-guard already shipped natively; validate-summary empirically low; correction-limit and post-compact tracked as deferred; rest are not-applicable-to-Pi or backend-already-covers).
- Phase-level Pi (triage, work-todos, multi-row navigation, roadmap regen) — separate decision, likely Phase 5.
- The other ~48 shell commands without Go equivalents — `cli-architecture-overhaul` outer ring; this row only ports the two hooks it needs.
- Pi-native leverage features (`pi-native-capability-leverage.md` items beyond the two `tool_call` handlers): system-prompt shaping, Furrow-stage presets, custom tools, dynamic resource discovery — fast-follow per the doc's own sequencing.

### Three-step user execution path

1. `/furrow:archive migration-state-of-the-union` (after reviewing this research.md).
2. `/furrow:work pi-row-audit-cleanup` — see §10 for full scope. Cleans the audit trail before validation work begins.
3. `/furrow:work pre-write-validation-go-first` — 4 deliverables per Wave 1 / Wave 2 above.

---

## 10. Pi-Era Audit Cleanup (added after user request)

User-requested follow-up: clean up the Pi-generated row artifacts so the audit trail is unambiguous before successor work begins.

### Audit findings across Pi-touched rows

| Row | Step / Status | Issue | Severity | Cleanup category |
|---|---|---|---|---|
| `pi-adapter-foundation` | implement / not_started, active | Phantom row — 0/3 deliverables, scope satisfied by `pi-step-ceremony` | High | A (existing CLI) |
| `pi-step-ceremony-and-artifact-enforcement` | review / completed, archived 2026-04-24 | `state.json.deliverables = {}` despite handoff/validation proving full delivery | Medium | B (needs new CLI) |
| `pi-step-ceremony.../handoff.md:62` | n/a | "continue in a new in-scope row" — dangling forward instruction | Low | A (markdown edit) |
| `pi-adapter-promotion` | review / completed, archived | `base_commit = "unknown"`, `seed_id = ""` | Low | C (historical, accept) |
| `pi-furrow-operating-layer` | review / completed, archived | `base_commit = "unknown"`, `seed_id = ""` | Low | C (historical, accept) |
| `backend-mediated-row-bookkeeping` | review / completed, archived | `base_commit = "unknown"`, `seed_id = ""` | Low | C (historical, accept) |

**Correction to earlier finding:** I cited `pi-adapter-foundation/handoff.md:27-29` as containing a dangling-successor instruction. That was wrong. The dangling-successor instruction is in `pi-step-ceremony-and-artifact-enforcement/handoff.md:62` ("continue in a new in-scope row rather than reopening this archived one"). Fixed in this audit.

### Cleanup row scope: `pi-row-audit-cleanup`

Mode `code`, supervised. 5 deliverables:

- **D1 — `furrow-row-repair-deliverables`**: Go CLI command. Reads a row's validation.md / handoff.md / spec.md, reconstructs the deliverables map (deliverable name + completion state + completed_at if inferable), atomic write to state.json with audit-trail entry. JSON-stable contract. Lives in `internal/cli/row.go` or new `internal/cli/repair.go`. `go test ./...` passes. **Honors user's Go-first stance** — first contribution to cli-architecture-overhaul outer ring beyond the existing Slice 1.
- **D2 — Apply D1 to `pi-step-ceremony-and-artifact-enforcement`**: backfill its state.json.deliverables from the existing `validation.md` evidence. After this, the row's accounting reflects what actually shipped.
- **D3 — Archive `pi-adapter-foundation`** via `/furrow:archive` with explicit supersedence evidence: "scope satisfied by pi-step-ceremony-and-artifact-enforcement (commit `e4adef5`); residual scope reframed as `pre-write-validation-go-first` (subsequent row)."
- **D4 — Edit `pi-step-ceremony-and-artifact-enforcement/handoff.md:62`** to remove or rewrite the dangling-successor instruction. Pointing at the new row name once it exists is fine; pointing at a phantom is not.
- **D5 — Add deferred todos to `.furrow/almanac/todos.yaml`**:
  - `pi-correction-limit-visibility` (urgency low, impact medium): Pi footer widget showing remaining correction budget; backend already tracks count. Empirically high friction (104-289 mentions in transcripts) but user has not yet identified the grinding pattern as conscious pain. Promote to a row when user surfaces it.
  - `pi-session-resume-reground` (urgency medium, impact medium-high): Pi compaction handler + session-start handler injecting step skill, summary.md, and recent decisions. Empirically real (9-of-11 sessions resumed same row across multiple Pi sessions) but user has absorbed it as background clumsiness. Promote after `pre-write-validation-go-first` archives, then re-evaluate.

Plus an explicit acceptance entry in the row's spec.md / summary.md documenting the three `base_commit = "unknown"` rows as **historical provenance loss** — not retroactively fixable through approved channels (would require git history rewrite); accepted as a known artifact of pre-seed-machinery row creation. Future rows must use proper seed wiring (already enforced for new rows; old archive is what it is).

### What this row does NOT do

- Does not re-derive `base_commit` for the three "unknown" rows. Git history alone may not have the original branch points; even if reconstructable from refs, retroactively writing them would forge provenance.
- Does not migrate the artifact-shape divergence between Pi-era rows (which use `handoff.md` / `execution-progress.md` / `implementation-plan.md` / `validation.md` / `team-plan.md`) and earlier rows (which use simpler `definition.yaml` / `spec.md` / `state.json` / `summary.md`). This is a shape evolution, not an audit gap. Document if desired in a separate pass.
- Does not address the `cli-architecture-overhaul` outer ring at large. Only ships D1's single repair command — one tool to close one specific gap.

### Why this row pays for itself

- **`furrow-row-repair-deliverables`** is reusable. The same recording gap could happen on any future archived row; having a CLI to fix it cleanly is permanent infrastructure.
- **Audit cleanliness before validation work** prevents the next row from inheriting confusing state. When `pre-write-validation-go-first` ships, its commits sit on a row tree that no longer has phantoms or dangling pointers.
- **Concrete progress on cli-architecture-overhaul.** Each subsequent row contributes one or more Go commands. Two-row commit (this cleanup + the validation row) ships ≥3 new first-class Go commands toward the outer ring.

### Updated user execution path

1. `/furrow:archive migration-state-of-the-union` (this row).
2. `/furrow:work pi-row-audit-cleanup` — 5 deliverables per §10. Cleans audit trail.
3. `/furrow:work pre-write-validation-go-first` — 4 deliverables per §9. Closes operator-experience pain.

After (3) archives, re-evaluate whether `pi-correction-limit-visibility` or `pi-session-resume-reground` has surfaced as conscious pain; if yes, promote to the next row.

---

## 11. Inline Triage (executed 2026-04-25)

Per user request, the triage was executed inline within this research row rather than deferred to a successor row. Constraint amendment: the row's original "read-only investigation" constraint was relaxed for this section to allow almanac mutations. Mutations executed via `alm add` for new entries and direct YAML edits for status changes, drops, and ID renames. Validated via `alm validate`, `rws validate-sort-invariant`, and `alm triage` (regenerates roadmap.yaml from todos.yaml).

### Brain-dump categorization (16 items)

| # | Item | Bucket | Disposition |
|---|---|---|---|
| 1 | `python3 -c` plan.json inspection | Roll into CLI | Folded into `cli-introspection-suite` parent todo |
| 2 | `python3 -c` plan waves iteration | Roll into CLI | Folded into `cli-introspection-suite` |
| 3 | `ls specialists/* + git log` for row context | Roll into CLI | `furrow row history` (Tier 1, in cli-introspection-suite) |
| 4 | `bin/rws` lacking archive discoverability | CLI ergonomics | Logged in cli-introspection-suite |
| 5 | `python3 -c` reading learnings.jsonl | Roll into CLI | `furrow row learnings` (Tier 2) |
| 6 | "validate-plan" doesn't exist | CLI gap | `furrow row validate` (Tier 1) |
| 7 | Inconsistencies in artifact presentation | Process standardization | New todo `standardize-artifact-presentation` |
| 8 | Projects shouldn't need ad-hoc CLI discovery | CLI ergonomics | Folded into cli-introspection-suite |
| 9 | "ceph with proxmox for home server" | Off-topic | Dropped (not Furrow) |
| 10 | Furrow context polluting non-Furrow projects | Architecture | New todo `furrow-context-isolation-layer` |
| 11 | "Use nate smith skill" | Process: external lens | Existing roadmap todo `apply-nate-jones-skill`; user-side action |
| 12 | TODO/row IDs auto-generated too long | Naming hygiene | 2 active long-IDs renamed; 6 dropped via fold |
| 13 | Use artifacts for handoff-prompt generation | Workflow: handoff contract | New todo `handoff-prompt-artifact-template` |
| 14 | Archive should propagate implications | Workflow: archive ceremony | New todo `archive-implications-propagation` |
| 15 | Documentation cleanup pass | Tracked | New todo `docs-cleanup-pass` |
| 16 | `/furrow:meta` should fold into roadmap | Workflow: meta behavior | New todo `furrow-meta-folds-into-roadmap` |

### Empirical-evidence harvested for §G new todos

- **Pi conversation history audit (§8)**: 11 sessions, 12MB. Surfaced `pi-correction-limit-visibility` and `pi-session-resume-reground` as deferred items; both added.
- **Claude `python3 -c` audit**: 49 sessions; 91 invocations across 14 sessions; 2.5x growth over 22 days. Confirmed CLI gap families.
- **Claude shell-fu audit**: 49 sessions; 1,192 distinct workarounds across 9 pattern families; all increasing 54-667%; **8 state-bypass mutations** (rm -rf .furrow/rows/, cp .furrow/almanac/todos.yaml, etc.). Tier 1 demand: `furrow row history` (112 hits, ↑273%), `furrow row repair-deliverables` (870 hits), `furrow row validate` (85 hits), `furrow row delete --force` (state-bypass risk). Triggered the new `state-guard-rm-coverage` todo as well.

### Mutations executed

**Added via `alm add` (14 new todos):**

1. `pi-correction-limit-visibility` (renamed from auto-generated `pi-correction-limit-visibility-footer-widget`)
2. `pi-session-resume-reground`
3. `standardize-artifact-presentation`
4. `furrow-context-isolation-layer`
5. `handoff-prompt-artifact-template`
6. `archive-implications-propagation`
7. `docs-cleanup-pass`
8. `furrow-meta-folds-into-roadmap`
9. `cli-introspection-suite` — parent meta-todo with 16 commands listed in `work_needed`, depends_on `cli-architecture-overhaul`
10. `post-install-hygiene-followup` — parent meta-todo absorbing the 6 review-finding todos
11. `state-guard-rm-coverage`
12. `pi-step-ceremony-deliverables-backfill` — bundled into `pi-row-audit-cleanup` D2
13. `archive-pi-adapter-foundation-as-superseded` — bundled into `pi-row-audit-cleanup` D3+D4
14. `cli-architecture-overhaul-slice-2`

**Status flipped active→done (6 entries) via direct YAML edit:**

| Todo | Reason | Citation |
|---|---|---|
| `dual-runtime-target-architecture` | Architecture frozen | `docs/architecture/host-strategy-matrix.md` |
| `go-cli-contract-v1` | Contract complete + Slice 1 shipped | `docs/architecture/go-cli-contract.md`, row `go-backend-slice` archive |
| `migration-operating-mode` | Stance locked | `docs/architecture/migration-stance.md:170-182` |
| `work-loop-boundary-hardening` | Shipped | row `review-archive-boundary-hardening` archive (2026-04-24) |
| `parallel-agent-orchestration-adoption` | Closed-by-design (rationale recorded in `work_needed`) | Pi-only direction supersedes |
| `cli-architecture-overhaul` | Split (rationale recorded in `work_needed`) | Slice 1 shipped; outer ring is now `cli-architecture-overhaul-slice-2` |

**Dropped (6 entries) via direct YAML deletion (folded into `post-install-hygiene-followup`):**

- `tighten-test-isolation-guard-ac-1-ac-5-wording-vs`
- `clean-up-shellcheck-sc2154-sc2034-in-test-sandbox`
- `clean-up-shellcheck-sc2221-sc2222-in-bin-frw-d-hoo`
- `rebase-reword-commit-5232e94-message-ac-10-e2e-fix`
- `resolve-test-hook-cascade-sh-no-hooks-source-commo`
- `wire-the-3-latent-git-pre-commit-hooks-bakfiles-ty`

**Renamed (3 entries):**

- `pi-correction-limit-visibility-footer-widget` → `pi-correction-limit-visibility` (43→30 chars)
- `support-sharded-todos-d-directory-to-reduce-merge` → `support-todos-sharding` (49→22 chars)
- `harness-level-fix-for-parallel-dispatch-git-index` → `harness-parallel-dispatch-race` (49→30 chars)

**Validation results:**

- `alm validate` → `todos.yaml is valid`, `observations.yaml is valid`
- `rws validate-sort-invariant --file .furrow/almanac/todos.yaml --key id` → exit 0 (sorted)
- `alm triage` → roadmap.yaml regenerated; done items auto-filtered out; new active items appear

**Final stats:**

- Total todos: 107 (was 98) — net +9 after add 14 / drop 6 / +1 from earlier merge
- Active: 69
- Done: 38

### What this triage did NOT do

- **Did not rename done long-ID todos** — these are historical references (cited in commits, gates, handoff text); renaming would create traceability churn. Live with the long IDs on done entries.
- **Did not address artifact-shape divergence** between Pi-era rows (handoff.md / execution-progress.md / implementation-plan.md / validation.md / team-plan.md) and earlier rows (definition / spec / state / summary). Shape evolution, not audit gap.
- **Did not retroactively fix `base_commit = "unknown"`** on three archived rows. Historical provenance loss; future rows must use proper seed wiring (already enforced).
- **Did not reorganize roadmap phase boundaries.** All current phases retained; only node-level statuses changed.
- **Did not commit.** Mutations are staged for the user's review; commit the YAML changes in a single conventional commit with reference to this row's research.md.

### Final two-row execution path (confirmed unchanged from §10)

1. `/furrow:archive migration-state-of-the-union` (this row).
2. `/furrow:work pi-row-audit-cleanup` — 5 deliverables per §10.
3. `/furrow:work pre-write-validation-go-first` — 4 deliverables per §9.

Each row contributes ≥1 first-class Go command toward `cli-architecture-overhaul-slice-2`; together with the 14 new todos in `cli-introspection-suite`, the outer ring of Migration A now has a tracked plan even though the work itself is still incremental.

After row 3 archives, re-check whether `pi-correction-limit-visibility`, `pi-session-resume-reground`, or `state-guard-rm-coverage` has surfaced as conscious pain; promote to a row when yes.

### Seeds design decomposition (added after first triage execution)

The initial triage's `seeds-concept` and `pi-almanac-operating-model` meta-todos understated the size of the seeds design (`docs/architecture/pi-almanac-operating-model.md`, ~250 lines, 13+ sections). User asked to break out the substantial sub-themes. Added 5 sub-todos via `alm add`:

- `seeds-typed-graph-nodes` — typed seeds (task, decision, observation, milestone, ...) per `pi-almanac-operating-model.md:161-182`
- `seed-row-binding-contract` — one primary seed per row + related seeds per `:183-196` and `:197-223`
- `todo-to-seed-cutover-migration` — cutover plan per `:150-159` and `:302-318`
- `pi-seed-surfaces-in-work-loop` — Pi `/work` seed visibility per `:232-251`
- `almanac-scope-after-todo-retirement` — post-retirement alm scope per `:302-318`

### Doc-vs-todo gap audit (added after seeds decomposition)

User asked to look for similar gaps across all architecture docs. Audit swept all 13 docs and identified 75 design points: **31 covered (41%), 23 partial (31%), 21 missing entirely (28%)**. Three doc-vs-doc contradictions also surfaced.

Added 18 todos via `alm add` to close priority gaps:

**Priority 1 — blocking parity (3 todos):**
- `shared-blocker-taxonomy-spec` — formalize 15+ hard blockers as canonical schema
- `artifact-validation-per-step-schema` — explicit per-step validation rules
- `claude-blocker-enforcement-parity` — Claude adapter audit against shared taxonomy

**Priority 2 — meta-todo decomposition (9 todos):**

`seeds-concept` decomposition (4):
- `seeds-backend-surface-layer` — `furrow seeds` Go CLI group
- `seeds-graph-queries` — graph traversal, ready-set, cycle detection
- `seeds-follow-up-promotion` — review→archive follow-up seed creation
- `roadmap-generation-from-seeds` — roadmap as seed-graph projection

`workflow-power-preservation` decomposition (5):
- `stage-aware-ceremony-enforcement` — prevent casual step-skipping
- `artifact-continuation-model` — artifacts-as-inputs contract
- `context-routing-infrastructure` — per-step context loading rules
- `review-evaluator-isolation-spec` — formalize evaluator isolation
- `parallel-orchestration-spec` — wave model + worktree integration

**Priority 3 — long-tail (5 todos):**
- `consumer-install-symlink-validation`
- `xdg-state-isolation-audit-and-doc`
- `doc-authority-class-enforcement`
- `migration-residue-archival`
- `supervised-decision-surface-spec`

**Doc-vs-doc contradictions tracker (1):**
- `doc-contradiction-reconciliation` — three identified tensions: (a) seed timing (canonical-vs-Phase-5-deferred), (b) blocker enforcement split (Pi-defined vs Claude-undefined), (c) artifact validation scope creep (`go-cli-contract.md:385-388` vs `pi-step-ceremony.../md:375-380`).

### Final stats after all triage rounds

- Total todos: **130** (was 98 — net +32 after add 37 / drop 6, with 1 dedup overlap between user-added and agent-recommended seeds entry)
- Active: **92**
- Done: **38**

The increase is *decomposition* of pre-existing meta-todos and explicit tracking of design points the docs already mandate, not novel-scope bloat. Validation per-pass: `alm validate` clean; `rws validate-sort-invariant` clean; `alm triage` regenerates roadmap.yaml without errors.
