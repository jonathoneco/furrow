# D3 — Boundary Enforcement Spec

Deliverable: `boundary-enforcement` (W5). Owner: harness-engineer. Depends on D2 (driver-architecture) and D4 (context-routing-cli).

## Goals

- Encode the operator/driver/engine layer model (D2) as **executable policy** consumed identically by Claude and Pi adapters.
- Ship `furrow hook layer-guard` and `furrow hook presentation-check` (D6) as **Go subcommands** wired into both adapters; no shell hooks.
- Make the operator→driver→engine boundary **observable in tests**: cross-adapter parity + post-hoc leakage smoke alarm.
- Land the 5 D3 blocker codes (and pave the way for D6's 1) as appendix-only additions to `schemas/blocker-taxonomy.yaml`.

## Non-goals

- Pi subagent layer enforcement beyond main-thread (subprocess spawn blinds parent hook bus — explicit constraint #16).
- Replacing existing shell hooks (state-guard.sh, etc.) — port is debt-driven, not D3's scope.
- New runtime-specific session/state files in the Furrow backend (constraint #6).
- Auto-fixing layer violations — hook only blocks/warns; remediation is human/driver-side.

## Approach

Five components, all canonical Go where executable:

1. **`schemas/layer-policy.schema.json`** — JSON Schema draft 2020-12 with `additionalProperties:false` at every level.
2. **`.furrow/layer-policy.yaml`** — single canonical policy, consumed verbatim by both adapters.
3. **`internal/cli/layer/policy.go`** — typed loader; backs `furrow validate layer-policy` and `furrow hook layer-guard`.
4. **`internal/cli/hook/layer_guard.go`** — Go subcommand; reads PreToolUse/tool_call JSON from stdin, returns `{block, reason}` envelope, exits per Claude hook protocol (2 = block, 0 = allow).
5. **Cross-adapter wiring** — `.claude/settings.json` registers as PreToolUse; `adapters/pi/extension/index.ts` exec's the same Go binary with stdin shaped to match Claude's payload.

All layer enforcement reads **one** policy file. Pi adapter never duplicates allow/deny logic; it only normalizes its `tool_call` event into Claude's hook JSON shape and exec's `furrow hook layer-guard`.

## layer-policy-yaml

### Schema (`schemas/layer-policy.schema.json`, abbreviated)

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "$id": "https://furrow.local/schemas/layer-policy.schema.json",
  "type": "object",
  "additionalProperties": false,
  "required": ["version", "agent_type_map", "layers"],
  "properties": {
    "version": {"const": "1"},
    "agent_type_map": {
      "type": "object",
      "additionalProperties": false,
      "patternProperties": {
        "^(operator|driver:[a-z_]+|engine:[a-z0-9_:-]+)$": {
          "type": "string",
          "enum": ["operator", "driver", "engine"]
        }
      }
    },
    "layers": {
      "type": "object",
      "additionalProperties": false,
      "required": ["operator", "driver", "engine"],
      "properties": {
        "operator": {"$ref": "#/$defs/layerRules"},
        "driver":   {"$ref": "#/$defs/layerRules"},
        "engine":   {"$ref": "#/$defs/layerRules"}
      }
    }
  },
  "$defs": {
    "layerRules": {
      "type": "object",
      "additionalProperties": false,
      "required": ["tools_allow", "tools_deny", "path_deny", "bash_allow_prefixes", "bash_deny_substrings"],
      "properties": {
        "tools_allow": {"type": "array", "items": {"type": "string"}},
        "tools_deny":  {"type": "array", "items": {"type": "string"}},
        "path_deny":   {"type": "array", "items": {"type": "string"}},
        "bash_allow_prefixes":  {"type": "array", "items": {"type": "string"}},
        "bash_deny_substrings": {"type": "array", "items": {"type": "string"}}
      }
    }
  }
}
```

### Canonical content (`.furrow/layer-policy.yaml`)

```yaml
version: "1"
# Maps observed agent_type values (Claude PreToolUse JSON) to layer labels.
# Pattern source: D2 driver-{step} naming + D1 engine:{specialist-id} convention.
agent_type_map:
  operator:                 operator
  driver:ideate:            driver
  driver:research:          driver
  driver:plan:              driver
  driver:spec:              driver
  driver:decompose:         driver
  driver:implement:         driver
  driver:review:            driver
  engine:freeform:          engine
  # specialist engines: pattern engine:specialist:{id}
  # Unknown agent_type → engine (fail-closed default; see policy.go LookupLayer)

layers:
  operator:
    tools_allow: ["*"]            # full surface
    tools_deny: []
    path_deny: []
    bash_allow_prefixes: []
    bash_deny_substrings: []

  driver:
    tools_allow: ["Read", "Grep", "Glob", "SendMessage", "Agent", "TaskCreate", "TaskGet", "TaskList", "TaskUpdate", "Bash"]
    tools_deny:  ["Edit", "Write", "NotebookEdit"]
    path_deny: []
    bash_allow_prefixes:
      - "rws "
      - "alm "
      - "sds "
      - "furrow context "
      - "furrow handoff render"
      - "furrow validate "
      - "go test "
    bash_deny_substrings:
      - " > "        # output redirection
      - " >> "
      - "rm -"
      - "git commit"

  engine:
    tools_allow: ["Read", "Grep", "Glob", "Edit", "Write", "Bash"]
    tools_deny:  ["SendMessage", "Agent", "TaskCreate"]
    path_deny:
      - ".furrow/"
      - "schemas/blocker-taxonomy.yaml"
      - "schemas/definition.schema.json"
    bash_allow_prefixes: []        # no whitelist; deny-list mode
    bash_deny_substrings:
      - "furrow "
      - "rws "
      - "alm "
      - "sds "
      - ".furrow/"
```

ACs covered: `Layer policy authority`, `Layer policy content`.

## layer-policy-go-struct

`internal/cli/layer/policy.go`:

```go
package layer

type Layer string
const (
    LayerOperator Layer = "operator"
    LayerDriver   Layer = "driver"
    LayerEngine   Layer = "engine"
)

type LayerRules struct {
    ToolsAllow         []string `yaml:"tools_allow"          json:"tools_allow"`
    ToolsDeny          []string `yaml:"tools_deny"           json:"tools_deny"`
    PathDeny           []string `yaml:"path_deny"            json:"path_deny"`
    BashAllowPrefixes  []string `yaml:"bash_allow_prefixes"  json:"bash_allow_prefixes"`
    BashDenySubstrings []string `yaml:"bash_deny_substrings" json:"bash_deny_substrings"`
}

type Policy struct {
    Version       string             `yaml:"version"`
    AgentTypeMap  map[string]Layer   `yaml:"agent_type_map"`
    Layers        map[Layer]LayerRules `yaml:"layers"`
}

// Load reads .furrow/layer-policy.yaml, validates against schemas/layer-policy.schema.json,
// returns (*Policy, error). Validation failure → blocker code layer_policy_invalid.
func Load(path string) (*Policy, error) { /* schema-validate then yaml.Unmarshal */ }

// LookupLayer returns the layer for an agent_type. Fail-closed: unknown driver:* /
// engine:* pattern → LayerEngine (most-restricted); empty/missing → LayerOperator
// (matches Claude's main-thread PreToolUse with no agent_type field).
func (p *Policy) LookupLayer(agentType string) Layer { /* ... */ }

// Decide is the pure verdict function — no I/O. Returns (allow, reason).
func (p *Policy) Decide(layer Layer, toolName, toolInput string) (bool, string) { /* ... */ }
```

ACs covered: `Layer policy authority`. Test file `policy_test.go` table-drives Decide across the parity fixtures (below).

## layer-guard-go-subcommand

`internal/cli/hook/layer_guard.go` — registered under `furrow hook layer-guard` via `internal/cli/app.go` (sequential touch after D2's W4 register).

### Stdin payload (Claude PreToolUse, also Pi-normalized)

```json
{
  "session_id": "...",
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": { "file_path": ".furrow/state.json", "old_string": "...", "new_string": "..." },
  "agent_id":   "subagent_123",
  "agent_type": "engine:specialist:relational-db-architect"
}
```

### Implementation outline

```go
func RunLayerGuard(ctx context.Context, in io.Reader, out io.Writer) int {
    var ev hookInput
    if err := json.NewDecoder(in).Decode(&ev); err != nil {
        emit(out, true, "layer_guard: malformed hook payload: " + err.Error())
        return 2
    }
    pol, err := layer.Load(".furrow/layer-policy.yaml")
    if err != nil { emit(out, true, "layer_policy_invalid: " + err.Error()); return 2 }
    lyr := pol.LookupLayer(ev.AgentType)         // empty → operator
    flat := flattenToolInput(ev.ToolName, ev.ToolInput)
    allow, reason := pol.Decide(lyr, ev.ToolName, flat)
    if !allow {
        emit(out, true, fmt.Sprintf("layer_tool_violation: %s in layer %s: %s",
            ev.ToolName, lyr, reason))
        return 2  // Claude hook block exit code
    }
    return 0
}

func emit(w io.Writer, block bool, reason string) {
    json.NewEncoder(w).Encode(map[string]any{"block": block, "reason": reason})
}
```

Verdict envelope is exactly `{ "block": bool, "reason": string }` on stdout. Exit code `2` blocks (per Claude hook protocol); `0` allows.

ACs covered: `furrow hook layer-guard Go subcommand`, `Pi adapter wiring`.

## skill-layer-frontmatter

Every skill file gains a `layer:` YAML front-matter field. D4's loader rejects skills missing this field with `skill_layer_unset`.

| Path glob                          | Layer                            |
|------------------------------------|----------------------------------|
| `skills/{step}.md` (the 7 steps)   | `driver`                         |
| `skills/work-context.md`           | `operator`                       |
| `skills/shared/layer-protocol.md`  | `shared`                         |
| `skills/shared/specialist-delegation.md` | `shared`                   |
| `skills/shared/presentation-protocol.md` (D6) | `operator`            |
| `skills/shared/decision-format.md` | `shared`                         |
| `skills/shared/skill-template.md`  | `shared`                         |
| `specialists/*.md`                 | `engine`                         |
| `commands/work.md.tmpl` (rendered as operator skill) | `operator`     |

Front-matter form (additive only, leading frontmatter block):

```yaml
---
layer: driver
---
```

ACs covered: `Prompt-level scoping`, `Skill layer assignment is mechanically derivable`, `furrow validate skill-layers`.

## claude-settings-additions

Additive delta to `.claude/settings.json`. The PreToolUse `matcher: "Write|Edit"` array gains `frw hook layer-guard`; a new entry adds layer-guard to `Bash` (driver bash policing) and a wildcard matcher to catch `SendMessage`/`Agent`. D6's `presentation-check` joins the Stop array.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "frw hook state-guard" },
          { "type": "command", "command": "frw hook ownership-warn" },
          { "type": "command", "command": "frw hook validate-definition" },
          { "type": "command", "command": "frw hook correction-limit" },
          { "type": "command", "command": "frw hook verdict-guard" },
          { "type": "command", "command": "frw hook append-learning" },
          { "type": "command", "command": "furrow hook layer-guard" }
        ]
      },
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "frw hook gate-check" },
          { "type": "command", "command": "frw hook script-guard" },
          { "type": "command", "command": "furrow hook layer-guard" }
        ]
      },
      {
        "matcher": "SendMessage|Agent|TaskCreate|TaskUpdate",
        "hooks": [
          { "type": "command", "command": "furrow hook layer-guard" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "frw hook work-check" },
          { "type": "command", "command": "frw hook stop-ideation" },
          { "type": "command", "command": "frw hook validate-summary" }
        ]
      }
    ]
  }
}
```

Notes:
- `furrow` (not `frw`) is the canonical Go binary per constraint #1; existing `frw hook *` shell entries remain pending the canonical-Go port.
- D3 does NOT pre-write `furrow hook presentation-check` — D6 owns that registration entirely (W6 appends to the existing Stop array).
- Joint touch ordering: D3 (W5) writes the layer-guard entries to PreToolUse; D6 (W6) appends `presentation-check` to Stop.

ACs covered: `Claude adapter wiring`.

## pi-extension-tool-call

`adapters/pi/extension/index.ts` registers a `tool_call` hook that exec's `furrow hook layer-guard`:

```typescript
import { spawnSync } from "node:child_process";
import { extension } from "@tintinweb/pi-subagents";

extension.on("tool_call", async (ev, ctx) => {
  // Normalize Pi tool_call event → Claude PreToolUse JSON shape
  const payload = {
    session_id: ctx.session.id,
    hook_event_name: "PreToolUse",
    tool_name: ev.tool,
    tool_input: ev.input ?? {},
    agent_id:   ctx.agent?.id   ?? "main",
    agent_type: ctx.agent?.type ?? "operator",
  };
  const res = spawnSync("furrow", ["hook", "layer-guard"], {
    input: JSON.stringify(payload),
    encoding: "utf-8",
  });
  if (res.status === 2) {
    let reason = "layer_tool_violation";
    try { reason = JSON.parse(res.stdout).reason ?? reason; } catch {}
    ctx.ui.notify(`layer-guard blocked: ${reason}`);
    return { block: true, reason };
  }
  return { block: false };
});
```

Constraints honored:
- Stdin JSON shape **identical** to Claude's PreToolUse payload (cross-adapter parity invariant, constraint #8).
- Pi-side enforcement scoped to main-thread/operator: subprocess subagents are blind to the parent's tool_call event bus (constraint #16).
- UX divergence (`ctx.ui.notify` vs Claude's stdout/stderr) is intrinsic and acceptable; verdict logic stays in Go.

ACs covered: `Pi adapter wiring`, `Pi capability gap`.

## leakage-corpus

Canonical at `tests/integration/test-boundary-leakage.sh`. Engine artifact captured into `$ARTIFACT_DIR`; corpus matches via `grep -E -r -f corpus.regex`.

### `tests/integration/fixtures/leakage-corpus.regex`

```
\.furrow/
^\.furrow$
\bfurrow row\b
\bfurrow handoff\b
\bfurrow context\b
\bfurrow validate\b
\bfurrow hook\b
\brws\s
\balm\s
\bsds\s
\bstate\.json\b
\bdefinition\.yaml\b
\bsummary\.md\b
\bblocker_envelope\b
\bgate_policy\b
\bdeliverable_id\b
\balmanac\b
\brationale\.yaml\b
\bblocker code [a-z_]+\b
skill_layer_unset|layer_policy_invalid|layer_tool_violation|engine_furrow_leakage|driver_definition_invalid
```

### Fixture engine handoff (dispatched by the test)

`tests/integration/fixtures/engine-leakage-fixture.json` — passed to `furrow handoff render --target=engine:specialist:go-specialist`:

```json
{
  "target": "engine:specialist:go-specialist",
  "objective": "Add a function double(x int) int returning x*2 to /tmp/test-furrow-leakage-$$/add.go.",
  "deliverables": [{
    "name": "double-function",
    "acceptance_criteria": ["double(2) returns 4", "go test ./... passes"],
    "file_ownership": ["add.go", "add_test.go"]
  }],
  "constraints": ["No external dependencies"],
  "grounding": [],
  "return_format": "engine-eos-report"
}
```

Test asserts `grep -E -r -f corpus.regex "$ARTIFACT_DIR" | wc -l` equals `0`. Any match → `engine_furrow_leakage` blocker, NON-NEGOTIABLE per constraint #9.

ACs covered: `Post-hoc boundary leakage test`.

## parity-test-fixtures

`tests/integration/test-layer-policy-parity.sh` drives both `furrow hook layer-guard` (Claude) and the Pi `tool_call` handler with identical fixtures.

| # | agent_type                                  | tool_name   | tool_input (key fields)                  | Expected |
|---|---------------------------------------------|-------------|------------------------------------------|----------|
| 1 | operator                                    | Write       | `file_path: definition.yaml`             | allow    |
| 2 | driver:plan                                 | Write       | `file_path: plan.json`                   | **block** (driver tools_deny: Write) |
| 3 | driver:plan                                 | Bash        | `command: rws status`                    | allow    |
| 4 | driver:plan                                 | Bash        | `command: rm -rf /tmp/x`                 | **block** (bash_deny_substrings) |
| 5 | engine:specialist:go-specialist             | Write       | `file_path: src/foo.go`                  | allow    |
| 6 | engine:specialist:go-specialist             | Write       | `file_path: .furrow/learnings.jsonl`     | **block** (engine path_deny) |
| 7 | engine:specialist:go-specialist             | Bash        | `command: furrow context for-step plan`  | **block** (engine bash_deny_substrings) |
| 8 | engine:specialist:go-specialist             | SendMessage | `to: subagent_1, body: ...`              | **block** (engine tools_deny) |
| 9 | engine:freeform                             | Read        | `file_path: src/foo.go`                  | allow    |
| 10| (missing/main-thread)                       | Write       | `file_path: src/foo.go`                  | allow (operator default) |

Verification: `diff <(claude_verdicts) <(pi_verdicts)` returns empty; otherwise test fails.

ACs covered: `Cross-adapter parity test`.

## e2e-test

`tests/integration/test-layered-dispatch-e2e.sh`:

1. `furrow row create fixture-e2e --gate-policy=auto`
2. Operator spawns `driver:plan` (Claude: TeamCreate; Pi: pi-subagents spawn). Layer-guard PreToolUse active.
3. Driver runs `rws status fixture-e2e` (allow), then `furrow context for-step plan --target=engine:specialist:go-specialist`.
4. Driver dispatches via `furrow handoff render --target=engine:specialist:go-specialist --row=fixture-e2e --step=plan --write`.
5. Engine receives Furrow-stripped handoff (D1 schema enforced), edits `src/foo.go` (allow), attempts `Edit .furrow/state.json` → **block** (`layer_tool_violation`).
6. Engine returns EOS-report; driver folds into phase result; operator presents per D6 protocol.
7. Assertions:
   - Each layer's tool log matches its allowlist (parsed from `~/.claude/projects/.../hook.log` Claude-side; from `ctx.session.log` Pi-side).
   - Boundary leakage corpus check on engine artifacts: `0` matches.
   - `furrow validate skill-layers && furrow validate layer-policy && furrow validate driver-definitions` all exit 0.

WHEN: e2e fixture runs end-to-end on Claude **and** Pi adapter. THEN: all assertions pass; round-trip completes without operator intervention.

ACs covered: `End-to-end smoke`.

## blocker-codes

Append to `schemas/blocker-taxonomy.yaml` (sequential append, no reorder, after D1's 3 codes):

```yaml
  - code: skill_layer_unset
    category: layer
    severity: block
    message_template: "{path}: skill missing required 'layer:' front-matter field"
    remediation_hint: "Add 'layer: operator|driver|engine|shared' to the YAML frontmatter; see skills/shared/skill-template.md"
    confirmation_path: block

  - code: layer_policy_invalid
    category: layer
    severity: block
    message_template: "{path}: .furrow/layer-policy.yaml failed schema validation: {detail}"
    remediation_hint: "Validate against schemas/layer-policy.schema.json; ensure required keys version/agent_type_map/layers present"
    confirmation_path: block

  - code: layer_tool_violation
    category: layer
    severity: block
    message_template: "agent_type={agent_type} layer={layer}: tool {tool_name} denied: {detail}"
    remediation_hint: "Either invoke the tool from the appropriate layer, or revisit .furrow/layer-policy.yaml if the policy is wrong"
    confirmation_path: block

  - code: engine_furrow_leakage
    category: layer
    severity: block
    message_template: "engine artifact {artifact_path} contains Furrow vocabulary or path: {match}"
    remediation_hint: "Driver must strip Furrow vocab from EngineHandoff grounding/objective; see D1 EngineHandoff content discipline"
    confirmation_path: block

  - code: driver_definition_invalid
    category: definition
    severity: block
    message_template: "{path}: driver definition failed schema validation: {detail}"
    remediation_hint: "Validate against schemas/driver-definition.schema.json; required keys: name, step, tools_allowlist, model"
    confirmation_path: block
```

ACs covered: `schemas/blocker-taxonomy.yaml gains: ...`.

## acceptance (refined WHEN/THEN)

| AC ref | Scenario | Verification command |
|--------|----------|----------------------|
| AC1 (skill front-matter + skill_layer_unset) | WHEN any `skills/**/*.md` lacks `layer:` THEN `furrow validate skill-layers --json` exits non-zero with code `skill_layer_unset` | `furrow validate skill-layers --json \| jq '.blockers[].code'` |
| AC2 (mechanical assignment) | WHEN D3 runs THEN every skill file has `layer:` matching the table above | `tests/integration/test-skill-layer-assignment.sh` |
| AC3 (validate skill-layers) | WHEN command runs against good fixture THEN exit 0; against bad fixture THEN exit non-zero | `go test ./internal/cli/...` |
| AC4 (layer-policy authority) | WHEN `.furrow/layer-policy.yaml` violates schema THEN `furrow validate layer-policy` emits `layer_policy_invalid` | `furrow validate layer-policy --json` |
| AC5 (policy content) | WHEN policy loaded THEN driver tools_deny includes Edit/Write; engine path_deny includes `.furrow/` | `go test ./internal/cli/layer/...` |
| AC6 (hook subcommand) | WHEN PreToolUse fires for engine attempting `Write .furrow/x` THEN `furrow hook layer-guard` returns `{block:true}` exit 2 | `echo $PAYLOAD \| furrow hook layer-guard; echo $?` |
| AC7 (Claude wiring) | WHEN `.claude/settings.json` loaded THEN `furrow hook layer-guard` registered on PreToolUse Write\|Edit/Bash/SendMessage matchers | `jq '.hooks.PreToolUse' .claude/settings.json` |
| AC8 (Pi wiring) | WHEN Pi `tool_call` fires THEN extension exec's `furrow hook layer-guard` with Claude-shaped JSON | `bun test adapters/pi/` |
| AC9 (Pi capability gap doc) | WHEN docs read THEN `docs/architecture/orchestration-delegation-contract.md` documents Pi subagent main-thread-only scope | `grep -F "main-thread only" docs/architecture/orchestration-delegation-contract.md` |
| AC10 (parity test) | WHEN parity fixtures run THEN Claude verdicts == Pi verdicts | `bash tests/integration/test-layer-policy-parity.sh` |
| AC11 (leakage test) | WHEN engine fixture dispatched THEN zero corpus matches in artifacts | `bash tests/integration/test-boundary-leakage.sh` |
| AC12 (e2e smoke) | WHEN operator→driver→engine round-trip on both adapters THEN each layer made only allowed calls; zero leakage | `bash tests/integration/test-layered-dispatch-e2e.sh` |
| AC13 (taxonomy) | WHEN D3 lands THEN 5 codes appended; existing entries unchanged | `git diff main schemas/blocker-taxonomy.yaml` |
| AC14 (orchestration doc) | WHEN doc rendered THEN sections for D1/D2/D3/D4/D5 cross-link | `grep -F "## Boundary Enforcement" docs/architecture/orchestration-delegation-contract.md` |
| AC15 (test gate) | `go test ./...` passes; `bun test adapters/pi/` passes | both commands |

## open-questions

1. Should `agent_type_map` lookup fail-closed to `engine` for unknown patterns, or reject with a new code (`unknown_agent_type`)? Current spec: fail-closed-to-engine (most-restricted). Revisit if the strict reject yields better debuggability.
2. Pi subagent enforcement gap — file an explicit follow-up row for upstream patch to `@tintinweb/pi-subagents` exposing a parent-bus tool_call event.
3. Bash deny-substring approach is coarse. If false positives become an issue, escalate to a token-aware shell parser (out of scope this row).
4. `.claude/settings.json` `furrow` vs `frw` binary name — consolidate at canonical-Go port; until then, both names ship side-by-side.

---

## Summary (150 words)

**Top 3 implementation risks**: (1) **Pi subagent blindness** — `@tintinweb/pi-subagents` subprocess model means parent hook bus cannot intercept engine tool_calls; mitigation is EngineHandoff Furrow-stripping (D1) + post-hoc leakage smoke alarm, but the gap is real and must be re-papered every release. (2) **Cross-adapter payload drift** — Claude's PreToolUse JSON shape and Pi's `tool_call` event are independently versioned; parity test fixtures must include schema assertions, not just verdict equality. (3) **Bash policy false-positives** — coarse substring matching on driver/engine bash commands risks blocking legitimate dev loops; needs alert path for human override.

**Leakage corpus regex set**: `\.furrow/`, `\bfurrow (row|handoff|context|validate|hook)\b`, `\b(rws|alm|sds)\s`, `\b(state\.json|definition\.yaml|summary\.md|gate_policy|deliverable_id|almanac|rationale\.yaml)\b`, plus the 5 D3 blocker code names as a literal alternation.

**`.claude/settings.json` registration approach**: additive only — append `furrow hook layer-guard` to the existing PreToolUse `Write|Edit` and `Bash` matcher arrays, plus a new `SendMessage|Agent|TaskCreate|TaskUpdate` matcher entry. D3 does NOT touch the Stop array — D6 owns Stop registration in W6. No reordering or removal of existing `frw hook *` entries; canonical-Go binary name `furrow` ships alongside legacy `frw` until the global port lands.
