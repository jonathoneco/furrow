# Orchestration-Delegation Contract — Canonical Reference

This document is the canonical reference for the Furrow 3-layer orchestration
model shipped by the `orchestration-delegation-contract` row (W1–W6).

All runtime adapters (Claude, Pi) implement this contract. The Furrow backend
is runtime-agnostic. Cross-references link to the authoritative artefacts.

---

## 1. Overview: 3-Layer Architecture

```
┌─────────────────────────────────────────────────────────────┐
│  OPERATOR (whole-row, user-facing, state-mutating)          │
│  /work agent. Main thread. Full tool surface.               │
├─────────────────────────────────────────────────────────────┤
│  DRIVER  (one-step, runtime-managed phase driver)           │
│  driver:{step}. No Edit/Write. Bash via allowlist only.     │
├─────────────────────────────────────────────────────────────┤
│  ENGINE  (one-shot specialist, Furrow-unaware)              │
│  engine:{specialist-id}. No .furrow/ access. No rws/alm.   │
└─────────────────────────────────────────────────────────────┘
```

Layer boundaries are enforced by `furrow hook layer-guard` (a Go subcommand),
which is wired into both adapters' hook buses. The canonical policy file
`.furrow/layer-policy.yaml` is the single source of truth for all adapters —
no allow/deny logic is duplicated.

---

## 2. Handoff Schemas (D1)

D1 (W1) ships the EngineHandoff and DriverHandoff schemas that enforce
Furrow-vocabulary isolation at the boundary.

- `schemas/handoff-driver.schema.json` — DriverHandoff (operator → driver)
- `schemas/handoff-engine.schema.json` — EngineHandoff (driver → engine)
- `internal/cli/handoff/` — Go render and validate implementation

**EngineHandoff content discipline**: the `objective`, `grounding`, and
`deliverables[].acceptance_criteria` fields must contain zero Furrow vocabulary
(`.furrow/` paths, `rws`, `alm`, `sds`, `state.json`, etc.). This is enforced
post-hoc by `tests/integration/test-boundary-leakage.sh` (AC11/D3).

Validation: `furrow validate definition` + `furrow handoff render`.

---

## 3. Layer Architecture (D2)

D2 (W2) ships the driver architecture reframe: the 7 step skills are now
"driver briefs" rather than operator skills. Drivers run the step ceremony and
dispatch engines; operators coordinate across steps.

- `skills/shared/layer-protocol.md` — layer: shared — canonical 3-layer contract
- `skills/shared/specialist-delegation.md` — layer: shared — driver→engine dispatch protocol
- `skills/{ideate,research,plan,spec,decompose,implement,review}.md` — layer: driver
- `.furrow/drivers/driver-{step}.yaml` — per-step driver definitions (tools_allowlist, model)
- `internal/cli/render/` — renders driver definitions to runtime-specific files
- `adapters/pi/extension/index.ts` — Pi adapter: `before_agent_start` + `tool_call` hooks

See also: `schemas/driver-definition.schema.json`.

---

## 4. Boundary Enforcement (D3)

D3 (W5) ships the executable layer-policy enforcement layer.

### 4.1 Layer Policy Authority

The single canonical policy file is `.furrow/layer-policy.yaml`. Both adapters
read it directly — no duplication of allow/deny logic.

- Schema: `schemas/layer-policy.schema.json` (JSON Schema draft 2020-12)
- Loader + verdict: `internal/cli/layer/policy.go`
- Validation: `furrow validate layer-policy`

Policy structure: per-layer rules (operator/driver/engine) covering
`tools_allow`, `tools_deny`, `path_deny`, `bash_allow_prefixes`,
`bash_deny_substrings`. See `.furrow/layer-policy.yaml` for the canonical
content.

### 4.2 furrow hook layer-guard

`internal/cli/hook/layer_guard.go` — registered as `furrow hook layer-guard`.

**Stdin payload** (Claude PreToolUse JSON, also Pi-normalized):

```json
{
  "session_id": "...",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": { "file_path": ".furrow/state.json", ... },
  "agent_id": "subagent_123",
  "agent_type": "engine:specialist:go-specialist"
}
```

**Stdout**:

```json
{ "block": true, "reason": "layer_tool_violation: ..." }
```

**Exit codes** (Claude hook protocol):
- `0` → allow (empty stdout)
- `2` → block (JSON verdict to stdout)

**Fail-closed semantics**:
- Empty/missing `agent_type` → `operator` layer (Claude main-thread).
- Unknown type with `engine:` prefix → `engine` (most restricted).
- Unknown type with `driver:` prefix → `driver`.
- Completely unknown type → `engine` (fail-closed default).

### 4.3 Hook Registration

**Claude adapter** (`.claude/settings.json` PreToolUse):

```json
{ "matcher": "Write|Edit", "hooks": [..., { "command": "furrow hook layer-guard" }] }
{ "matcher": "Bash",        "hooks": [..., { "command": "furrow hook layer-guard" }] }
{ "matcher": "SendMessage|Agent|TaskCreate|TaskUpdate",
  "hooks": [{ "command": "furrow hook layer-guard" }] }
```

