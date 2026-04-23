# Plan Step — Phase 1: Top-level architecture decisions

**Row**: `agent-host-portability-research`
**Step**: plan
**Purpose**: Lock top-level architecture before per-deliverable decisions. These shape Phase 2 (Pi adapter architecture), Phase 3 (host-independent improvement design), and the final `plan.json` + `team-plan.md`.

Answer inline. One-liners or "agree with lean" fine.

---

## P-1 — Dual-host parity mechanism

Where do host-independent improvements physically live so they touch both hosts?

- **(a) Core-only** — everything lives in `bin/frw*`, `rws`, `alm`, `.furrow/`, `skills/`. Hosts just dispatch to it. Hook scripts in `bin/frw.d/hooks/` stay host-neutral; adapters register them differently per host.
  - Pro: single source of truth; parity is free.
  - Con: requires refactoring current `.claude/settings.json`-specific hook logic to be host-neutral.

- **(b) Core + host-specific bindings** — `adapters/cc/` and `adapters/pi/` mirror each other. Every host-independent improvement touches core; hosts pull from core via adapter shims.
  - Pro: symmetric; easy to audit parity.
  - Con: adds an indirection layer; more files.

- **(c) Core-preferred, host-override where necessary** — core is the default, hosts override individual surfaces as needed (e.g., Pi's `session_before_compact`).
  - Pro: pragmatic; doesn't force parity where it'd be artificial.
  - Con: "override points" are an API surface — governance issue if it proliferates.

**My lean: (c)**. (a) is elegant but forces Pi not to use `session_before_compact`'s superior semantics. (b) is heavy. (c) lets Pi's native wins be Pi-only while core carries the parity load.

> YOUR ANSWER: Agree with lean

---

## P-2 — CC binding extraction

Currently `.claude/`, `bin/frw.d/hooks/`, `skills/` are scattered. Pi adapter lives at `adapters/pi/`.

- **(a) Leave CC where it is.** Pi goes in `adapters/pi/`. Asymmetric layout.
  - Pro: zero churn on CC side; less risk of regression during migration.
  - Con: adapters tree is half-populated; interface-spec diffing is awkward.

- **(b) Extract CC to `adapters/cc/`.** Symmetric layout. Add shims at old paths (`.claude/settings.json` → loads from `adapters/cc/settings.json`) to preserve CC behavior during transition.
  - Pro: symmetric; interface deliverable becomes concrete diff between `adapters/cc/` and `adapters/pi/`.
  - Con: CC refactor risk; shim complexity.

- **(c) Staged**: start with (a), extract CC in a follow-up row once Pi adapter stabilizes.
  - Pro: lower risk; clean separation of "add Pi" from "refactor CC."
  - Con: defers symmetry; interface deliverable can't use concrete diff approach.

**My lean: (c) staged.** (a) for this row, file a follow-up row for CC extraction once Pi is proven. Reduces scope here and respects "keep CC functional throughout."

> YOUR ANSWER: Agree with lean

---

## P-3 — Host-independent improvement landing

For the R10 + memory adopt-list (SCRATCHPAD, priority injection, pattern library, stagnation safeguard, typed schema blocks, typed `produces:`) — where do these land?

- **(a) In this row, as part of the migration.** Bigger scope, but dual-host parity verified in the same row.
  - Pro: parity is proven end-to-end.
  - Con: this row becomes huge; migration + improvements in one.

- **(b) In follow-up rows after migration.** Keeps this row tighter.
  - Pro: small, focused migration row.
  - Con: risks "migrate first, parity later" drift; improvements may accumulate without being applied to CC.

- **(c) Split**: schema-level improvements (typed blocks, typed `produces:`) in this row; behavior-level improvements (SCRATCHPAD, priority injection, stagnation safeguard, pattern library) in follow-up rows.
  - Rationale: schema changes affect the interface spec, so they belong here. Behavior changes can layer on top of a stable dual-host.

**My lean: (c) split.** Keeps this row's code-size honest. Schema changes are structural; behavior changes are additive.

> YOUR ANSWER: Agreed with lean

---

## P-4 — Interface spec style

The `pi-adapter-interface` deliverable — what format?

- **(a) Prose-heavy architecture doc.** Markdown, diagrams, tables. Flexible, human-readable.
- **(b) JSON Schema / TypeBox schema for the interface shape.** Plus prose commentary. Machine-verifiable.
- **(c) Both**: prose for humans, schema extracted from prose for mechanical validation.

**My lean: (c)**. Matches the R10 adopt of typed JSON Schema for almanac — sets the precedent.

> YOUR ANSWER: C

---

## P-5 — Review of plan-step artifacts

Plan skill requires dual-reviewer protocol (fresh Claude + cross-model). Plan produces `plan.json` + `team-plan.md` + architecture decisions in summary. Reviewer runs once on final, or iteratively per phase?

- **(a) Once, at end of plan step.** Matches protocol literally.
- **(b) Per-phase.** Costs more but catches issues earlier.

**My lean: (a)** — cheaper, and the user gives per-phase feedback directly.

> YOUR ANSWER:A

---

## What comes after Phase 1 is locked

- **Phase 2** — Pi adapter architecture: interface surface taxonomy, Pi binding structure, subagent wrapping approach, extension composition strategy
- **Phase 3** — Host-independent improvement design (only for items in this row per P-3): typed schema blocks for almanac, typed `produces:` in definition.yaml; SCRATCHPAD/priority-injection/stagnation/pattern-library designs if P-3 landed more in this row
- **Phase 4** — Wave ordering in `plan.json`, specialist assignments in `team-plan.md`, dual reviewer dispatch, transition to spec
