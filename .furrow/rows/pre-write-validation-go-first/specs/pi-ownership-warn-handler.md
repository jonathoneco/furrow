# Spec: pi-ownership-warn-handler (D5, wave 5)

## Interface Contract

### Pi adapter `tool_call` handler

In `adapters/pi/furrow.ts`, add a handler (after D4's validate-definition handler):

```typescript
pi.on("tool_call", async (event, ctx) => {
  if (event.tool_name !== "Write" && event.tool_name !== "Edit") return;
  const filePath = event.tool_input?.file_path ?? event.tool_input?.path;
  if (typeof filePath !== "string") return;

  const result = await runFurrowJson<ValidateOwnershipData>(
    root, ["validate", "ownership", "--path", filePath, "--json"], ctx.signal
  );
  const data = result.envelope?.data;
  if (data?.verdict === "out_of_scope") {
    const proceed = await ctx.ui.confirm(
      "This file is outside the deliverable file_ownership. Proceed anyway?",
      data.envelope?.message ?? ""
    );
    if (!proceed) {
      return { block: true, reason: data.envelope?.message ?? "ownership violation" };
    }
  }
  // in_scope or not_applicable → silent allow
});

interface ValidateOwnershipData {
  ok: boolean;
  verdict: "in_scope" | "out_of_scope" | "not_applicable";
  matched_deliverable?: string;
  matched_glob?: string;
  reason?: string;
  envelope?: {
    code: string;
    category: string;
    severity: string;
    message: string;
    remediation_hint: string;
    confirmation_path: string;
  };
}
```

### parity-verification.md (NEW — D5 authors header + Pi rows; D6 appends Claude rows in wave 6)

File: `.furrow/rows/pre-write-validation-go-first/parity-verification.md`

```markdown
# Cross-adapter parity verification — pre-write-validation-go-first

This document records paired Pi-side and Claude-side observations for the same Go-validator outputs, proving that the cross-adapter parity invariant from definition.yaml constraint #4 holds: identical step-agnostic non-blocking awareness on both runtimes, with intrinsic UX divergence (Pi: interactive confirm; Claude: log_warning).

## Paired scenarios

| # | Scenario | Input path | Input row | Go validator verdict (D2) | Pi handler outcome (D5) | Claude hook outcome (D6) | Parity OK? | Notes |
|---|---|---|---|---|---|---|---|---|
| 1 | in_scope match | (filled by D5) | (filled by D5) | (filled by D5) | (filled by D5) | (filled by D6) | yes | (filled by D5) |
| 2 | out_of_scope | ... | ... | ... | confirm prompt fires | log_warning fires | yes | UX divergence is intrinsic and accepted |
| 3 | not_applicable (no row) | ... | (none) | not_applicable / no_active_row | silent allow | silent allow | yes | ... |

## Methodology

(Filled by D5/D6.)
```

D5 fills rows 1-3 with concrete Pi observations. D6 (wave 6) fills the Claude column for each row.

## Acceptance Criteria (Refined)

1. Pi adapter has a new `tool_call` handler intercepting all Write and Edit tool calls (not gated to `*/definition.yaml`).
2. Handler invokes `furrow validate ownership --path <filePath> --json`; verdict drives behavior:
   - `in_scope`: silent allow (no notify, no block)
   - `out_of_scope`: `ctx.ui.confirm(...)` fires; user "yes" returns `{block: false}`; user "no" returns `{block: true, reason: <message>}`
   - `not_applicable`: silent allow
3. Step-agnostic: handler does NOT read `state.step` to gate behavior. Verified by test running same input across multiple state.step values; outcome identical.
4. Handler runs AFTER D4's validate-definition handler in the chain. Both can fire on the same Write/Edit (a write to `*/definition.yaml` triggers both validators).
5. `furrow.test.ts` extended with at least 4 new test cases: in_scope (silent), out_of_scope confirmed-proceed, out_of_scope rejected-block, not_applicable.
6. `parity-verification.md` is authored with header + 3 paired-scenario table rows; Pi columns filled with concrete observations from runs against fixture rows. Claude columns left as `(filled by D6)` placeholders.
7. `bun test` (in `adapters/pi/`) passes.
8. No modifications to `internal/cli/` (those are D2's). No modifications to `adapters/pi/package.json`, `tsconfig.json`, `README.md` (those are D4's).

## Test Scenarios

### Scenario: in-scope-silent-allow
- **Verifies**: AC #2 in_scope branch
- **WHEN**: mock `runFurrowJson` returns `{verdict: "in_scope", matched_deliverable: "x", matched_glob: "y"}`; handler invoked
- **THEN**: handler returns void; ctx.ui.confirm NOT called; ctx.ui.notify NOT called
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "ownership in_scope is silent"`

### Scenario: out-of-scope-confirmed
- **Verifies**: AC #2 out_of_scope branch (proceed)
- **WHEN**: mock returns `{verdict: "out_of_scope", envelope: {message: "..."}}`; mock `ctx.ui.confirm` returns `true`
- **THEN**: handler returns void (no block); ctx.ui.confirm called once
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "ownership out_of_scope confirmed proceeds"`

### Scenario: out-of-scope-rejected
- **Verifies**: AC #2 out_of_scope branch (block)
- **WHEN**: mock returns `{verdict: "out_of_scope"}`; mock `ctx.ui.confirm` returns `false`
- **THEN**: handler returns `{block: true, reason: ...}`
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "ownership out_of_scope rejected blocks"`

### Scenario: not-applicable-silent
- **Verifies**: AC #2 not_applicable branch
- **WHEN**: mock returns `{verdict: "not_applicable", reason: "no_active_row"}`
- **THEN**: silent allow
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "ownership not_applicable is silent"`

### Scenario: step-agnostic-verdict
- **Verifies**: AC #3
- **WHEN**: same path/row across state.step values [ideate, plan, implement]; handler invoked each time
- **THEN**: handler outcome identical across runs (specifically: out_of_scope confirms fire identically regardless of step)
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "ownership handler is step-agnostic"`

### Scenario: chain-order-after-d4
- **Verifies**: AC #4
- **WHEN**: source-order inspection of adapters/pi/furrow.ts
- **THEN**: D4's `*/definition.yaml`-matching handler appears before D5's all-Write/Edit handler
- **Verification**: `awk '/\\*\\/definition.yaml/{vd=NR} /validate.+ownership/{vo=NR} END{exit !(vd<vo)}' adapters/pi/furrow.ts && echo OK`

### Scenario: parity-verification-md-scaffold-authored
- **Verifies**: AC #6
- **WHEN**: file `.furrow/rows/pre-write-validation-go-first/parity-verification.md` exists
- **THEN**: file contains the table header row and at least 3 paired-scenario rows; the "Claude hook outcome" column for each row contains either a concrete value or the placeholder `(filled by D6)`
- **Verification**: `test -f .furrow/rows/pre-write-validation-go-first/parity-verification.md && grep -c '^|' .furrow/rows/pre-write-validation-go-first/parity-verification.md` (returns >= 5: header + separator + 3 data rows)

## Implementation Notes

- ctx.ui.confirm is async; await it before deciding the return value.
- Test mocks: bun's `mock()` for runFurrowJson and ctx.ui.confirm.
- The handler runs on EVERY Write/Edit, including writes to definition.yaml (which D4 also intercepts). Both fire; D4's runs first for definition.yaml, then D5's. This is correct: a definition.yaml write that's invalid (D4 blocks) never reaches D5; an out-of-scope definition.yaml write (D5 confirms) is fine because D4 already validated.
- parity-verification.md is the FIRST instance of this file in the row; D5 owns the file scaffolding entirely. D6 in wave 6 only appends.

## Dependencies

- D2 (validate-ownership-go) — wave 3: provides the `furrow validate ownership` CLI command.
- D3 (blocker-taxonomy-schema) — wave 1: D2's error envelope follows this taxonomy; D5 surfaces the message.
- D4 (pi-validate-definition-handler) — wave 4: established the Pi test scaffolding (`package.json`, `tsconfig.json`, first `furrow.test.ts`); D5 extends `furrow.test.ts` with new tests; ownership of those scaffold files remains with D4.
- `runFurrowJson` (existing pattern) at `adapters/pi/furrow.ts:313-346`.
