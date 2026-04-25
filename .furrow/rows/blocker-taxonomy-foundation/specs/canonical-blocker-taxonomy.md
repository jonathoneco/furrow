# Spec: canonical-blocker-taxonomy

> See `specs/shared-contracts.md` for cross-cutting decisions; that document overrides any conflicting detail here.

**Row**: `blocker-taxonomy-foundation`
**Wave**: 1 (parallel with `doc-contradiction-reconciliation`)
**Specialist**: migration-strategist
**Date**: 2026-04-25

This spec turns deliverable D1 (`definition.yaml:13-31`) into testable
acceptance criteria, scenarios, and an explicit final code inventory.
Migration discipline is **expand-contract**: the registry is extended (expand),
producers (`blocker(...)`) and consumers (Pi `formatBlockers`) are migrated
through a single canonical envelope shape, and the **only** legacy obligation
that survives — backward-compat for the 11 existing code strings — is enforced
by golden tests at `internal/cli/blocker_envelope_test.go:12-23`.

---

## 1. Interface Contract

### 1.1 `Taxonomy` YAML schema (consumed by `LoadTaxonomy`)

File: `schemas/blocker-taxonomy.yaml` (existing 11 entries; will grow to ≥21).
Validator: `schemas/blocker-taxonomy.schema.json` (already shapes top-level
`additionalProperties: false`, `applicable_steps` already supported per
`schemas/blocker-taxonomy.schema.json:46-50`).

Top level (no change):

```yaml
version: "1"
blockers: [<entry>, ...]
```

Per-entry shape (`schemas/blocker-taxonomy.schema.json:18-50`,
`internal/cli/blocker_envelope.go:15-24`):

| Field               | Required | Type    | Constraint                                                   |
| ------------------- | -------- | ------- | ------------------------------------------------------------ |
| `code`              | yes      | string  | pattern `^[a-z][a-z0-9]*([_-][a-z0-9]+)*$`; unique           |
| `category`          | yes      | string  | non-empty; free-form (e.g., `state-mutation`, `gate`, `summary`) |
| `severity`          | yes      | enum    | `block` \| `warn` \| `info`                                  |
| `message_template`  | yes      | string  | `{placeholder}` substitution; emitter supplies matching keys |
| `remediation_hint`  | yes      | string  | non-empty; sourced verbatim by Pi render                     |
| `confirmation_path` | yes      | enum    | `block` \| `warn-with-confirm` \| `silent`                   |
| `applicable_steps`  | no       | [string]| absent/empty → all steps; otherwise restricts to listed steps |

**No adapter-specific fields.** No `claude.*`, `pi.*`, runtime hints, or
host-specific metadata in the registry. Per-host coverage is a backend
property proven by D4 parity tests (`team-plan.md:73-74`).

**Extension surface for D1**: `applicable_steps` is the only optional field,
already supported by the loader (no schema change needed). New top-level
fields are not introduced by D1; if a future deliverable needs one, the
schema requires `additionalProperties: false` to be widened explicitly.

### 1.2 `BlockerEnvelope` JSON schema (the wire shape)

Defined in Go at `internal/cli/blocker_envelope.go:34-42`. This is the
shape every adapter consumes; it is also the shape every status/transition
JSON output's `blockers[]` array entry must match after D1.

```json
{
  "code":              "string (must exist in taxonomy)",
  "category":          "string (mirrors taxonomy entry)",
  "severity":          "block | warn | info",
  "message":           "string (interpolated from message_template)",
  "remediation_hint":  "string (mirrors taxonomy entry)",
  "confirmation_path": "block | warn-with-confirm | silent"
}
```

Validation enums: `internal/cli/blocker_envelope.go:44-46`
(`validSeverities`, `validConfirmationPaths`).
Production fallback for unknown codes (graceful, non-test): a synthetic
envelope with `category: "unregistered"`, `severity: "warn"`,
`confirmation_path: "warn-with-confirm"` (`blocker_envelope.go:142-149`).
In test mode `EmitBlocker` panics on unregistered codes
(`blocker_envelope.go:139-141`) — this is intentional and locked.

**No fields beyond the six.** Detail keys (`seed_id`, `path`, `artifact_id`,
`finding_codes`, `count`, `expected_status`, `actual_status`,
`required_commit`, `required_row`, `confirmed_commit`, `confirmed_row`)
that today are **merged into** the envelope at
`internal/cli/row_semantics.go:54-56` MUST move into a sibling `details`
map next to (not inside) the envelope, OR be interpolated into `message`
via `{placeholder}` keys.

### 1.3 `blocker(...)` constructor — primary migration target

Current shape (`internal/cli/row_semantics.go:46-58`):

```go
func blocker(code, category, message string, details map[string]any) map[string]any {
    entry := map[string]any{
        "code":              code,
        "category":          category,
        "severity":          "error",                          // hardcoded
        "message":           message,                           // free-form
        "confirmation_path": blockerConfirmationPath(code),     // prose
    }
    for key, value := range details { entry[key] = value }     // merges arbitrary keys
    return entry
}
```

**Diverges from canonical envelope on four axes** (per
`research/status-callers-and-pi-shim.md:62-75`):
1. `severity` is hardcoded `"error"` — must become per-code lookup against
   taxonomy (`block | warn | info`).
2. `confirmation_path` is prose (e.g., `"Resolve or clear..."`) — must
   become enum token from taxonomy.
3. `remediation_hint` is missing — must be sourced from taxonomy entry.
4. Detail keys are merged into the envelope — must move out (sibling
   `details` field on the parent blockers[] entry, OR interpolated into
   `message` via `{placeholder}` substitution).

Target signature:

