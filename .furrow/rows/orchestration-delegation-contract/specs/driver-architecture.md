# Spec: driver-architecture (D2)

## Goals

- Land the vertical 3-layer contract (operator → phase driver → engine) as concrete artifacts: 7 static driver definitions, layer-protocol doc, rewritten specialist-delegation doc, 7 reframed step skills, runtime-branched `commands/work.md.tmpl`, and a `furrow render adapters` Go util that produces runtime-specific files.
- Wire a minimal-but-functioning end-to-end smoke on BOTH adapters (Claude `.claude/agents/driver-{step}.md` rendered subagents; Pi `@tintinweb/pi-subagents` extension) proving operator→driver→engine round-trip with layer-guard active and zero Furrow leakage in engine artifacts.
- Keep Furrow backend runtime-agnostic: no `drivers.json`, no session-id awareness, no `.layer-context` files. Operator session-resume is a runtime concern documented in the operator skill.

## Non-Goals

- Per-driver model routing UI, parallel engine teams, dashboard UX (follow-up rows).
- Pi-side subagent layer enforcement (subprocess-spawn capability gap; D3 owns the documented limitation).
- Migration of existing `bin/frw.d/hooks/state-guard.sh` to Go (debt to port; out of scope for D2).
- Rewriting `skills/shared/skill-template.md` semantics (D3 adds layer front-matter additively).

## Approach

D2 reorganises the existing operator-as-everything model into three named layers backed by static YAML driver definitions and a runtime-rendering adapter. The implementation order inside the wave is: (1) write driver YAMLs + schema; (2) write `skills/shared/layer-protocol.md` and rewrite `skills/shared/specialist-delegation.md`; (3) reframe the 7 step skills as driver briefs and lift user-facing presentation into `commands/work.md.tmpl`; (4) implement `furrow render adapters` and emit `.claude/agents/driver-{step}.md` × 7 + a Claude-rendered `commands/work.md`; (5) implement Pi extension scaffolding consuming the same definitions; (6) recursive-spawn verification on `@tintinweb/pi-subagents` src/agent-runner.ts; (7) integration smoke. Drivers carry runtime-agnostic data (tools/model/step); persona is implicit by convention (`skills/{step}.md` is the brief); user dialog stays operator-side.

## driver-definition-yaml

**Schema** (`schemas/driver-definition.schema.json`, JSON Schema draft 2020-12, `additionalProperties:false` at all levels) — AC: "schemas/driver-definition.schema.json validates the YAML structure".

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "type": "object",
  "additionalProperties": false,
  "required": ["name", "step", "tools_allowlist", "model"],
  "properties": {
    "name":            { "type": "string", "pattern": "^driver:(ideate|research|plan|spec|decompose|implement|review)$" },
    "step":            { "type": "string", "enum": ["ideate","research","plan","spec","decompose","implement","review"] },
    "tools_allowlist": { "type": "array",  "items": { "type": "string" }, "minItems": 1, "uniqueItems": true },
    "model":           { "type": "string", "enum": ["opus","sonnet","haiku"] }
  }
}
```

**Example driver YAML** — `.furrow/drivers/driver-research.yaml`:

```yaml
name: driver:research
step: research
tools_allowlist:
  - Read
  - Grep
  - Glob
  - WebFetch
  - SendMessage
  - Agent
  - Bash(rws:*)
  - Bash(alm:*)
  - Bash(sds:*)
  - Bash(furrow:context for-step:*)
  - Bash(furrow:handoff render:*)
