# Plan Step — Phase 2: Pi adapter architecture

**Row**: `agent-host-portability-research`
**Step**: plan
**Phase**: 2 of 4
**Purpose**: Lock the Pi adapter's internal architecture now that top-level (Phase 1) decisions are set. These decisions determine what actually gets built at `adapters/pi/`.

Phase 1 locked:

- **P-1**: Core-preferred with host-override where Pi has superior primitives
- **P-2**: CC extraction staged to follow-up row (9 TODOs logged in almanac)
- **P-3**: Schema-level improvements in this row; behavior-level deferred
- **P-4**: Interface spec = prose + JSON Schema
- **P-5**: Dual-reviewer runs once at end of plan step

Answer inline. One-liners or "agree with lean" fine.

---

## P2-1 — Interface surface taxonomy

What are the named surfaces in the Host Adapter Interface? R1 found 8. Proposal:

1. **commands** — slash-command registration
2. **hooks** — lifecycle events (subdivide further? see P2-2)
3. **subagents** — dispatch + result handling
4. **context-injection** — skills, AGENTS.md, system-prompt pipeline
5. **tool-metadata** — pre/post-execution visibility for gating
6. **programmatic** — RPC / subprocess / `--bare` equivalent for scripted use
7. **install** — fresh-machine bootstrap contract
8. **compaction** — before/after hooks for context-recovery

