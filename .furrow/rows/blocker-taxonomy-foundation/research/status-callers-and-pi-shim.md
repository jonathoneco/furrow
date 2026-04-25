# Status Callers Inventory & Pi Adapter Shim Landscape

Research for `blocker-taxonomy-foundation` row, deliverables D1
(`canonical-blocker-taxonomy`) and D4 (`coverage-and-parity-tests`).

---

## Section A — `furrow row status` Caller Inventory

### A.1 What `furrow row status --json` emits today

The Go status handler is `runRowStatus` in
`/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/row.go:109-146`
which builds the response body via `buildRowStatusData` at
`internal/cli/row.go:603-663`. The `blockers` array is produced by
`rowBlockers` in `internal/cli/row_workflow.go:1005-1085` and shaped by the
helper `blocker(...)` in `internal/cli/row_semantics.go:46-58`:

```go
// internal/cli/row_semantics.go:46-58
func blocker(code, category, message string, details map[string]any) map[string]any {
    entry := map[string]any{
        "code":              code,
        "category":          category,
        "severity":          "error",
        "message":           message,
        "confirmation_path": blockerConfirmationPath(code),
    }
    for key, value := range details {
        entry[key] = value
    }
    return entry
}
```

`blockerConfirmationPath` (`row_semantics.go:60-77`) returns prose strings
like `"Resolve or clear the pending user actions through the canonical
workflow before advancing."`.

### A.2 Divergence vs. canonical `BlockerEnvelope`

The canonical envelope is defined in
`/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/blocker_envelope.go:34-42`:

```go
type BlockerEnvelope struct {
    Code             string `json:"code"`
    Category         string `json:"category"`
    Severity         string `json:"severity"`
    Message          string `json:"message"`
    RemediationHint  string `json:"remediation_hint"`
    ConfirmationPath string `json:"confirmation_path"`
}
```

Validation (`blocker_envelope.go:44-46`) requires:

- `severity ∈ {block, warn, info}`
- `confirmation_path ∈ {block, warn-with-confirm, silent}`
- `remediation_hint` non-empty

Today's `rowBlockers` output diverges on **four** axes:

| Field | Today | Canonical | Drift |
|-------|-------|-----------|-------|
| `severity` | always `"error"` (literal) | `block`/`warn`/`info` | All entries violate enum |
| `confirmation_path` | full prose sentence | enum token (`block` etc.) | Type mismatch — string-but-different-domain |
| `remediation_hint` | absent | required string | Missing field |
| extra detail keys | merged in (`seed_id`, `path`, `artifact_id`, `finding_codes`, `count`, `expected_status`, `actual_status`, `required_commit`, `required_row`, `confirmed_commit`, `confirmed_row`) | not part of envelope | Schema-extension drift |

Any caller that validates against the canonical envelope schema today
**fails**. Any caller that consumes the existing fields by name and tolerates
extras will continue to work for `code`, `category`, `message`. Callers that
read `severity` expecting `"error"` will break when D1 lands. Callers that
treat `confirmation_path` as prose will break when it becomes an enum token.

### A.3 Caller inventory

#### Programmatic JSON consumers (parse `--json` envelope)

