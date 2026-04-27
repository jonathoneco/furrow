# Spec: normalized-blocker-event-and-go-emission-path

> See `specs/shared-contracts.md` for cross-cutting decisions; that document overrides any conflicting detail here.

## Interface Contract

This deliverable lands three artefacts in dependency order:

1. `schemas/blocker-event.yaml` — host-agnostic event envelope and per-event-type
   payload contracts (data).
2. `schemas/blocker-event.schema.json` — JSON Schema (draft 2020-12) validating
   instances of the event envelope (validation).
3. `furrow guard <event-type>` — Go entry point that consumes a normalized event
   on stdin and emits a canonical `BlockerEnvelope` JSON document on stdout
   (behaviour).
4. `bin/frw.d/lib/blocker_emit.sh` — POSIX-sh helper sourced by D3 hook shims
   that translates host events into the normalized payload and invokes the Go
   entry point (shell adapter).

D2 lands all four artefacts; D3 sources `blocker_emit.sh` without modifying it.

---

### 1. `schemas/blocker-event.yaml`

Top-level shape:

```yaml
version: "1"            # bumped on any breaking shape change
event_types:
  - name: <snake_case>
    description: <one-line summary of the host trigger>
    emitted_codes: [<canonical taxonomy code>, ...]   # closed set; drift-checked
    payload_keys:                                     # ordered list, documents intent
      - name: <snake_case>
        type: string|number|boolean|array|object
        description: <one-line>
    required: [<payload_key>, ...]                    # subset of payload_keys[]
```

`version` is mandatory and explicit. Per the locked plan decisions (team-plan.md:40),
the value at this deliverable's landing is `"1"`. Future breaking changes to either
the envelope or any per-event-type payload contract bump this string.

The normalized event envelope on stdin:

```json
{
  "version": "1",
  "event_type": "<one of event_types[].name>",
  "target_path": "<path|optional>",
  "step": "<row step|optional>",
  "row": "<row name|optional>",
  "payload": { "<payload_key>": <value>, ... }
}
```

Top-level fields `target_path`, `step`, `row` are optional convenience fields
hoisted out of `payload` because every emitter consumes at least one of them.
Per-event-type contracts live in `payload`; `payload_keys[]` enumerates legal
keys for the named `event_type` and `required` enforces non-empty subset.

#### Event-type catalog (closed set for D2 landing)

Sourced from `research/hook-audit.md` §2 (per-hook audit). One entry per emitting
hook plus the dead-code marker is excluded. Codes referenced are the canonical
codes the migration-strategist (D1) lands in `schemas/blocker-taxonomy.yaml`.

| `event_type` | Triggered by (host event) | Canonical codes emitted | Required payload keys |
|---|---|---|---|
| `pre_write` | Claude `PreToolUse(Write|Edit)` | `state_json_direct_write`, `verdict_direct_write`, `correction_limit_reached` | `target_path` |
| `pre_bash` | Claude `PreToolUse(Bash)` | `script_guard_internal_invocation` | `command` |
| `stop_ideation` | Claude `Stop` (during `ideate`) | `ideation_incomplete_definition_fields` | `row` |
| `stop_summary_validation` | Claude `Stop` (any non-prechecked) | `summary_section_missing`, `summary_section_empty` | `row` |
| `stop_work_check` | Claude `Stop` (every active row) | `state_validation_failed_warn`, `summary_section_missing_warn`, `summary_section_empty_warn` | `row` |
| `precommit_paths` | git pre-commit (bakfiles, type-change) | `precommit_install_artifact_staged`, `precommit_typechange_to_symlink` | `staged_paths[]` |
| `precommit_modes` | git pre-commit (script modes) | `precommit_script_mode_invalid` | `staged_paths[]` |

Per the audit final inventory (hook-audit.md:33), 10 emit-bearing hooks map to
**7 event types** because `state-guard`, `verdict-guard`, and `correction-limit`
share a single `pre_write` shape (audit §2.1, §2.7, §2.10), and the three
pre-commit path-checks share `precommit_paths` (audit §2.3, §2.5).

`pre-commit-script-modes` keeps a separate `precommit_modes` event because its
payload includes `mode` (the offending git index mode) which the others do not.

#### Per-event-type payload contracts

Each event type below lists `payload_keys[]` and `required[]`. Optional keys are
present in `payload_keys[]` but absent from `required[]`.

