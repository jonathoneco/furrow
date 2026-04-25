// furrow.test.ts — Pi adapter contract tests against the Furrow Go CLI.
//
// These tests verify the JSON envelope shapes that adapters/pi/furrow.ts
// handlers depend on. They invoke the real `furrow` binary and assert the
// envelope structure matches what runFurrowJson<T>() expects.
//
// Bootstrapped by D4 of pre-write-validation-go-first. Subsequent deliverables
// (D5) extend this file with their own contract tests; do not delete this file
// or the scaffolding around it.

import { describe, expect, test, beforeAll } from "bun:test";
import { mkdtemp, writeFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

const execFileAsync = promisify(execFile);

const projectRoot = resolve(import.meta.dir, "..", "..");

async function runFurrow(args: string[], cwd = projectRoot): Promise<{ exitCode: number; stdout: string }> {
	try {
		const { stdout } = await execFileAsync("go", ["run", "./cmd/furrow", ...args], { cwd });
		return { exitCode: 0, stdout };
	} catch (error: any) {
		return {
			exitCode: typeof error?.code === "number" ? error.code : 1,
			stdout: String(error?.stdout ?? ""),
		};
	}
}

const validDefinitionFixture = `objective: "pi adapter contract test fixture"
deliverables:
  - name: thing
    acceptance_criteria:
      - "thing does the thing"
context_pointers:
  - path: "/tmp/foo"
    note: "fixture pointer"
constraints: []
gate_policy: supervised
mode: code
`;

const invalidDefinitionFixture = `deliverables: []
context_pointers:
  - path: "/tmp/foo"
    note: "n"
constraints: []
gate_policy: bogus_value
`;

describe("furrow validate definition (D1 contract — consumed by D4 Pi handler)", () => {
	let workDir: string;
	let validPath: string;
	let invalidPath: string;

	beforeAll(async () => {
		workDir = await mkdtemp(join(tmpdir(), "pi-furrow-test-"));
		validPath = join(workDir, "valid-definition.yaml");
		invalidPath = join(workDir, "invalid-definition.yaml");
		await writeFile(validPath, validDefinitionFixture);
		await writeFile(invalidPath, invalidDefinitionFixture);
	});

	test("valid definition.yaml: exit 0, envelope.data.verdict === 'valid'", async () => {
		const { exitCode, stdout } = await runFurrow(["validate", "definition", "--path", validPath, "--json"]);
		expect(exitCode).toBe(0);
		const envelope = JSON.parse(stdout);
		expect(envelope.ok).toBe(true);
		expect(envelope.data.verdict).toBe("valid");
	});

	test("invalid definition.yaml: non-zero exit, envelope.data.verdict === 'invalid', errors[] non-empty", async () => {
		// Note: through `go run`, exit code 3 from the Go binary surfaces as 1 from the wrapper.
		// Pi handler reads envelope.data, not exit code, so the contract is on envelope shape.
		const { exitCode, stdout } = await runFurrow(["validate", "definition", "--path", invalidPath, "--json"]);
		expect(exitCode).not.toBe(0);
		const envelope = JSON.parse(stdout);
		expect(envelope.ok).toBe(false);
		expect(envelope.data.verdict).toBe("invalid");
		expect(Array.isArray(envelope.data.errors)).toBe(true);
		expect(envelope.data.errors.length).toBeGreaterThan(0);
		const codes = envelope.data.errors.map((e: any) => e.code);
		expect(codes).toContain("definition_gate_policy_invalid");
	});

	test("each error has the BlockerEnvelope shape D4 handler relies on", async () => {
		const { stdout } = await runFurrow(["validate", "definition", "--path", invalidPath, "--json"]);
		const envelope = JSON.parse(stdout);
		for (const err of envelope.data.errors) {
			expect(typeof err.code).toBe("string");
			expect(typeof err.category).toBe("string");
			expect(typeof err.severity).toBe("string");
			expect(typeof err.message).toBe("string");
			expect(typeof err.remediation_hint).toBe("string");
			expect(typeof err.confirmation_path).toBe("string");
		}
	});
});
