---
layer: shared
---
# Layer Protocol

Canonical contract for the 3-layer orchestration model. All runtime adapters
(Claude, Pi) implement this protocol. Furrow backend is runtime-agnostic.

Cross-references: `skills/shared/specialist-delegation.md` (driver→engine dispatch),
D1 `schemas/handoff-driver.schema.json` + `schemas/handoff-engine.schema.json`,
D3 `.furrow/layer-policy.yaml` (enforcement matrix).

---

## Purpose

Furrow's orchestration model has three named layers. Each layer has a distinct
scope, tool surface, and accountability boundary. Layers communicate via
structured handoffs — never via shared mutable state. Runtime-agnostic semantics
are defined here in terms of "spawn", "message", and "return"; each adapter maps
these to its own primitives.

```
operator  ──handoff──▶  phase driver  ──handoff──▶  engine(s)
   ◀──phase result──        ◀──EOS-report──
```

---

## Operator

**Scope**: whole-row lifecycle. **Session**: long-running (persists across steps).
**State**: the only layer that calls `rws`/`alm`/`sds` and reads/writes row state.
**User dialog**: the only layer that addresses the user. Presentation follows
`skills/shared/presentation-protocol.md` (D6).

Responsibilities:
- Load operator bundle via `furrow context for-step <step> --target operator`.
- Detect current step from row state.
- Spawn the phase driver for the current step (runtime primitive: Claude `Agent`,
  Pi `pi-subagents spawn`).
- Prime the driver with its context bundle via `furrow context for-step <step> --target driver`.
- Persist the driver handoff artifact via `furrow handoff render --target driver:{step} --write`.
- Receive the phase result (EOS-report) from the driver.
- Present phase results to user per `skills/shared/presentation-protocol.md`.
- Request step transition via `rws transition` after user approval.

Session-resume: **runtime concern**. Claude operator reads `~/.claude/teams/{row}/config.json`
and re-spawns stale drivers via `Agent`. Pi operator: `@tintinweb/pi-subagents` handles
session-tree resume natively. Furrow backend has no session-id awareness.

---

## Phase Driver

**Scope**: one step. **Session**: session-scoped (runtime-managed).
**State**: read-only access to row state (via bundle); no direct `rws` writes.
**Persona**: implicit — `skills/{step}.md` is the driver brief (D3 adds `layer: driver` front-matter in W5).

Tools constrained by `.furrow/drivers/driver-{step}.yaml` `tools_allowlist`.
See `schemas/driver-definition.schema.json` for schema.

Responsibilities:
- Load driver context bundle (provided by operator prime message).
- Run the step ceremony per `skills/{step}.md`.
- Compose an engine team at dispatch-time (not at planning-time). See
  `skills/shared/specialist-delegation.md` for dispatch protocol.
- Dispatch engine teams via `furrow handoff render --target engine:{specialist-id}`.
- Collect EOS-reports from engines; assemble phase result.
- Return phase result to operator via runtime primitive (Claude: `SendMessage` to lead;
  Pi: agent return value).

Engine team composition is per-dispatch, not per-plan. `plan.json`'s `specialist:` field
is a hint only — drivers compose teams based on the work at hand.

---

## Engine

**Scope**: one deliverable (one-shot). **Session**: ephemeral.
**State**: Furrow-unaware. No `.furrow/` reads. No Furrow vocab in inputs.

Engines receive only an `EngineHandoff` (D1 schema) — an isolated task brief
containing source-tree grounding paths, a task-scoped objective, deliverables
with acceptance criteria, and engine-scoped constraints. No row, no step, no
gate policy, no Furrow internals.

Enforcement:
- D1 `EngineHandoff` schema rejects `.furrow/` paths and Furrow vocab in any field.
- D3 `furrow hook layer-guard` enforces tool allowlist at runtime (Claude: PreToolUse hook;
  Pi: `tool_call` extension event).
- D3 post-hoc boundary leakage test asserts zero Furrow leakage in engine artifacts.

Engines return an EOS-report per `templates/handoffs/return-formats/{step}.json`.
The driver assembles per-deliverable rollups before returning the phase result.

---

## Handoff Exchange

Driver→engine dispatch uses D1's render command:

```sh
furrow handoff render --target engine:specialist:{id} --row <name> --step <step> [--write]
```

This builds an `EngineHandoff` value (driver-curated; driver provides structured
value via stdin or args). Rendered markdown is the engine's input.

For the operator→driver handoff:

```sh
furrow handoff render --target driver:{step} --row <name> --step <step> [--write]
```

Artifacts written to `.furrow/rows/{name}/handoffs/{step}-to-{target}.md` when `--write` is passed.

---

## Engine-Team-Composed-at-Dispatch

Drivers compose engine teams **at dispatch-time**, not at planning-time. This means:

- `plan.json`'s `specialist:` field per deliverable is a **hint** for the driver, not a contract.
- A driver may dispatch multiple engines in parallel for one deliverable.
- Team composition adapts to the work at hand — research might spawn 3 parallel research
  engines; implement might spawn 1 implementer + 1 test-engineer concurrently.
- No planning artifact (team-plan.md etc.) binds team membership. `team-plan.md` is retired.

---

## Runtime-Agnostic Message-Passing

Layer transitions are defined in terms of three primitives. Adapters provide implementations.

| Primitive | Claude adapter | Pi adapter |
|-----------|---------------|------------|
| `spawn(agent, config)` | `Agent(subagent_type="driver:{step}", ...)` | `pi-subagents spawn({name, systemPrompt, tools})` |
| `message(handle, body)` | `SendMessage(to=agent_id, body=...)` | `pi-subagents sendMessage(handle, body)` |
| `return(result)` | `SendMessage` back to operator | agent return value |

The `.claude/agents/driver-{step}.md` subagent definitions are rendered from
`.furrow/drivers/driver-{step}.yaml` + `skills/{step}.md` by `furrow render adapters --runtime=claude`.
Pi adapter reads the same driver YAML via `adapters/pi/extension/index.ts` `before_agent_start` hook.

Furrow backend has no concept of session-id, no `drivers.json`, no per-row driver registry.