```yaml
event_types:
  - name: pre_write
    description: "PreToolUse(Write|Edit) — about to write/edit a file"
    emitted_codes: [state_json_direct_write, verdict_direct_write, correction_limit_reached]
    payload_keys:
      - { name: target_path, type: string, description: "absolute or repo-relative path the tool intends to write" }
      - { name: tool_name,   type: string, description: "Write or Edit (informational)" }
    required: [target_path]

  - name: pre_bash
    description: "PreToolUse(Bash) — about to run a shell command"
    emitted_codes: [script_guard_internal_invocation]
    payload_keys:
      - { name: command, type: string, description: "the full bash command string from tool_input.command" }
    required: [command]

  - name: stop_ideation
    description: "Stop hook during ideate step — completeness check on definition.yaml"
    emitted_codes: [ideation_incomplete_definition_fields]
    payload_keys:
      - { name: row, type: string, description: "active row name" }
    required: [row]

  - name: stop_summary_validation
    description: "Stop hook — block-severity summary.md validation (verdict-guarded)"
    emitted_codes: [summary_section_missing, summary_section_empty]
    payload_keys:
      - { name: row, type: string, description: "active row name" }
    required: [row]

  - name: stop_work_check
    description: "Stop hook — warn-severity multi-row health check (always exit 0)"
    emitted_codes: [state_validation_failed_warn, summary_section_missing_warn, summary_section_empty_warn]
    payload_keys:
      - { name: row, type: string, description: "row name being checked (caller iterates active rows)" }
    required: [row]

  - name: precommit_paths
    description: "git pre-commit — staged paths under refusal globs (bakfiles, type-change-to-symlink)"
    emitted_codes: [precommit_install_artifact_staged, precommit_typechange_to_symlink]
    payload_keys:
      - { name: staged_paths, type: array, description: "list of staged file paths that triggered the check" }
      - { name: check,        type: string, description: "bakfiles | typechange — discriminator for which guard fired" }
    required: [staged_paths, check]

  - name: precommit_modes
    description: "git pre-commit — staged scripts with wrong index mode"
    emitted_codes: [precommit_script_mode_invalid]
    payload_keys:
      - { name: staged_paths, type: array, description: "list of offending paths" }
      - { name: mode,         type: string, description: "the offending git index mode (e.g. 100644)" }
    required: [staged_paths, mode]
```

The catalog is exhaustive at landing. Adding a new event type later requires
(a) a new `event_types[]` entry, (b) a matching Go handler, (c) updated tests
(see Test Scenarios → drift guard).

---

### 2. `schemas/blocker-event.schema.json`

JSON Schema (draft 2020-12, matching the convention in
`bin/frw.d/lib/validate-json.sh:67-70`) that validates a single event instance
on stdin (not the YAML catalog file).

Required top-level keys: `version`, `event_type`, `payload`. Optional:
`target_path`, `step`, `row`. `additionalProperties: false`.

`event_type` is constrained to the closed `enum` of names from
`schemas/blocker-event.yaml` `event_types[].name`. The schema enumerates them
literally (no `oneOf`/`if-then-else` per-type payload validation, to keep the
schema small and to match how `schemas/blocker-taxonomy.schema.json:16-52`
validates structure but defers semantic checks to Go — see
`schemas/blocker-taxonomy.schema.json:1-55`).

Per-event-type payload validation is **performed in Go** (`Guard()` returns an
explicit error if `required` keys are missing). The JSON Schema is structural
only; the Go validator is semantic. This split mirrors the precedent at
`internal/cli/blocker_envelope.go:83-129` (YAML schema is documentation;
runtime validation is hand-coded in `LoadTaxonomy`).

```json
{
  "$schema": "https://json-schema.org/draft/2020-12/schema",
  "title": "Blocker Event",
  "type": "object",
  "required": ["version", "event_type", "payload"],
  "additionalProperties": false,
  "properties": {
    "version":     { "type": "string" },
    "event_type":  { "type": "string", "enum": ["pre_write","pre_bash","stop_ideation","stop_summary_validation","stop_work_check","precommit_paths","precommit_modes"] },
    "target_path": { "type": "string" },
    "step":        { "type": "string", "enum": ["ideate","research","plan","spec","decompose","implement","review"] },
    "row":         { "type": "string" },
    "payload":     { "type": "object" }
  }
}
```

---

### 3. `furrow guard <event-type>` CLI

#### Stdin

A single JSON document conforming to `schemas/blocker-event.schema.json`. The
`event_type` in the JSON **must** match the `<event-type>` positional arg
(otherwise: explicit error, exit 1). The redundant arg lets shell wrappers fail
fast on misrouting before the JSON parses.

#### Stdout

