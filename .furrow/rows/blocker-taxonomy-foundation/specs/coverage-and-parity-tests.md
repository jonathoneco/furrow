# Spec: coverage-and-parity-tests

> See `specs/shared-contracts.md` for cross-cutting decisions; that document overrides any conflicting detail here.

Row: `blocker-taxonomy-foundation`
Wave: 4 (final integration deliverable)
Specialist: test-engineer
Depends on: D1 (`canonical-blocker-taxonomy`), D2 (`normalized-blocker-event-and-go-emission-path`), D3 (`hook-migration-and-quality-audit`)

This deliverable is the durable anti-drift mechanism for the row. It produces
two integration tests, a per-code fixture tree, and a Pi-side test driver.
The tests assert (a) every taxonomy code has a working Go-emission path, (b)
every migrated hook shim produces an envelope identical to the Pi adapter's
envelope for the same logical event, and (c) no shim has silently faked
canonical output to mimic the Go backend.

---

## Interface Contract

### `tests/integration/test-blocker-coverage.sh`

- **Shebang**: `#!/bin/bash` (sources `helpers.sh` which is bash-specific).
- **Sources**: `tests/integration/helpers.sh` for `setup_test_env`,
  `assert_json_field`, `assert_output_contains`, `assert_file_exists`,
  `print_summary`. Optionally `lib/sandbox.sh` via `setup_sandbox` if it
  needs to mutate filesystem state under `$FURROW_ROOT`; first cut runs
  read-only against the live checkout (no setup_sandbox) and uses
  `$(mktemp -d)` only for envelope-output capture.
- **What it walks**:
  1. Enumerate every code in `schemas/blocker-taxonomy.yaml` via
     `yq '.[].code' schemas/blocker-taxonomy.yaml`.
  2. For each code, assert
     `tests/integration/fixtures/blocker-events/<code>/normalized.json` and
     `expected-envelope.json` exist.
  3. Pipe `normalized.json` to `go run ./cmd/furrow guard <event-type>
     --json` (the D2 entry point), capture stdout to a temp file.
  4. Use `assert_json_field` to assert `.code`, `.category`, `.severity`,
     `.confirmation_path` of the captured output match the expected
     envelope.
  5. Skip any code listed in `DEFERRED_CODES` (literal constant at the top
     of the script — operational mirror of the D3 audit's deferral
     decision); print `SKIP: <code> (reason: deferred per audit)` to
     stdout.
- **Exit code semantics**: exit 0 iff `print_summary` sees
  `TESTS_FAILED=0`; exit 1 otherwise. The script's own structural
  prerequisites (taxonomy file readable, `yq`/`jq`/`go` on PATH) fail
  fast with a single `FAIL:` line and exit 1.
- **Cleanup**: trap on EXIT/INT/TERM removes the per-test capture dir
  (`$(mktemp -d)`); no live worktree state is mutated, so `run-all.sh`'s
  post-check is satisfied automatically.

### `tests/integration/test-blocker-parity.sh`

- **Shebang**: `#!/bin/bash`.
- **Sources**: `helpers.sh` (same assertion surface).
- **What it walks**:
  1. Enumerate every migrated hook script under
     `bin/frw.d/hooks/<hook>.sh` (D3's post-migration shim list, derived
     from `bin/frw.d/hooks/*.sh` minus the deleted `gate-check.sh` minus
     known non-emitters [`append-learning.sh`, `auto-install.sh`,
     `post-compact.sh`] minus already-canonical
     [`validate-definition.sh`, `ownership-warn.sh`]).
  2. For each migrated hook, the script knows the code(s) it emits
     (lookup via a small mapping table at the top of the parity test, or
     via `grep` of `furrow guard <event-type>` invocations in the shim
     body — see "Implementation Notes"). For each `(hook, code)` pair:
     - Pipe `tests/integration/fixtures/blocker-events/<code>/claude.json`
       to `bash -c '. <hook>.sh; <hook_function>'` (matching the
       precedent at `test-ownership-warn-hook.sh:53`). Capture stdout +
       exit code.
     - Run the Pi-side test driver
       (`adapters/pi/test-driver-blocker-parity.ts`) with
       `tests/integration/fixtures/blocker-events/<code>/pi.json` as input;
       it imports `validate-actions.ts` and emits an envelope on stdout.
     - Use `jq -S` to canonicalize both envelopes; assert byte-for-byte
       equality with the contents of `expected-envelope.json` (also
       `jq -S` canonicalized).
  3. Run two anti-cheat assertions before the per-code loop (see
     "Test Scenarios" below): subprocess-invocation assertion and
     emit-site inventory assertion.
  4. Skip codes listed in `DEFERRED_CODES` with a logged reason.