model: sonnet
```

The 6 other YAMLs (`driver-ideate.yaml`, `driver-plan.yaml`, `driver-spec.yaml`, `driver-decompose.yaml`, `driver-implement.yaml`, `driver-review.yaml`) follow the same shape; `driver-implement.yaml` adds `Edit`/`Write` and removes `WebFetch`; `driver-review.yaml` is read-only.

`furrow validate driver-definitions --json` (D3 owns the registration, D2 owns the schema and emits blocker `driver_definition_invalid` per the joint-ownership note). Reconciled post-archive: also wired into `frw doctor` (under "Driver definitions" section) so a broken driver YAML surfaces at doctor-time, not just on demand. See commit `eb2a43f`.

## layer-protocol-doc

`skills/shared/layer-protocol.md` (canonical contract, ~120 lines) — AC: "skills/shared/layer-protocol.md is the canonical contract".

Sections:

1. **Purpose** — names the 3 layers; states runtime-agnostic semantics.
2. **Operator** — whole-row, user-facing, state-mutating; only layer that calls `rws`/`alm`/`sds`; only layer that addresses the user.
3. **Phase driver** — one-per-step, session-scoped, runtime-managed; persona implicit via `skills/{step}.md`; tools constrained by `.furrow/drivers/driver-{step}.yaml`; runs step ceremony, dispatches engine teams, assembles EOS-report.
4. **Engine** — one-shot, Furrow-unaware; no `.furrow/` reads; no Furrow vocab in inputs (enforced by D1 `EngineHandoff` schema).
5. **Handoff exchange** — driver→engine via `furrow handoff render --target engine:*` (D1); engine returns EOS-report shape per `templates/handoffs/return-formats/`.
6. **Engine-team-composed-at-dispatch** — drivers compose engine teams per dispatch (parallel allowed); no planning-time team binding; `plan.json` `specialist:` is hint only.
7. **Runtime-agnostic message-passing** — defined in terms of "spawn", "message", "return" — Claude maps to `Agent`/`SendMessage`/return; Pi maps to `pi-subagents` API.
8. **Cross-references** — `skills/shared/specialist-delegation.md` (driver→engine framing); D1 schema; D3 layer-policy.

## specialist-delegation-rewrite

`skills/shared/specialist-delegation.md` rewritten end-to-end (current operator→specialist framing retired) — AC: "skills/shared/specialist-delegation.md rewritten for driver→engine dispatch".

Outline:

1. **Audience** — phase drivers (not the operator).
2. **Why this exists** — engines run Furrow-unaware; the driver bears curation responsibility.
3. **Composing an engine team at dispatch** — one driver may dispatch N engines in parallel for one deliverable; team membership is per-dispatch, not per-plan.
4. **Dispatch primitive** — `furrow handoff render --target engine:specialist:{id} --row <name> --step <step>` builds an `EngineHandoff` (D1 schema enforces no `.furrow/` paths, no Furrow vocab); driver pipes the rendered markdown to the runtime spawn primitive.
5. **Curation checklist** — grounding paths must be source-tree relative (no `.furrow/`); constraints must use engine-scoped vocab; deliverables must enumerate file ownership and acceptance.
6. **Return contract** — engines return EOS-report; driver assembles per-deliverable rollup before returning phase result to operator.
7. **Cross-reference** — `skills/shared/layer-protocol.md` for boundaries.

## step-skill-reframe

For each of `skills/{ideate,research,plan,spec,decompose,implement,review}.md`, the reframe diff sketch is:

- **Header rewrite**: change audience line to "You are the {step} phase driver." Persona implicit by file name (no front-matter persona; D3 adds `layer: driver` in W5).
- **Remove user-facing presentation blocks** — every "Show this to the user", "Ask the user", "Confirm with user" block is lifted into `commands/work.md.tmpl`. Step skills speak only to the driver and return phase results upward.
- **Add EOS-report assembly section** at end: "Assemble phase EOS-report per `templates/handoffs/return-formats/{step}.json`. Return to operator via runtime primitive (Claude: `SendMessage` to lead; Pi: agent return value)."
- **Add dispatch section** where applicable (research/spec/decompose/implement/review): "Compose engine team via `skills/shared/specialist-delegation.md`. Dispatch via `furrow handoff render --target engine:*`."

Per-skill notes:

- `ideate.md`: keep section markers (D6 codifies), drop user-confirmation prose.
- `research.md`: dispatch model = parallel research engines; assemble `research/synthesis.md` from engine outputs.
- `plan.md`: **drops `team-plan.md` prescription entirely**. Reframes around layered model — engine teams composed at dispatch by drivers, not planning time. `plan.json` keeps `wave`/`file_ownership`/`specialist:` hint surface. **Existing `.furrow/rows/orchestration-delegation-contract/team-plan.md` is deleted as part of this deliverable.**
- `spec.md`: dispatches per-deliverable spec-writer engines.
- `decompose.md`: dispatches decomposition engine; produces wave plan.
- `implement.md`: dispatches per-deliverable implementer engines (parallel allowed).
- `review.md`: dispatches reviewer engines; assembles review rollup.

`skills/work-context.md` updated: scope narrowed to operator's per-row context; per-step context delegated to `furrow context for-step <step> --target driver` (D4 primitive — step is positional, target is layer).

## commands-work-tmpl

`commands/work.md.tmpl` — Go `text/template`, two runtime branches. The unrendered template is the runtime-agnostic source of truth. Sketch:

```gotmpl
# /work — operator skill