On a triggered emission: a single `BlockerEnvelope` JSON document, encoding-end
newline, formatted via `encoding/json` `SetIndent("", "  ")` to match the
existing pattern at `internal/cli/app.go:192-197`. Schema:
`internal/cli/blocker_envelope.go:35-42`. No wrapper envelope — the
`BlockerEnvelope` is the entire stdout payload (not nested under `data`),
because hooks pipe stdout straight to stderr-or-stdout per host conventions.

On no trigger: zero bytes on stdout.

When the Go validator detects multiple emissions for one event (e.g.,
`precommit_paths` with two offending staged paths), stdout contains a JSON
**array** of `BlockerEnvelope` objects. Hooks consume the array and decide
how to surface (typically: print each `message` to stderr, exit nonzero once).
Single-trigger event types may emit a bare object **or** a one-element array;
hooks must accept both.

#### Stderr

Reserved for invocation errors only (bad JSON, unknown event type, missing
required payload key). Triggered envelopes do **not** write to stderr — that's
the hook shim's job in the host's adapter idiom.

#### Exit codes

| Code | Meaning |
|---|---|
| 0 | Ran cleanly. Stdout is either empty (no trigger) or contains the envelope(s). |
| 1 | Invocation error: bad JSON, unknown event type, missing required key, mismatch between positional arg and `event_type` field. Stderr explains. |
| 2 | (Reserved — host-blocking exit; not used by `furrow guard` itself. The shell helper translates envelope severity to host exit codes.) |

Per the row's locked decision (team-plan.md:42), `furrow guard` does not
itself signal "blocking" via exit code — emission is the signal. The shell
helper `emit_canonical_blocker` (below) inspects the envelope's `severity` /
`confirmation_path` and translates to Claude exit codes (0 = pass, 2 = block).

#### Wiring into `cmd/furrow/main.go` and `internal/cli/app.go`

- `cmd/furrow/main.go:9-12` is unchanged — dispatches via `cli.New(...).Run(...)`.
- `internal/cli/app.go:51-78` `Run()` switch gains a new case `"guard"` that
  routes to `runGuard(args[1:])`, parallel to `case "validate"` at line 68-69.
- `runGuard` lives in a new file `internal/cli/guard.go` (matches the
  one-command-per-file pattern: `validate.go`, `validate_definition.go`,
  `validate_ownership.go`).

#### Help

`furrow guard help` prints usage:

```
furrow guard <event-type>

Reads a normalized blocker event JSON document on stdin and emits zero or
more canonical BlockerEnvelope JSON documents on stdout.

Event types: pre_write, pre_bash, stop_ideation, stop_summary_validation,
             stop_work_check, precommit_paths, precommit_modes
```

---

### 4. Go internal API

Located in `internal/cli/guard.go`. Constructor injection via the existing
`*App` struct (`internal/cli/app.go:13-16`); no package-level state, no `init()`.

```go
// NormalizedEvent matches schemas/blocker-event.schema.json.
type NormalizedEvent struct {
    Version    string                 `json:"version"`
    EventType  string                 `json:"event_type"`
    TargetPath string                 `json:"target_path,omitempty"`
    Step       string                 `json:"step,omitempty"`
    Row        string                 `json:"row,omitempty"`
    Payload    map[string]any         `json:"payload"`
}

// GuardResult is what Guard returns; zero or more envelopes.
// A nil/empty slice means "no condition triggered" (exit 0, empty stdout).
type GuardResult struct {
    Envelopes []BlockerEnvelope
}

// Guard dispatches a normalized event to the registered handler for
// eventType. Returns:
//   - (&GuardResult{Envelopes: nil}, nil) when no condition triggered.
//   - (&GuardResult{Envelopes: [...]}, nil) when one or more codes fired.
//   - (nil, error) on invocation errors (unknown event_type, missing required
//     payload key, downstream loader failures).
//
// The taxonomy is loaded once via LoadTaxonomy() and indexed; missing-code
// emissions panic in test mode (matching blocker_envelope.go:139 semantics).
func Guard(eventType string, evt NormalizedEvent) (*GuardResult, error)

// runGuard is the App-level CLI shim. Exit codes documented above.
func (a *App) runGuard(args []string) int
```

Internally, `Guard` consults a package-level handler registry keyed by
`event_type`:

```go
type eventHandler func(t *Taxonomy, evt NormalizedEvent) ([]BlockerEnvelope, error)

var guardHandlers = map[string]eventHandler{
    "pre_write":               handlePreWrite,
    "pre_bash":                handlePreBash,
    "stop_ideation":           handleStopIdeation,
    "stop_summary_validation": handleStopSummaryValidation,
    "stop_work_check":         handleStopWorkCheck,
    "precommit_paths":         handlePrecommitPaths,
    "precommit_modes":         handlePrecommitModes,
}
```