```go
// blocker resolves code against the loaded taxonomy and returns a canonical
// six-field envelope plus an optional sibling "details" map for
// non-interpolated context. The taxonomy is the single source of truth for
// severity, remediation_hint, and confirmation_path.
func blocker(tx *cli.Taxonomy, code string, interp map[string]string, details map[string]any) map[string]any
```

Return shape (one map per entry in the parent `blockers[]` array):

```jsonc
{
  // canonical envelope (six fields, fixed order, schema-validated)
  "code":              "...",
  "category":          "...",
  "severity":          "block | warn | info",
  "message":           "...",
  "remediation_hint":  "...",
  "confirmation_path": "block | warn-with-confirm | silent",

  // optional sibling — present only when caller passed non-nil details.
  // Adapters MAY consume; not part of the canonical envelope contract.
  "details": { "seed_id": "...", "path": "...", ... }
}
```

**Caller migration map** (file ownership per `definition.yaml:21-30`):

| Caller | Lines | Today | Migration |
|---|---|---|---|
| `rowBlockers` `pending_user_actions` emit | `row_workflow.go:1011-1013` | merged `count` detail | `interp={"count":"N"}`, `details={"count":N}` |
| `rowBlockers` `seed_store_unavailable` emit | `row_workflow.go:1017` | no details | unchanged |
| `rowBlockers` `missing_seed_record` emit | `row_workflow.go:1019` | merged `seed_id` | `interp={"seed_id":...}`, `details={"seed_id":...}` |
| `rowBlockers` `closed_seed` emit | `row_workflow.go:1021` | merged `seed_id` | same shape as above |
| `rowBlockers` `seed_status_mismatch` emit | `row_workflow.go:1023` | merged 3 detail keys | placeholders + `details` map |
| `rowBlockers` `supersedence_evidence_missing` emit (no-confirm) | `row_workflow.go:1039-1045` | merged 2 detail keys | placeholders + `details` map |
| `rowBlockers` `supersedence_evidence_missing` emit (mismatch) | `row_workflow.go:1047-1058` | merged 4 detail keys | placeholders + `details` map |
| `rowBlockers` `missing_required_artifact` emit | `row_workflow.go:1068` | merged `path`, `artifact_id` | placeholders + `details` map |
| `rowBlockers` `artifact_scaffold_incomplete` emit | `row_workflow.go:1072` | merged `path`, `artifact_id` | placeholders + `details` map |
| `rowBlockers` `artifact_validation_failed` emit | `row_workflow.go:1076` | merged 3 detail keys | placeholders + `details` map |
| `rowBlockers` `archive_requires_review_gate` emit | `row_workflow.go:1081` | no details | unchanged |
| `buildRowStatusData` consumer | `row.go:603-663` | passes `blockers` through verbatim into `gates.pending_blockers` (line 640) and top-level `blockers` (line 659) | unchanged — it forwards the new shape |

`blockerConfirmationPath` (`row_semantics.go:60-77`) is **deleted** when the
constructor switches to taxonomy lookup. Its prose contents become
`remediation_hint` text inside the taxonomy YAML for the relevant codes
(`pending_user_actions`, `seed_store_unavailable`, `missing_seed_record`,
`closed_seed`, `seed_status_mismatch`, `missing_required_artifact`,
`artifact_scaffold_incomplete`, `artifact_validation_failed`,
`archive_requires_review_gate`). Note that the prose used today is **policy
guidance**, not a confirmation token — that semantic is what the new
`remediation_hint` field captures.

### 1.4 Sibling status / transition outputs

Per definition `definition.yaml:19`: status AND sibling status/transition
outputs emit canonical envelopes. Audit targets (line 13 of team-plan):

- `runRowStatus` → calls `buildRowStatusData` → `rowBlockers`
  (`row.go:138`, `:603-663`, `row_workflow.go:1005`). Surfaces blockers at
  two paths: top-level `blockers` (line 659) and `gates.pending_blockers`
  (line 640). Both come from the same `rowBlockers` slice, so a single
  constructor migration covers both surfaces.
- `runRowTransition` → uses `rowBlockers` at the call sites cited in
  `research/status-callers-and-pi-shim.md:469-471` (`row.go:201, :439, :610`
  per the research note). Same constructor — same migration covers it.
- Archive / complete responses — same constructor (`row.go:610` in the
  research caller list).

**No backward-compat shim required** (`research/status-callers-and-pi-shim.md:226`).
The only programmatic consumer is Pi (`adapters/pi/furrow.ts:187`) and Pi's
TS type already declares `severity?: string` and `confirmation_path?: string`
as loose optional strings — the shape change is absorbed without a recompile
breakage. Pi's render still needs the migration described in §1.5.

### 1.5 Pi render contract

File: `adapters/pi/furrow.ts:395-402`. Today:

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

After cutover, `blocker.confirmation_path` is the enum token (e.g., `block`)
— interpolating it as `:: fix: block` is meaningless to humans. Migration:

1. Update the `RowStatusData` type at `adapters/pi/furrow.ts:187` to
   declare `remediation_hint?: string` alongside the existing fields.
2. Replace the `confirmation` line so the user-facing prose is sourced
   from `remediation_hint` (verbatim), not `confirmation_path`.
3. `confirmation_path` may still drive a small UX decoration (e.g., a
   leading `[block] ` vs `[warn] ` icon, or no decoration for `silent`),
   but Pi MUST NOT maintain its own `enum → prose` dictionary. The
   registry is the single source of truth for hint text.

Required post-cutover render output (illustrative):

```
- [seed/block] missing_seed_record: linked seed S-123 was not found :: fix: Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend.
```

Acceptance: every prose word visible to the user after `:: fix:` originates
in `schemas/blocker-taxonomy.yaml`'s `remediation_hint` field for that code.