**Pi adapter** (`adapters/pi/extension/index.ts` `tool_call` hook):
Normalizes Pi's `tool_call` event into Claude's PreToolUse JSON shape and
exec's `furrow hook layer-guard` synchronously. Identical stdin shape ensures
cross-adapter parity.

### 4.4 Parity Invariant

Cross-adapter parity test: `tests/integration/test-layer-policy-parity.sh`.

Both adapters internally call the same `furrow hook layer-guard` Go binary with
identical payload shape. The parity test runs 10 fixture tuples through the Go
binary (representing both the Claude and Pi paths) and asserts 100% verdict
match.

### 4.5 Boundary Leakage Smoke Alarm

`tests/integration/test-boundary-leakage.sh` — **NON-NEGOTIABLE** per row
constraint #9.

Sets up a fixture non-Furrow project, constructs a simulated EngineHandoff
and engine output, and asserts ZERO matches against the leakage corpus
(`tests/integration/fixtures/leakage-corpus.regex`). Any match triggers
blocker code `engine_furrow_leakage`.

Leakage corpus regexes include: `.furrow/`, `furrow row|handoff|context`,
`rws`, `alm`, `sds`, `state.json`, `definition.yaml`, `summary.md`,
`almanac`, `rationale.yaml`, plus all 5 D3 blocker code names.

### 4.6 Skill Layer Assignment

All skill files carry a `layer:` YAML front-matter field. D4's context-routing
loader rejects skills missing this field with blocker code `skill_layer_unset`.

| Path glob | Layer |
|-----------|-------|
| `skills/{ideate,research,plan,spec,decompose,implement,review}.md` | `driver` |
| `skills/work-context.md` | `operator` |
| `skills/shared/layer-protocol.md` | `shared` |
| `skills/shared/specialist-delegation.md` | `shared` |

Validation: `furrow validate skill-layers`.

### 4.7 Driver Definition Validation

All 7 driver definition YAMLs (`.furrow/drivers/driver-{step}.yaml`) are
validated against `schemas/driver-definition.schema.json`.

Validation: `furrow validate driver-definitions`.

### 4.8 Blocker Codes (D3)

Five blocker codes added to `schemas/blocker-taxonomy.yaml`:

| Code | Category | Severity |
|------|----------|----------|
| `skill_layer_unset` | layer | block |
| `layer_policy_invalid` | layer | block |
| `layer_tool_violation` | layer | block |
| `engine_furrow_leakage` | layer | block |
| `driver_definition_invalid` | definition | block |

---

## 5. Context Routing (D4)

D4 (W3) ships the context-routing CLI and strategy registry.

- `internal/cli/context/` — context bundle assembly (Builder, Strategy, ChainNode)
- `internal/cli/context/contracts.go` — D5 contract interfaces
- `furrow context for-step <step> --target <target> --row <row>` — build context bundle

Context is filtered by layer: operator receives operator+shared skills; drivers
receive driver+shared skills; engines receive no Furrow skills (EngineHandoff
discipline).

---

## 6. Construction Patterns (D5)

D5 (W4) ships the context construction contract (Builder, Strategy, ChainNode
design patterns).

- `internal/cli/context/contracts.go` — interface definitions and conformance harness
- `docs/architecture/context-construction-patterns.md` — design rationale

---

## 7. Pi Capability Gap

**Pi subagent layer enforcement is main-thread only.**

`@tintinweb/pi-subagents` 0.6.1 spawns subagents as subprocess invocations.
The parent's `tool_call` extension event bus does not reach inside these
subprocesses — only main-thread tool calls fire extension hooks.

**Consequence**: `furrow hook layer-guard` on the Pi adapter enforces layer
boundaries for the operator (main-thread) only. Driver and engine tool calls
made within pi-subagent subprocesses are **not** intercepted by the parent
hook bus.

**Mitigations**:
1. **D1 EngineHandoff content discipline**: engine receives a Furrow-stripped
   handoff with no `.furrow/` paths, no `rws`/`alm`/`sds` references.
2. **Post-hoc leakage smoke alarm** (`test-boundary-leakage.sh`): verifies
   engine artifacts contain zero Furrow vocabulary.
3. **Follow-up row**: upstream patch to `@tintinweb/pi-subagents` to expose
   a parent-bus `tool_call` event reaching into subprocess subagents.

This limitation is documented here as a **known, explicitly-accepted constraint**
(constraint #16). It does not block D3 completion — the leakage alarm provides
adequate observability for the current release.

---

## 8. End-to-End Validation

Run all D3 boundary tests:

```sh
# Go unit tests (layer policy + hook + validate commands)
go test ./internal/cli/layer/... ./internal/cli/hook/... ./internal/cli/...

# Integration tests
bash tests/integration/test-boundary-leakage.sh
bash tests/integration/test-layer-policy-parity.sh
bash tests/integration/test-layered-dispatch-e2e.sh

# Validate all three policy artefacts
furrow validate layer-policy
furrow validate skill-layers
furrow validate driver-definitions
```