The map is populated by an `init()` in `guard.go` — this is the **one**
permitted `init()` in the deliverable, justified because the handler set is
closed at compile time and the alternative (constructor parameter) leaks
implementation details into every `*App` caller. Drift-guard test (Scenario F)
asserts every event_type in the YAML has a registry entry.

Per-handler signature is one-method by design: each handler decides whether to
emit (returns empty slice ⇒ no trigger) and which codes. Handlers receive the
loaded `*Taxonomy` so `taxonomy.EmitBlocker(code, interp)` produces the
envelope (`internal/cli/blocker_envelope.go:136-159`).

#### Error-wrapping conventions

Per CLAUDE.md Go conventions and the precedent at `blocker_envelope.go:67,
86, 91, 95`: every error returned from `Guard` and from handlers wraps the
underlying cause with `fmt.Errorf("guard %s: %w", eventType, err)`. The
top-level `runGuard` translates `error` → exit code 1 + stderr line via
`a.fail(...)` in the existing `app.go:171-190` style (but with a non-JSON
default since `furrow guard` writes envelopes, not the standard wrapper).

---

### 5. `bin/frw.d/lib/blocker_emit.sh` — shell helpers

POSIX sh, idempotent source-guard following `validate-json.sh:23-26`. Sourced
by D3 hook shims. Header documents the subprocess invocation pattern (per
team-plan.md:46 hand-off to wave 3).

#### `emit_canonical_blocker(event_type)`