### 1.6 LoadTaxonomy contract

File: `internal/cli/blocker_envelope.go:52-73`. Already validates:
- `version` non-empty
- `blockers[]` non-empty
- per-entry: code/category/message_template/remediation_hint non-empty
- `severity ∈ {block, warn, info}`
- `confirmation_path ∈ {block, warn-with-confirm, silent}`
- code uniqueness

D1 must NOT relax these constraints. New codes added to YAML must satisfy
them or `LoadTaxonomy` returns a non-nil error and the binary fails to
serve any blocker-emitting command (effectively a build-time gate via
the package-init test path at `blocker_envelope_test.go:26-43`).

---

## 2. Acceptance Criteria (Refined)

Each AC below is testable via the verification command shown.

### AC-D1.1 — Taxonomy registry contains ≥21 canonical codes

**Source**: `definition.yaml:15` (≥15 target; team-plan and synthesis
over-cleared to 21).
**Verifies**: `len(LoadTaxonomy().Blockers) >= 21` AND every code in §6
inventory is present.
**Verification**:
```sh
yq -r '.blockers | length' schemas/blocker-taxonomy.yaml   # >= 21
yq -r '.blockers[].code' schemas/blocker-taxonomy.yaml | sort -u | wc -l   # >= 21
go test ./internal/cli -run TestBlockerTaxonomyLoadsAndValidates
```

### AC-D1.2 — Every entry carries the six required fields

**Source**: `definition.yaml:16`.
**Verifies**: `code`, `category`, `severity`, `message_template`,
`remediation_hint`, `confirmation_path` are all populated for every entry;
`applicable_steps` is optional.
**Verification**:
```sh
yq -e '.blockers[] | (has("code") and has("category") and has("severity") and has("message_template") and has("remediation_hint") and has("confirmation_path"))' schemas/blocker-taxonomy.yaml
go test ./internal/cli -run TestBlockerEnvelopeAllInitialCodesResolve   # extended to all 21+ codes
```

### AC-D1.3 — No adapter-specific fields in taxonomy

**Source**: `definition.yaml:16`, constraint at `definition.yaml:126`.
**Verifies**: No top-level or per-entry key matches `^(claude|pi|host|adapter)`.
**Verification**:
```sh
! yq -r '.blockers[] | keys[]' schemas/blocker-taxonomy.yaml | grep -iE '^(claude|pi|host|adapter)'
```

### AC-D1.4 — JSON schema validates the registry

**Source**: `definition.yaml:17`.
**Verifies**: `schemas/blocker-taxonomy.schema.json` (with
`additionalProperties: false` at top level and per-entry) accepts the
extended YAML; `LoadTaxonomy()` succeeds against the new file.
**Verification**:
```sh
# JSON-schema validation (existing schema already supports applicable_steps,
# so D1 likely needs no schema edit; if a new field is introduced, schema
# is updated in lock-step):
ajv validate -s schemas/blocker-taxonomy.schema.json \
             -d <(yq -o=json '.' schemas/blocker-taxonomy.yaml)
go test ./internal/cli -run TestBlockerTaxonomyLoadsAndValidates
```

### AC-D1.5 — Backward-compat for the canonical 11 codes

**Source**: `definition.yaml:18`. Locked plan decision: 11 codes keep
their strings, severities, and `message_template` keys.
**Verifies**: For each of the 11 codes listed in §4 below, the YAML
entry's `code`, `severity`, and the set of placeholders in
`message_template` are unchanged from the pre-D1 file.
**Verification**:
```sh
# Snapshot diff: the 11 canonical entries' code/severity/message_template
# must be byte-identical to the pre-D1 snapshot saved in the test data.
go test ./internal/cli -run TestBlockerTaxonomyBackwardCompat11
```
The Go test (new — added under D1) loads the current YAML, asserts each of
the 11 codes is present, asserts `severity` equals the locked value, and
asserts the placeholder set extracted from `message_template` is identical
to the locked set in `expectedInitialCodes` (extension of
`blocker_envelope_test.go:12-23`).

### AC-D1.6 — `furrow row status --json` emits canonical envelope shape

**Source**: `definition.yaml:19`.
**Verifies**: For every blocker in `data.blockers[]` AND every blocker in
`data.row.gates.pending_blockers[]`, the entry contains the six canonical
fields and only the six canonical fields (plus an optional `details` map).
No `severity == "error"` (the legacy literal). No prose
`confirmation_path`.
**Verification**:
```sh
# Drive a fixture row that produces ≥1 blocker per code path in rowBlockers
# (pending_user_actions / seed_* / supersedence / missing_artifact / etc).
go run ./cmd/furrow row status --json fixture-row | \
  jq -e '.blockers[] | (.severity | IN("block","warn","info")) and (.confirmation_path | IN("block","warn-with-confirm","silent")) and has("remediation_hint") and (.remediation_hint | length > 0)'
go test ./internal/cli -run TestRowStatusEmitsCanonicalBlockers
```

### AC-D1.7 — Sibling status/transition outputs emit canonical envelope shape