You are the operator. Row: {{ "{{ROW_NAME}}" }}. Step: detect via `rws status`.

## Step 1 — Load operator bundle
Run: `furrow context for-step <step> --target operator --row <row> --json`.

## Step 2 — Detect step + dispatch driver
{{ if eq .Runtime "claude" -}}
### Claude runtime
- Session-resume detection: read `~/.claude/teams/{{ "{{ROW_NAME}}" }}/config.json`. If absent or `members[].agent_id` stale (no live process), re-spawn drivers.
- Spawn driver: `Agent(subagent_type="driver:{step}", description="<concise task>", prompt="<priming message body>")`. Claude Code's `Agent` tool dispatches to a pre-registered subagent definition at `.claude/agents/driver-{step}.md` (rendered by `furrow render adapters --runtime=claude` from `.furrow/drivers/driver-{step}.yaml` + `skills/{step}.md`); the system prompt and tool allowlist come from that definition's frontmatter, NOT inline arguments.
- Prime: `SendMessage(to=agent_id, body=<bundle from furrow context for-step <step> --target driver>)` then render driver handoff via `furrow handoff render --target driver:{step}` (D1) for the persisted artifact at `.furrow/rows/{name}/handoffs/{step}-to-driver.md`.
- On driver return: render phase result per `skills/shared/presentation-protocol.md` (D6); confirm gate with user; `rws transition`.
{{- else if eq .Runtime "pi" -}}
### Pi runtime
- Session-resume detection: `@tintinweb/pi-subagents` handles its own resume via session-tree branches.
- Spawn driver: pi-subagents `spawn({name: "driver:{step}", systemPrompt: <skills/{step}.md>, tools: <allowlist>})` (extension wires `before_agent_start` to inject these).
- Prime: pi-subagents `sendMessage(handle, <bundle>)`.
- On driver return: render phase result per `skills/shared/presentation-protocol.md`; confirm gate with user; `rws transition`.
{{- end }}

## Step 3 — Presentation
Use `skills/shared/presentation-protocol.md` (D6) for all artifact rendering to user.
```

`Runtime` template variable: **typed enum** for compile-time safety (resolution of OQ #2). Definition in `internal/cli/render/adapters.go`:

```go
// Runtime identifies the adapter target for template rendering.
type Runtime string

const (
    RuntimeClaude Runtime = "claude"
    RuntimePi     Runtime = "pi"
)

type RenderCtx struct {
    Runtime    Runtime
    RowName    string
    ProjectDir string
}
```

Templates compare `{{ if eq .Runtime "claude" }}` against the underlying string value; the typed-enum gives compile-time safety in Go callers while keeping template syntax simple. D3 and D6 extend `RenderCtx` additively (new fields only — never modify existing).

## render-adapters-util

`furrow render adapters --runtime=<claude|pi> [--write]` — Go util at `internal/cli/render/adapters.go`.

Behaviour per runtime:

- `--runtime=claude`:
  - Renders `commands/work.md.tmpl` → `commands/work.md` with `.Runtime = "claude"`.
  - For each `.furrow/drivers/driver-{step}.yaml` (×7), renders `.claude/agents/driver-{step}.md`. Output format = subagent definition: YAML front-matter (`name`, `description`, `tools` (mapped from `tools_allowlist`), `model`) + body = literal contents of `skills/{step}.md` (the driver brief).
- `--runtime=pi`:
  - Renders `commands/work.md.tmpl` → `commands/work.md` with `.Runtime = "pi"`.
  - Optionally invokes `cd adapters/pi && bun run build` (if `--build` flag passed) to compile `extension/index.ts`. Build invocation gated to keep the Go util pure rendering by default.
- Without `--write`: emits all rendered output to stdout as a manifest (path → content); useful for tests.
- Idempotent: same inputs → identical bytes (stable map iteration order; templates use sorted keys).

`internal/cli/app.go` registers the `render` top-level command group following the pre-write-validation-go-first registration pattern (W4 in joint ordering).

## pi-extension

`adapters/pi/extension/index.ts` — TypeScript extension consuming `@tintinweb/pi-subagents`. Outline:

```ts
import { defineExtension } from "@tintinweb/pi-subagents";
import { execFileSync } from "node:child_process";