The single canonical translator. Reads stdin (the host's tool-input JSON),
**normalizes** it into a `BlockerEvent` payload appropriate for the named
`event_type`, invokes `furrow guard <event_type>` via subprocess, and forwards
any returned envelope(s) to stderr in human-readable form. Returns the host
exit code per envelope severity.

Contract:

| Aspect | Behavior |
|---|---|
| Args | `$1 = event_type` (one of the seven catalog entries). |
| Stdin | Host tool-input JSON (Claude's `tool_input` shape, or pre-commit's iterated path list — the helper handles both via `event_type` discriminator). |
| Stdout | Empty. (Envelopes go to stderr in shim contract.) |
| Stderr | One human-readable `[furrow:<severity>] <message>` line per envelope. |
| Exit code | 0 if no envelope (or all envelopes are `severity: warn` with `confirmation_path: silent`); 2 if any envelope is `severity: block`; 0 with stderr line otherwise. |
| Side effects | One subprocess to `furrow guard`. No file writes. |

Internally:

1. Read stdin once into `_input`.
2. Translate `_input` + `event_type` to a normalized JSON payload (jq filter
   per event type — small, table-like, keeps shell logic at "translation only").
3. Invoke: `printf '%s' "$_normalized" | go run ./cmd/furrow guard "$event_type"`,
   matching the `go run ./cmd/furrow ...` pattern at
   `bin/frw.d/hooks/ownership-warn.sh:60-61`. (D3 may swap to a built binary
   when `FURROW_BIN` env is set — the helper checks `${FURROW_BIN:-go run ./cmd/furrow}`.)
4. If `furrow guard` exited nonzero, log `[furrow:error] guard invocation failed`
   and return 1 (treat as a hook bug, not a triggered blocker).
5. If stdout is empty: return 0 (no trigger).
6. Parse stdout (object **or** array per stdout contract above) and for each
   envelope, emit `[furrow:<severity>] <message>` to stderr.
7. Return 2 if any envelope has `severity == "block"`; else 0.

#### `parse_tool_input_path()`

Wraps the duplicated `jq -r '.tool_input.file_path // .tool_input.path // ""'`
idiom (audit §2.7 cites six hooks using this). Reads stdin tool-input JSON,
prints the resolved path on stdout.

```sh
parse_tool_input_path() {
  jq -r '.tool_input.file_path // .tool_input.filePath // .tool_input.path // ""' 2>/dev/null
}
```

Used by D3's `pre_write` shims (state-guard, verdict-guard, correction-limit)
to extract the path before passing to `emit_canonical_blocker pre_write`.

#### `parse_tool_input_command()`

Wraps `jq -r '.tool_input.command // ""'`. Used only by `script-guard.sh` per
audit §2.6 ("stdin parsing of `.tool_input.command` is unique to bash-tool
guards — only `script-guard.sh` uses it"). Lands here anyway so future bash
guards (if any) reuse one canonical implementation.

#### `precommit_init()`

Eliminates the 8-line boilerplate at the top of all three pre-commit hooks
(audit §2.3 quality finding: "duplicated verbatim in the other two pre-commit
hooks"). Resolves `_GIT_ROOT` via `git rev-parse --show-toplevel`, sources
`common-minimal.sh`, and stubs `log_warning` / `log_error` if those are
unavailable in the pre-commit context.

```sh
precommit_init() {
  _GIT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || _GIT_ROOT="."
  FURROW_ROOT="${FURROW_ROOT:-$_GIT_ROOT}"
  if [ -f "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh" ]; then
    # shellcheck source=/dev/null
    . "${FURROW_ROOT}/bin/frw.d/lib/common-minimal.sh"
  else
    log_warning() { echo "[furrow:warning] $1" >&2; }
    log_error()   { echo "[furrow:error] $1"   >&2; }
  fi
}
```

#### Composition

D3 hook shims are expected to compose these helpers into the audit's
"three operations only" shape (definition.yaml:55):

```sh
# Example: pre-commit-bakfiles.sh post-migration (≤ 30 lines target)
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"
precommit_init
_paths="$(git diff --cached --name-only --diff-filter=ACMR | grep -E '\.bak$' || true)"
[ -z "$_paths" ] && exit 0
printf '{"staged_paths":%s,"check":"bakfiles"}' \
  "$(printf '%s\n' "$_paths" | jq -R . | jq -s .)" \
  | emit_canonical_blocker precommit_paths
```

This is **illustrative** — the shim itself is D3's deliverable; this spec
guarantees only that the helpers are in place and their contracts hold.

---

## Acceptance Criteria (Refined)

Refined from definition.yaml:36-41. Each criterion is testable; commands or
verification predicates are listed in Test Scenarios.

**AC1.** `schemas/blocker-event.yaml` exists with `version: "1"` at the top
level and an `event_types[]` array containing exactly the seven catalog
entries above (`pre_write`, `pre_bash`, `stop_ideation`,
`stop_summary_validation`, `stop_work_check`, `precommit_paths`,
`precommit_modes`). Each entry has `name`, `description`, `emitted_codes[]`
(non-empty), `payload_keys[]` (non-empty), `required[]` (subset of
`payload_keys[].name`).

**AC2.** `schemas/blocker-event.schema.json` validates a representative
fixture for each of the seven event types (`tests/integration/fixtures/blocker-events/<code>/normalized.json`)
without errors when run through `bin/frw.d/lib/validate-json.sh::validate_json`.

**AC3.** `furrow guard <event-type>` exists as a CLI subcommand wired through
`internal/cli/app.go:51-78` `Run()` switch. Reading a normalized event JSON
on stdin emits a canonical `BlockerEnvelope` JSON on stdout when a condition
triggers; emits empty stdout and exits 0 when no condition triggers; exits 1
with a stderr explanation when invocation is malformed.

**AC4.** Table-driven tests in `internal/cli/guard_test.go` cover at least one
code per blocker category present in the post-D1 taxonomy (state-mutation,
gate, scaffold, summary, ideation). Each test row runs `Guard(eventType, evt)`
and asserts the returned `BlockerEnvelope.Code` matches expectation.

**AC5.** Adding a new entry to `schemas/blocker-event.yaml` `event_types[]`
without registering a corresponding handler in `guardHandlers` fails the
`TestGuardHandlerRegistryParity` test (drift guard).

**AC6.** `bin/frw.d/lib/blocker_emit.sh` exists, is POSIX sh (passes `shellcheck -s sh`),
exports `emit_canonical_blocker`, `parse_tool_input_path`,
`parse_tool_input_command`, `precommit_init` as functions, and is sourceable
without side effects (idempotent source guard per `validate-json.sh:23-26`).

**AC7.** Round-trip integration: piping a normalized event through
`emit_canonical_blocker <event_type>` produces the same `BlockerEnvelope`
JSON on the helper's downstream channel as a direct invocation of
`furrow guard <event_type>` on the same input. (Wire-format parity, no shell
re-implementation.)

---

## Test Scenarios

All Go unit tests live in `internal/cli/guard_test.go` and follow the
table-driven `Test{Thing}_{Condition}_{ExpectedResult}` naming used by the
existing suite (e.g., `blocker_envelope_test.go:26, 45`).

### Scenario A: `furrow guard pre_write` reads normalized JSON, emits envelope

- **Verifies**: AC3, AC4
- **WHEN**: Stdin = `{"version":"1","event_type":"pre_write","target_path":".furrow/rows/foo/state.json","payload":{"target_path":".furrow/rows/foo/state.json"}}`
- **THEN**: Stdout is a single `BlockerEnvelope` JSON document with
  `code == "state_json_direct_write"`, `severity == "block"`, `category == "state-mutation"`,
  `message` matching the post-D1 template. Exit code 0.
- **Verification**: `printf '...' | go run ./cmd/furrow guard pre_write | jq -e '.code == "state_json_direct_write"'`

### Scenario B: unknown event type returns explicit error

- **Verifies**: AC3 (invocation error path)
- **WHEN**: `furrow guard not_a_real_type` invoked with valid-shape JSON whose
  `event_type` is `"not_a_real_type"`.
- **THEN**: Stdout is empty. Stderr contains a line beginning with `guard not_a_real_type:`
  citing "unknown event type". Exit code 1.
- **Verification**: Go test `TestGuard_UnknownEventType_ReturnsError` table row:
  asserts `err != nil`, `errors.Is(err, ErrUnknownEventType)`, `result == nil`.

### Scenario C: trigger condition not met → empty stdout, exit 0

- **Verifies**: AC3 (clean-pass path, parity-test correctness)
- **WHEN**: Stdin = `pre_write` event with `target_path = "README.md"` (does
  not match any `pre_write` handler's path predicate).
- **THEN**: Stdout is empty (zero bytes). Stderr is empty. Exit code 0.
- **Verification**: `out=$(printf '...' | go run ./cmd/furrow guard pre_write); [ -z "$out" ] && [ $? -eq 0 ]`.
  Go test: `TestGuard_PreWrite_NoMatch_EmptyResult` asserts `result.Envelopes` is nil/empty, `err == nil`.

### Scenario D: shell `emit_canonical_blocker` round-trips through Go

- **Verifies**: AC6, AC7
- **WHEN**: A `pre_write` host event JSON is piped to
  `emit_canonical_blocker pre_write` from a test harness shim.
- **THEN**: The function's stderr contains `[furrow:block] state.json is Furrow-exclusive — use frw update-state`
  (or the post-D1 canonical message), exit code 2, no stdout output.
- **Verification**: `tests/integration/test-blocker-emit-helper.sh` (lives in D2's
  test surface, not D4's): sources `bin/frw.d/lib/blocker_emit.sh`, pipes a
  fixture, asserts captured stderr and exit code via `assert_eq`. Bypass the
  network: set `FURROW_BIN="$(go build -o /tmp/furrow-test ./cmd/furrow && echo /tmp/furrow-test)"`
  to avoid `go run` overhead in the loop.

### Scenario E: schema validates each event type's representative fixture

- **Verifies**: AC2
- **WHEN**: For each of the seven catalog event types, a representative
  normalized event JSON document is fed to
  `validate_json schemas/blocker-event.schema.json <fixture>`.
- **THEN**: All seven invocations return 0 (or the SKIP path per
  `validate-json.sh:88-89`). Any invalid fixture (missing required key, wrong
  enum value) returns 1 with a `Schema error at ...` stderr line.
- **Verification**: `tests/integration/test-blocker-event-schema.sh` (D2 test
  surface — D4 is per-code parity, not schema validation). Loops the fixtures,
  runs `validate_json`, asserts exit codes.

### Scenario F: drift guard — adding event_type to schema without Go handler fails tests

- **Verifies**: AC5
- **WHEN**: A new entry is added to `schemas/blocker-event.yaml` `event_types[]`
  (e.g., simulated by appending to a test-only YAML in `internal/cli/testdata/`)
  but the corresponding entry is **not** added to `guardHandlers`.
- **THEN**: `TestGuardHandlerRegistryParity` fails with
  `event_type "<new>": no registered handler in guardHandlers`.
- **Verification**: Go test reads `schemas/blocker-event.yaml` (path resolved
  via `findFurrowRoot()` per `blocker_envelope.go:65-69`), iterates
  `event_types[].name`, asserts each is a key in `guardHandlers`. The reverse
  direction (handler with no schema entry) is also asserted — it would be
  dead code.

### Scenario G: Stop-ideation handler emits canonical envelope with placeholder interpolation

- **Verifies**: AC4 (covers the `ideation` category)
- **WHEN**: Stdin = `stop_ideation` event with `payload.row = "test-row"`,
  test harness pre-populates `.furrow/rows/test-row/definition.yaml` missing
  the `gate_policy` field.
- **THEN**: Stdout is a `BlockerEnvelope` with
  `code == "ideation_incomplete_definition_fields"`, `message` containing the
  list of missing fields with placeholders resolved (no `{missing}` literal).
- **Verification**: Go table-driven test in `guard_test.go` with a temp-dir
  furrow root via `t.TempDir()` and `t.Setenv("FURROW_ROOT", ...)`.

### Scenario H: precommit_paths emits one envelope per offending path (array stdout)

- **Verifies**: AC3 (multi-emit path)
- **WHEN**: `precommit_paths` event with `payload.staged_paths = ["bin/foo.bak","bin/bar.bak"]`,
  `payload.check = "bakfiles"`.
- **THEN**: Stdout is a JSON **array** with two `BlockerEnvelope` objects,
  each `code == "precommit_install_artifact_staged"`, `message` interpolating
  the respective path. Exit code 0 (the helper, not `furrow guard`, decides
  the host's blocking exit).
- **Verification**: Go test asserts `len(result.Envelopes) == 2`, each
  envelope's message contains the expected path substring.

---

## Implementation Notes

### Sequencing within D2

1. **Schema first** — land `schemas/blocker-event.yaml` and `schemas/blocker-event.schema.json`
   as data. No code consumes them yet, but they are inspectable artefacts that
   D3/D4 fixtures reference. Spec-driven: the YAML is the contract.

2. **Schema validator wiring** — add a unit test in `internal/cli/guard_test.go`
   that loads `schemas/blocker-event.yaml` via `gopkg.in/yaml.v3` (already a
   dep — `blocker_envelope.go:12`) and asserts it parses into a typed struct.
   Reuse `validate_json` (`bin/frw.d/lib/validate-json.sh`) only at the
   integration-test layer (Scenario E).

3. **Go entry point skeleton** — wire `case "guard"` in `app.go:51-78` to a
   stub `runGuard` that returns "not implemented" error. Add `cmd/furrow help`
   line. Verify dispatch with a smoke test (matches the smoke-test pattern
   in `app_test.go`).

4. **Table tests authored before handlers** (TDD per CLAUDE.md): write
   `guard_test.go` with table-driven cases for every event type using fixture
   inputs and expected `code` outputs. All red.

5. **Handlers implemented one event type at a time** to make table tests pass.
   Order: `pre_write` (3 codes, exercises shared dispatch) → `pre_bash`
   (1 code, simplest) → `stop_*` family (need taxonomy + filesystem context) →
   `precommit_*` (multi-emit path).

6. **`bin/frw.d/lib/blocker_emit.sh`** authored last, after Go side is
   green. Helper-level test (Scenario D) lives in `tests/integration/`
   alongside D4's fixtures — auto-discovered per `tests/integration/run-all.sh`
   convention (synthesis.md headline finding 6).

7. **Integration of one hook** as proof: pick `state-guard.sh` (smallest,
   mechanical per audit §2.7) and rewrite it to source `blocker_emit.sh` +
   call `emit_canonical_blocker pre_write`. **Land this rewrite in D3, not D2** —
   D2's responsibility ends at "the helpers exist and round-trip works against
   a fixture". Doing it here would muddy file ownership (definition.yaml:42-48
   gives D2 ownership of `bin/frw.d/lib/**`, not `bin/frw.d/hooks/**`).

### Reuse `internal/cli/app.go` dispatch pattern

The `Run()` switch (`app.go:51-78`) is the canonical command-dispatch
mechanism. Add `case "guard"` next to `case "validate"` (line 68-69) — both
are top-level commands consuming structured input. Do **not** introduce a
sub-group (`furrow guard run` etc.); the row's locked decision specifies a
flat `furrow guard <event-type>` shape (team-plan.md:42) and stub-group
(`runStubGroup`) is reserved for unimplemented surfaces (`app.go:60-61`).

### Subprocess invocation matching `ownership-warn.sh:60-61`

The shell helper invokes Go via `go run ./cmd/furrow guard "$event_type"`
exactly as `ownership-warn.sh:61` invokes `go run ./cmd/furrow validate
ownership`. This includes the `cd "${FURROW_ROOT}"` step (line 60) so the
working directory is the project root regardless of the hook's CWD. The
helper supports a `FURROW_BIN` env override (e.g., `FURROW_BIN=/tmp/furrow`)
for test-suite speed; the override falls through to `go run` when unset.

### `blocker_emit.sh` is POSIX sh

No bashisms (no arrays except via `set --`, no `[[ ]]`, no `$(())` arithmetic
where `expr` suffices, no `local` — uses underscore-prefixed variable names
like the rest of `common-minimal.sh:24-37`). Validated by `shellcheck -s sh
bin/frw.d/lib/blocker_emit.sh`. Source-guard idiom per
`validate-json.sh:23-26`.

### Avoiding `go run` overhead in tests

Per Scenario D, integration tests build a binary once via `go build -o
/tmp/furrow-test ./cmd/furrow` (in the test setup) and pass it via
`FURROW_BIN`. This drops per-invocation latency from ~1s to ~10ms. The
`run-all.sh` driver should set this once before iterating fixtures.

### Error-wrapping discipline

All errors returned from `Guard` and from handlers wrap with
`fmt.Errorf("guard %s: %w", eventType, err)` (CLAUDE.md Go conventions). The
top-level `runGuard` translates `error` → `cliError{exit: 1, code:
"guard_error", message: err.Error()}` and writes the message to stderr. No
`%v` swallowing.

### Structured logging via `slog`

Internal handlers that have multiple decision points (e.g., `stop_summary_validation`
walks required-sections) emit `slog.Debug` lines for observability.
`slog.Default()` is used; no custom handler. Lines are tagged with
`event_type` and `row` attributes.

### No new dependencies

Per the row's broader constraint and `blocker_envelope.go`'s "no-new-deps"
note (line 56): use only stdlib + existing `gopkg.in/yaml.v3`. JSON Schema
validation (Scenario E) reuses the existing `validate-json.sh` Python shim;
no Go-side schema validator is introduced. (Scope of the JSON Schema is
documentation + integration-test gate, not runtime validation.)

### One permitted `init()`

The `guardHandlers` registry uses `init()` to populate a map from named
handlers. Justified per CLAUDE.md "init() requires explicit justification":
the handler set is closed at compile time, the alternative (passing a map
into every call site) leaks implementation detail, and the drift-guard test
(Scenario F) catches missed registrations. Documented inline in `guard.go`.

---

## Dependencies

### Hard prerequisites

- **D1 `canonical-blocker-taxonomy` must complete first.** D2 emits envelopes
  whose `code` strings must already exist in `schemas/blocker-taxonomy.yaml`.
  Specifically, the new codes named in `research/hook-audit.md` §2 and §5
  (`state_json_direct_write`, `verdict_direct_write`, `correction_limit_reached`,
  `script_guard_internal_invocation`, `ideation_incomplete_definition_fields`,
  `summary_section_missing`, `summary_section_empty`, `state_validation_failed_warn`,
  `summary_section_missing_warn`, `summary_section_empty_warn`,
  `precommit_install_artifact_staged`, `precommit_typechange_to_symlink`,
  `precommit_script_mode_invalid`) must all be present. Without them,
  `taxonomy.EmitBlocker(...)` panics in test mode (`blocker_envelope.go:139-141`).
- **Canonical `BlockerEnvelope` shape settled by D1** (`blocker_envelope.go:35-42`).
  D2 emits the existing struct verbatim; no shape changes here.

### Existing infrastructure D2 consumes (no modification)

- `internal/cli/blocker_envelope.go` — `Taxonomy`, `BlockerEnvelope`,
  `LoadTaxonomy()`, `EmitBlocker()` (lines 27-159).
- `internal/cli/app.go` — `App` struct + `Run()` dispatch (lines 13-78);
  D2 adds one switch case.
- `cmd/furrow/main.go` — entry point (lines 9-12); unchanged.
- `bin/frw.d/lib/validate-json.sh` — Python-backed JSON Schema validator;
  used by integration tests in Scenario E (lines 28-92).
- `bin/frw.d/lib/common-minimal.sh` — sourced by `precommit_init` if
  available (lines 9-15 for `log_warning`/`log_error`).
- `gopkg.in/yaml.v3` — already a module dep per `blocker_envelope.go:12`.

### Downstream consumers (D3, D4 — D2 must hand off cleanly)

- **D3 `hook-migration-and-quality-audit`** sources `bin/frw.d/lib/blocker_emit.sh`
  and replaces 10 hook bodies with three-operation shims (definition.yaml:55).
  Hand-off requires: helpers exported, subprocess invocation pattern documented
  in the helper's header comment, fixture per event type available for D3 to
  validate against during migration.
- **D4 `coverage-and-parity-tests`** consumes `furrow guard` directly
  (`tests/integration/test-blocker-coverage.sh` per definition.yaml:69) and
  through hook shims (`test-blocker-parity.sh` per definition.yaml:70-71).
  Hand-off requires: every code in `schemas/blocker-taxonomy.yaml` is
  reachable via at least one `event_type`'s `emitted_codes[]`, and each
  `event_type` has a fixture set in `tests/integration/fixtures/blocker-events/<code>/`.

### No-dependency on Pi adapter

D2 produces only the canonical envelope shape that the Pi adapter already
consumes (post-D1). No Pi-side changes here. Pi-shape event fixtures are D4's
concern (definition.yaml:70).