- **Exit code semantics**: same as coverage test — `print_summary` is
  the single exit point. Anti-cheat assertion failures count as test
  failures (not structural failures); they accrue into `TESTS_FAILED`.
- **Cleanup**: same trap pattern. The Pi driver writes only to a temp
  dir under `$(mktemp -d)`. Bun is required (`bun run`); if missing,
  the test fails with a clear diagnostic.

### Anti-cheat assertion (1) — subprocess invocation

For each migrated hook `<hook>.sh`:

- Assert that the shim source contains either `furrow guard` or
  `go run ./cmd/furrow` (`grep -q -E 'furrow guard|go run \./cmd/furrow'
  <hook>.sh`). Failure means the shim does not invoke the Go backend
  via subprocess at all.
- Assert that the shim source does NOT contain a hard-coded canonical
  envelope literal: `! grep -q -E '"code"\s*:\s*"' <hook>.sh`. Failure
  means a shim is hand-rolling a JSON envelope and could pass parity by
  mimicking Go output.

(Optional reinforcement: a wrapper-interception variant — set
`PATH=$TMP/wrapper:$PATH` where `$TMP/wrapper/go` is a stub recording its
argv — is described in "Implementation Notes" as a follow-up if static
grep proves insufficient. Not required for v1.)

### Anti-cheat assertion (2) — emit-site inventory gate

Independent of per-code coverage:

- Build the migrated-shim list from `bin/frw.d/hooks/*.sh`, applying the
  exclusion set above. This is a list of **shim files**, not codes.
- For each shim, derive the set of emitted codes by `grep`ping for
  `furrow guard <event-type>` invocations and looking up
  `<event-type>` in `schemas/blocker-event.yaml` (or via a sidecar
  mapping table). For each such code, assert that
  `tests/integration/fixtures/blocker-events/<code>/{claude.json,
  pi.json, expected-envelope.json}` all exist.
- Failure mode: if any shim emits a code whose fixture set is incomplete
  or absent, the test fails with `FAIL: shim <hook>.sh emits code <code>
  but fixture set under tests/integration/fixtures/blocker-events/<code>/
  is incomplete`. This catches the case where a new shim is added
  without parity coverage — a regression class that pure per-code
  coverage misses.

### Fixture file format spec

Each `tests/integration/fixtures/blocker-events/<code>/` directory contains
exactly four files:

#### `normalized.json` — backend input

A JSON document conforming to `schemas/blocker-event.schema.json` (the D2
schema). Required fields:

```json
{
  "version": "1",
  "event_type": "<event-type-from-schema>",
  "target_path": "<absolute-or-row-relative-path>",
  "step": "<current-step>",
  "row": "<row-name>",
  "payload": { /* event-type-specific fields */ }
}
```

Consumed by the coverage test as stdin to `furrow guard`.

#### `claude.json` — Claude `PreToolUse` event

The shape that Claude Code's hook engine pipes to a hook script's stdin.
Minimal example shape (reverse-engineered from the existing hook handlers
that read `tool_input.file_path` etc.):

```json
{
  "hook_event_name": "PreToolUse",
  "tool_name": "Edit",
  "tool_input": {
    "file_path": "<absolute-path>",
    "content": "<optional>"
  },
  "session_id": "<test-session-id>",
  "transcript_path": "<unused-in-tests>",
  "cwd": "<absolute-cwd>"
}
```

Per-code variants vary in `tool_name` and `tool_input` shape — e.g.
`pre-commit-bakfiles` codes use `tool_name: "Bash"` with a `command`
field. The fixture must match the natural input shape that the
corresponding migrated hook expects.

Consumed by the parity test as stdin to the migrated hook shim.

#### `pi.json` — Pi `tool_call` event

The shape Pi's runtime delivers to a `tool_call` handler:

```json
{
  "toolName": "edit",
  "input": {
    "path": "<absolute-path>",
    "content": "<optional>"
  }
}
```

