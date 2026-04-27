// dispatch.test.ts — Regression test for R5: shell injection safety in
// dispatchEngineAsSubprocess.
//
// Verifies that dispatchEngineAsSubprocess uses execFileSync with an args array
// rather than shell string interpolation, so shell metacharacters in the
// EngineHandoff markdown are never evaluated by a shell.

import { describe, expect, test, mock } from "bun:test";

// ---------------------------------------------------------------------------
// Captured call registry — populated by the mock before import
// ---------------------------------------------------------------------------

const capturedCalls: Array<{ file: string; args: string[]; options: unknown }> = [];

// Use Bun's module mocking to intercept node:child_process before the
// extension module is imported.
mock.module("node:child_process", () => ({
  execFileSync: (file: string, args: string[], options?: unknown): string => {
    capturedCalls.push({ file, args, options });
    return "mock engine output";
  },
  // Preserve other exports as no-ops (execSync is no longer imported by index.ts)
  execSync: () => {
    throw new Error("execSync must not be called — R5 regression: shell injection risk");
  },
}));

// Import AFTER mock.module so the mock is in effect.
const { FurrowPiAdapter } = await import("./extension/index.ts");

// ---------------------------------------------------------------------------
// Regression test: R5 — shell injection safety
// ---------------------------------------------------------------------------

describe("dispatchEngineAsSubprocess — shell injection safety (R5)", () => {
  test("passes handoff markdown verbatim as args-array element — no shell interpolation", () => {
    capturedCalls.length = 0;
    const adapter = new FurrowPiAdapter();
    const maliciousMarkdown =
      "hello `rm -rf /` world\n$(echo injected)\nbacktick`test`end";

    const result = adapter.dispatchEngineAsSubprocess(maliciousMarkdown);

    expect(capturedCalls).toHaveLength(1);
    const call = capturedCalls[0];

    // Must invoke 'pi' as a file, not a shell
    expect(call.file).toBe("pi");
    // First arg must be '--prompt' (args-array form)
    expect(call.args[0]).toBe("--prompt");
    // Second arg must be the exact, unescaped markdown — no shell metachar mangling
    expect(call.args[1]).toBe(maliciousMarkdown);
    // Must NOT have applied the old replace(/"/g, '\\"') escaping
    expect(call.args[1]).not.toContain('\\"');
    // Return value must be the stdout string
    expect(result).toBe("mock engine output");
  });

  test("backtick content is NOT shell-evaluated — R5 attack surface", () => {
    capturedCalls.length = 0;
    const adapter = new FurrowPiAdapter();
    // Backticks were the specific metacharacter class NOT handled by the old
    // replace(/"/g, '\\"') escaping — this is the exact R5 attack surface.
    const backtickHandoff =
      "# Engine Brief\n\nRun: `furrow status`\nResult: `$(date)`";

    adapter.dispatchEngineAsSubprocess(backtickHandoff);

    expect(capturedCalls).toHaveLength(1);
    // Passed verbatim — not shell-expanded
    expect(capturedCalls[0].args[1]).toBe(backtickHandoff);
  });

  test("newlines and dollar signs are passed verbatim — not expanded", () => {
    capturedCalls.length = 0;
    const adapter = new FurrowPiAdapter();
    const envVarHandoff = "step: $STEP\npath: ${HOME}/.furrow\ntoken: $SECRET_TOKEN";

    adapter.dispatchEngineAsSubprocess(envVarHandoff);

    expect(capturedCalls).toHaveLength(1);
    expect(capturedCalls[0].args[1]).toBe(envVarHandoff);
  });

  test("execSync is never called (removed in R5 fix)", () => {
    // The mock above throws if execSync is called. This test confirms no throw
    // occurs during normal dispatchEngineAsSubprocess execution.
    capturedCalls.length = 0;
    const adapter = new FurrowPiAdapter();

    expect(() => adapter.dispatchEngineAsSubprocess("safe content")).not.toThrow();
    // And the execFileSync mock was what got called
    expect(capturedCalls).toHaveLength(1);
  });
});
