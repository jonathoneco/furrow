// furrow.test.ts — Pi adapter contract tests against the Furrow Go CLI.
//
// These tests verify the JSON envelope shapes that adapters/pi/furrow.ts
// handlers depend on. They invoke the real `furrow` binary and assert the
// envelope structure matches what runFurrowJson<T>() expects.
//
// Bootstrapped by D4 of pre-write-validation-go-first. Subsequent deliverables
// (D5) extend this file with their own contract tests; do not delete this file
// or the scaffolding around it.

import { describe, expect, test, beforeAll, mock } from "bun:test";
import { mkdtemp, mkdir, writeFile, rm, symlink } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { execFile } from "node:child_process";
import { promisify } from "node:util";

import { decideValidateDefinitionAction, decideOwnershipAction } from "./validate-actions.ts";

const execFileAsync = promisify(execFile);

const projectRoot = resolve(import.meta.dir, "..", "..");
let furrowBinary = "";

async function buildFurrowBinary(): Promise<string> {
	if (furrowBinary) return furrowBinary;
	const binDir = await mkdtemp(join(tmpdir(), "pi-furrow-bin-"));
	const target = join(binDir, "furrow");
	await execFileAsync("go", ["build", "-o", target, "./cmd/furrow"], { cwd: projectRoot });
	furrowBinary = target;
	return target;
}