(Per `validate-actions.ts:60-81` and the research note at
`research/status-callers-and-pi-shim.md` Section B.3.) Consumed by the
Pi-side test driver. For codes whose Pi-side `tool_call` handler does
not yet exist (per research B.6 — most new codes), the fixture defines
the **aspirational contract** that a future Pi handler will satisfy.
The driver runs the existing pure factoring (`validate-actions.ts`
exports) for codes that already have Pi handlers; for codes that don't,
the driver emits the canonical envelope by invoking `furrow guard
<event-type>` directly with a normalized event derived from `pi.json` —
proving that the Pi-shape input round-trips through the same Go path
the Claude-shape input does.

#### `expected-envelope.json` — canonical BlockerEnvelope

The expected output, conforming to
`schemas/blocker-taxonomy.schema.json`'s envelope shape:

```json
{
  "code": "<code>",
  "category": "<category>",
  "severity": "block | warn | info",
  "message": "<resolved-message-with-placeholders-filled>",
  "remediation_hint": "<non-empty-string>",
  "confirmation_path": "block | warn-with-confirm | silent"
}
```

Both tests `jq -S` canonicalize this file before comparison so key
ordering differences do not produce false negatives.

### Pi-side test driver

`adapters/pi/test-driver-blocker-parity.ts`:

- Bun-runnable single file (no new build step). Invoked as
  `bun run adapters/pi/test-driver-blocker-parity.ts <pi-fixture-json>`.
- Reads the fixture from the path argument (or stdin if argument is `-`).
- For codes whose existing Pi handler factoring covers the event
  (`runDefinitionValidationHandler`, `runOwnershipWarnHandler`):
  imports the handler from `validate-actions.ts`, injects a real
  `runFurrowJson` that shells out to `go run ./cmd/furrow ... --json`,
  collects the resulting envelope, prints `JSON.stringify(envelope)` to
  stdout.
- For codes without an existing Pi handler: derives a normalized event
  from the Pi fixture (one branch per `toolName`) and shells out to
  `go run ./cmd/furrow guard <event-type>` directly, forwarding stdout.
- Exit code 0 on successful envelope emission; exit 1 on subprocess
  failure or unparseable input. The bash test asserts on stdout
  content, not exit code (an envelope is meaningful even if the inner
  Go command exited non-zero — the bash test diffs the envelope, not
  the exit code).
- **No new shipped Pi binary**; the driver is test-only and lives next
  to `furrow.test.ts` to share the existing Bun setup. `package.json`
  may grow a `test:driver` script entry but no new dependencies.

---

## Acceptance Criteria (Refined)

Each AC below is a refinement of `definition.yaml` lines 68-74 (D4
acceptance criteria). Each is testable with a concrete pass/fail
condition.

### AC-1: Per-code coverage

- **Given** every code listed in `schemas/blocker-taxonomy.yaml`
- **When** `tests/integration/test-blocker-coverage.sh` runs
- **Then** for each code (excluding `$DEFERRED_CODES`),
  `go run ./cmd/furrow guard <event-type> --json` reading
  `fixtures/blocker-events/<code>/normalized.json` produces stdout that
  passes `assert_json_field` checks for `.code`, `.severity`,
  `.category`, and `.confirmation_path` against
  `fixtures/blocker-events/<code>/expected-envelope.json`.
- **Failure mode**: a missing fixture file is an explicit `FAIL:
  fixture missing for code <code>` line; an envelope mismatch is an
  explicit `FAIL: envelope <jq-expr> mismatch for code <code>`.

### AC-2: Coverage failure surfaces code name

- **Given** an empty or malformed
  `fixtures/blocker-events/<code>/normalized.json`
- **When** `test-blocker-coverage.sh` runs
- **Then** the failure line includes the literal `<code>` string so
  reviewers can locate the regression without re-reading the script.

### AC-3: Per-code parity

- **Given** every migrated code (i.e., not in `$DEFERRED_CODES`)
- **When** `tests/integration/test-blocker-parity.sh` runs
- **Then** for each `(migrated hook, code)` pair, the Claude shim's
  envelope and the Pi driver's envelope, both `jq -S` canonicalized,
  are byte-for-byte identical, and both are byte-for-byte identical to
  `expected-envelope.json` (also `jq -S` canonicalized).