Option: **(a) 8 surfaces as above**. Faithful to R1.
Option: **(b) Collapse to 6** — merge `tool-metadata` into `hooks` (it's always observed via a hook); merge `install` into a meta-surface "host-ops."
Option: **(c) Expand to 10** — split `hooks` into {pre-tool-use, post-tool-use, session-lifecycle, compaction}.

**My lean: (a) 8 surfaces.** Matches R1, maps 1:1 to rationale.yaml entries, keeps interface auditable. (b) merges concerns that have different stakeholders. (c) is overfit.

> YOUR ANSWER: Agreed

---

## P2-2 — Pi binding structure: single extension or multiple

How does the Furrow-on-Pi adapter physically manifest as Pi extensions?

- **(a) One monolithic extension `@furrow/pi-adapter`** that registers all commands + hooks + subagent wrapping in one file.
  - Pro: single load, simpler install, single version to pin.
  - Con: hard to test surfaces in isolation; large file.

- **(b) Multiple focused extensions** (`@furrow/pi-commands`, `@furrow/pi-hooks`, `@furrow/pi-subagents-wrapper`) that compose.
  - Pro: per-surface testability; users can disable individual surfaces.
  - Con: 3-4 install lines; version alignment across them.

- **(c) One extension + a TS module tree** (`@furrow/pi-adapter` with internal `src/commands/`, `src/hooks/`, `src/subagents/`) — monolithic at the Pi boundary, modular internally.
  - Pro: single install, but clean code organization.
  - Con: requires TS build setup (no external files to `pi install`).

**My lean: (c)**. One extension, clean internal structure. Install story stays simple; code stays maintainable. R9 noted Pi compiles TS on-the-fly via jiti — no build step needed.

> YOUR ANSWER: Agreed

---

## P2-3 — Subagent wrapping layer

`@tintinweb/pi-subagents` is the compose target. Furrow needs consistent subagent config (prompt_mode=replace, skills=false, inherit_context=false, disallowed_tools=write,edit,bash) across all specialists.

- **(a) Direct use**: each Furrow specialist calls pi-subagents with its own config each time.
  - Pro: maximum flexibility per specialist.
  - Con: config drift — Furrow has 22 specialists, each has to remember to set 4 config keys.

- **(b) Thin wrapper**: `furrow.dispatchSpecialist(name, prompt, overrides?)` — centralizes the 4 config keys, allows per-call overrides.
  - Pro: consistency; one place to change defaults; preserves per-specialist override.
  - Con: adds indirection; one more abstraction.

- **(c) Specialist-as-data**: specialists declare `dispatch:` frontmatter in their markdown (model, tool allowlist, prompt_mode) — wrapper reads frontmatter.
  - Pro: declarative; specialists own their dispatch config; matches R10 adopt of "YAML contract layer."
  - Con: requires frontmatter schema + validation; existing specialists need backfill.

**My lean: (c)**. Pairs naturally with the R10 YAML-contract-layer adopt we're keeping in this row. Specialist markdown gets a `dispatch:` frontmatter section; wrapper reads it; no magic.

> YOUR ANSWER: Agreed

---

## P2-4 — Pi extension install + update mechanism

How does `install.sh --host pi` actually install the Furrow adapter?

- **(a) Global**: `pi install git:github.com/<user>/furrow@<tag>` installed to `~/.pi/agent/extensions/`. Dependencies (`pi-subagents`) also global-installed.
  - Pro: single install covers all projects.
  - Con: version conflicts if two Furrow projects want different versions.

- **(b) Project-local**: extensions installed to `.pi/extensions/` per-project.
  - Pro: version-isolated per project.
  - Con: re-install per project.

- **(c) Hybrid**: Furrow adapter global (one per machine), pi-subagents also global, configuration lives in project `.pi/settings.json`.
  - Pro: single source of adapter, per-project config.
  - Con: if adapter version changes, all projects pick up new version simultaneously (could regress).

**My lean: (b) project-local** for initial release. Matches Furrow's current install model (`bin/frw` symlinked in PATH but config in project `.claude/` / `.furrow/`). Reversal to (a) or (c) is cheap later.

> YOUR ANSWER: Option A, different projects should never want different versions, honestly this should also be the case for the cc install

---

## P2-5 — Handling upstream Pi version churn

R9: Pi releases near-daily; breaking changes at patch level are plausible. We exact-pin. How do we handle upgrades?

- **(a) Pin and forget** — version frozen in install.sh until explicit user bump. Users run `furrow pi-upgrade` to advance. Changelog diff shown before bump.
  - Pro: never silent breakage; deterministic.
  - Con: users have to act to get upgrades.

- **(b) Continuous upgrade with canary** — install auto-pulls latest minor; before each session, preflight runs smoke test against pinned ACs; degrades to last-known-good on failure.
  - Pro: stay current.
  - Con: complex; smoke test is a moving target.

- **(c) Scheduled**: adapter ships new compatible Pi version in each Furrow release; Furrow release cadence drives Pi adoption.
  - Pro: one upgrade cadence for user to track; Furrow tests ensure compat.
  - Con: Furrow release cadence has to be real (currently ad-hoc).

**My lean: (a) pin and forget.** Safest default. `frw doctor` can warn if Pi is >90 days old. A follow-up row can formalize upgrade choreography if this becomes painful.

> YOUR ANSWER: Agreed

---

## P2-6 — Compaction behavior split (P-1 host-override example)

Per P-1, we prefer core-with-host-override. Compaction is the first concrete override point:

- **CC**: keeps `post-compact.sh` stdout re-injection (core-registered, CC-specific hook behavior)
- **Pi**: uses `session_before_compact` to author the summary directly (Pi-native, strictly stronger)

Where does the behavior split physically land?

- **(a) Core defines the "what"** (capture-and-recover protocol), adapters define the "how."
  - Core: `frw compaction-context <name>` produces the payload.
  - CC adapter: shell hook reads payload, emits to stdout post-compact.
  - Pi adapter: TS hook reads payload, returns it as custom summary pre-compact.

- **(b) Core defines nothing, each adapter rolls its own.**
  - Simpler, but no parity — payload format drifts between hosts.

- **(c) Shim approach**: core provides `frw compaction-context`, Pi adapter wraps it to author summary; CC behavior stays as-is (not refactored) since it works.
  - Pro: minimum CC churn.
  - Con: CC behavior isn't conceptually aligned with Pi side; audit is harder.

**My lean: (a)**. Sets the pattern for other override points (e.g., if Pi's tool_call input mutation ever matters, same split). Core payload definition means follow-up CC refactor to use it is trivial.

> YOUR ANSWER: Agreed

---

## P2-7 — Pi extension file language

Pi extensions are TypeScript. Furrow today is shell + markdown + YAML.

- **(a) Adapter is pure TypeScript** — `.ts` files under `adapters/pi/src/`, compiled on-the-fly by Pi via jiti.
  - Pro: native to Pi's model; types help; composable with other Pi TS extensions.
  - Con: introduces TS to the Furrow codebase (new dep on Node+TS tooling for contributors).

- **(b) Adapter is shell-first, TS shim** — TS extension stub calls out to `frw` / `rws` shell CLIs for heavy lifting.
  - Pro: reuses Furrow's existing shell tooling; minimal new language surface.
  - Con: more process-spawning overhead; TS shim is thin and fragile.

- **(c) Adapter is TS for event handling + shell for state mutation** — TS handles lifecycle events, invokes `rws update-summary`/`rws transition` via subprocess for any state change.
  - Pro: event handling stays in Pi's native paradigm; state CLI reuse.
  - Con: TS/shell boundary; requires subprocess discipline.

**My lean: (c)**. Event handling is Pi-native (TS in Pi process); state mutation goes through existing shell CLIs (which enforce state-guard + schema validation). Matches Furrow's CLI-mediation principle without duplicating it in TS.

> YOUR ANSWER: Agreed, honestly I'm tempted to migrate our cli's to typescript

---

## What comes next after Phase 2 is locked

- **Phase 3** — Host-independent improvement design for items kept in this row per P-3: typed JSON Schema blocks for almanac, typed `produces:` outputs per deliverable, specialist YAML-contract-layer frontmatter. Each needs schema + migration + validation design.
- **Phase 4** — Wave ordering in `plan.json`, specialist assignments in `team-plan.md`, dual-reviewer dispatch, transition to spec.