export default defineExtension({
  name: "furrow",

  hooks: {
    before_agent_start: async (ctx) => {
      const driverYaml = readDriverYaml(ctx.agentName); // .furrow/drivers/driver-{step}.yaml
      ctx.setActiveTools(driverYaml.tools_allowlist);
      const skill = readSkill(driverYaml.step); // skills/{step}.md
      return { systemPrompt: skill };
    },

    tool_call: async (ctx, call) => {
      const payload = JSON.stringify({
        hook_event_name: "PreToolUse",
        tool_name: call.tool_name,
        tool_input: call.tool_input,
        agent_id: ctx.agentId,
        agent_type: ctx.agentName, // matches Claude shape
      });
      const result = execFileSync("furrow", ["hook", "layer-guard"], { input: payload });
      const verdict = JSON.parse(result.toString());
      if (verdict.block) ctx.deny(verdict.reason);
    },
  },
});
```

`adapters/pi/package.json`:

```json
{
  "name": "furrow-pi-adapter",
  "version": "0.1.0",
  "dependencies": { "@tintinweb/pi-subagents": "0.6.1" },
  "peerDependencies": { "@mariozechner/pi-coding-agent": "^0.70.0" },
  "devDependencies": { "typescript": "^5.6.0", "@types/node": "^22.0.0" }
}
```

`adapters/pi/tsconfig.json`: standard ESNext + NodeNext config; strict mode on. Wrapped behind a thin `PiAdapter` interface (internal package boundary) so the dep is swappable per constraint.

## recursive-spawn-verification

**Code path to read**: `node_modules/@tintinweb/pi-subagents/src/agent-runner.ts` after `bun install` in `adapters/pi/`. Specifically the function that handles `Agent` tool-call dispatch from within a running subagent — assert that the subagent's `Agent` tool invocation enqueues a child agent on the same runner (recursive), not a hard-failure / "subagents cannot spawn subagents" guard.

**Assertions**:

1. The runner's `dispatchTool` (or equivalent) routes `tool_name === "Agent"` through the same spawn path regardless of caller depth.
2. No depth check raises before `MAX_DEPTH` configurable limit; if such a limit exists, document its default.
3. Child agent's `tool_call` events bubble to extension hooks (so `furrow hook layer-guard` fires inside engines) — if NOT, document the gap and fall back per below.

**Fallback if broken**: drivers dispatch engines as **subprocess** subagents per the pi-mono example pattern (`spawn` a separate `pi` process with the engine handoff as input, capture stdout). Engine isolation preserved by `EngineHandoff` Furrow-stripping (D1) regardless. Spec captures verification result in `## Open Questions` of the row summary; implementation may pivot to subprocess fallback without re-spec.

## acceptance

Refined ACs with WHEN/THEN scenarios.

**AC1 — Driver YAMLs validate** *(definition AC: "Driver definitions at .furrow/drivers/driver-{step}.yaml — 7 files")*
- WHEN `furrow validate driver-definitions --json` runs over `.furrow/drivers/`
- THEN exit 0; stdout contains `{"valid": true, "count": 7}`.
- VERIFY: `furrow validate driver-definitions --json | jq -e '.valid == true and .count == 7'`.

**AC2 — Schema rejects malformed driver YAML** *(definition AC: "schemas/driver-definition.schema.json validates")*
- WHEN a `driver-foo.yaml` with `name: driver:foo` (unknown step) is added
- THEN `furrow validate driver-definitions --json` exits non-zero, emits blocker `driver_definition_invalid`.
- VERIFY: `tests/integration/test-driver-architecture.sh::test_invalid_driver_rejected`.

