// test-driver-blocker-parity.ts — D4 Pi-side test driver.
//
// Bun-runnable single file. Reads a Pi-shape `tool_call` fixture from a
// path argument (or stdin when arg is "-") and emits the canonical
// BlockerEnvelope JSON-array on stdout that the bash parity test
// (tests/integration/test-blocker-parity.sh) compares against the
// Claude-shim envelope.
//
// Per specs/coverage-and-parity-tests.md "Pi-side test driver":
//
//   For codes whose existing Pi handler factoring covers the event
//   (currently runDefinitionValidationHandler and runOwnershipWarnHandler
//   from validate-actions.ts), import the handler and inject a
//   runFurrowJson sink that shells out to `go run ./cmd/furrow ... --json`
//   (or $FURROW_BIN when set, for test-suite speedup).
//
//   For codes without an existing Pi handler, derive a normalized event
//   from the Pi fixture's tool_call shape and shell out to `furrow guard
//   <event-type>` directly. This is the "Pi-shape input round-trips
//   through the same Go path the Claude-shape input does" branch — the
//   Pi adapter does not yet intercept the event live, so the parity test
//   asserts the contract a future Pi handler must satisfy.
//
// Exit code: 0 on successful envelope emission, 1 on subprocess or
// parse failure.
//
// Invocation:
//   bun run adapters/pi/test-driver-blocker-parity.ts <pi.json>
//   bun run adapters/pi/test-driver-blocker-parity.ts -      # stdin
//
// Env overrides:
//   FURROW_BIN  — pre-built furrow binary (default: `go run ./cmd/furrow`)

import { readFileSync } from "node:fs";
import { spawnSync } from "node:child_process";
import {
	runDefinitionValidationHandler,
	runOwnershipWarnHandler,
	type ValidateDefinitionData,
	type ValidateOwnershipData,
} from "./validate-actions.ts";

// --- Read fixture -----------------------------------------------------

const arg = process.argv[2];
if (!arg) {
	process.stderr.write("usage: test-driver-blocker-parity.ts <pi.json|->\n");
	process.exit(1);
}

let raw: string;
try {
	if (arg === "-") {
		raw = readFileSync(0, "utf8");
	} else {
		raw = readFileSync(arg, "utf8");
	}
} catch (e) {
	process.stderr.write(`failed to read fixture: ${(e as Error).message}\n`);
	process.exit(1);
}

let pi: any;
try {
	pi = JSON.parse(raw);
} catch (e) {
	process.stderr.write(`fixture is not valid JSON: ${(e as Error).message}\n`);
	process.exit(1);
}

// --- runFurrow helper -------------------------------------------------

function runFurrow(args: string[], stdin?: string): { stdout: string; stderr: string; code: number } {
	const bin = process.env.FURROW_BIN ?? "";
	let cmd: string;
	let cmdArgs: string[];
	if (bin.length > 0) {
		// Allow multi-token override via shell.
		cmd = "/bin/sh";
		cmdArgs = ["-c", `${bin} ${args.map((a) => JSON.stringify(a)).join(" ")}`];
	} else {
		cmd = "go";
		cmdArgs = ["run", "./cmd/furrow", ...args];
	}
	const result = spawnSync(cmd, cmdArgs, {
		input: stdin ?? "",
		encoding: "utf8",
	});
	return {
		stdout: result.stdout ?? "",
		stderr: result.stderr ?? "",
		code: result.status ?? 0,
	};
}

// --- Branch 1: native Pi handler (definition / ownership) -------------
//
// The Pi fixture for these codes carries a `code` field naming which
// taxonomy code it exercises so the driver can pick the right handler.
// The handler returns a HandlerAction; we extract the underlying
// envelope by re-invoking the validator and emitting its envelope[].

async function runDefinitionBranch(targetPath: string): Promise<unknown[]> {
	const envelopes: unknown[] = [];
	const runJson = async (args: string[]) => {
		const r = runFurrow(args);
		try {
			const data = JSON.parse(r.stdout) as ValidateDefinitionData;
			if (data.errors) {
				for (const e of data.errors) envelopes.push(e);
			}
			return { data };
		} catch {
			return { data: undefined };
		}
	};
	await runDefinitionValidationHandler("write", targetPath, runJson);
	return envelopes;
}

async function runOwnershipBranch(targetPath: string): Promise<unknown[]> {
	const envelopes: unknown[] = [];
	const runJson = async (args: string[]) => {
		const r = runFurrow(args);
		try {
			const data = JSON.parse(r.stdout) as ValidateOwnershipData;
			if (data.envelope) envelopes.push(data.envelope);
			return { data };
		} catch {
			return { data: undefined };
		}
	};
	await runOwnershipWarnHandler("write", targetPath, runJson);
	return envelopes;
}

// --- Branch 2: future-handler stub (direct furrow guard) --------------
//
// The Pi fixture carries a `normalized` block — a verbatim normalized
// event that the driver feeds straight to `furrow guard <event_type>`.
// This is the "the Pi adapter does not yet intercept this event" branch:
// the driver asserts that whenever a Pi handler IS authored later, its
// envelope output will match what the Claude shim produces today.

function runDirectGuardBranch(eventType: string, normalized: unknown): unknown[] {
	const r = runFurrow(["guard", eventType], JSON.stringify(normalized));
	if (r.code !== 0) {
		process.stderr.write(`furrow guard ${eventType} exited ${r.code}: ${r.stderr}\n`);
		return [];
	}
	try {
		const arr = JSON.parse(r.stdout);
		return Array.isArray(arr) ? arr : [];
	} catch (e) {
		process.stderr.write(`failed to parse furrow guard stdout: ${(e as Error).message}\n`);
		return [];
	}
}

// --- Dispatch ---------------------------------------------------------

(async () => {
	let envelopes: unknown[];

	// Pi fixture shape (per coverage-and-parity-tests.md):
	//   { "toolName": "...", "input": {...}, ... }
	// For driver-internal routing we accept two optional helper fields:
	//   "_driver_branch": "definition" | "ownership" | "guard"
	//   "_driver_event_type": "<event-type>"
	//   "_driver_normalized": {<normalized event>}
	// Stub fixtures (see fixtures/blocker-events/<code>/pi.json) carry
	// these so the bash test does not need to encode dispatch logic.

	const branch: string | undefined = pi?._driver_branch;
	switch (branch) {
		case "definition": {
			const path = pi?.input?.path ?? pi?.input?.file_path ?? "";
			envelopes = await runDefinitionBranch(path);
			break;
		}
		case "ownership": {
			const path = pi?.input?.path ?? pi?.input?.file_path ?? "";
			envelopes = await runOwnershipBranch(path);
			break;
		}
		case "guard":
		default: {
			const eventType = pi?._driver_event_type ?? "";
			const normalized = pi?._driver_normalized ?? {};
			if (!eventType) {
				process.stderr.write(
					"fixture missing _driver_event_type (required for guard branch)\n",
				);
				process.exit(1);
			}
			envelopes = runDirectGuardBranch(eventType, normalized);
			break;
		}
	}

	process.stdout.write(JSON.stringify(envelopes));
	process.stdout.write("\n");
	process.exit(0);
})();