1. **`adapters/pi/furrow.ts`** — the Pi adapter is the **only** programmatic
   consumer of `furrow row status --json` blocker output. Multiple call sites:

   - `adapters/pi/furrow.ts:867` — `runFurrowJson<RowStatusData>(root, ["row", "status"])` (initial status refresh)
   - `adapters/pi/furrow.ts:1006` — same call inside `/work` after row init
   - `adapters/pi/furrow.ts:1100` — `[ "row", "status", targetRow ]`
   - `adapters/pi/furrow.ts:1125,1140,1188,1203,1209` — refreshed status after scaffold/transition/archive
   - `adapters/pi/furrow.ts:1293` — `/furrow-next`
   - `adapters/pi/furrow.ts:1332` — `/furrow-complete`
   - `adapters/pi/furrow.ts:1390` — `/furrow-transition`

   Type expectation at `adapters/pi/furrow.ts:187`:

   ```ts
   blockers?: Array<{ code?: string; category?: string; severity?: string;
                      message?: string; path?: string; confirmation_path?: string }>;
   ```

   Render code at `adapters/pi/furrow.ts:395-402`:

   ```ts
   function formatBlockers(data?: RowStatusData): string[] {
       const blockers = data?.blockers ?? [];
       if (blockers.length === 0) return ["- none"];
       return blockers.map((blocker) => {
           const prefix = [blocker.category, blocker.severity].filter(Boolean).join("/");
           const confirmation = blocker.confirmation_path ? ` :: fix: ${blocker.confirmation_path}` : "";
           return `- ${prefix ? `[${prefix}] ` : ""}${blocker.code ?? "blocked"}: ${blocker.message ?? "unspecified blocker"}${confirmation}`;
       });
   }
   ```

   Pi reads: `code`, `category`, `severity`, `message`, `confirmation_path`. It
   does NOT consume `path` outside this type definition (the `path` field is
   one of the merged detail keys today). It does NOT consume
   `remediation_hint` today, but adding it is purely additive.

   **Behavioral impact of envelope cutover for Pi:**
   - `severity`: today renders `"error"` in `[category/severity]` prefix; will
     render `[category/block]` etc. — purely cosmetic, no logic depends on
     specific value.
   - `confirmation_path`: today appended as prose `:: fix: Resolve or clear
     the pending user actions...`. After cutover this becomes `:: fix: block`
     which is meaningless to a human. **Pi rendering needs migration: map
     enum token → human-readable hint (likely via the new
     `remediation_hint` field).** This is a small render-side fix, not a
     contract break.
   - Pi already declares `severity?: string` (free string, not enum) so the
     TS type stays valid.

2. **`adapters/pi/furrow.ts:1144`** — branching logic that reads
   `(status.blockers?.length ?? 0) === 0`. Length-only check, envelope-shape-
   tolerant.

#### Plain-text status callers (don't parse blockers)

3. **`bin/rws status` shim** (`bin/rws:1777-1807`, `rws_status()`). This is a
   `jq`-driven plain-text printer. It reads `state.json` directly (not the Go
   backend) and prints title/step/step_status/branch/deliverable counts/gate
   count. It does **not** surface blockers at all. Envelope-shape change has
   zero effect.

4. **`bin/rws` dispatcher** (`bin/rws:2943`) routes `status` subcommand to
   `rws_status`. Help text at `bin/rws:2882`. Same as above.

5. **`tests/integration/test-rws.sh:78`** — calls `rws status test-row` and
   captures stdout for substring assertions on title/step. Envelope-shape
   tolerant (operates one level above blocker shape).

6. **`tests/integration/test-script-guard.sh:107-108`** — invokes
   `bin/rws status` only to assert hook script-guard policy (allows
   non-`frw.d/` paths). Exit-code-only check.

#### Documentation / prompt mentions (no parse, no execute)