async function runFurrow(args: string[], cwd = projectRoot): Promise<{ exitCode: number; stdout: string }> {
	const bin = await buildFurrowBinary();
	try {
		const { stdout } = await execFileAsync(bin, args, { cwd });
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

describe("decideValidateDefinitionAction (D4 handler unit)", () => {
	test("verdict=valid → undefined (silent allow)", () => {
		const action = decideValidateDefinitionAction({ verdict: "valid" });
		expect(action).toBeUndefined();
	});

	test("undefined data → undefined (silent allow)", () => {
		const action = decideValidateDefinitionAction(undefined);
		expect(action).toBeUndefined();
	});

	test("verdict=invalid → block with concatenated messages", () => {
		const action = decideValidateDefinitionAction({
			verdict: "invalid",
			errors: [
				{ code: "definition_objective_missing", category: "definition", severity: "block", message: "missing objective", remediation_hint: "add it", confirmation_path: "block" },
			],
		}) as any;
		expect(action.block).toBe(true);
		expect(action.reason).toContain("missing objective");
		expect(action.reason).toContain("(hint: add it)");
	});

	test("verdict=invalid with notify → notify is called with concatenated message", () => {
		const calls: Array<[string, string]> = [];
		const notify = (msg: string, level: any) => { calls.push([msg, level]); };
		decideValidateDefinitionAction({
			verdict: "invalid",
			errors: [
				{ code: "x", category: "y", severity: "block", message: "msg1", remediation_hint: "", confirmation_path: "block" },
				{ code: "x", category: "y", severity: "block", message: "msg2", remediation_hint: "", confirmation_path: "block" },
			],
		}, notify);
		expect(calls.length).toBe(1);
		expect(calls[0][1]).toBe("error");
		expect(calls[0][0]).toContain("msg1");
		expect(calls[0][0]).toContain("msg2");
	});

	test("verdict=invalid with empty errors → fallback message + block", () => {
		const action = decideValidateDefinitionAction({ verdict: "invalid", errors: [] }) as any;
		expect(action.block).toBe(true);
		expect(action.reason).toBe("definition.yaml validation failed");
	});
});

describe("decideOwnershipAction (D5 handler unit)", () => {
	test("verdict=in_scope → undefined (silent allow)", async () => {
		const action = await decideOwnershipAction({ verdict: "in_scope", matched_deliverable: "x", matched_glob: "y" });
		expect(action).toBeUndefined();
	});

	test("verdict=not_applicable → undefined (silent allow)", async () => {
		const action = await decideOwnershipAction({ verdict: "not_applicable", reason: "no_active_row" });
		expect(action).toBeUndefined();
	});

	test("verdict=out_of_scope without confirm → { block: false } (degraded silent allow)", async () => {
		const action = await decideOwnershipAction({
			verdict: "out_of_scope",
			envelope: { code: "ownership_outside_scope", category: "ownership", severity: "warn", message: "outside", remediation_hint: "", confirmation_path: "warn-with-confirm" },
		}) as any;
		expect(action.block).toBe(false);
	});

	test("verdict=out_of_scope + confirm-yes → { block: false }", async () => {
		const confirm = mock(async (_title: string, _body: string) => true);
		const action = await decideOwnershipAction({
			verdict: "out_of_scope",
			envelope: { code: "ownership_outside_scope", category: "ownership", severity: "warn", message: "outside", remediation_hint: "", confirmation_path: "warn-with-confirm" },
		}, confirm) as any;
		expect(action.block).toBe(false);
		expect(confirm).toHaveBeenCalledTimes(1);
		expect(confirm.mock.calls[0][0]).toBe("This file is outside the deliverable file_ownership. Proceed anyway?");
		expect(confirm.mock.calls[0][1]).toBe("outside");
	});

	test("verdict=out_of_scope + confirm-no → { block: true, reason }", async () => {
		const confirm = mock(async (_title: string, _body: string) => false);
		const action = await decideOwnershipAction({
			verdict: "out_of_scope",
			envelope: { code: "ownership_outside_scope", category: "ownership", severity: "warn", message: "outside", remediation_hint: "", confirmation_path: "warn-with-confirm" },
		}, confirm) as any;
		expect(action.block).toBe(true);
		expect(action.reason).toBe("outside");
	});
});

describe("furrow validate ownership (D2 contract — consumed by D5 Pi handler)", () => {
	let workDir: string;
	let rowDir: string;

	beforeAll(async () => {
		workDir = await mkdtemp(join(tmpdir(), "pi-furrow-ownership-"));
		rowDir = join(workDir, ".furrow", "rows", "fixture-row");
		await mkdir(rowDir, { recursive: true });
		await writeFile(
			join(rowDir, "definition.yaml"),
			`objective: "ownership fixture"
deliverables:
  - name: a-thing
    file_ownership:
      - "src/a/**/*.go"
context_pointers:
  - path: "/tmp"
    note: "n"
constraints: []
gate_policy: supervised
`,
		);
		// Symlink schemas so taxonomy can load.
		const schemasSrc = join(projectRoot, "schemas");
		await symlink(schemasSrc, join(workDir, "schemas"));
	});

	test("in_scope: verdict=in_scope with matched_deliverable + matched_glob", async () => {
		const { exitCode, stdout } = await runFurrow(
			["validate", "ownership", "--path", "src/a/sub/foo.go", "--row", "fixture-row", "--json"],
			workDir,
		);
		expect(exitCode).toBe(0);
		const envelope = JSON.parse(stdout);
		expect(envelope.data.verdict).toBe("in_scope");
		expect(envelope.data.matched_deliverable).toBe("a-thing");
		expect(envelope.data.matched_glob).toBe("src/a/**/*.go");
	});

	test("out_of_scope: verdict=out_of_scope with envelope.code ownership_outside_scope", async () => {
		const { exitCode, stdout } = await runFurrow(
			["validate", "ownership", "--path", "src/b/foo.go", "--row", "fixture-row", "--json"],
			workDir,
		);
		expect(exitCode).toBe(0);
		const envelope = JSON.parse(stdout);
		expect(envelope.data.verdict).toBe("out_of_scope");
		expect(envelope.data.envelope.code).toBe("ownership_outside_scope");
		expect(envelope.data.envelope.confirmation_path).toBe("warn-with-confirm");
	});

	test("not_applicable: missing row resolves cleanly with reason", async () => {
		const { exitCode, stdout } = await runFurrow(
			["validate", "ownership", "--path", "x.go", "--row", "no-such-row", "--json"],
			workDir,
		);
		expect(exitCode).toBe(0);
		const envelope = JSON.parse(stdout);
		expect(envelope.data.verdict).toBe("not_applicable");
		expect(envelope.data.reason).toBeDefined();
	});

	test("step-agnostic: verdict identical regardless of state.step value", async () => {
		// Vary state.json.step across multiple values; verdict for the same path/row must be identical.
		// (The Go validator never reads state.step, so this is a contract assertion.)
		const stepValues = ["ideate", "plan", "implement"];
		const verdicts = new Set<string>();
		for (const step of stepValues) {
			await writeFile(
				join(rowDir, "state.json"),
				JSON.stringify({ name: "fixture-row", step, step_status: "in_progress" }),
			);
			const { stdout } = await runFurrow(
				["validate", "ownership", "--path", "src/a/foo.go", "--row", "fixture-row", "--json"],
				workDir,
			);
			const envelope = JSON.parse(stdout);
			verdicts.add(envelope.data.verdict);
		}
		expect(verdicts.size).toBe(1);
		expect(verdicts.has("in_scope")).toBe(true);
	});
});

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