**AC3 — layer-protocol.md exists with required sections** *(definition AC: "skills/shared/layer-protocol.md is the canonical contract")*
- WHEN `grep -E '^## (Operator|Phase driver|Engine|Handoff exchange|Engine-team-composed-at-dispatch)' skills/shared/layer-protocol.md`
- THEN all 5 section headers present.

**AC4 — specialist-delegation.md rewritten** *(definition AC: "skills/shared/specialist-delegation.md rewritten for driver→engine dispatch")*
- WHEN `grep -c 'operator dispatches' skills/shared/specialist-delegation.md`
- THEN result is 0 (old framing gone); WHEN `grep -c 'driver dispatches engine' skills/shared/specialist-delegation.md` THEN result ≥ 1.

**AC5 — All 7 step skills addressed to driver** *(definition AC: "All 7 skills/{step}.md reframed as driver briefs")*
- WHEN `for f in skills/{ideate,research,plan,spec,decompose,implement,review}.md; do grep -q 'phase driver' "$f" || echo MISSING:$f; done`
- THEN no MISSING output.

**AC6 — team-plan.md retired** *(definition AC: "team-plan.md is dropped from the row artifact set entirely")*
- WHEN `grep -r team-plan.md skills/ commands/ 2>/dev/null`
- THEN no matches (excluding archive paths). The current row's `team-plan.md` is deleted as part of D2's commit.

**AC7 — work.md.tmpl renders for both runtimes** *(definition AC: "commands/work.md.tmpl is a Go text/template ... with runtime branches")*
- WHEN `furrow render adapters --runtime=claude` and `--runtime=pi` run
- THEN `commands/work.md` is generated; Claude render contains `Agent(name="driver:`; Pi render contains `pi-subagents`.

**AC8 — `.claude/agents/driver-{step}.md` rendered** *(definition AC: ".furrow/drivers/driver-{step}.yaml → .claude/agents/driver-{step}.md")*
- WHEN `furrow render adapters --runtime=claude --write` runs
- THEN `.claude/agents/driver-{step}.md` exists for all 7 steps with valid front-matter (`name`, `tools`, `model`) and body = `skills/{step}.md` content.

**AC9 — Pi extension compiles** *(definition AC: "Pi adapter package adoption")*
- WHEN `cd adapters/pi && bun install && bun run typecheck`
- THEN exit 0.

**AC10 — End-to-end smoke on both runtimes** *(definition AC: "Adapter integration in this row is minimal-but-functioning on BOTH adapters")*
- WHEN `tests/integration/test-driver-architecture.sh` runs against fixture row
- THEN: operator spawns one driver → driver dispatches one engine → layer-guard fires on each tool call → leakage test passes → exit 0. Runs once with Claude in-process Agent stub, once with Pi via `@tintinweb/pi-subagents`.

**AC11 — `frw doctor` checks experimental flag** *(constraint: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)*
- WHEN `frw doctor` runs in Claude mode
- THEN warns if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` ≠ `1`.

**AC12 — `go test ./... && go vet ./...`** passes after D2 commit.

## open-questions

1. **Pinned exact pi-subagents version**: latest is **0.6.1** at spec time (`npm view @tintinweb/pi-subagents version` → `0.6.1`). Pin `"@tintinweb/pi-subagents": "0.6.1"` exactly (not `^0.6.1`) until recursive-spawn verification passes; relax to `~0.6.1` after green smoke. **Decision needed at implementation start**: confirm 0.6.1 still latest; if 0.6.2+ available re-run verification.
2. **`Runtime` template variable shape**: proposed `type RenderCtx struct { Runtime string; RowName string; ProjectDir string }` passed to `tmpl.Execute`. Open: should `Runtime` be a typed enum (`type Runtime string` with `RuntimeClaude`/`RuntimePi` constants) for compile-time safety, or stay loose-typed string for ease of template authoring? Recommendation: typed constant + `String()` method; template still does `eq .Runtime "claude"` against the underlying string. **MOST CRITICAL** because it locks the contract D3 and D6 both extend.
3. Recursive-spawn verification result — pending spec-step read of `src/agent-runner.ts`. If broken, subprocess fallback adds ~1 wave of work.
4. Should `furrow render adapters` write the Pi extension build artifact (`adapters/pi/dist/index.js`) or leave that to a separate `bun run build` invocation? Default: leave to bun; keep Go util pure.
