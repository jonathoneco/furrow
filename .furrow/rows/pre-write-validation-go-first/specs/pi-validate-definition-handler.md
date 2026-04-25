# Spec: pi-validate-definition-handler (D4, wave 4)

## Interface Contract

### Pi adapter `tool_call` handler

In `adapters/pi/furrow.ts`, register a new handler in the `pi.on("tool_call", ...)` chain (after the existing state-guard interceptor at lines 883-899) that:

```typescript
pi.on("tool_call", async (event, ctx) => {
  // existing state-guard runs first; this handler runs after if state-guard didn't block
  if (event.tool_name !== "Write" && event.tool_name !== "Edit") return;
  const filePath = event.tool_input?.file_path ?? event.tool_input?.path;
  if (typeof filePath !== "string") return;
  // only intercept writes to definition.yaml files
  if (!filePath.endsWith("/definition.yaml")) return;

  const result = await runFurrowJson<ValidateDefinitionData>(
    root, ["validate", "definition", "--path", filePath, "--json"], ctx.signal
  );
  if (result.envelope?.data?.verdict === "invalid") {
    const errs = result.envelope.data.errors ?? [];
    const message = errs.map(e => e.message).join("; ");
    ctx.ui.notify(message, "error");
    return { block: true, reason: message };
  }
});

interface ValidateDefinitionData {
  ok: boolean;
  verdict: "valid" | "invalid";
  errors?: Array<{
    code: string;
    category: string;
    severity: string;
    message: string;
    remediation_hint: string;
    confirmation_path: string;
  }>;
}
```

### Pi adapter test scaffolding (NEW — bootstrap)

- `adapters/pi/package.json`:
  ```json
  {
    "name": "@furrow/pi-adapter",
    "version": "0.1.0",
    "private": true,
    "scripts": {
      "test": "bun test"
    },
    "type": "module"
  }
  ```
- `adapters/pi/tsconfig.json`:
  ```json
  {
    "compilerOptions": {
      "target": "ES2022",
      "module": "ESNext",
      "moduleResolution": "bundler",
      "strict": true,
      "esModuleInterop": true,
      "skipLibCheck": true,
      "types": ["bun-types"]
    },
    "include": ["*.ts"]
  }
  ```
- `adapters/pi/furrow.test.ts`: first test file, exercising the new handler against fixture row.

### README footnote

`adapters/pi/README.md` gains one paragraph noting:
> Pre-write validation handlers (validate-definition, ownership-warn) shell out to the Go backend via `runFurrowJson` (`go run ./cmd/furrow ...`). Cold-start latency is ~45ms per call; double-fire on every Write/Edit. Optimization is tracked under almanac todo `pi-adapter-binary-caching` (build the binary once at adapter init, exec the path).

## Acceptance Criteria (Refined)

1. Loading the Pi adapter registers a `tool_call` handler that intercepts Write and Edit tool calls with target file_path matching `*/definition.yaml`.
2. On a valid definition.yaml: `runFurrowJson` returns `verdict: valid`; handler returns void / no block; tool call proceeds.
3. On an invalid definition.yaml: handler returns `{ block: true, reason: <interpolated message> }` AND calls `ctx.ui.notify(message, "error")`. Tool call does NOT proceed.
4. Existing state-guard handler at lines 883-899 is unchanged and runs first in the handler chain.
5. `adapters/pi/package.json`, `tsconfig.json`, `furrow.test.ts` are created with the contents above (or equivalent minimal scaffolding).
6. `bun test` (run in `adapters/pi/`) passes; tests cover the valid and invalid handler branches.
7. `adapters/pi/README.md` gains the footnote referenced above (~3-5 lines).

## Test Scenarios

### Scenario: valid-definition-yaml-passes
- **Verifies**: AC #2
- **WHEN**: a fixture project with a valid definition.yaml; mock `runFurrowJson` to return `{verdict: "valid"}`; handler invoked with `tool_input.file_path = "valid/path/definition.yaml"`
- **THEN**: handler returns no block; ctx.ui.notify is NOT called
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "valid definition passes"`

### Scenario: invalid-definition-yaml-blocks
- **Verifies**: AC #3
- **WHEN**: mock `runFurrowJson` to return `{verdict: "invalid", errors: [{code: "definition_objective_missing", message: "missing objective"}]}`; handler invoked with `file_path = "invalid/path/definition.yaml"`
- **THEN**: handler returns `{block: true, reason: "missing objective"}`; ctx.ui.notify called with `("missing objective", "error")`
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "invalid definition blocks"`

### Scenario: non-definition-file-no-op
- **Verifies**: AC #1
- **WHEN**: handler invoked with `file_path = "src/foo.ts"`
- **THEN**: handler returns void without calling runFurrowJson
- **Verification**: `cd adapters/pi && bun test furrow.test.ts -t "non-definition file is not intercepted"`

### Scenario: state-guard-runs-first
- **Verifies**: AC #4
- **WHEN**: handler order in adapters/pi/furrow.ts inspected; the existing state-guard interceptor (lines 883-899 prior to D4) appears earlier in the file than D4's new handler registration
- **THEN**: state-guard appears before D4's handler in source order
- **Verification**: `awk '/Blocked direct mutation of canonical Furrow state/{sg=NR} /\\*\\/definition.yaml/{vd=NR} END{exit !(sg<vd)}' adapters/pi/furrow.ts && echo OK`

### Scenario: readme-footnote-present
- **Verifies**: AC #7
- **WHEN**: grep adapters/pi/README.md for `pi-adapter-binary-caching` (the follow-up todo named in the footnote)
- **THEN**: at least one line matches
- **Verification**: `grep -q 'pi-adapter-binary-caching' adapters/pi/README.md && echo OK`

## Implementation Notes

- Mock `runFurrowJson` via test-fixture injection or by mocking the `execFileAsync` it calls. Bun's built-in mock module (`bun:test`'s `mock()`) handles this.
- The handler chain runs in registration order; this handler must be added AFTER the state-guard handler to preserve current state-protection behavior (state-guard returns `{block: true}` for canonical state.json mutations and short-circuits the chain).
- Error envelope `errors[]` may have multiple entries; concatenate messages with `"; "` for the `reason` field and the `notify` text. Don't truncate; the user wants to see all violations.
- README footnote should be discoverable by readers exploring the adapter code; place near the top of any "Behavior" or "Hooks" section.

## Dependencies

- D1 (validate-definition-go) — wave 2: provides the `furrow validate definition` CLI command D4 invokes.
- D3 (blocker-taxonomy-schema) — wave 1: D1's error envelopes follow this taxonomy; D4 just relays them.
- `runFurrowJson` (existing pattern) at `adapters/pi/furrow.ts:313-346` — D4 reuses unchanged.
- Existing state-guard `tool_call` interceptor at `adapters/pi/furrow.ts:883-899` — D4 registers AFTER this in the chain.