**Source**: `definition.yaml:19` ("furrow row status AND any sibling
status/transition outputs").
**Verifies**: `runRowTransition`, `runRowComplete`, archive responses, and
any other JSON-emitting command in `internal/cli/` that surfaces blockers
return the same canonical shape. Audit list per team-plan task 4.
**Verification**:
```sh
go test ./internal/cli -run 'TestRowTransitionEmitsCanonicalBlockers|TestRowCompleteEmitsCanonicalBlockers|TestRowArchiveEmitsCanonicalBlockers'
# Plus a grep gate that no producer constructs a literal severity:"error"
# outside the unregistered-code fallback at blocker_envelope.go:142-149.
! grep -rE '"severity"\s*:\s*"error"' internal/cli/ | grep -v blocker_envelope.go
```

### AC-D1.8 — Pi render uses `remediation_hint`

**Source**: locked plan decision; `team-plan.md:14-15`.
**Verifies**: `formatBlockers` at `adapters/pi/furrow.ts:395-402` sources
post-`:: fix:` text from `blocker.remediation_hint`, NOT
`blocker.confirmation_path`. Pi declares no enum→prose dictionary.
**Verification**:
```sh
# Static check: no large object literal mapping enum tokens to prose
# survives in adapters/pi/.
! grep -rE '("block"|"warn-with-confirm"|"silent")\s*:\s*"' adapters/pi/
# Behavioural check: feed a synthetic envelope through formatBlockers.
cd adapters/pi && bun test furrow.test.ts -t 'formatBlockers uses remediation_hint'
```

### AC-D1.9 — `applicable_steps` filtering compiles and is honored

**Source**: existing schema field at
`schemas/blocker-taxonomy.schema.json:46-50`; codes such as
`ideation_incomplete_definition_fields` (ideate-only),
`archive_requires_review_gate` / `archive_before_review_pass` (review-only)
need step scoping for parity-test correctness.
**Verifies**: Codes carrying a non-empty `applicable_steps` array are
emitted only when the row's current `step` matches; codes with absent
`applicable_steps` apply to every step.
**Verification**:
```sh
# Driven by the parity test under D4, but a unit test under D1 already
# asserts the filter:
go test ./internal/cli -run TestBlockerApplicableStepsFilter
```

### AC-D1.10 — Doc cites the registry as canonical

**Source**: `definition.yaml:20`.
**Verifies**: `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
"Blocker baseline" section (lines 267-300 today) cites
`schemas/blocker-taxonomy.yaml` as canonical and removes prose duplicating
the registry — the bullet list at lines 271-286 is replaced with a pointer.
The "never sufficient by themselves" list (lines 295-301) stays — it is
about completion semantics, not registry content.
**Verification**:
```sh
# Bulleted hard-blocker list is removed; canonical pointer present.
grep -F 'schemas/blocker-taxonomy.yaml' docs/architecture/pi-step-ceremony-and-artifact-enforcement.md
! grep -E '^- direct mutation of canonical workflow state' docs/architecture/pi-step-ceremony-and-artifact-enforcement.md
```

---

## 3. Test Scenarios

### Scenario 3.1: Registry validation accepts extended YAML

- **Verifies**: AC-D1.1, AC-D1.2, AC-D1.4
- **WHEN**: `schemas/blocker-taxonomy.yaml` is the post-D1 file with ≥21
  entries and the loader runs at process start.
- **THEN**: `LoadTaxonomy()` returns a non-nil `*Taxonomy` with no error;
  every entry has all six required fields populated; severity ∈
  `{block, warn, info}`; `confirmation_path` ∈
  `{block, warn-with-confirm, silent}`; codes are unique.
- **Verification**:
  ```sh
  go test ./internal/cli -run TestBlockerTaxonomyLoadsAndValidates -v
  ajv validate -s schemas/blocker-taxonomy.schema.json -d <(yq -o=json '.' schemas/blocker-taxonomy.yaml)
  ```

### Scenario 3.2: Backward-compat for the canonical 11

- **Verifies**: AC-D1.5
- **WHEN**: Any of the 11 pre-D1 codes (`definition_yaml_invalid`, …,
  `ownership_outside_scope` per §4) is resolved through `EmitBlocker`
  with the placeholder set used today
  (`blocker_envelope_test.go:55-64`: `path`, `name`, `value`, `keys`,
  `index`, `row`, `detail`).
- **THEN**: `BlockerEnvelope.Code` matches the input code byte-for-byte,
  `BlockerEnvelope.Severity` matches the locked severity (10 × `block`,
  1 × `warn` for `ownership_outside_scope`), and the rendered `Message`
  contains every placeholder substituted (no `[unfilled placeholder ...]`
  prefix).
- **Verification**:
  ```sh
  go test ./internal/cli -run TestBlockerEnvelopeAllInitialCodesResolve -v
  go test ./internal/cli -run TestBlockerTaxonomyBackwardCompat11 -v
  ```
  The new `TestBlockerTaxonomyBackwardCompat11` asserts byte-identity of
  `code`, `severity`, and the extracted placeholder set against a frozen
  fixture committed with D1.

### Scenario 3.3: `furrow row status` emits canonical envelopes

- **Verifies**: AC-D1.6, AC-D1.7
- **WHEN**: A fixture row in a temp Furrow root is set up with state that
  exercises every emit path in `rowBlockers` (`row_workflow.go:1005-1085`)
  — a pending user action, a closed seed, a missing required artifact,
  an incomplete artifact scaffold, a failing artifact validation, and a
  stalled review-step row pending archive — then `furrow row status
  --json fixture-row` is invoked.
- **THEN**: The `data.blockers[]` array AND `data.row.gates.pending_blockers[]`
  array each contain one entry per condition, every entry has the six
  canonical fields populated with valid enum values, `remediation_hint` is
  non-empty, and no entry contains a top-level field outside
  `{code, category, severity, message, remediation_hint, confirmation_path, details}`.
- **Verification**:
  ```sh
  go test ./internal/cli -run TestRowStatusEmitsCanonicalBlockers -v
  # Snapshot:
  go run ./cmd/furrow row status --json fixture-row > /tmp/status.json
  jq -e '.blockers | all(. ; (.severity | IN("block","warn","info")) and (.confirmation_path | IN("block","warn-with-confirm","silent")) and (.remediation_hint | length > 0))' /tmp/status.json
  jq -e '.blockers | all(. ; (keys - ["code","category","severity","message","remediation_hint","confirmation_path","details"] | length == 0))' /tmp/status.json
  ```

### Scenario 3.4: Pi render uses `remediation_hint` for prose, not `confirmation_path`

- **Verifies**: AC-D1.8
- **WHEN**: `formatBlockers` is called with a synthetic envelope
  `{code:"missing_seed_record", category:"seed", severity:"block",
  message:"linked seed S-123 was not found",
  remediation_hint:"Repair the linked seed state ...",
  confirmation_path:"block"}`.
- **THEN**: The returned string contains the verbatim
  `remediation_hint` text after `:: fix:`, does NOT contain the literal
  word `block` after `:: fix:`, and `confirmation_path` is not
  interpolated into the prose body.
- **Verification**:
  ```sh
  cd adapters/pi && bun test furrow.test.ts -t 'formatBlockers uses remediation_hint'
  # Static gate: no enum→prose dictionary exists in adapters/pi/.
  ! grep -rE '("block"|"warn-with-confirm"|"silent")\s*:\s*"[A-Z]' adapters/pi/
  ```
  A new test case is added to `adapters/pi/furrow.test.ts` under D1.

### Scenario 3.5: `applicable_steps` filtering is honored

- **Verifies**: AC-D1.9
- **WHEN**: A code carrying `applicable_steps: ["ideate"]` (e.g.,
  `ideation_incomplete_definition_fields`) is checked against a row
  whose `state.step == "research"`; AND the same code is checked
  against a row whose `state.step == "ideate"`.
- **THEN**: The first check returns false (code does not apply); the
  second returns true (code applies). For codes with absent
  `applicable_steps`, both checks return true.
- **Verification**:
  ```sh
  go test ./internal/cli -run TestBlockerApplicableStepsFilter -v
  ```
  Test is table-driven over (code, current_step, expected_applies).

### Scenario 3.6: Adapter-agnostic invariant — no host fields in registry

- **Verifies**: AC-D1.3
- **WHEN**: A grep scans `schemas/blocker-taxonomy.yaml` for any key
  matching `^(claude|pi|host|adapter)` or any value containing a
  host-specific token like `tool_call`, `PreToolUse`, `Stop hook`.
- **THEN**: Zero matches.
- **Verification**:
  ```sh
  ! yq -r '.blockers[] | keys[]' schemas/blocker-taxonomy.yaml | grep -iE '^(claude|pi|host|adapter)'
  ! grep -iE '\b(claude|pi-coding-agent|tool_call|PreToolUse)\b' schemas/blocker-taxonomy.yaml
  ```

---

## 4. Implementation Notes

### 4.1 Sequencing within D1 (strict order, each step independently green)

Because D1 spans YAML + 4 Go files + 1 TS file, the migration is sequenced
to keep each phase compilable and testable on its own — classic
expand-contract:

1. **YAML extension (expand)** — add the new entries to
   `schemas/blocker-taxonomy.yaml` per §6 inventory. The 11 existing
   entries are not edited. After this phase, `LoadTaxonomy()` still
   passes; consumers haven't changed.
2. **Schema validator (no-op for D1 unless new top-level field)** —
   `schemas/blocker-taxonomy.schema.json` already supports
   `applicable_steps` (line 46-50). D1 adds **no** new top-level fields.
   Schema edit is required only if the inventory introduces one (none
   planned). If introduced, schema lands before §4.1.3.
3. **Go envelope and loader** — extend
   `internal/cli/blocker_envelope_test.go:12-23` `expectedInitialCodes`
   to include all ≥21 codes. Add a new test
   `TestBlockerTaxonomyBackwardCompat11` (frozen fixture) and a new test
   `TestBlockerApplicableStepsFilter`. The loader at
   `blocker_envelope.go:63-129` does not change — its rules already
   cover the new shape.
4. **`blocker(...)` constructor migration** —
   `internal/cli/row_semantics.go:46-58`: switch to taxonomy lookup.
   New signature accepts `*Taxonomy`, code, `interp` map, `details`
   map. Build per `§1.3`. Delete `blockerConfirmationPath`
   (`row_semantics.go:60-77`); its prose is now in
   `remediation_hint` of the relevant entries.
5. **`rowBlockers` caller migration** — update every emit-site at
   `row_workflow.go:1011-1083` to pass placeholders instead of
   merging detail keys (per §1.3 caller migration map). Status output
   surface stays — `buildRowStatusData` (`row.go:603-663`) forwards
   the new shape unchanged.
6. **Sibling outputs audit (D1 obligation)** — grep
   `internal/cli/` for callers of `rowBlockers` and any other
   ad-hoc free-form-text blocker emission. Migrate them to the
   constructor. Cited callers per
   `research/status-callers-and-pi-shim.md:469-471`: `row.go:201,
   :439, :610` (transition / archive / complete).
7. **Pi render migration (cutover)** —
   `adapters/pi/furrow.ts:187` (type) +
   `adapters/pi/furrow.ts:395-402` (renderer). Update test in
   `adapters/pi/furrow.test.ts`. After this phase the only programmatic
   consumer matches the new wire shape.
8. **Doc update (cutover finalization)** —
   `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:267-300`:
   replace the prose hard-blocker list (lines 271-286) with a citation
   pointer to `schemas/blocker-taxonomy.yaml`. Keep the "never
   sufficient" list (lines 295-301).

### 4.2 Migration discipline (expand-contract)

Phase 1 is pure **expand** — new codes alongside old, no consumer
changes. Even after step 4 (constructor) the runtime change is
internal: the JSON shape consumers see flips on a single deploy.
Because there is exactly one programmatic consumer (Pi) and Pi's
TS type is loose enough to accept both the old and new shape, **no
dual-write window is required** — the cutover is atomic per the
`research/status-callers-and-pi-shim.md:226` finding ("No backward-compat
shim is needed").

The single irreversibility risk: Pi must be in lock-step. The Pi
render edit (step 7) lives inside the same row commit set; it is
deployed together. There is no live-Pi-runtime rollback worry because
`team-plan.md:78` and `definition.yaml:132` explicitly defer live-Pi
invocation to a separate follow-up TODO.

**Rollback story per phase**:

| Phase | Rollback cost | Mechanism |
|---|---|---|
| 1 (YAML extension) | trivial | revert YAML edit; `LoadTaxonomy` passes against old file |
| 3 (Go test extension) | trivial | revert test fixtures |
| 4 (constructor) | low | revert `row_semantics.go` to the pre-D1 commit; sibling status callers don't break because they accept `map[string]any` |
| 5 (caller emit-sites) | low | revert `row_workflow.go` along with phase 4 |
| 6 (sibling outputs) | low | grouped with phase 5 commit |
| 7 (Pi render) | medium | revert TS file; Pi re-renders prose `confirmation_path` (legacy shape) — but the YAML/Go side has already moved, so the prose says `[seed/block] missing_seed_record: ... :: fix: block` which is degraded UX, not broken contract. **Mitigation**: phases 1-7 ship in one commit row. |
| 8 (doc) | trivial | revert markdown |

### 4.3 Locked backward-compat — the canonical 11 code strings

These code strings, severities, and `message_template` placeholder sets
are immutable in D1. Drift fails `TestBlockerTaxonomyBackwardCompat11`.

| Code | Severity | Placeholders |
|---|---|---|
| `definition_yaml_invalid` | block | `{path}`, `{detail}` |
| `definition_objective_missing` | block | `{path}` |
| `definition_gate_policy_missing` | block | `{path}` |
| `definition_gate_policy_invalid` | block | `{path}`, `{value}` |
| `definition_mode_invalid` | block | `{path}`, `{value}` |
| `definition_deliverables_empty` | block | `{path}` |
| `definition_deliverable_name_missing` | block | `{path}`, `{index}` |
| `definition_deliverable_name_invalid_pattern` | block | `{path}`, `{name}` |
| `definition_acceptance_criteria_placeholder` | block | `{path}`, `{name}`, `{value}` |
| `definition_unknown_keys` | block | `{path}`, `{keys}` |
| `ownership_outside_scope` | warn | `{path}`, `{row}` |

Source for severity and placeholders: `schemas/blocker-taxonomy.yaml:14-91`
(pre-D1 file).

### 4.4 New code naming conventions

- Hook-emit codes use the snake_case names proposed in
  `research/hook-audit.md` (e.g., `state_json_direct_write`,
  `correction_limit_reached`).
- Soft-emit (warn-only) sites that share semantics with a block-only code
  use the same code name with `_warn` suffix (e.g.,
  `summary_section_missing_warn`). This is the locked Option A from
  `research/hook-audit.md:181-184`. Severity is per-code; sharing across
  emit-sites would violate the registry shape.
- Go-side codes (state-mutation, gate, archive, supervised-boundary)
  follow the pattern `<noun>_<verb>` or `<noun>_<state>` (e.g.,
  `step_order_invalid`, `archive_before_review_pass`,
  `archived_row_mutation`).

### 4.5 Test mode panic discipline

`EmitBlocker` panics on unregistered codes in test mode
(`blocker_envelope.go:139-141`). D1 must not regress this — every code
the row emits in any test path must exist in the YAML before that test
runs. In particular `expectedInitialCodes` at
`blocker_envelope_test.go:12-23` is extended to include all ≥21 entries
so `TestBlockerEnvelopeAllInitialCodesResolve` covers the full inventory.

### 4.6 Coordination with parallel D5 (`doc-contradiction-reconciliation`)

D5 edits `pi-almanac-operating-model.md`, `migration-stance.md`,
`go-cli-contract.md`, `documentation-authority-taxonomy.md`. D1 edits
`pi-step-ceremony-and-artifact-enforcement.md`. **No file-glob conflict**
(team-plan §"Specialist conflict map", line 85). D1 and D5 may both run in
wave 1 with no merge coordination beyond the row-level commit.

---

## 5. Dependencies

**Hard deps**: none. D1 is wave 1; the only inputs are the existing
registry, Go types, Pi render, and source docs that already exist on the
branch.

**Soft deps**:
- D1's hand-off to wave 2 (`team-plan.md:19`) is: `Taxonomy` and
  `BlockerEnvelope` types compile, `LoadTaxonomy` passes against new
  YAML, canonical envelope shape ratified. D2 (`normalized-blocker-event-and-go-emission-path`)
  cannot start until this is true.
- D3 (hook migration) consumes D2's `furrow guard` entry point, which in
  turn requires D1's extended taxonomy — D1 → D2 → D3 is the chain.
- D4 (parity tests) requires every hook-emit code in §6 below to exist
  in the registry; D1 satisfies that contract.

**Build/runtime deps already present** (no new imports):
- `gopkg.in/yaml.v3` (YAML loader, `blocker_envelope.go:12`).
- Existing `findFurrowRoot`, `interpolate`, `unresolvedPlaceholders`
  helpers in `internal/cli/`.
- `bun` (Pi adapter test runner; `adapters/pi/package.json`).
- `yq`, `jq`, `ajv` (CLI test verification; already used elsewhere).

---

## 6. Final Code Inventory (≥21 canonical codes)

The inventory is the union of:
- **11 pre-D1 codes** (kept verbatim per AC-D1.5)
- **11 hook-emit codes** from `research/hook-audit.md` §3
- **10 Go-side enforcement codes** from
  `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:271-286`
  and `research/hook-audit.md:254-264`
- minus duplicates where a Go-side code already covers the same condition
  as a hook (none — the hook codes guard direct-write surfaces, the Go
  codes enforce post-mutation invariants).

Total entries listed below: **32** (11 pre-D1 + 11 hook + 10 Go-side).
This comfortably exceeds the ≥21 lower bound and the ≥15 AC threshold,
and matches the `team-plan.md:10` figure ("≥21").

### 6.1 Pre-D1 codes (kept verbatim — backward-compat)

| Code | Category | Severity | Confirmation Path | Applicable Steps | Emit Site |
|---|---|---|---|---|---|
| `definition_yaml_invalid` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_objective_missing` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_gate_policy_missing` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_gate_policy_invalid` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_mode_invalid` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_deliverables_empty` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_deliverable_name_missing` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_deliverable_name_invalid_pattern` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_acceptance_criteria_placeholder` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `definition_unknown_keys` | definition | block | block | (any) | `cmd/furrow validate definition` (Go) |
| `ownership_outside_scope` | ownership | warn | warn-with-confirm | (any) | `cmd/furrow validate ownership` (Go) |

### 6.2 Hook-emit codes (new — from `research/hook-audit.md` §3)

| Code | Category | Severity | Confirmation Path | Applicable Steps | Emit Site |
|---|---|---|---|---|---|
| `correction_limit_reached` | state-mutation | block | block | implement | `bin/frw.d/hooks/correction-limit.sh` (`hook-audit.md` §2.1) |
| `precommit_install_artifact_staged` | scaffold | block | block | (any) | `bin/frw.d/hooks/pre-commit-bakfiles.sh` (`hook-audit.md` §2.3) |
| `precommit_script_mode_invalid` | scaffold | block | block | (any) | `bin/frw.d/hooks/pre-commit-script-modes.sh` (`hook-audit.md` §2.4) |
| `precommit_typechange_to_symlink` | scaffold | block | block | (any) | `bin/frw.d/hooks/pre-commit-typechange.sh` (`hook-audit.md` §2.5) |
| `script_guard_internal_invocation` | scaffold | block | block | (any) | `bin/frw.d/hooks/script-guard.sh` (`hook-audit.md` §2.6) |
| `state_json_direct_write` | state-mutation | block | block | (any) | `bin/frw.d/hooks/state-guard.sh` (`hook-audit.md` §2.7) |
| `ideation_incomplete_definition_fields` | ideation | block | block | ideate | `bin/frw.d/hooks/stop-ideation.sh` (`hook-audit.md` §2.8) |
| `summary_section_missing` | summary | block | block | research, plan, spec, decompose, implement, review | `bin/frw.d/hooks/validate-summary.sh` (`hook-audit.md` §2.9) |
| `summary_section_empty` | summary | block | block | research, plan, spec, decompose, implement, review | `bin/frw.d/hooks/validate-summary.sh` (`hook-audit.md` §2.9) |
| `verdict_direct_write` | gate | block | block | (any) | `bin/frw.d/hooks/verdict-guard.sh` (`hook-audit.md` §2.10) |
| `state_validation_failed_warn` | state-mutation | warn | silent | (any) | `bin/frw.d/hooks/work-check.sh` (`hook-audit.md` §2.11) |

Notes:
- `summary_section_missing` and `summary_section_empty` carry
  `applicable_steps` because the ideate step has different required-section
  semantics (`hook-audit.md:152`).
- `work-check.sh` also emits warn-only variants of the summary codes per
  `hook-audit.md:181-184`. Locked decision: **Option A** (separate
  `_warn`-suffixed codes). The two extra codes are listed as Go-side
  emissions in §6.3 because the warning is generated at Stop boundary
  through the same Go path that subsumes `validate-summary.sh`.

### 6.3 Go-side enforcement codes (new — from `pi-step-ceremony-and-artifact-enforcement.md:271-286` + work-check.sh warn variants)

| Code | Category | Severity | Confirmation Path | Applicable Steps | Emit Site |
|---|---|---|---|---|---|
| `pending_user_action_unresolved` | state-mutation | block | block | (any) | `rowBlockers` `pending_user_actions` path (`row_workflow.go:1011-1013`); also `rws_transition` |
| `step_order_invalid` | state-mutation | block | block | (any) | `rws_transition` (Go-side) |
| `decided_by_invalid_for_policy` | gate | block | block | (any) | `rws_transition` (Go-side) |
| `nonce_stale` | gate | block | block | (any) | `rws_transition` evaluator-result check (Go-side) |
| `verdict_linkage_missing` | gate | block | block | (any) | `rws_transition` evaluated-gate check (Go-side; gap noted in `hook-audit.md:247`) |
| `archive_before_review_pass` | archive | block | block | review | `rowBlockers` archive guard at `row_workflow.go:1079-1082` (existing code `archive_requires_review_gate` is renamed for inventory-baseline alignment; backward-compat alias retained — see Note A) |
| `archived_row_mutation` | archive | block | block | (any) | `rws_transition` archived-state guard (Go-side) |
| `supervised_boundary_unconfirmed` | gate | block | block | (any) | `rws_transition` supervised-policy guard (Go-side) |
| `summary_section_missing_warn` | summary | warn | silent | (any) | Go-side summary check invoked from `work-check.sh` (`hook-audit.md` §2.11) |
| `summary_section_empty_warn` | summary | warn | silent | (any) | Go-side summary check invoked from `work-check.sh` (`hook-audit.md` §2.11) |

**Note A — `archive_requires_review_gate` reconciliation**: the pre-D1
constructor at `row_workflow.go:1081` emits the literal code
`archive_requires_review_gate`. Because D1 locks the 11 pre-D1 codes only
(`ownership_outside_scope` + 10 `definition_*`), this code is **not**
covered by AC-D1.5. The implementer has two options:
- **(preferred)** rename the emit-site to `archive_before_review_pass`
  to align with `pi-step-ceremony-and-artifact-enforcement.md:284`, and
  delete the legacy code. Pi tolerates the rename (no Pi logic depends on
  the code string). Update the relevant `archive` `remediation_hint`
  accordingly (sourced from the prose at `row_semantics.go:72-73`).
- **(fallback)** keep `archive_requires_review_gate` and add it to
  inventory in §6.3 in addition to `archive_before_review_pass`. Both
  codes coexist; only one is emitted. Less clean — registry grows by an
  extra entry that exists only for naming continuity.

The spec does not pre-decide; the implement step picks one and records
the choice in the row's `summary.md` Settled Decisions section.

### 6.4 Existing Go-side codes that already use the constructor (from `row_workflow.go:1011-1083`)

These codes are emitted today via the legacy `blocker(...)` constructor
shape. After D1 they pass through the new constructor and must have
registry entries. They are listed for completeness — they are part of
the pre-D1 corpus but are NOT in the locked-11 backward-compat set
because they were never in `schemas/blocker-taxonomy.yaml` pre-D1.

| Code | Category | Severity | Confirmation Path | Applicable Steps | Emit Site |
|---|---|---|---|---|---|
| `pending_user_actions` | state-mutation | block | block | (any) | `row_workflow.go:1012` (alias for `pending_user_action_unresolved` — see Note A above; pick one) |
| `seed_store_unavailable` | seed | block | block | (any) | `row_workflow.go:1017` |
| `missing_seed_record` | seed | block | block | (any) | `row_workflow.go:1019` |
| `closed_seed` | seed | block | block | (any) | `row_workflow.go:1021` |
| `seed_status_mismatch` | seed | block | block | (any) | `row_workflow.go:1023` |
| `supersedence_evidence_missing` | archive | block | block | (any) | `row_workflow.go:1039-1058` |
| `missing_required_artifact` | artifact | block | block | (any) | `row_workflow.go:1068` |
| `artifact_scaffold_incomplete` | artifact | block | block | (any) | `row_workflow.go:1072` |
| `artifact_validation_failed` | artifact | block | block | (any) | `row_workflow.go:1076` |

These overlap with §6.3's seed-state and artifact-validation entries.
Reconciliation rule for D1 (locked):
- Use the **existing** emit-site code names in the registry
  (`missing_seed_record`, `closed_seed`, `seed_status_mismatch`,
  `seed_store_unavailable`, `missing_required_artifact`,
  `artifact_scaffold_incomplete`, `artifact_validation_failed`,
  `supersedence_evidence_missing`, `pending_user_actions`).
- Do NOT introduce duplicate `seed_missing` / `seed_closed` / `seed_invalid`
  codes from `hook-audit.md:249,256` — the existing names cover the
  same conditions and changing them creates churn for the only
  consumer (Pi).
- Add `archive_before_review_pass`, `archived_row_mutation`,
  `step_order_invalid`, `decided_by_invalid_for_policy`, `nonce_stale`,
  `verdict_linkage_missing`, `supervised_boundary_unconfirmed`,
  `pending_user_action_unresolved` (or alias to `pending_user_actions`)
  as fresh registry entries even when the Go emit-site is not yet
  routed through the constructor — this is the registry catching up
  to the baseline list.

### 6.5 Inventory totals

| Source | Count |
|---|---|
| Pre-D1 (locked) | 11 |
| Hook-emit (new) | 11 |
| Go-side (new — baseline + work-check warn variants) | 10 |
| Existing emit-site codes that need registry entries | 9 (3 of which alias §6.3 entries — see §6.4 reconciliation) |
| **Final registry size** (after dedup per §6.4) | **32–34** depending on Note A resolution |

The implement-step output is the post-dedup registry. AC-D1.1 (≥21)
is satisfied with comfortable margin.

---

## Sources

- `definition.yaml:13-31` — D1 acceptance criteria, file_ownership,
  specialist
- `team-plan.md:5-19` — D1 task list, hand-off to wave 2
- `research/synthesis.md:14-19` — single-point migration claim, ≥21 codes
  total, no shim required
- `research/hook-audit.md:34, §2.1-§2.11, §3, §4, §5` — per-hook proposed
  codes, helper extraction, baseline gap analysis
- `research/status-callers-and-pi-shim.md` §A — `blocker(...)` divergence
  axes, caller inventory, migration plan
- `schemas/blocker-taxonomy.yaml:1-91` — current 11-code registry
- `schemas/blocker-taxonomy.schema.json:1-55` — JSON schema (top-level
  + per-entry shape)
- `internal/cli/blocker_envelope.go:15-46, :63-159` — Go types, validation
  enums, loader contract, `EmitBlocker`
- `internal/cli/blocker_envelope_test.go:12-23` — locked
  `expectedInitialCodes`
- `internal/cli/row_semantics.go:46-77` — `blocker(...)` constructor,
  `blockerConfirmationPath`
- `internal/cli/row_workflow.go:1005-1085` — `rowBlockers` emit-sites
- `internal/cli/row.go:603-663` — `buildRowStatusData` blockers surface
- `adapters/pi/furrow.ts:187, :395-402` — `RowStatusData.blockers` type,
  `formatBlockers` render
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:267-300`
  — Blocker baseline (source of truth for ≥15 → ≥21)