7. **`commands/*.md`** (Claude slash command wiring): `commands/checkpoint.md:7`,
   `commands/redirect.md:11`, `commands/review.md:18`, `commands/archive.md:17`,
   `commands/work-todos.md:23`, `commands/reground.md:11`,
   `commands/status.md:32`. All instruct the model to "find active task via
   `rws status`" — these are prompts, not code, and depend only on plain
   text (route #3 above).

8. **`bin/frw.d/scripts/merge-audit.sh:201`** — prints user-facing message
   `_warn "Run /furrow:status to check row state."`. No parse.

9. **`bin/frw.d/install.sh:673`** — install table row. No parse.

10. **`bin/frw.d/scripts/doctor.sh:383`** — references `rws transition`, not
    status. No bearing on D1.

11. **`.claude/rules/cli-mediation.md:10`** — table cell instructing CLI
    usage. No code path.

12. **`adapters/pi/README.md:21-22`** — documentation citing
    `go run ./cmd/furrow row status --json` as a backend mutation surface.
    Doc-only.

13. Multiple `.furrow/rows/*` archived rows reference `furrow row status` —
    historical artifacts; no runtime callers.

#### Other Go callers (internal use, not external contract)

14. **`internal/cli/row_semantics.go:67,71`** — error-path message templates
    that suggest `"...rerun furrow row status..."`. These are prose embedded
    in `blockerConfirmationPath`; they will be replaced when D1 normalizes
    `confirmation_path` to enum tokens.

15. **`internal/cli/app.go:225`** — usage string mentioning `furrow row
    status [row-name] [--json]`. Doc-only.

16. **`internal/cli/row.go` calls to `buildRowStatusData`** at line 138 are
    the only producers of the contract.

### A.4 Classification summary

| Class | Count | Callers |
|-------|-------|---------|
| (a) JSON-aware, envelope-shape **tolerant** (need only minor render tweak) | 1 site (~9 invocations) | `adapters/pi/furrow.ts` |
| (b) **Needs migration** — actively parses fields whose semantics change | 0 | none |
| (c) **Plain-text / opaque** (no envelope dependency) | 6 distinct callers | `bin/rws status`, `tests/integration/test-rws.sh`, `tests/integration/test-script-guard.sh`, `bin/frw.d/scripts/merge-audit.sh:201`, `commands/*.md` prompts, `bin/frw.d/install.sh:673` |
| (d) **Doc/prompt mentions only** (no code) | ~15 references | `docs/architecture/*`, `.furrow/rows/*`, `.claude/rules/cli-mediation.md`, READMEs |

The only programmatic consumer of the blocker envelope shape is
`adapters/pi/furrow.ts`. There is **no** Claude-side code that parses
`furrow row status --json` blocker arrays today — Claude consumes status via
the plain-text `rws status` shim which doesn't surface blockers.

### A.5 Migration plan (recommendation)

1. **Update `internal/cli/row_semantics.go:46-58`** so `blocker(...)` returns
   the canonical six-field shape. Replace literal `"error"` severity by
   per-code lookup against the taxonomy. Replace prose `confirmation_path`
   with the taxonomy's enum token. Surface `remediation_hint` from the
   taxonomy. This is the single chokepoint that flows to all status,
   transition, archive, and complete responses (`row.go:201`, `:439`, `:610`).
2. **Move detail keys out of the envelope** into a sibling `details` map (or
   keep them as a lateral field on the response — `pending_blockers` already
   carries detail-bearing entries today). The taxonomy schema requires
   adapter-agnostic shape; any seed_id/path/artifact_id detail must be
   either (a) interpolated into the message via `{placeholder}` keys, or
   (b) shipped in a parallel structure.
3. **Pi adapter render fix in `adapters/pi/furrow.ts:395-402`**: stop
   interpolating raw `confirmation_path` enum into user-facing prose. Either
   render `remediation_hint` instead, or map the enum token to a phrase. This
   is purely cosmetic — the JSON contract stays compatible.
4. **No backward-compat shim is needed.** No existing caller (other than Pi)
   reads the envelope, and Pi already declares the relevant fields as
   optional/string. The single "shim" we owe is the Pi render-side hint
   mapping above.
5. **Add a parity test fixture** (D4 follow-up) that asserts `furrow row
   status --json` blockers validate against
   `schemas/blocker-taxonomy.schema.json`.

**Total caller categories: (a)=1 (Pi, render-tweak only), (b)=0,
(c)=6, (d)=~15.** The migration is low-risk because the only programmatic
consumer is Pi and Pi's TS types are already loose enough to absorb the
shape change without recompilation breakage.

---

## Section B — Pi Adapter Shim Landscape

### B.1 Does `adapters/pi/` exist?

**Yes.** The directory is populated and active:

```
/home/jonco/src/furrow-blocker-taxonomy-foundation/adapters/pi/
├── README.md
├── _meta.yaml
├── furrow.ts            (~1500 lines — the canonical Pi extension)
├── furrow.test.ts       (bun-test unit tests)
├── package.json
├── tsconfig.json
└── validate-actions.ts  (D4/D5 handler logic, dependency-free)
```

A compatibility shim re-exports the canonical adapter for Pi's auto-discovery
mechanism: `.pi/extensions/furrow.ts` (per `adapters/pi/README.md:46-48`).

### B.2 Pi adapter architecture today

`adapters/pi/furrow.ts` registers `tool_call` handlers (3 of them) and slash
commands (`/furrow-overview`, `/furrow-next`, `/furrow-transition`,
`/furrow-complete`, `/work`). The handlers:

1. **State-mutation guard** (`furrow.ts:894-910`): blocks Edit/Write to
   canonical `.furrow/.focused` and row `state.json`.
2. **Definition validation** (`furrow.ts:916-929`): on Write/Edit to
   `*/definition.yaml`, calls `furrow validate definition --path <file>
   --json` and surfaces an error via `ctx.ui.notify`.
3. **Ownership warn** (`furrow.ts:935-948`): on every Write/Edit, calls
   `furrow validate ownership --path <file> --json` and surfaces a
   `ctx.ui.confirm` dialog on `out_of_scope`.

Handler logic is factored into `validate-actions.ts` for unit testability:
`runDefinitionValidationHandler`, `runOwnershipWarnHandler`,
`decideValidateDefinitionAction`, `decideOwnershipAction`.

The contract between the handlers and the Go backend is already an
**envelope-shaped error** — see `validate-actions.ts:11-18`:

```ts
export type ValidationErrorEnvelope = {
    code: string;
    category: string;
    severity: string;
    message: string;
    remediation_hint: string;
    confirmation_path: string;
};
```

This is essentially the same shape as the canonical `BlockerEnvelope`. The
Pi adapter is already prepared to consume canonical envelopes from the Go
backend — that pattern is shipped and tested for definition/ownership.

### B.3 Pi `tool_call` event shape

Pi's runtime is `@mariozechner/pi-coding-agent`. Pi event shape passed to a
handler (extracted from `adapters/pi/furrow.ts:894-948` and
`validate-actions.ts:60-81`):

```ts
event = {
    toolName: "edit" | "write" | ...,   // tool the agent attempted
    input: { path?: string, content?: string, ... },  // tool-specific args
}
ctx = {
    cwd: string,
    signal: AbortSignal,
    hasUI: boolean,
    ui?: { notify(msg, level), confirm(title, body), ... },
}
```

Handlers return `undefined | { block: true; reason: string } | { block: false }`.

This is **Pi-runtime-shaped**, not normalized. A deliverable D4 fixture for
"Pi-shape event" needs to look like a Pi `tool_call` event payload, which the
adapter then translates into a Go subprocess invocation
(`runFurrowJson(root, ["validate", "ownership", "--path", absolutePath, "--json"])`).

### B.4 Architectural intent (per docs)

- **`docs/architecture/core-adapter-boundary.md:175-176`**: "`adapters/claude-
  code/` and `adapters/pi/` should contain wiring, not domain logic."
- **`docs/architecture/core-adapter-boundary.md:118-124`**: lists
  `furrow row status --json` and friends as the canonical adapter contract.
- **`docs/architecture/migration-stance.md:110-116`**: "Prefer target-shape
  implementation over transitional shims... use the existing Furrow Pi
  adapter in `adapters/pi/furrow.ts`. Do not create a parallel Pi adapter
  just to keep options open."
- **`docs/architecture/migration-stance.md:86-89`** (the cited authority for
  parity): "Shared semantics across hosts remain real... Pi and Claude-
  compatible flows do not need identical UX, but they should not silently
  diverge on canonical workflow semantics."
- **`adapters/pi/README.md:54-69`**: tool_call validators are the established
  pattern; new validators add a handler that calls a Go validator and
  surfaces the envelope through `ctx.ui`.
- **`docs/architecture/dual-runtime-migration-plan.md:85-96`**: Pi adapter
  consumes the Go contract; "host-specific invocation shims" are explicitly
  named as adapter responsibility.
- **`docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:317-326`**
  ("Pi adapter implications") names "blocker/warning presentation" as Pi's
  responsibility, sourced from backend.

### B.5 What "Pi adapter shim" means in D4 acceptance criteria

Re-reading deliverable D4 in
`/home/jonco/src/furrow-blocker-taxonomy-foundation/.furrow/rows/blocker-taxonomy-foundation/definition.yaml:73-95`:

> for each migrated code, the test feeds a Claude-shape event fixture
> through the Claude adapter shim AND a Pi-shape event fixture through the
> Pi adapter shim, asserts both produce identical canonical
> BlockerEnvelopes. Pi runtime presence is not required — fixture-driven
> invocation through the Pi shim suffices.

Two readings are possible:

- **Reading 1 (test-the-shim-as-code)**: Pi adapter shim = a thin
  shell/Node script under `adapters/pi/` that, given a Pi-shape event JSON
  on stdin, invokes the Go backend and emits the canonical envelope on
  stdout. The parity test runs this binary and diffs its output against
  the Claude adapter shim's output for the same logical event.
- **Reading 2 (test-the-go-backend-via-pi-shaped-input)**: Pi adapter shim
  = a *contract* (not a binary) that pipes a Pi-shape event JSON directly
  into `furrow guard <event-type> --json` (the new D2 entry point). The
  parity test asserts that the Go backend, when fed the Pi-shape and
  Claude-shape variants of the same event, emits identical envelopes.

Reading 1 is closer to the literal phrasing of D4 ("shim AND ... shim").
Reading 2 is closer to the architectural intent of D2/D3 (Go owns
enforcement; adapters just translate event shape).

### B.6 Recommendation — author a Pi shim binary? **NO (with one nuance)**

**Do not author a separate `adapters/pi/blocker-shim.{ts,sh}` binary in
this row.** Instead, treat "the Pi adapter shim" as the existing
`adapters/pi/furrow.ts` plus a new fixture-driven test entry point.
Rationale:

1. **A separate shim binary duplicates `furrow.ts`'s job and violates the
   migration stance.** `migration-stance.md:110-116` explicitly forbids
   parallel Pi adapters. The existing `adapters/pi/furrow.ts` already
   intercepts `tool_call` events, translates them, and invokes the Go
   backend — that *is* the shim, and it is shipped.
2. **Live Pi-runtime invocation is already excluded.** D4 says "Pi runtime
   presence is not required — fixture-driven invocation through the Pi
   shim suffices." The parity test does not need Pi running. What it
   needs is to exercise the Pi-side translation logic (`tool_call` event
   → normalized event → Go subprocess → envelope) in isolation. The
   factoring already exists: `validate-actions.ts` exposes pure functions
   (`runDefinitionValidationHandler`, `runOwnershipWarnHandler`,
   `shouldInterceptForDefinitionValidation`, etc.) that take a Pi-shape
   event-like input and return a Pi handler action, with the Go subprocess
   injected. Add a thin **test driver** (not a shipped binary) that:
   - reads a Pi-shape `tool_call` fixture from `tests/integration/fixtures/
     blocker-events/pi/<code>.json`,
   - calls the relevant translator (`runDefinitionValidationHandler` etc.),
   - injects a real `runFurrowJson` that shells out to the Go binary,
   - prints the resulting envelope for the parity test to diff.
3. **The Claude side has the same factoring.** The migrated hooks in
   `bin/frw.d/hooks/` (per D3 acceptance criteria) become 30-line shims
   that read a Claude-shape event from stdin, normalize it, invoke the Go
   backend, and translate the envelope back to exit code + stdout. That
   *is* the Claude adapter shim; the parity test diffs envelope output for
   the equivalent normalized event.
4. **What the row actually needs** is therefore three artifacts, not a
   new shim binary:
   - a small Node test driver under `tests/integration/` (or
     `adapters/pi/`) that wraps the existing pure handler factoring
   - per-code Pi-shape fixtures under `tests/integration/fixtures/
     blocker-events/pi/`
   - per-code Claude-shape fixtures under `tests/integration/fixtures/
     blocker-events/claude/`
5. **Nuance: a `tool_call` event for many of the new codes (state-mutation,
   gate, archive, scaffold, summary, ideation, seed-state) does not
   currently exist on the Pi side.** Today's Pi `tool_call` handlers cover
   only `definition.yaml` validation and ownership warning, plus the raw
   state-mutation block. For the **new** codes added in D1, the Pi-shape
   "event" is fictional until the D2 normalized-event schema is defined —
   the Pi adapter has not yet been extended to intercept (e.g.) `gate
   transitions` or `archive ceremony` events. **The Pi-shape fixture is
   therefore an aspirational contract, not a record of an existing Pi
   tool_call payload.** Two ways to reconcile:
   - **Preferred**: define the Pi-shape fixture as `{ toolName: "<verb>",
     input: {...} }`-style payloads consistent with the Pi runtime's
     existing handler signature, even where the Pi adapter doesn't yet
     dispatch on them. Document that the fixtures define the contract that
     a future Pi `tool_call` handler will satisfy. This matches D4's
     "follow-up TODO" provision: "Live Pi-process invocation is an
     explicit follow-up TODO if not delivered here."
   - Do not author per-code Pi handlers in this row. That is a clear
     follow-up TODO ("`pi-tool-call-canonical-schema-and-surface-audit`"
     already exists in `.furrow/almanac/todos.yaml:4267`).

### B.7 Concrete D4 plan

1. Add `tests/integration/fixtures/blocker-events/pi/<code>.json` with
   Pi `tool_call`-shape payloads for each migrated code.
2. Add `tests/integration/fixtures/blocker-events/claude/<code>.json` with
   Claude hook-input-shape payloads.
3. Add a normalized event fixture
   `tests/integration/fixtures/blocker-events/normalized/<code>.json` (per
   D2's host-agnostic schema).
4. The parity test
   (`tests/integration/test-blocker-parity.sh`) drives:
   - Claude shim: `bin/frw.d/hooks/<hook>.sh < claude/<code>.json` →
     captures stdout/exit
   - Pi shim: invoke a small Node driver that imports the relevant
     `validate-actions.ts` translator (or a new `tool_call` translator added
     in this row) and feeds it `pi/<code>.json`, with the real Go
     subprocess injected → captures the envelope it would have emitted
   - assert both envelopes equal each other and equal the Go backend's
     direct output for `normalized/<code>.json`.

**No new Pi binary, no new long-lived `adapters/pi/blocker-shim.ts`.** Just
fixtures and a test driver. The "shim" is `adapters/pi/furrow.ts`'s
existing factoring; the parity test exercises the same pure functions that
the Pi runtime exercises in production.

---

## Sources Consulted

### Primary (load-bearing for the report)

- `/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/row.go`
  lines 109-146 (`runRowStatus`), 138 (`buildRowStatusData` invocation),
  201/439/610 (`rowBlockers` callers), 603-663 (`buildRowStatusData`)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/row_workflow.go`
  lines 1005-1085 (`rowBlockers`)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/row_semantics.go`
  lines 46-58 (`blocker` constructor), 60-77 (`blockerConfirmationPath`)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/blocker_envelope.go`
  lines 15-42 (canonical types), 44-46 (validation enums), 136-159
  (`EmitBlocker`)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/adapters/pi/furrow.ts`
  lines 82-189 (`RowStatusData` type), 187 (`blockers` field), 395-402
  (`formatBlockers`), 867 / 1006 / 1100 / 1125 / 1140 / 1188 / 1203 / 1209 /
  1293 / 1332 / 1390 (status invocations), 894-948 (tool_call handlers)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/adapters/pi/validate-actions.ts`
  lines 11-18 (`ValidationErrorEnvelope`), 60-81 (handler signatures)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/rws` lines 1777-1807
  (`rws_status`), 2882, 2943
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/.furrow/rows/blocker-taxonomy-foundation/definition.yaml`
  lines 19, 73-95 (D1 + D4 acceptance criteria)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/docs/architecture/core-adapter-boundary.md`
  lines 116-124, 134-141, 175-176
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/docs/architecture/migration-stance.md`
  lines 86-89, 110-116
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/docs/architecture/dual-runtime-migration-plan.md`
  lines 85-96, 147
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/adapters/pi/README.md`
  lines 21-22, 46-48, 54-69

### Secondary (caller inventory, supporting context)

- `/home/jonco/src/furrow-blocker-taxonomy-foundation/tests/integration/test-rws.sh:78`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/tests/integration/test-script-guard.sh:107-108`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/scripts/merge-audit.sh:201`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/bin/frw.d/install.sh:673`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/commands/checkpoint.md:7`,
  `archive.md:17`, `redirect.md:11`, `review.md:18`, `work-todos.md:23`,
  `reground.md:11`, `status.md:32`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/.claude/rules/cli-mediation.md:10`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/internal/cli/app.go:225`
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/docs/architecture/pi-parity-ladder.md`
  lines 125, 165, 208
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
  lines 269, 317-326
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/.furrow/almanac/todos.yaml`
  line 3583 (shared-blocker-taxonomy-spec), line 4267 (pi-tool-call-canonical-
  schema-and-surface-audit)
- `/home/jonco/src/furrow-blocker-taxonomy-foundation/.furrow/almanac/roadmap.md`
  lines 108, 125-126, 135, 155