### AC-4: Anti-cheat (subprocess invocation)

- **Given** the migrated-hook list (built from `bin/frw.d/hooks/*.sh`
  minus the exclusion set)
- **When** `test-blocker-parity.sh` runs
- **Then** for every migrated hook, `grep -q -E 'furrow guard|go run
  \./cmd/furrow' <hook>.sh` exits 0 AND `grep -q -E '"code"\s*:\s*"'
  <hook>.sh` exits 1 (no hand-rolled envelope literal).

### AC-5: Anti-cheat (emit-site inventory gate)

- **Given** the migrated-hook list
- **When** `test-blocker-parity.sh` runs
- **Then** every code that appears as the argument to a `furrow guard`
  invocation in any migrated shim has a complete fixture set
  (`claude.json`, `pi.json`, `expected-envelope.json` all present and
  non-empty). This is a separate assertion from per-code coverage —
  it catches the case where a shim is added but its fixture set is
  not, even if the code already exists in the taxonomy with a
  fixture set covering the coverage test.

### AC-6: Deferred-code skipping

- **Given** the `DEFERRED_CODES` constant at the top of each test
  script (e.g., `DEFERRED_CODES="script_guard_complex
  work_check_updated_at"` if D3's fallback fires for those hooks)
- **When** either test runs
- **Then** each deferred code is logged as `SKIP: <code> (reason:
  deferred per audit)` and contributes neither to `TESTS_PASSED` nor
  `TESTS_FAILED`. The skip list maps 1:1 to the named hooks in
  `research/hook-audit-final.md`'s deferral section.

### AC-7: Pi-side driver round-trip

- **Given** any non-deferred code's `pi.json` fixture
- **When** `bun run adapters/pi/test-driver-blocker-parity.ts <pi.json>`
  is invoked
- **Then** stdout is a single JSON document validating against
  `schemas/blocker-taxonomy.schema.json`'s envelope shape, and equal
  (under `jq -S`) to `expected-envelope.json` for the same code.

### AC-8: Auto-discovery

- **"Auto-discovered"** means: the new test files match the glob
  `tests/integration/test-*.sh` evaluated by
  `tests/integration/run-all.sh:32` (`for _test in
  "${SCRIPT_DIR}"/test-*.sh`).
- **Given** the new files at
  `tests/integration/test-blocker-coverage.sh` and
  `tests/integration/test-blocker-parity.sh`, both executable (`chmod
  +x`)
- **When** `tests/integration/run-all.sh` runs
- **Then** both files appear in the per-test `>>> <name>` banner and
  contribute to the totals line. No edit to `run-all.sh`, no Makefile,
  no CI script change is required. A `git status --porcelain`
  invocation before and after the suite is empty (per
  `run-all.sh:21-25,51-56`).

### AC-9: New code without fixture fails coverage

- **Given** a hypothetical new code `foo_bar` is added to
  `schemas/blocker-taxonomy.yaml`
- **When** `test-blocker-coverage.sh` runs against the unchanged
  fixture tree
- **Then** the test exits non-zero with `FAIL: fixture missing for
  code foo_bar`. (Verifiable in a CI pre-merge check by a synthetic
  taxonomy mutation; not part of the standing test suite, but the
  failure mode must be stable.)

### AC-10: New emit-site without parity coverage fails parity

- **Given** a new shim is added under `bin/frw.d/hooks/` that calls
  `furrow guard <event-type>` for code `baz_qux`, but no fixture
  directory `fixtures/blocker-events/baz_qux/` exists
- **When** `test-blocker-parity.sh` runs
- **Then** the test exits non-zero via the emit-site inventory gate
  (AC-5) with `FAIL: shim <new-hook>.sh emits code baz_qux but
  fixture set under fixtures/blocker-events/baz_qux/ is incomplete`.

---

## Test Scenarios

The seven scenarios below operationalize the ACs above. Each is a
self-contained verification step run by the test scripts.

### Scenario: coverage-every-code-has-fixture
- **Verifies**: AC-1, AC-2
- **WHEN**: `test-blocker-coverage.sh` enumerates every code in
  `schemas/blocker-taxonomy.yaml`
- **THEN**: each non-deferred code has a complete fixture directory
  under `tests/integration/fixtures/blocker-events/<code>/` with all
  four files present and non-empty
- **Verification**: `assert_file_exists "<code> normalized.json"
  fixtures/blocker-events/<code>/normalized.json` (×4 per code)

### Scenario: coverage-missing-fixture-fails-with-code-name
- **Verifies**: AC-2, AC-9
- **WHEN**: a synthetic mutation removes
  `fixtures/blocker-events/<code>/normalized.json`
- **THEN**: `test-blocker-coverage.sh` fails with a `FAIL:` line
  containing the literal `<code>` string
- **Verification**: manual one-off check during implementation; the
  standing suite runs against the complete fixture tree. The failure
  format string is `assert_file_exists "<code> normalized.json"
  <path>` so the substring presence is guaranteed by `helpers.sh`'s
  `assert_file_exists` implementation
  (`helpers.sh:147-159`).

### Scenario: parity-claude-and-pi-produce-identical-envelope
- **Verifies**: AC-3
- **WHEN**: `test-blocker-parity.sh` runs each `(hook, code)` pair
  through both shim paths
- **THEN**: `diff <(jq -S . claude-out) <(jq -S . pi-out)` is empty,
  and both are equal to `jq -S . expected-envelope.json`
- **Verification**: shell `diff` invocation; failure prints the
  unified diff to stderr for the reviewer.

### Scenario: parity-anti-cheat-shim-without-furrow-guard-fails
- **Verifies**: AC-4
- **WHEN**: `test-blocker-parity.sh` runs the subprocess-invocation
  assertion against every migrated shim
- **THEN**: a synthetic shim with no `furrow guard` invocation (or
  containing a literal `"code":` JSON fragment) fails the assertion
  with a clear `FAIL:` line naming the offending shim
- **Verification**: `grep -q -E 'furrow guard|go run \./cmd/furrow'
  <hook>.sh` is the canonical check; second `grep -q -E
  '"code"\s*:\s*"' <hook>.sh` (inverted) is the literal-envelope
  check. Both run via `assert_file_contains` /
  `assert_file_not_contains` from `helpers.sh:177-204`.

### Scenario: parity-emit-site-inventory-gate-catches-missing-fixture
- **Verifies**: AC-5, AC-10
- **WHEN**: `test-blocker-parity.sh` walks every migrated shim and
  derives the set of emitted codes
- **THEN**: any code emitted by a shim whose fixture set is missing
  any of the three required files (`claude.json`, `pi.json`,
  `expected-envelope.json`) produces a `FAIL:` line; per-code
  coverage might not catch this if the code is also in the taxonomy
  with a complete fixture set but a separate shim emits it differently
- **Verification**: shell loop over `bin/frw.d/hooks/*.sh` →
  `grep -oE 'furrow guard [a-z_-]+'` → unique codes → `assert_file_exists`
  per file.

### Scenario: deferred-code-skipping-with-logged-reason
- **Verifies**: AC-6
- **WHEN**: `DEFERRED_CODES="<code>"` is set and either test runs
- **THEN**: stdout contains a `SKIP: <code> (reason: deferred per
  audit)` line and `TESTS_PASSED + TESTS_FAILED` excludes the deferred
  code's would-be assertions
- **Verification**: a literal `case "$code" in $DEFERRED_CODES) ... ;;`
  branch at the top of the per-code loop in each test, matched against
  the audit report (`research/hook-audit-final.md`).

### Scenario: pi-driver-produces-envelope-matching-expected
- **Verifies**: AC-7
- **WHEN**: `bun run adapters/pi/test-driver-blocker-parity.ts
  fixtures/blocker-events/<code>/pi.json` runs for each non-deferred
  code
- **THEN**: stdout is a single JSON document, `jq -S` canonicalized
  byte-equal to `jq -S` canonicalized
  `fixtures/blocker-events/<code>/expected-envelope.json`
- **Verification**: shell `diff <(bun run ... | jq -S .) <(jq -S .
  expected-envelope.json)`; stderr captures any Bun runtime errors,
  surfaced via `assert_output_contains` in the parity test on the
  driver's combined stdout+stderr.

---

## Implementation Notes

### Reuse existing test infrastructure

- **Assertion library**: source `helpers.sh` from
  `${SCRIPT_DIR}` (matching the precedent at `test-rws.sh:5-7`). Use
  `assert_json_field` (`helpers.sh:207-220`) for envelope-field
  assertions, `assert_output_contains` (`helpers.sh:238-250`) for
  diagnostic strings, `assert_file_exists` /
  `assert_file_not_contains` (`helpers.sh:147-204`) for fixture and
  anti-cheat checks. Call `print_summary` (`helpers.sh:283-292`) as
  the single exit point.
- **Sandbox isolation**: not required for v1 because the tests do not
  mutate any live state — they only read taxonomy + fixtures and pipe
  to a Go subprocess that writes only to its own stdout. If a future
  test variant needs `$FURROW_ROOT` isolation,
  `setup_sandbox`/`assert_no_worktree_mutation` from
  `lib/sandbox.sh:73-185` are the canonical surface.
- **Per-test cleanup**: each test script's own trap (matching
  `setup_test_env`'s pattern at `helpers.sh:76`) removes any
  `$(mktemp -d)` directory it creates. The suite-wide
  `git status --porcelain` post-check at `run-all.sh:51-56` enforces
  this.

### Go invocation

- Canonical pattern is `go run ./cmd/furrow <subcommand>` per
  `bin/frw.d/hooks/ownership-warn.sh:61` (the only existing precedent
  for shelling out to the Go backend from a hook). For the D2 entry
  point: `go run ./cmd/furrow guard <event-type> --json`. Both tests
  must `cd "${PROJECT_ROOT}"` before invoking `go run` so the module
  resolves; this is identical to `test-ownership-warn-hook.sh:50`'s
  `cd "${PROJECT_ROOT}"` before invoking the hook.
- Do not pre-compile `bin/furrow`; rely on `go run` matching the
  established convention. CI build-step ordering is avoided.

### Pi driver — minimal scope

- The driver is fixture-replay only. Do not author new Pi `tool_call`
  handlers in this row (research B.6 — that is
  `pi-tool-call-canonical-schema-and-surface-audit`'s scope).
- For the two existing pure handlers
  (`runDefinitionValidationHandler`, `runOwnershipWarnHandler` in
  `validate-actions.ts:60-81`), import directly and inject
  `runFurrowJson` that shells out to `go run ./cmd/furrow validate
  ... --json`. Capture the resulting envelope from
  `data.errors[0]`/`data.envelope` per
  `validate-actions.ts:11-18`.
- For codes without an existing Pi handler: the driver derives a
  normalized event from the Pi fixture (a small switch on `toolName`)
  and invokes `furrow guard` directly. This is equivalent to "the Pi
  adapter does not yet intercept this event, so the parity test
  asserts that if/when it does, the envelope produced will match the
  Claude path" — i.e., the test enforces the contract for future Pi
  extension. Document this branching at the top of the driver source
  with a comment.

### Fixture authoring — mechanical, not specified here

Fixture authoring is left to the implement step. For each code, the
implementer:

1. Reads the migrated hook to determine the event input shape (Claude
   side).
2. Reads the Pi handler factoring (or — if no Pi handler yet — picks
   the natural `tool_call` shape per the research note).
3. Reads `schemas/blocker-event.yaml` for the normalized shape.
4. Constructs `expected-envelope.json` from
   `schemas/blocker-taxonomy.yaml`'s entry for the code, resolving
   `{placeholder}` keys with concrete values consistent across all
   four fixture files.

This work is not scoped further in the spec because it is mechanical
and per-code; deviations from the four-file pattern are surfaced at
review time. The spec mandates the layout and the assertion shape,
not the per-code content.

### Shim → code mapping

The parity test needs to know which codes each migrated shim emits.
The cleanest mechanism is to grep the shim source for
`furrow guard <event-type>` invocations and look up `<event-type>` in
`schemas/blocker-event.yaml` to get the set of codes that event type
can produce. Alternatives — a hard-coded mapping table at the top of
the parity test, or a sidecar YAML file — are rejected as they
introduce a second source of truth that can drift from the shim
sources. Stick with grep.

### Forward-looking: wrapper-interception variant

If `grep`-based static checks prove insufficient (e.g., a shim
constructs the `furrow guard` invocation via variable interpolation
that defeats the regex), the parity test can fall back to an
intercept variant: prepend a `$TMP/wrapper/` directory to PATH where
`go` is a stub that records its argv to `$TMP/calls.log`, then run
the shim and assert `calls.log` contains the expected invocation. This
is a v2 hardening step and is not required for the standing AC.

### Skip list as operational mirror

The `DEFERRED_CODES` constant is the operational mirror of D3's
`research/hook-audit-final.md` deferral section. It must:

- Be a literal string at the top of each test script (no parsing the
  audit report — that introduces a parser failure mode that masks the
  underlying assertion).
- Carry an inline comment citing the audit report path and the date
  the deferral was recorded.
- Be the same string in both `test-blocker-coverage.sh` and
  `test-blocker-parity.sh` (extract to a shared
  `tests/integration/lib/blocker-deferred-codes.sh` if it grows past
  three entries, but not before).

---

## Dependencies

### Hard dependencies (must complete before D4 implement)

- **D1 — `canonical-blocker-taxonomy`**: provides
  `schemas/blocker-taxonomy.yaml` (extended), `internal/cli/blocker_envelope.go`
  validating against the new shape, and the canonical `BlockerEnvelope`
  shape that all assertions compare against. Without D1, the
  `expected-envelope.json` content has no canonical source.
- **D2 — `normalized-blocker-event-and-go-emission-path`**: provides
  `schemas/blocker-event.yaml`, `schemas/blocker-event.schema.json`,
  and the `go run ./cmd/furrow guard <event-type> --json` entry
  point. Without D2, the coverage test has nothing to invoke.
- **D3 — `hook-migration-and-quality-audit`**: provides the migrated
  shim list under `bin/frw.d/hooks/` (with `gate-check.sh` deleted
  and the 10 emit-bearing hooks rewritten as ≤30-line shims), and the
  deferral list in `research/hook-audit-final.md`. Without D3, the
  parity test has no migrated shims to walk and no authoritative
  deferral list.

### Soft dependencies (test runtime requirements)

- `jq` (already a hard suite dependency, used in 12+ existing tests).
- `yq` (Go-based or Python-based; required for taxonomy enumeration in
  the coverage test). Verify availability via
  `command -v yq >/dev/null || { echo "yq required"; exit 1; }` at
  the top of the coverage test.
- `bun` (Pi adapter test driver runtime; matches existing
  `adapters/pi/package.json` `bun test` script). Verify availability
  via `command -v bun >/dev/null || { echo "bun required"; exit 1; }`
  at the top of the parity test, before any `bun run` invocation.
- `go` (already required by the suite for `go run ./cmd/furrow`
  invocations).

### Files this deliverable creates

- `tests/integration/test-blocker-coverage.sh` (new, executable)
- `tests/integration/test-blocker-parity.sh` (new, executable)
- `tests/integration/fixtures/blocker-events/<code>/{normalized.json,
  claude.json, pi.json, expected-envelope.json}` (per-code; one
  directory per non-deferred code in
  `schemas/blocker-taxonomy.yaml`)
- `adapters/pi/test-driver-blocker-parity.ts` (new, Bun-runnable, no
  new dependencies)

### Files this deliverable does NOT create

- No Makefile (per AC-8: auto-discovery via `run-all.sh` glob is
  sufficient).
- No CI workflow file (`.github/workflows/` does not exist in this
  checkout per research C.1; CI wiring of `run-all.sh` itself is
  out-of-scope and captured as a follow-up TODO if not already
  covered).
- No new Pi shim binary (per research B.6 and team-plan.md Wave 4 —
  the driver is test-only; the shim is the existing
  `adapters/pi/furrow.ts` factoring).
- No edit to `tests/integration/run-all.sh` (auto-discovery; per
  AC-8).

### Follow-up TODOs deferred from this deliverable

- **`pi-tool-call-canonical-schema-and-surface-audit`** (already in
  `.furrow/almanac/todos.yaml:4267`): live Pi-runtime invocation, and
  authoring per-code Pi `tool_call` handlers for codes whose
  `pi.json` fixtures are currently aspirational contracts. D4 produces
  the contract; that TODO closes the implementation gap.
- **CI wiring of `run-all.sh`** (if not covered elsewhere): the suite
  is invokable manually but no `.github/workflows/` yaml gates
  merges. Surface as a TODO during the implement step if the row
  reviewer flags it.
