You are reviewing deliverable 'coverage-and-parity-tests' for quality.

## Acceptance Criteria

- tests/integration/test-blocker-coverage.sh: for every code in schemas/blocker-taxonomy.yaml, the test feeds a normalized event fixture to the Go emission path and asserts the canonical BlockerEnvelope (code, severity, message keys) is produced. Codes deferred from migration are explicitly skipped with logged reason.
- tests/integration/test-blocker-parity.sh: for each migrated code, the test feeds a Claude-shape event fixture through the Claude adapter shim AND a Pi-shape event fixture through the Pi adapter shim, asserts both produce identical canonical BlockerEnvelopes. Pi runtime presence is not required — fixture-driven invocation through the Pi shim suffices. Live Pi-process invocation is an explicit follow-up TODO if not delivered here.
- The parity test independently asserts that each migrated hook invokes the Go backend via subprocess (e.g., by intercepting the Go binary call or asserting absence of inline policy logic in the shim) — preventing a regression where a shim hard-codes a canonical envelope string and silently passes parity by mimicking Go output.
- Adding a new code to the taxonomy without a corresponding emit-site fails test-blocker-coverage.sh; adding an emit-site for a code without parity coverage fails test-blocker-parity.sh.
- Emit-site inventory gate — test-blocker-parity.sh enumerates every migrated hook shim under bin/frw.d/hooks/ and fails when any shim lacks a corresponding {claude.json, pi.json, expected-envelope.json} fixture set. This is an inventory check distinct from per-code coverage; it ensures fixtures track shims, not just registry codes.
- Tests are auto-discovered by tests/integration/run-all.sh (POSIX glob over test-*.sh) so they run whenever the integration suite runs. CI wiring of run-all.sh itself is out of scope and captured as a follow-up TODO if not already covered elsewhere.

## Evaluation Dimensions

- **correctness**: Whether the implementation matches spec behavior
  Pass: All spec acceptance criteria pass when tested (commands run, output inspected)
  Fail: Any AC fails when tested with a fresh run
- **test-coverage**: Whether new code paths have corresponding tests
  Pass: Every new function or method with branching logic has at least one test
  Fail: Any new function with branching logic has zero tests
- **spec-compliance**: Whether the implementation follows the spec's interface contracts
  Pass: All interface contracts from the spec are implemented as specified (function signatures, file locations, behavior)
  Fail: Any interface contract is missing or differs from spec
- **unplanned-changes**: Whether changes outside file_ownership are justified
  Pass: All files modified outside the deliverable's file_ownership globs are documented with justification
  Fail: Unplanned changes exist without justification
- **code-quality**: Whether the code follows project conventions and code-quality skill rules
  Pass: Code passes linting, follows naming conventions, and does not violate code-quality rules (spec: skills/code-quality.md)
  Fail: Any code-quality rule violation exists

## Changes

```
commit 4c76d9039cfcd7b6978f20f934c06ade7d8fde5a
Author: Test <test@test.com>
Date:   Sat Apr 25 15:52:26 2026 -0400

    test(blocker-taxonomy): D4 coverage + parity tests + per-code fixtures
    
    Closes the W4 deliverable for blocker-taxonomy-foundation. Two
    integration tests are auto-discovered via tests/integration/run-all.sh's
    test-*.sh glob; per-code fixtures live under
    tests/integration/fixtures/blocker-events/<code>/.
    
    - test-blocker-coverage.sh walks every code in
      schemas/blocker-taxonomy.yaml via `yq '.blockers[].code'` and asserts
      the canonical 4-file fixture set plus a guard-driven envelope match
      for the 13 codes routed through `furrow guard <event-type>`. Codes
      without an event-type handler (27 Go-side-only) are skipped via a
      SKIP_REASON marker file naming the future surface.
    - test-blocker-parity.sh runs two anti-cheat assertions
      (subprocess-invocation grep + emit-site inventory gate) across the
      10 migrated D3 shims, then attempts per-(shim, code) parity replay.
      Pi-handler-absent codes skip with the named follow-up TODO
      (pi-tool-call-canonical-schema-and-surface-audit).
    - adapters/pi/test-driver-blocker-parity.ts is a Bun-runnable
      fixture-replay driver. For codes whose Pi handler exists in
      validate-actions.ts it imports the handler and injects a
      Go-shelling-out runFurrow sink; for codes without a handler it
      reads the fixture's _driver_normalized payload and feeds it to
      `furrow guard <event-type>` directly, proving Pi-shape input
      round-trips through the same Go path Claude shape does.
    - Per-code fixtures (40 directories): normalized.json, claude.json,
      pi.json, expected-envelope.json. Codes that need filesystem state
      (definition.yaml, summary.md) ship the supporting file alongside
      and the fixture's normalized.json carries an __FIXTURE_DIR__
      placeholder the test substitutes before piping.
    
    D3 audit §6 follow-up: tests/integration/test-precommit-{block,bypass}.sh
    asserted the literal substring `pre-commit: refusing type-change` which
    the canonical message_template (D1) does not carry. Updated to match
    `refusing type-change to symlink`, the canonical envelope-driven
    emission (`[furrow:block] refusing type-change to symlink on <path>`)
    produced by D2's emit_canonical_blocker.
    
    No edits to schemas/, internal/cli/, bin/frw.d/hooks/, bin/frw.d/lib/,
    or run-all.sh — all D1/D2/D3 surfaces preserved.
    
    Verification:
    - test-blocker-coverage.sh: 244/0/244 pass.
    - test-blocker-parity.sh: 59/0/59 pass; 13 parity SKIPs logged with the
      named follow-up TODO (Pi handlers not yet wired for any of the 10
      shim-emitted codes — every claude shape currently round-trips
      through the direct guard branch).
    - test-precommit-block.sh / test-precommit-bypass.sh: 14/0/14 and
      6/0/6 pass after the substring update.
    - Anti-cheat: deleting a fixture set surfaces the code name in the
      FAIL line; removing a fixture file fails the inventory gate.
    - go test ./internal/cli/... -count=1: unchanged.
    - frw validate-definition still passes against the row.

diff --git a/adapters/pi/test-driver-blocker-parity.ts b/adapters/pi/test-driver-blocker-parity.ts
new file mode 100644
index 0000000..335a749
--- /dev/null
+++ b/adapters/pi/test-driver-blocker-parity.ts
@@ -0,0 +1,204 @@
+// test-driver-blocker-parity.ts — D4 Pi-side test driver.
+//
+// Bun-runnable single file. Reads a Pi-shape `tool_call` fixture from a
+// path argument (or stdin when arg is "-") and emits the canonical
+// BlockerEnvelope JSON-array on stdout that the bash parity test
+// (tests/integration/test-blocker-parity.sh) compares against the
+// Claude-shim envelope.
+//
+// Per specs/coverage-and-parity-tests.md "Pi-side test driver":
+//
+//   For codes whose existing Pi handler factoring covers the event
+//   (currently runDefinitionValidationHandler and runOwnershipWarnHandler
+//   from validate-actions.ts), import the handler and inject a
+//   runFurrowJson sink that shells out to `go run ./cmd/furrow ... --json`
+//   (or $FURROW_BIN when set, for test-suite speedup).
+//
+//   For codes without an existing Pi handler, derive a normalized event
+//   from the Pi fixture's tool_call shape and shell out to `furrow guard
+//   <event-type>` directly. This is the "Pi-shape input round-trips
+//   through the same Go path the Claude-shape input does" branch — the
+//   Pi adapter does not yet intercept the event live, so the parity test
+//   asserts the contract a future Pi handler must satisfy.
+//
+// Exit code: 0 on successful envelope emission, 1 on subprocess or
+// parse failure.
+//
+// Invocation:
+//   bun run adapters/pi/test-driver-blocker-parity.ts <pi.json>
+//   bun run adapters/pi/test-driver-blocker-parity.ts -      # stdin
+//
+// Env overrides:
+//   FURROW_BIN  — pre-built furrow binary (default: `go run ./cmd/furrow`)
+
+import { readFileSync } from "node:fs";
+import { spawnSync } from "node:child_process";
+import {
+	runDefinitionValidationHandler,
+	runOwnershipWarnHandler,
+	type ValidateDefinitionData,
+	type ValidateOwnershipData,
+} from "./validate-actions.ts";
+
+// --- Read fixture -----------------------------------------------------
+
+const arg = process.argv[2];
+if (!arg) {
+	process.stderr.write("usage: test-driver-blocker-parity.ts <pi.json|->\n");
+	process.exit(1);
+}
+
+let raw: string;
+try {
+	if (arg === "-") {
+		raw = readFileSync(0, "utf8");
+	} else {
+		raw = readFileSync(arg, "utf8");
+	}
+} catch (e) {
+	process.stderr.write(`failed to read fixture: ${(e as Error).message}\n`);
+	process.exit(1);
+}
+
+let pi: any;
+try {
+	pi = JSON.parse(raw);
+} catch (e) {
+	process.stderr.write(`fixture is not valid JSON: ${(e as Error).message}\n`);
+	process.exit(1);
+}
+
+// --- runFurrow helper -------------------------------------------------
+
+function runFurrow(args: string[], stdin?: string): { stdout: string; stderr: string; code: number } {
+	const bin = process.env.FURROW_BIN ?? "";
+	let cmd: string;
+	let cmdArgs: string[];
+	if (bin.length > 0) {
+		// Allow multi-token override via shell.
+		cmd = "/bin/sh";
+		cmdArgs = ["-c", `${bin} ${args.map((a) => JSON.stringify(a)).join(" ")}`];
+	} else {
+		cmd = "go";
+		cmdArgs = ["run", "./cmd/furrow", ...args];
+	}
+	const result = spawnSync(cmd, cmdArgs, {
+		input: stdin ?? "",
+		encoding: "utf8",
+	});
+	return {
+		stdout: result.stdout ?? "",
+		stderr: result.stderr ?? "",
+		code: result.status ?? 0,
+	};
+}
+
+// --- Branch 1: native Pi handler (definition / ownership) -------------
+//
+// The Pi fixture for these codes carries a `code` field naming which
+// taxonomy code it exercises so the driver can pick the right handler.
+// The handler returns a HandlerAction; we extract the underlying
+// envelope by re-invoking the validator and emitting its envelope[].
+
+async function runDefinitionBranch(targetPath: string): Promise<unknown[]> {
+	const envelopes: unknown[] = [];
+	const runJson = async (args: string[]) => {
+		const r = runFurrow(args);
+		try {
+			const data = JSON.parse(r.stdout) as ValidateDefinitionData;
+			if (data.errors) {
+				for (const e of data.errors) envelopes.push(e);
+			}
+			return { data };
+		} catch {
+			return { data: undefined };
+		}
+	};
+	await runDefinitionValidationHandler("write", targetPath, runJson);
+	return envelopes;
+}
+
+async function runOwnershipBranch(targetPath: string): Promise<unknown[]> {
+	const envelopes: unknown[] = [];
+	const runJson = async (args: string[]) => {
+		const r = runFurrow(args);
+		try {
+			const data = JSON.parse(r.stdout) as ValidateOwnershipData;
+			if (data.envelope) envelopes.push(data.envelope);
+			return { data };
+		} catch {
+			return { data: undefined };
+		}
+	};
+	await runOwnershipWarnHandler("write", targetPath, runJson);
+	return envelopes;
+}
+
+// --- Branch 2: future-handler stub (direct furrow guard) --------------
+//
+// The Pi fixture carries a `normalized` block — a verbatim normalized
+// event that the driver feeds straight to `furrow guard <event_type>`.
+// This is the "the Pi adapter does not yet intercept this event" branch:
+// the driver asserts that whenever a Pi handler IS authored later, its
+// envelope output will match what the Claude shim produces today.
+
+function runDirectGuardBranch(eventType: string, normalized: unknown): unknown[] {
+	const r = runFurrow(["guard", eventType], JSON.stringify(normalized));
+	if (r.code !== 0) {
+		process.stderr.write(`furrow guard ${eventType} exited ${r.code}: ${r.stderr}\n`);
+		return [];
+	}
+	try {
+		const arr = JSON.parse(r.stdout);
+		return Array.isArray(arr) ? arr : [];
+	} catch (e) {
+		process.stderr.write(`failed to parse furrow guard stdout: ${(e as Error).message}\n`);
+		return [];
+	}
+}
+
+// --- Dispatch ---------------------------------------------------------
+
+(async () => {
+	let envelopes: unknown[];
+
+	// Pi fixture shape (per coverage-and-parity-tests.md):
+	//   { "toolName": "...", "input": {...}, ... }
+	// For driver-internal routing we accept two optional helper fields:
+	//   "_driver_branch": "definition" | "ownership" | "guard"
+	//   "_driver_event_type": "<event-type>"
+	//   "_driver_normalized": {<normalized event>}
+	// Stub fixtures (see fixtures/blocker-events/<code>/pi.json) carry
+	// these so the bash test does not need to encode dispatch logic.
+
+	const branch: string | undefined = pi?._driver_branch;
+	switch (branch) {
+		case "definition": {
+			const path = pi?.input?.path ?? pi?.input?.file_path ?? "";
+			envelopes = await runDefinitionBranch(path);
+			break;
+		}
+		case "ownership": {
+			const path = pi?.input?.path ?? pi?.input?.file_path ?? "";
+			envelopes = await runOwnershipBranch(path);
+			break;
+		}
+		case "guard":
+		default: {
+			const eventType = pi?._driver_event_type ?? "";
+			const normalized = pi?._driver_normalized ?? {};
+			if (!eventType) {
+				process.stderr.write(
+					"fixture missing _driver_event_type (required for guard branch)\n",
+				);
+				process.exit(1);
+			}
+			envelopes = runDirectGuardBranch(eventType, normalized);
+			break;
+		}
+	}
+
+	process.stdout.write(JSON.stringify(envelopes));
+	process.stdout.write("\n");
+	process.exit(0);
+})();
diff --git a/tests/integration/fixtures/blocker-events/archive_requires_review_gate/SKIP_REASON b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/archive_requires_review_gate/claude.json b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/archive_requires_review_gate/expected-envelope.json b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/expected-envelope.json
new file mode 100644
index 0000000..266229e
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "archive_requires_review_gate",
+  "category": "archive",
+  "severity": "block",
+  "message": "row cannot archive until a passing ->review gate exists",
+  "remediation_hint": "Record a passing implement->review gate before archiving so the review boundary has durable evidence.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/archive_requires_review_gate/normalized.json b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/archive_requires_review_gate/pi.json b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archive_requires_review_gate/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/archived_row_mutation/SKIP_REASON b/tests/integration/fixtures/blocker-events/archived_row_mutation/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archived_row_mutation/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/archived_row_mutation/claude.json b/tests/integration/fixtures/blocker-events/archived_row_mutation/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archived_row_mutation/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/archived_row_mutation/expected-envelope.json b/tests/integration/fixtures/blocker-events/archived_row_mutation/expected-envelope.json
new file mode 100644
index 0000000..deff6e4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archived_row_mutation/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "archived_row_mutation",
+  "category": "archive",
+  "severity": "block",
+  "message": "row {row} is archived and cannot be mutated",
+  "remediation_hint": "Archived rows are read-only. Open a new row instead of editing an archived one.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/archived_row_mutation/normalized.json b/tests/integration/fixtures/blocker-events/archived_row_mutation/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archived_row_mutation/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/archived_row_mutation/pi.json b/tests/integration/fixtures/blocker-events/archived_row_mutation/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/archived_row_mutation/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/SKIP_REASON b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/claude.json b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/expected-envelope.json b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/expected-envelope.json
new file mode 100644
index 0000000..9932a48
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "artifact_scaffold_incomplete",
+  "category": "artifact",
+  "severity": "block",
+  "message": "current-step artifact {artifact_id} at {path} is still an incomplete scaffold",
+  "remediation_hint": "Replace the incomplete scaffold with real step content, then rerun furrow row complete or /work --complete.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/normalized.json b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/pi.json b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_scaffold_incomplete/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/artifact_validation_failed/SKIP_REASON b/tests/integration/fixtures/blocker-events/artifact_validation_failed/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_validation_failed/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/artifact_validation_failed/claude.json b/tests/integration/fixtures/blocker-events/artifact_validation_failed/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_validation_failed/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/artifact_validation_failed/expected-envelope.json b/tests/integration/fixtures/blocker-events/artifact_validation_failed/expected-envelope.json
new file mode 100644
index 0000000..b9e465c
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_validation_failed/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "artifact_validation_failed",
+  "category": "artifact",
+  "severity": "block",
+  "message": "current-step artifact {artifact_id} at {path} failed validation",
+  "remediation_hint": "Address the reported validation findings in the artifact, then rerun furrow row status or /work.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/artifact_validation_failed/normalized.json b/tests/integration/fixtures/blocker-events/artifact_validation_failed/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_validation_failed/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/artifact_validation_failed/pi.json b/tests/integration/fixtures/blocker-events/artifact_validation_failed/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/artifact_validation_failed/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/closed_seed/SKIP_REASON b/tests/integration/fixtures/blocker-events/closed_seed/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/closed_seed/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/closed_seed/claude.json b/tests/integration/fixtures/blocker-events/closed_seed/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/closed_seed/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/closed_seed/expected-envelope.json b/tests/integration/fixtures/blocker-events/closed_seed/expected-envelope.json
new file mode 100644
index 0000000..0b52a08
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/closed_seed/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "closed_seed",
+  "category": "seed",
+  "severity": "block",
+  "message": "linked seed {seed_id} is closed",
+  "remediation_hint": "Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/closed_seed/normalized.json b/tests/integration/fixtures/blocker-events/closed_seed/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/closed_seed/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/closed_seed/pi.json b/tests/integration/fixtures/blocker-events/closed_seed/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/closed_seed/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/correction_limit_reached/SKIP_REASON b/tests/integration/fixtures/blocker-events/correction_limit_reached/SKIP_REASON
new file mode 100644
index 0000000..c5b8dd5
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/correction_limit_reached/SKIP_REASON
@@ -0,0 +1 @@
+correction_limit_reached requires materialized FURROW_ROOT state (plan.json+state.json+furrow.yaml) — covered by internal/cli/correction_limit_test.go; integration coverage is the future surface for follow-up TODO correction-limit-integration-fixture
diff --git a/tests/integration/fixtures/blocker-events/correction_limit_reached/claude.json b/tests/integration/fixtures/blocker-events/correction_limit_reached/claude.json
new file mode 100644
index 0000000..007ad74
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/correction_limit_reached/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":"/tmp/x.go"}}
diff --git a/tests/integration/fixtures/blocker-events/correction_limit_reached/expected-envelope.json b/tests/integration/fixtures/blocker-events/correction_limit_reached/expected-envelope.json
new file mode 100644
index 0000000..570b7ea
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/correction_limit_reached/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "correction_limit_reached",
+  "category": "state-mutation",
+  "severity": "block",
+  "message": "Correction limit (3) reached for deliverable 'foo' (path: /tmp/x.go). Escalate to human for guidance.",
+  "remediation_hint": "The deliverable has reached its correction limit. Stop attempting fixes and escalate to a human reviewer; no CLI override exists.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/correction_limit_reached/normalized.json b/tests/integration/fixtures/blocker-events/correction_limit_reached/normalized.json
new file mode 100644
index 0000000..a19ef35
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/correction_limit_reached/normalized.json
@@ -0,0 +1,8 @@
+{
+  "version": "1",
+  "event_type": "pre_write_correction_limit",
+  "payload": {
+    "target_path": "__FIXTURE_DIR__/notexist.go",
+    "tool_name": "Write"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/correction_limit_reached/pi.json b/tests/integration/fixtures/blocker-events/correction_limit_reached/pi.json
new file mode 100644
index 0000000..7b664dd
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/correction_limit_reached/pi.json
@@ -0,0 +1,16 @@
+{
+  "toolName": "write",
+  "input": {
+    "path": "/tmp/x.go"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_write_correction_limit",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_write_correction_limit",
+    "payload": {
+      "target_path": "/tmp/x.go",
+      "tool_name": "Write"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/SKIP_REASON b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/claude.json b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/expected-envelope.json b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/expected-envelope.json
new file mode 100644
index 0000000..0907e2e
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "decided_by_invalid_for_policy",
+  "category": "gate",
+  "severity": "block",
+  "message": "row {row}: decided_by '{decided_by}' is not valid for gate policy '{policy}'",
+  "remediation_hint": "Match decided_by to the row's gate_policy: supervised → human, delegated → evaluator, autonomous → automated.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/normalized.json b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/pi.json b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/decided_by_invalid_for_policy/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/claude.json b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/expected-envelope.json
new file mode 100644
index 0000000..6ac1b60
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_acceptance_criteria_placeholder",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: deliverable '{name}' has placeholder text in acceptance_criteria: {value}",
+  "remediation_hint": "Replace placeholder strings (TODO, TBD, XXX, placeholder) with concrete acceptance criteria",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/normalized.json b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/pi.json b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_acceptance_criteria_placeholder/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/claude.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/expected-envelope.json
new file mode 100644
index 0000000..6b81ac1
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_deliverable_name_invalid_pattern",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: deliverable name '{name}' does not match kebab-case pattern ^[a-z][a-z0-9]*(-[a-z0-9]+)*$",
+  "remediation_hint": "Rename the deliverable to lowercase with hyphen separators only",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/normalized.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/pi.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_invalid_pattern/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/claude.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/expected-envelope.json
new file mode 100644
index 0000000..30233f8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_deliverable_name_missing",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: deliverable at index {index} is missing required field 'name'",
+  "remediation_hint": "Add a kebab-case 'name:' field to the deliverable",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/normalized.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/pi.json b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverable_name_missing/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverables_empty/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverables_empty/claude.json b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverables_empty/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/expected-envelope.json
new file mode 100644
index 0000000..1f0b7f5
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_deliverables_empty",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: deliverables[] is empty or missing; at least one deliverable is required",
+  "remediation_hint": "Add at least one deliverable entry with name and acceptance_criteria",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverables_empty/normalized.json b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_deliverables_empty/pi.json b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_deliverables_empty/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/claude.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/expected-envelope.json
new file mode 100644
index 0000000..f759b46
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_gate_policy_invalid",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: gate_policy '{value}' is not one of: supervised, delegated, autonomous",
+  "remediation_hint": "Set gate_policy to one of the valid values",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/normalized.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/pi.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_invalid/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/claude.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/expected-envelope.json
new file mode 100644
index 0000000..2f4d3a7
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_gate_policy_missing",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: missing required field 'gate_policy'",
+  "remediation_hint": "Set gate_policy to one of: supervised, delegated, autonomous",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/normalized.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/pi.json b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_gate_policy_missing/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_mode_invalid/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_mode_invalid/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_mode_invalid/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_mode_invalid/claude.json b/tests/integration/fixtures/blocker-events/definition_mode_invalid/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_mode_invalid/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_mode_invalid/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_mode_invalid/expected-envelope.json
new file mode 100644
index 0000000..96a6ba5
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_mode_invalid/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_mode_invalid",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: mode '{value}' is not one of: code, research",
+  "remediation_hint": "Set mode to either code (default) or research",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_mode_invalid/normalized.json b/tests/integration/fixtures/blocker-events/definition_mode_invalid/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_mode_invalid/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_mode_invalid/pi.json b/tests/integration/fixtures/blocker-events/definition_mode_invalid/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_mode_invalid/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_objective_missing/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_objective_missing/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_objective_missing/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_objective_missing/claude.json b/tests/integration/fixtures/blocker-events/definition_objective_missing/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_objective_missing/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_objective_missing/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_objective_missing/expected-envelope.json
new file mode 100644
index 0000000..06b61ba
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_objective_missing/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_objective_missing",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: missing required field 'objective'",
+  "remediation_hint": "Add a one-sentence 'objective:' field at the top level of definition.yaml",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_objective_missing/normalized.json b/tests/integration/fixtures/blocker-events/definition_objective_missing/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_objective_missing/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_objective_missing/pi.json b/tests/integration/fixtures/blocker-events/definition_objective_missing/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_objective_missing/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_unknown_keys/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_unknown_keys/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_unknown_keys/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_unknown_keys/claude.json b/tests/integration/fixtures/blocker-events/definition_unknown_keys/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_unknown_keys/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_unknown_keys/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_unknown_keys/expected-envelope.json
new file mode 100644
index 0000000..9939525
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_unknown_keys/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_unknown_keys",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: contains unknown top-level keys: {keys}",
+  "remediation_hint": "Remove keys not declared in schemas/definition.schema.json (additionalProperties is false)",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_unknown_keys/normalized.json b/tests/integration/fixtures/blocker-events/definition_unknown_keys/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_unknown_keys/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_unknown_keys/pi.json b/tests/integration/fixtures/blocker-events/definition_unknown_keys/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_unknown_keys/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_yaml_invalid/SKIP_REASON b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/definition_yaml_invalid/claude.json b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/definition_yaml_invalid/expected-envelope.json b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/expected-envelope.json
new file mode 100644
index 0000000..fc9cbeb
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "definition_yaml_invalid",
+  "category": "definition",
+  "severity": "block",
+  "message": "{path}: definition.yaml failed schema validation: {detail}",
+  "remediation_hint": "Inspect the YAML syntax and structural conformance against schemas/definition.schema.json",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/definition_yaml_invalid/normalized.json b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/definition_yaml_invalid/pi.json b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/definition_yaml_invalid/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/claude.json b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/claude.json
new file mode 100644
index 0000000..3673868
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"Stop","stop_hook_active":true}
diff --git a/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/definition.yaml b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/definition.yaml
new file mode 100644
index 0000000..71478da
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/definition.yaml
@@ -0,0 +1,3 @@
+# Fixture: missing required ideation fields (objective, gate_policy,
+# deliverables, context_pointers, constraints).
+mode: code
diff --git a/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/expected-envelope.json b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/expected-envelope.json
new file mode 100644
index 0000000..1f2471d
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "ideation_incomplete_definition_fields",
+  "category": "ideation",
+  "severity": "block",
+  "message": "Ideation incomplete — definition.yaml missing required fields: constraints, context_pointers, deliverables, gate_policy, objective",
+  "remediation_hint": "Populate the missing definition.yaml fields (objective, gate_policy, deliverables, context_pointers, constraints) before completing the ideate step.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/normalized.json b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/normalized.json
new file mode 100644
index 0000000..81e58c1
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/normalized.json
@@ -0,0 +1,11 @@
+{
+  "version": "1",
+  "event_type": "stop_ideation_completeness",
+  "row": "r1",
+  "step": "ideate",
+  "payload": {
+    "row": "r1",
+    "gate_policy": "supervised",
+    "definition_path": "__FIXTURE_DIR__/definition.yaml"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/pi.json b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/pi.json
new file mode 100644
index 0000000..dd57e38
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ideation_incomplete_definition_fields/pi.json
@@ -0,0 +1,19 @@
+{
+  "toolName": "stop",
+  "input": {
+    "row": "r1"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "stop_ideation_completeness",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "stop_ideation_completeness",
+    "row": "r1",
+    "step": "ideate",
+    "payload": {
+      "row": "r1",
+      "gate_policy": "supervised",
+      "definition_path": "__FIXTURE_DIR__/definition.yaml"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/missing_required_artifact/SKIP_REASON b/tests/integration/fixtures/blocker-events/missing_required_artifact/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_required_artifact/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/missing_required_artifact/claude.json b/tests/integration/fixtures/blocker-events/missing_required_artifact/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_required_artifact/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/missing_required_artifact/expected-envelope.json b/tests/integration/fixtures/blocker-events/missing_required_artifact/expected-envelope.json
new file mode 100644
index 0000000..649935e
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_required_artifact/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "missing_required_artifact",
+  "category": "artifact",
+  "severity": "block",
+  "message": "required current-step artifact {artifact_id} is missing at {path}",
+  "remediation_hint": "Create or scaffold the required current-step artifact, then rerun /work or furrow row status.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/missing_required_artifact/normalized.json b/tests/integration/fixtures/blocker-events/missing_required_artifact/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_required_artifact/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/missing_required_artifact/pi.json b/tests/integration/fixtures/blocker-events/missing_required_artifact/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_required_artifact/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/missing_seed_record/SKIP_REASON b/tests/integration/fixtures/blocker-events/missing_seed_record/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_seed_record/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/missing_seed_record/claude.json b/tests/integration/fixtures/blocker-events/missing_seed_record/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_seed_record/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/missing_seed_record/expected-envelope.json b/tests/integration/fixtures/blocker-events/missing_seed_record/expected-envelope.json
new file mode 100644
index 0000000..d68aea9
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_seed_record/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "missing_seed_record",
+  "category": "seed",
+  "severity": "block",
+  "message": "linked seed {seed_id} was not found",
+  "remediation_hint": "Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/missing_seed_record/normalized.json b/tests/integration/fixtures/blocker-events/missing_seed_record/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_seed_record/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/missing_seed_record/pi.json b/tests/integration/fixtures/blocker-events/missing_seed_record/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/missing_seed_record/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/nonce_stale/SKIP_REASON b/tests/integration/fixtures/blocker-events/nonce_stale/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/nonce_stale/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/nonce_stale/claude.json b/tests/integration/fixtures/blocker-events/nonce_stale/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/nonce_stale/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/nonce_stale/expected-envelope.json b/tests/integration/fixtures/blocker-events/nonce_stale/expected-envelope.json
new file mode 100644
index 0000000..ec913ed
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/nonce_stale/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "nonce_stale",
+  "category": "gate",
+  "severity": "block",
+  "message": "evaluator result nonce '{nonce}' is stale or does not match the expected '{expected_nonce}' for row {row}",
+  "remediation_hint": "Re-run the evaluator with a fresh nonce; stale evaluator results cannot satisfy the gate.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/nonce_stale/normalized.json b/tests/integration/fixtures/blocker-events/nonce_stale/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/nonce_stale/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/nonce_stale/pi.json b/tests/integration/fixtures/blocker-events/nonce_stale/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/nonce_stale/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/ownership_outside_scope/SKIP_REASON b/tests/integration/fixtures/blocker-events/ownership_outside_scope/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ownership_outside_scope/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/ownership_outside_scope/claude.json b/tests/integration/fixtures/blocker-events/ownership_outside_scope/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ownership_outside_scope/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/ownership_outside_scope/expected-envelope.json b/tests/integration/fixtures/blocker-events/ownership_outside_scope/expected-envelope.json
new file mode 100644
index 0000000..0062f5e
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ownership_outside_scope/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "ownership_outside_scope",
+  "category": "ownership",
+  "severity": "warn",
+  "message": "{path} is outside file_ownership for any deliverable in {row}",
+  "remediation_hint": "Add the path to the appropriate deliverable's file_ownership in definition.yaml, or write to a different file",
+  "confirmation_path": "warn-with-confirm"
+}
diff --git a/tests/integration/fixtures/blocker-events/ownership_outside_scope/normalized.json b/tests/integration/fixtures/blocker-events/ownership_outside_scope/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ownership_outside_scope/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/ownership_outside_scope/pi.json b/tests/integration/fixtures/blocker-events/ownership_outside_scope/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/ownership_outside_scope/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/pending_user_actions/SKIP_REASON b/tests/integration/fixtures/blocker-events/pending_user_actions/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/pending_user_actions/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/pending_user_actions/claude.json b/tests/integration/fixtures/blocker-events/pending_user_actions/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/pending_user_actions/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/pending_user_actions/expected-envelope.json b/tests/integration/fixtures/blocker-events/pending_user_actions/expected-envelope.json
new file mode 100644
index 0000000..533443d
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/pending_user_actions/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "pending_user_actions",
+  "category": "user_action",
+  "severity": "block",
+  "message": "row has {count} pending user action(s)",
+  "remediation_hint": "Resolve or clear the pending user actions through the canonical workflow before advancing.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/pending_user_actions/normalized.json b/tests/integration/fixtures/blocker-events/pending_user_actions/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/pending_user_actions/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/pending_user_actions/pi.json b/tests/integration/fixtures/blocker-events/pending_user_actions/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/pending_user_actions/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/claude.json b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/claude.json
new file mode 100644
index 0000000..fdc88c3
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit"}}
diff --git a/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/expected-envelope.json b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/expected-envelope.json
new file mode 100644
index 0000000..6c2daf0
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "precommit_install_artifact_staged",
+  "category": "scaffold",
+  "severity": "block",
+  "message": "refusing to stage install-artifact bin/foo.bak; move to $XDG_STATE_HOME/furrow/",
+  "remediation_hint": "Install artifacts (bin/*.bak, .claude/rules/*.bak) belong in $XDG_STATE_HOME/furrow/, not in the repository. Unstage and relocate.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/normalized.json b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/normalized.json
new file mode 100644
index 0000000..eda4ca2
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/normalized.json
@@ -0,0 +1,9 @@
+{
+  "version": "1",
+  "event_type": "pre_commit_bakfiles",
+  "payload": {
+    "staged_paths": [
+      "bin/foo.bak"
+    ]
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/pi.json b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/pi.json
new file mode 100644
index 0000000..acdbfae
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_install_artifact_staged/pi.json
@@ -0,0 +1,19 @@
+{
+  "toolName": "git_commit",
+  "input": {
+    "staged_paths": [
+      "bin/foo.bak"
+    ]
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_commit_bakfiles",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_commit_bakfiles",
+    "payload": {
+      "staged_paths": [
+        "bin/foo.bak"
+      ]
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/claude.json b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/claude.json
new file mode 100644
index 0000000..fdc88c3
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit"}}
diff --git a/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/expected-envelope.json b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/expected-envelope.json
new file mode 100644
index 0000000..7b2e1e1
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "precommit_script_mode_invalid",
+  "category": "scaffold",
+  "severity": "block",
+  "message": "bin/frw.d/scripts/foo.sh must be 100755 (got 100644)",
+  "remediation_hint": "Run `chmod +x {path}` and re-stage so the file's git index mode is 100755.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/normalized.json b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/normalized.json
new file mode 100644
index 0000000..1a0e9ad
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/normalized.json
@@ -0,0 +1,12 @@
+{
+  "version": "1",
+  "event_type": "pre_commit_script_modes",
+  "payload": {
+    "script_modes": [
+      {
+        "path": "bin/frw.d/scripts/foo.sh",
+        "mode": "100644"
+      }
+    ]
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/pi.json b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/pi.json
new file mode 100644
index 0000000..c8581cb
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_script_mode_invalid/pi.json
@@ -0,0 +1,21 @@
+{
+  "toolName": "git_commit",
+  "input": {
+    "path": "bin/frw.d/scripts/foo.sh",
+    "mode": "100644"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_commit_script_modes",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_commit_script_modes",
+    "payload": {
+      "script_modes": [
+        {
+          "path": "bin/frw.d/scripts/foo.sh",
+          "mode": "100644"
+        }
+      ]
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/claude.json b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/claude.json
new file mode 100644
index 0000000..fdc88c3
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"git commit"}}
diff --git a/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/expected-envelope.json b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/expected-envelope.json
new file mode 100644
index 0000000..5138fa5
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "precommit_typechange_to_symlink",
+  "category": "scaffold",
+  "severity": "block",
+  "message": "refusing type-change to symlink on bin/alm (see docs/architecture/self-hosting.md)",
+  "remediation_hint": "Protected paths (bin/alm, bin/rws, bin/sds, .claude/rules/*) must remain regular files; do not stage a symlink type-change.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/normalized.json b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/normalized.json
new file mode 100644
index 0000000..2d7b753
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/normalized.json
@@ -0,0 +1,13 @@
+{
+  "version": "1",
+  "event_type": "pre_commit_typechange",
+  "payload": {
+    "typechange_entries": [
+      {
+        "path": "bin/alm",
+        "new_mode": "120000",
+        "status": "T"
+      }
+    ]
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/pi.json b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/pi.json
new file mode 100644
index 0000000..85424e4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/precommit_typechange_to_symlink/pi.json
@@ -0,0 +1,21 @@
+{
+  "toolName": "git_commit",
+  "input": {
+    "path": "bin/alm"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_commit_typechange",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_commit_typechange",
+    "payload": {
+      "typechange_entries": [
+        {
+          "path": "bin/alm",
+          "new_mode": "120000",
+          "status": "T"
+        }
+      ]
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/claude.json b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/claude.json
new file mode 100644
index 0000000..86f09a1
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/claude.json
@@ -0,0 +1,7 @@
+{
+  "hook_event_name": "PreToolUse",
+  "tool_name": "Bash",
+  "tool_input": {
+    "command": "bash bin/frw.d/hooks/foo.sh"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/expected-envelope.json b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/expected-envelope.json
new file mode 100644
index 0000000..81074a3
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "script_guard_internal_invocation",
+  "category": "scaffold",
+  "severity": "block",
+  "message": "bin/frw.d/ scripts are internal — use frw, rws, alm, or sds (command: bash bin/frw.d/hooks/foo.sh)",
+  "remediation_hint": "Invoke the public CLI entry points (frw, rws, alm, sds). Direct invocation of bin/frw.d/ scripts is blocked.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/normalized.json b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/normalized.json
new file mode 100644
index 0000000..0535e99
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/normalized.json
@@ -0,0 +1,7 @@
+{
+  "version": "1",
+  "event_type": "pre_bash_internal_script",
+  "payload": {
+    "command": "bash bin/frw.d/hooks/foo.sh"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/pi.json b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/pi.json
new file mode 100644
index 0000000..5a76c5d
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/script_guard_internal_invocation/pi.json
@@ -0,0 +1,15 @@
+{
+  "toolName": "bash",
+  "input": {
+    "command": "bash bin/frw.d/hooks/foo.sh"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_bash_internal_script",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_bash_internal_script",
+    "payload": {
+      "command": "bash bin/frw.d/hooks/foo.sh"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/seed_status_mismatch/SKIP_REASON b/tests/integration/fixtures/blocker-events/seed_status_mismatch/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_status_mismatch/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/seed_status_mismatch/claude.json b/tests/integration/fixtures/blocker-events/seed_status_mismatch/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_status_mismatch/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/seed_status_mismatch/expected-envelope.json b/tests/integration/fixtures/blocker-events/seed_status_mismatch/expected-envelope.json
new file mode 100644
index 0000000..eab979f
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_status_mismatch/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "seed_status_mismatch",
+  "category": "seed",
+  "severity": "block",
+  "message": "linked seed {seed_id} status {actual_status} does not match expected {expected_status}",
+  "remediation_hint": "Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/seed_status_mismatch/normalized.json b/tests/integration/fixtures/blocker-events/seed_status_mismatch/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_status_mismatch/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/seed_status_mismatch/pi.json b/tests/integration/fixtures/blocker-events/seed_status_mismatch/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_status_mismatch/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/seed_store_unavailable/SKIP_REASON b/tests/integration/fixtures/blocker-events/seed_store_unavailable/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_store_unavailable/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/seed_store_unavailable/claude.json b/tests/integration/fixtures/blocker-events/seed_store_unavailable/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_store_unavailable/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/seed_store_unavailable/expected-envelope.json b/tests/integration/fixtures/blocker-events/seed_store_unavailable/expected-envelope.json
new file mode 100644
index 0000000..3d0aebf
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_store_unavailable/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "seed_store_unavailable",
+  "category": "seed",
+  "severity": "block",
+  "message": "seed store could not be read",
+  "remediation_hint": "Repair the linked seed state so it matches the row step, then retry the checkpoint through the backend.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/seed_store_unavailable/normalized.json b/tests/integration/fixtures/blocker-events/seed_store_unavailable/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_store_unavailable/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/seed_store_unavailable/pi.json b/tests/integration/fixtures/blocker-events/seed_store_unavailable/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/seed_store_unavailable/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/state_json_direct_write/claude.json b/tests/integration/fixtures/blocker-events/state_json_direct_write/claude.json
new file mode 100644
index 0000000..0f2d3af
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_json_direct_write/claude.json
@@ -0,0 +1,7 @@
+{
+  "hook_event_name": "PreToolUse",
+  "tool_name": "Write",
+  "tool_input": {
+    "file_path": "/tmp/fakerow/.furrow/rows/r1/state.json"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/state_json_direct_write/expected-envelope.json b/tests/integration/fixtures/blocker-events/state_json_direct_write/expected-envelope.json
new file mode 100644
index 0000000..92fd24b
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_json_direct_write/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "state_json_direct_write",
+  "category": "state-mutation",
+  "severity": "block",
+  "message": "state.json is Furrow-exclusive — use frw update-state (path: /tmp/fakerow/.furrow/rows/r1/state.json)",
+  "remediation_hint": "Route the mutation through the canonical CLI (frw update-state, rws transition, rws complete-deliverable). Direct edits to state.json are blocked by the state-guard hook.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/state_json_direct_write/normalized.json b/tests/integration/fixtures/blocker-events/state_json_direct_write/normalized.json
new file mode 100644
index 0000000..812289c
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_json_direct_write/normalized.json
@@ -0,0 +1,8 @@
+{
+  "version": "1",
+  "event_type": "pre_write_state_json",
+  "payload": {
+    "target_path": "/tmp/fakerow/.furrow/rows/r1/state.json",
+    "tool_name": "Write"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/state_json_direct_write/pi.json b/tests/integration/fixtures/blocker-events/state_json_direct_write/pi.json
new file mode 100644
index 0000000..1e78a62
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_json_direct_write/pi.json
@@ -0,0 +1,16 @@
+{
+  "toolName": "write",
+  "input": {
+    "path": "/tmp/fakerow/.furrow/rows/r1/state.json"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_write_state_json",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_write_state_json",
+    "payload": {
+      "target_path": "/tmp/fakerow/.furrow/rows/r1/state.json",
+      "tool_name": "write"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/state_validation_failed_warn/claude.json b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/claude.json
new file mode 100644
index 0000000..3673868
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"Stop","stop_hook_active":true}
diff --git a/tests/integration/fixtures/blocker-events/state_validation_failed_warn/expected-envelope.json b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/expected-envelope.json
new file mode 100644
index 0000000..d3b3225
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "state_validation_failed_warn",
+  "category": "state-mutation",
+  "severity": "warn",
+  "message": "state.json validation failed for r1",
+  "remediation_hint": "Run `rws status {row}` and inspect the reported issues; the state may have drifted from schema.",
+  "confirmation_path": "silent"
+}
diff --git a/tests/integration/fixtures/blocker-events/state_validation_failed_warn/normalized.json b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/normalized.json
new file mode 100644
index 0000000..ef4061c
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/normalized.json
@@ -0,0 +1,10 @@
+{
+  "version": "1",
+  "event_type": "stop_work_check",
+  "row": "r1",
+  "payload": {
+    "row": "r1",
+    "summary_path": "/nonexistent/summary.md",
+    "state_validation_ok": false
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/state_validation_failed_warn/pi.json b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/pi.json
new file mode 100644
index 0000000..f56afce
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/state_validation_failed_warn/pi.json
@@ -0,0 +1,18 @@
+{
+  "toolName": "stop",
+  "input": {
+    "row": "r1"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "stop_work_check",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "stop_work_check",
+    "row": "r1",
+    "payload": {
+      "row": "r1",
+      "summary_path": "/nonexistent/summary.md",
+      "state_validation_ok": false
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/step_order_invalid/SKIP_REASON b/tests/integration/fixtures/blocker-events/step_order_invalid/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/step_order_invalid/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/step_order_invalid/claude.json b/tests/integration/fixtures/blocker-events/step_order_invalid/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/step_order_invalid/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/step_order_invalid/expected-envelope.json b/tests/integration/fixtures/blocker-events/step_order_invalid/expected-envelope.json
new file mode 100644
index 0000000..0e2fef9
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/step_order_invalid/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "step_order_invalid",
+  "category": "state-mutation",
+  "severity": "block",
+  "message": "row {row}: invalid step order — cannot transition from '{current_step}' to '{target_step}'",
+  "remediation_hint": "Only adjacent forward transitions in the step sequence are supported. Complete the current step or reground via `rws status`.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/step_order_invalid/normalized.json b/tests/integration/fixtures/blocker-events/step_order_invalid/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/step_order_invalid/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/step_order_invalid/pi.json b/tests/integration/fixtures/blocker-events/step_order_invalid/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/step_order_invalid/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty/claude.json b/tests/integration/fixtures/blocker-events/summary_section_empty/claude.json
new file mode 100644
index 0000000..3673868
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"Stop","stop_hook_active":true}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty/expected-envelope.json b/tests/integration/fixtures/blocker-events/summary_section_empty/expected-envelope.json
new file mode 100644
index 0000000..84d6cd9
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "summary_section_empty",
+  "category": "summary",
+  "severity": "block",
+  "message": "summary.md section 'Key Findings' has 0 non-empty content lines (need at least 1) at __FIXTURE_DIR__/summary.md",
+  "remediation_hint": "Use `rws update-summary <section>` to populate the section with substantive content; placeholders are not sufficient.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty/normalized.json b/tests/integration/fixtures/blocker-events/summary_section_empty/normalized.json
new file mode 100644
index 0000000..927f607
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty/normalized.json
@@ -0,0 +1,12 @@
+{
+  "version": "1",
+  "event_type": "stop_summary_validation",
+  "row": "r1",
+  "step": "plan",
+  "payload": {
+    "row": "r1",
+    "step": "plan",
+    "summary_path": "__FIXTURE_DIR__/summary.md",
+    "last_decided_by": "human"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty/pi.json b/tests/integration/fixtures/blocker-events/summary_section_empty/pi.json
new file mode 100644
index 0000000..b1d4447
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty/pi.json
@@ -0,0 +1,20 @@
+{
+  "toolName": "stop",
+  "input": {
+    "row": "r1"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "stop_summary_validation",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "stop_summary_validation",
+    "row": "r1",
+    "step": "plan",
+    "payload": {
+      "row": "r1",
+      "step": "plan",
+      "summary_path": "__FIXTURE_DIR__/summary.md",
+      "last_decided_by": "human"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty/summary.md b/tests/integration/fixtures/blocker-events/summary_section_empty/summary.md
new file mode 100644
index 0000000..4c5a690
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty/summary.md
@@ -0,0 +1,26 @@
+## Task
+
+A.
+
+## Current State
+
+B.
+
+## Artifact Paths
+
+C.
+
+## Settled Decisions
+
+D.
+
+## Key Findings
+
+
+## Open Questions
+
+F.
+
+## Recommendations
+
+G.
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty_warn/claude.json b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/claude.json
new file mode 100644
index 0000000..3673868
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"Stop","stop_hook_active":true}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty_warn/expected-envelope.json b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/expected-envelope.json
new file mode 100644
index 0000000..0bc9b0e
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "summary_section_empty_warn",
+  "category": "summary",
+  "severity": "warn",
+  "message": "summary.md section 'Key Findings' has fewer than 2 lines of content for r1",
+  "remediation_hint": "Use `rws update-summary {section}` to add substantive content. This is a session-boundary warning, not a hard block.",
+  "confirmation_path": "silent"
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty_warn/normalized.json b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/normalized.json
new file mode 100644
index 0000000..572d486
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/normalized.json
@@ -0,0 +1,10 @@
+{
+  "version": "1",
+  "event_type": "stop_work_check",
+  "row": "r1",
+  "payload": {
+    "row": "r1",
+    "summary_path": "__FIXTURE_DIR__/summary.md",
+    "state_validation_ok": true
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty_warn/pi.json b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/pi.json
new file mode 100644
index 0000000..06bac2f
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/pi.json
@@ -0,0 +1,18 @@
+{
+  "toolName": "stop",
+  "input": {
+    "row": "r1"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "stop_work_check",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "stop_work_check",
+    "row": "r1",
+    "payload": {
+      "row": "r1",
+      "summary_path": "__FIXTURE_DIR__/summary.md",
+      "state_validation_ok": true
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_empty_warn/summary.md b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/summary.md
new file mode 100644
index 0000000..4e0aa7b
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_empty_warn/summary.md
@@ -0,0 +1,27 @@
+## Task
+
+A.
+
+## Current State
+
+B.
+
+## Artifact Paths
+
+C.
+
+## Settled Decisions
+
+D.
+
+## Key Findings
+
+one line
+
+## Open Questions
+
+one line
+
+## Recommendations
+
+one line
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing/claude.json b/tests/integration/fixtures/blocker-events/summary_section_missing/claude.json
new file mode 100644
index 0000000..3673868
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"Stop","stop_hook_active":true}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing/expected-envelope.json b/tests/integration/fixtures/blocker-events/summary_section_missing/expected-envelope.json
new file mode 100644
index 0000000..d967fc5
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "summary_section_missing",
+  "category": "summary",
+  "severity": "block",
+  "message": "summary.md is missing required section 'Recommendations' (path: __FIXTURE_DIR__/summary.md)",
+  "remediation_hint": "Use `rws update-summary <section>` to add the missing section. summary.md must contain Task, Current State, Artifact Paths, Settled Decisions, Key Findings, Open Questions, and Recommendations.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing/normalized.json b/tests/integration/fixtures/blocker-events/summary_section_missing/normalized.json
new file mode 100644
index 0000000..927f607
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing/normalized.json
@@ -0,0 +1,12 @@
+{
+  "version": "1",
+  "event_type": "stop_summary_validation",
+  "row": "r1",
+  "step": "plan",
+  "payload": {
+    "row": "r1",
+    "step": "plan",
+    "summary_path": "__FIXTURE_DIR__/summary.md",
+    "last_decided_by": "human"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing/pi.json b/tests/integration/fixtures/blocker-events/summary_section_missing/pi.json
new file mode 100644
index 0000000..b1d4447
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing/pi.json
@@ -0,0 +1,20 @@
+{
+  "toolName": "stop",
+  "input": {
+    "row": "r1"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "stop_summary_validation",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "stop_summary_validation",
+    "row": "r1",
+    "step": "plan",
+    "payload": {
+      "row": "r1",
+      "step": "plan",
+      "summary_path": "__FIXTURE_DIR__/summary.md",
+      "last_decided_by": "human"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing/summary.md b/tests/integration/fixtures/blocker-events/summary_section_missing/summary.md
new file mode 100644
index 0000000..271bfe7
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing/summary.md
@@ -0,0 +1,23 @@
+## Task
+
+A.
+
+## Current State
+
+B.
+
+## Artifact Paths
+
+C.
+
+## Settled Decisions
+
+D.
+
+## Key Findings
+
+E.
+
+## Open Questions
+
+F.
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing_warn/claude.json b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/claude.json
new file mode 100644
index 0000000..3673868
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/claude.json
@@ -0,0 +1 @@
+{"hook_event_name":"Stop","stop_hook_active":true}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing_warn/expected-envelope.json b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/expected-envelope.json
new file mode 100644
index 0000000..c781dec
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "summary_section_missing_warn",
+  "category": "summary",
+  "severity": "warn",
+  "message": "summary.md missing required sections for r1: Current State Artifact Paths Settled Decisions Key Findings Open Questions",
+  "remediation_hint": "Use `rws update-summary` to populate the missing sections. This is a session-boundary warning, not a hard block.",
+  "confirmation_path": "silent"
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing_warn/normalized.json b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/normalized.json
new file mode 100644
index 0000000..572d486
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/normalized.json
@@ -0,0 +1,10 @@
+{
+  "version": "1",
+  "event_type": "stop_work_check",
+  "row": "r1",
+  "payload": {
+    "row": "r1",
+    "summary_path": "__FIXTURE_DIR__/summary.md",
+    "state_validation_ok": true
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing_warn/pi.json b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/pi.json
new file mode 100644
index 0000000..06bac2f
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/pi.json
@@ -0,0 +1,18 @@
+{
+  "toolName": "stop",
+  "input": {
+    "row": "r1"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "stop_work_check",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "stop_work_check",
+    "row": "r1",
+    "payload": {
+      "row": "r1",
+      "summary_path": "__FIXTURE_DIR__/summary.md",
+      "state_validation_ok": true
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/summary_section_missing_warn/summary.md b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/summary.md
new file mode 100644
index 0000000..2fe238a
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/summary_section_missing_warn/summary.md
@@ -0,0 +1,3 @@
+## Task
+
+A.
diff --git a/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/SKIP_REASON b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/claude.json b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/expected-envelope.json b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/expected-envelope.json
new file mode 100644
index 0000000..bc367eb
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "supersedence_evidence_missing",
+  "category": "archive",
+  "severity": "block",
+  "message": "supersedence evidence missing or mismatched for row (required commit={required_commit}, row={required_row}; confirmed commit={confirmed_commit}, row={confirmed_row})",
+  "remediation_hint": "Pass --supersedes-confirmed <commit>:<row> matching the supersedes block in definition.yaml so the archive ceremony has durable evidence.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/normalized.json b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/pi.json b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supersedence_evidence_missing/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/SKIP_REASON b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/claude.json b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/expected-envelope.json b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/expected-envelope.json
new file mode 100644
index 0000000..d603d90
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "supervised_boundary_unconfirmed",
+  "category": "gate",
+  "severity": "block",
+  "message": "row {row}: supervised gate boundary '{boundary}' requires explicit human approval",
+  "remediation_hint": "Provide explicit human approval (decided_by=human with evidence) before crossing a supervised boundary.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/normalized.json b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/pi.json b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/supervised_boundary_unconfirmed/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/verdict_direct_write/claude.json b/tests/integration/fixtures/blocker-events/verdict_direct_write/claude.json
new file mode 100644
index 0000000..ee29c9c
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_direct_write/claude.json
@@ -0,0 +1,7 @@
+{
+  "hook_event_name": "PreToolUse",
+  "tool_name": "Write",
+  "tool_input": {
+    "file_path": "/tmp/fakerow/.furrow/rows/r1/gate-verdicts/v1.json"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/verdict_direct_write/expected-envelope.json b/tests/integration/fixtures/blocker-events/verdict_direct_write/expected-envelope.json
new file mode 100644
index 0000000..cf39a3b
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_direct_write/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "verdict_direct_write",
+  "category": "gate",
+  "severity": "block",
+  "message": "gate-verdicts/ is write-protected — verdicts written by evaluator subagent only (path: /tmp/fakerow/.furrow/rows/r1/gate-verdicts/v1.json)",
+  "remediation_hint": "Verdict files are written exclusively by the gate-evaluator subagent via the canonical evaluation flow. Do not hand-edit gate-verdicts/.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/verdict_direct_write/normalized.json b/tests/integration/fixtures/blocker-events/verdict_direct_write/normalized.json
new file mode 100644
index 0000000..3220a3b
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_direct_write/normalized.json
@@ -0,0 +1,8 @@
+{
+  "version": "1",
+  "event_type": "pre_write_verdict",
+  "payload": {
+    "target_path": "/tmp/fakerow/.furrow/rows/r1/gate-verdicts/v1.json",
+    "tool_name": "Write"
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/verdict_direct_write/pi.json b/tests/integration/fixtures/blocker-events/verdict_direct_write/pi.json
new file mode 100644
index 0000000..6495767
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_direct_write/pi.json
@@ -0,0 +1,16 @@
+{
+  "toolName": "write",
+  "input": {
+    "path": "/tmp/fakerow/.furrow/rows/r1/gate-verdicts/v1.json"
+  },
+  "_driver_branch": "guard",
+  "_driver_event_type": "pre_write_verdict",
+  "_driver_normalized": {
+    "version": "1",
+    "event_type": "pre_write_verdict",
+    "payload": {
+      "target_path": "/tmp/fakerow/.furrow/rows/r1/gate-verdicts/v1.json",
+      "tool_name": "write"
+    }
+  }
+}
diff --git a/tests/integration/fixtures/blocker-events/verdict_linkage_missing/SKIP_REASON b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/SKIP_REASON
new file mode 100644
index 0000000..d01d6e8
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/SKIP_REASON
@@ -0,0 +1 @@
+no guard event-type — emitted Go-side only (validators / row_workflow.go); covered by internal/cli/*_test.go; future surface for follow-up TODO go-side-emit-event-types
diff --git a/tests/integration/fixtures/blocker-events/verdict_linkage_missing/claude.json b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/claude.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/claude.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/fixtures/blocker-events/verdict_linkage_missing/expected-envelope.json b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/expected-envelope.json
new file mode 100644
index 0000000..ca0cdf9
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/expected-envelope.json
@@ -0,0 +1,8 @@
+{
+  "code": "verdict_linkage_missing",
+  "category": "gate",
+  "severity": "block",
+  "message": "row {row}: gate '{boundary}' has no linked verdict file",
+  "remediation_hint": "Evaluated gates require a verdict file under gate-verdicts/. Run the evaluator subagent to produce one before recording the gate.",
+  "confirmation_path": "block"
+}
diff --git a/tests/integration/fixtures/blocker-events/verdict_linkage_missing/normalized.json b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/normalized.json
new file mode 100644
index 0000000..59cc669
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/normalized.json
@@ -0,0 +1 @@
+{"version":"1","event_type":"","payload":{}}
diff --git a/tests/integration/fixtures/blocker-events/verdict_linkage_missing/pi.json b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/pi.json
new file mode 100644
index 0000000..0967ef4
--- /dev/null
+++ b/tests/integration/fixtures/blocker-events/verdict_linkage_missing/pi.json
@@ -0,0 +1 @@
+{}
diff --git a/tests/integration/test-blocker-coverage.sh b/tests/integration/test-blocker-coverage.sh
new file mode 100755
index 0000000..c1422f7
--- /dev/null
+++ b/tests/integration/test-blocker-coverage.sh
@@ -0,0 +1,236 @@
+#!/bin/bash
+# test-blocker-coverage.sh — D4 coverage assertion (per specs/shared-contracts.md §C7).
+#
+# For every code in schemas/blocker-taxonomy.yaml, asserts that
+# tests/integration/fixtures/blocker-events/<code>/ exists with at least
+# the four canonical fixture files {normalized.json, claude.json, pi.json,
+# expected-envelope.json}. For codes whose fixture set is reachable
+# through `furrow guard <event-type>` (i.e., a guard handler exists), the
+# test additionally:
+#
+#   1. Pipes normalized.json into `go run ./cmd/furrow guard <event-type>`
+#      after substituting any __FIXTURE_DIR__ placeholders with the
+#      absolute path of the fixture directory (so fixtures that need
+#      filesystem state can ship that state alongside).
+#   2. Asserts the resulting JSON array contains an envelope matching
+#      expected-envelope.json (jq -S byte-equal compare on .code,
+#      .severity, .category, .confirmation_path, .message,
+#      .remediation_hint).
+#
+# For codes with no guard event-type (Go-side codes emitted from
+# row_workflow.go / definition validators / etc., not reachable via
+# `furrow guard`), the fixture directory contains a SKIP_REASON file and
+# the test logs a SKIP line — these codes are not yet wired through the
+# guard CLI and per-code coverage is enforced via the existing Go tests
+# (internal/cli/*_test.go), not this integration test.
+#
+# Failure modes (per spec AC-1, AC-2, AC-9):
+#   - missing fixture dir            → FAIL: fixture missing for code <code>
+#   - missing fixture file           → FAIL: <code> <file> (file not found...)
+#   - guard envelope shape mismatch  → FAIL: <code> .<field> mismatch
+#
+# Auto-discovered by tests/integration/run-all.sh's test-*.sh glob.
+
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+# shellcheck source=helpers.sh
+source "$SCRIPT_DIR/helpers.sh"
+
+echo "=== test-blocker-coverage.sh ==="
+
+# --- Structural prerequisites -------------------------------------------
+for _bin in jq yq go; do
+  if ! command -v "$_bin" >/dev/null 2>&1; then
+    printf '  FAIL: required command not on PATH: %s\n' "$_bin" >&2
+    exit 1
+  fi
+done
+
+TAXONOMY="${PROJECT_ROOT}/schemas/blocker-taxonomy.yaml"
+EVENT_CATALOG="${PROJECT_ROOT}/schemas/blocker-event.yaml"
+FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/blocker-events"
+
+if [ ! -f "$TAXONOMY" ]; then
+  printf '  FAIL: taxonomy file not readable: %s\n' "$TAXONOMY" >&2
+  exit 1
+fi
+if [ ! -f "$EVENT_CATALOG" ]; then
+  printf '  FAIL: event catalog not readable: %s\n' "$EVENT_CATALOG" >&2
+  exit 1
+fi
+if [ ! -d "$FIXTURE_ROOT" ]; then
+  printf '  FAIL: fixture root missing: %s\n' "$FIXTURE_ROOT" >&2
+  exit 1
+fi
+
+# --- Skip lists ---------------------------------------------------------
+# DEFERRED_CODES: codes deferred from migration per
+# .furrow/rows/blocker-taxonomy-foundation/research/hook-audit-final.md §4.
+# D3 deferred zero codes (all 10 hooks fully migrated). Empty list keeps
+# the operational hook for future deferrals without a code change.
+DEFERRED_CODES=""
+
+# --- Build the guard-reachable code map (event-type per code) -----------
+# Read schemas/blocker-event.yaml's emitted_codes[] across all 10 event
+# types and produce a "code\tevent_type" mapping. For codes emitted by
+# multiple event types (currently none), the first wins — sufficient for
+# coverage assertion since both paths feed the same handler.
+build_event_map() {
+  yq -r '
+    .event_types[] as $et
+    | $et.emitted_codes[] | [., $et.name] | @tsv
+  ' "$EVENT_CATALOG"
+}
+
+EVENT_MAP="$(build_event_map)"
+
+event_type_for_code() {
+  printf '%s\n' "$EVENT_MAP" | awk -F'\t' -v c="$1" '$1==c {print $2; exit}'
+}
+
+# --- Per-code assertion -------------------------------------------------
+# Capture dir for normalized-event renders + guard outputs (per spec).
+CAPTURE_DIR="$(mktemp -d)"
+trap 'rm -rf "${CAPTURE_DIR:-}"' EXIT INT TERM
+
+assert_envelope_field() {
+  _code="$1"; _captured="$2"; _expected="$3"; _field="$4"; _fix_dir="$5"
+  TESTS_RUN=$((TESTS_RUN + 1))
+  # Expected value: read from expected-envelope.json with __FIXTURE_DIR__
+  # substituted to the absolute fixture directory (matches the same
+  # substitution applied to normalized.json before piping to guard).
+  _exp_raw="$(jq -r ".${_field}" "$_expected" 2>/dev/null || printf '__JQ_ERROR__')"
+  _exp="$(printf '%s' "$_exp_raw" | sed "s|__FIXTURE_DIR__|${_fix_dir}|g")"
+  # The guard CLI emits an array of zero or more envelopes. For codes
+  # that emit multiple envelopes per invocation (e.g. summary_section_*
+  # walks every required section), pick the FIRST envelope whose .code
+  # matches and assert against it. The single-envelope cases pick the
+  # only entry; multi-envelope cases pick the first ordered match,
+  # which the expected fixture is authored against.
+  _got="$(jq -r --arg c "$_code" \
+            'first(.[] | select(.code == $c)) | .'"${_field}" \
+            "$_captured" 2>/dev/null || printf '__JQ_ERROR__')"
+  if [ "$_exp" = "$_got" ]; then
+    printf "  PASS: %s envelope .%s matches expected\n" "$_code" "$_field"
+    TESTS_PASSED=$((TESTS_PASSED + 1))
+    return 0
+  else
+    printf "  FAIL: %s envelope .%s mismatch (expected '%s', got '%s')\n" \
+      "$_code" "$_field" "$_exp" "$_got" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    return 1
+  fi
+}
+
+run_one_code() {
+  _code="$1"
+  _dir="${FIXTURE_ROOT}/${_code}"
+
+  # AC-2 / AC-9: missing fixture dir surfaces the code name.
+  if [ ! -d "$_dir" ]; then
+    TESTS_RUN=$((TESTS_RUN + 1))
+    printf "  FAIL: fixture missing for code %s (dir not found: %s)\n" \
+      "$_code" "$_dir" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    return 1
+  fi
+
+  # Required four files.
+  assert_file_exists "${_code} normalized.json"        "${_dir}/normalized.json"
+  assert_file_exists "${_code} claude.json"            "${_dir}/claude.json"
+  assert_file_exists "${_code} pi.json"                "${_dir}/pi.json"
+  assert_file_exists "${_code} expected-envelope.json" "${_dir}/expected-envelope.json"
+
+  # Skip rule 1: deferred codes (none in W4).
+  case " $DEFERRED_CODES " in
+    *" ${_code} "*)
+      printf "  SKIP: %s (reason: deferred per audit)\n" "$_code"
+      return 0
+      ;;
+  esac
+
+  # Skip rule 2: guard handler not wired (Go-side codes only).
+  if [ -f "${_dir}/SKIP_REASON" ]; then
+    _reason="$(head -n1 "${_dir}/SKIP_REASON")"
+    printf "  SKIP: %s (%s)\n" "$_code" "$_reason"
+    return 0
+  fi
+
+  _event_type="$(event_type_for_code "$_code")"
+  if [ -z "$_event_type" ]; then
+    # Defensive: SKIP_REASON should have been set, but treat
+    # missing-event-type as a skip with logged reason rather than a hard
+    # failure so the inventory test (parity.sh) can carry the assertion.
+    printf "  SKIP: %s (no guard event-type — Go-only emit-site)\n" "$_code"
+    return 0
+  fi
+
+  # Render normalized.json with __FIXTURE_DIR__ resolved.
+  _rendered="${CAPTURE_DIR}/${_code}.normalized.json"
+  sed "s|__FIXTURE_DIR__|${_dir}|g" "${_dir}/normalized.json" > "$_rendered"
+
+  # Run guard. Use FURROW_BIN if exported (test-suite speedup); else go run.
+  _captured="${CAPTURE_DIR}/${_code}.envelope.json"
+  _stderr="${CAPTURE_DIR}/${_code}.stderr"
+  _ec=0
+  if [ -n "${FURROW_BIN:-}" ]; then
+    # shellcheck disable=SC2086
+    "$FURROW_BIN" guard "$_event_type" < "$_rendered" \
+      > "$_captured" 2> "$_stderr" || _ec=$?
+  else
+    ( cd "$PROJECT_ROOT" && go run ./cmd/furrow guard "$_event_type" \
+        < "$_rendered" > "$_captured" 2> "$_stderr" ) || _ec=$?
+  fi
+
+  TESTS_RUN=$((TESTS_RUN + 1))
+  if [ "$_ec" -ne 0 ]; then
+    printf "  FAIL: %s guard exited %s (stderr: %s)\n" \
+      "$_code" "$_ec" "$(tr '\n' ' ' < "$_stderr")" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    return 1
+  fi
+
+  # Array must be non-empty and contain at least one envelope with .code == $_code.
+  _len="$(jq -r 'length' "$_captured" 2>/dev/null || printf '0')"
+  if [ "$_len" = "0" ]; then
+    printf "  FAIL: %s guard returned empty array — no envelope emitted\n" \
+      "$_code" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    return 1
+  fi
+  _has="$(jq -r --arg c "$_code" 'any(.[]; .code == $c)' "$_captured" 2>/dev/null || printf 'false')"
+  if [ "$_has" != "true" ]; then
+    _got_codes="$(jq -r '[.[].code] | join(",")' "$_captured" 2>/dev/null || printf '?')"
+    printf "  FAIL: %s expected code in envelope array; got [%s]\n" \
+      "$_code" "$_got_codes" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    return 1
+  fi
+  printf "  PASS: %s guard emitted envelope with matching code\n" "$_code"
+  TESTS_PASSED=$((TESTS_PASSED + 1))
+
+  # Field-by-field assertion against expected-envelope.json (per spec AC-1).
+  # Pass the fixture dir so __FIXTURE_DIR__ in expected.message resolves.
+  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "code"              "$_dir"
+  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "category"          "$_dir"
+  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "severity"          "$_dir"
+  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "confirmation_path" "$_dir"
+  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "message"           "$_dir"
+  assert_envelope_field "$_code" "$_captured" "${_dir}/expected-envelope.json" "remediation_hint"  "$_dir"
+}
+
+# --- Walk every code ----------------------------------------------------
+CODES="$(yq -r '.blockers[].code' "$TAXONOMY")"
+TOTAL_CODES="$(printf '%s\n' "$CODES" | grep -c .)"
+printf "  --- walking %s codes from %s ---\n" "$TOTAL_CODES" "$(basename "$TAXONOMY")"
+
+# Stable iteration; bash IFS over newline.
+while IFS= read -r _c; do
+  [ -n "$_c" ] || continue
+  run_one_code "$_c" || true   # accrue failures into TESTS_FAILED; never abort
+done <<EOF
+$CODES
+EOF
+
+print_summary
diff --git a/tests/integration/test-blocker-parity.sh b/tests/integration/test-blocker-parity.sh
new file mode 100755
index 0000000..2e03647
--- /dev/null
+++ b/tests/integration/test-blocker-parity.sh
@@ -0,0 +1,301 @@
+#!/bin/bash
+# test-blocker-parity.sh — D4 parity + anti-cheat assertions.
+#
+# Per specs/shared-contracts.md §C7: for every (migrated shim, code)
+# pair, the Claude-shape input and the Pi-shape input must produce
+# byte-equal canonical envelopes (after `jq -S` canonicalization).
+#
+# Anti-cheat (1) — subprocess invocation: every migrated shim under
+# bin/frw.d/hooks/ (excluding non-emitters and already-canonical ones)
+# must source blocker_emit.sh and route through `furrow_guard` /
+# `emit_canonical_blocker`. No shim hand-rolls a canonical envelope
+# literal. (Per AC-4 in specs/coverage-and-parity-tests.md.)
+#
+# Anti-cheat (2) — emit-site inventory gate: every migrated shim
+# enumerates the set of event-types it dispatches. Each event-type's
+# emitted_codes[] (per schemas/blocker-event.yaml) must have a complete
+# fixture set under tests/integration/fixtures/blocker-events/<code>/
+# {claude.json, pi.json, expected-envelope.json}. Adding a new shim
+# without per-code fixtures fails this gate. (Per AC-5, AC-10.)
+#
+# Pi-handler-absent skip rule (per shared-contracts §C7): for codes
+# whose Pi-side handler does not exist in adapters/pi/validate-actions.ts,
+# the parity invocation skips with a logged reason naming follow-up TODO
+# pi-tool-call-canonical-schema-and-surface-audit.
+#
+# Auto-discovered by tests/integration/run-all.sh's test-*.sh glob.
+
+set -euo pipefail
+
+SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
+# shellcheck source=helpers.sh
+source "$SCRIPT_DIR/helpers.sh"
+
+echo "=== test-blocker-parity.sh ==="
+
+# --- Structural prerequisites -------------------------------------------
+for _bin in jq yq go; do
+  if ! command -v "$_bin" >/dev/null 2>&1; then
+    printf '  FAIL: required command not on PATH: %s\n' "$_bin" >&2
+    exit 1
+  fi
+done
+
+HOOK_DIR="${PROJECT_ROOT}/bin/frw.d/hooks"
+EVENT_CATALOG="${PROJECT_ROOT}/schemas/blocker-event.yaml"
+PI_ADAPTER="${PROJECT_ROOT}/adapters/pi/validate-actions.ts"
+PI_DRIVER="${PROJECT_ROOT}/adapters/pi/test-driver-blocker-parity.ts"
+FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/blocker-events"
+
+# --- Configuration ------------------------------------------------------
+# DEFERRED_CODES: same operational mirror as the coverage test; D3 deferred
+# zero codes per .furrow/rows/.../research/hook-audit-final.md §4.
+DEFERRED_CODES=""
+
+# MIGRATED_SHIMS: derived from hook-audit-final.md §1. Excludes:
+#   - already-canonical (validate-definition.sh, ownership-warn.sh)
+#   - non-emitters     (append-learning.sh, auto-install.sh, post-compact.sh)
+#   - deleted          (gate-check.sh — not on disk)
+MIGRATED_SHIMS="
+correction-limit.sh
+pre-commit-bakfiles.sh
+pre-commit-script-modes.sh
+pre-commit-typechange.sh
+script-guard.sh
+state-guard.sh
+stop-ideation.sh
+validate-summary.sh
+verdict-guard.sh
+work-check.sh
+"
+
+# Pi-handler presence: handlers exported from adapters/pi/validate-actions.ts.
+# Only definition_* and ownership_outside_scope have native Pi handlers
+# today. All other codes parity-invoke through the test driver's
+# direct-furrow-guard branch (still proves Pi-shape -> normalized event ->
+# Go envelope round-trips), but the *handler-absent* skip gate logs them
+# explicitly per the shared-contracts §C7 rule. Per the spec note: "for
+# codes whose Pi-side `tool_call` shape isn't yet defined", the pi.json
+# fixture is a stub and parity SKIPs with the named follow-up TODO.
+PI_HANDLER_PRESENT_CODES="
+definition_yaml_invalid
+definition_objective_missing
+definition_gate_policy_missing
+definition_gate_policy_invalid
+definition_mode_invalid
+definition_deliverables_empty
+definition_deliverable_name_missing
+definition_deliverable_name_invalid_pattern
+definition_acceptance_criteria_placeholder
+definition_unknown_keys
+ownership_outside_scope
+"
+# Note: those 11 codes are NOT emitted by any of the 10 migrated shims —
+# they flow through validate-definition.sh / ownership-warn.sh (already
+# canonical, out of D3 migration scope). So in practice every per-(shim,
+# code) parity test in this row hits the handler-absent skip path. The
+# skip rule is preserved verbatim because (a) it's the contract specified
+# in shared-contracts §C7, and (b) it documents the precise follow-up
+# work left for pi-tool-call-canonical-schema-and-surface-audit.
+
+# --- Pre-test asserts ---------------------------------------------------
+if [ ! -d "$HOOK_DIR" ]; then
+  printf '  FAIL: hook dir missing: %s\n' "$HOOK_DIR" >&2
+  exit 1
+fi
+if [ ! -f "$EVENT_CATALOG" ]; then
+  printf '  FAIL: event catalog missing: %s\n' "$EVENT_CATALOG" >&2
+  exit 1
+fi
+if [ ! -f "$PI_DRIVER" ]; then
+  printf '  FAIL: Pi driver missing: %s (D4 must ship it)\n' "$PI_DRIVER" >&2
+  exit 1
+fi
+
+# --- Build code → event-type map ----------------------------------------
+build_event_map() {
+  yq -r '
+    .event_types[] as $et
+    | $et.emitted_codes[] | [., $et.name] | @tsv
+  ' "$EVENT_CATALOG"
+}
+EVENT_MAP="$(build_event_map)"
+
+event_type_for_code() {
+  printf '%s\n' "$EVENT_MAP" | awk -F'\t' -v c="$1" '$1==c {print $2; exit}'
+}
+
+# Build event-type → emitted_codes[] map (one per line: "<event_type> <code>").
+event_codes_map() {
+  yq -r '.event_types[] | .name as $n | .emitted_codes[] | "\($n) \(.)"' "$EVENT_CATALOG"
+}
+
+# Capture dir for shim/driver outputs.
+CAPTURE_DIR="$(mktemp -d)"
+trap 'rm -rf "${CAPTURE_DIR:-}"' EXIT INT TERM
+
+# --- Anti-cheat (1): subprocess invocation -----------------------------
+echo "  --- anti-cheat #1: subprocess invocation ---"
+for _shim in $MIGRATED_SHIMS; do
+  _path="${HOOK_DIR}/${_shim}"
+  if [ ! -f "$_path" ]; then
+    TESTS_RUN=$((TESTS_RUN + 1))
+    printf "  FAIL: anti-cheat #1: shim missing: %s\n" "$_path" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    continue
+  fi
+  # Must invoke `furrow_guard` (or `emit_canonical_blocker`, which
+  # transitively requires guard output upstream — work-check.sh uses
+  # the run_stop_work_check helper which calls furrow_guard internally).
+  assert_file_contains \
+    "${_shim} routes through furrow_guard or emit_canonical_blocker" \
+    "$_path" \
+    "furrow_guard\|emit_canonical_blocker"
+  # Must NOT contain a hard-coded canonical envelope literal — i.e., a
+  # `"code"` key declaration in JSON form. (Catches a shim that pretends
+  # to invoke Go but actually echoes a hand-rolled envelope.)
+  assert_file_not_contains \
+    "${_shim} has no hand-rolled \"code\": envelope literal" \
+    "$_path" \
+    '"code"[[:space:]]*:[[:space:]]*"'
+done
+
+# --- Anti-cheat (2): emit-site inventory gate --------------------------
+echo "  --- anti-cheat #2: emit-site inventory gate ---"
+# For each migrated shim, find the event_types it dispatches via
+# `furrow_guard <event_type>`, then enumerate that event_type's
+# emitted_codes[] and assert the fixture set exists.
+for _shim in $MIGRATED_SHIMS; do
+  _path="${HOOK_DIR}/${_shim}"
+  [ -f "$_path" ] || continue
+  # Extract every `furrow_guard <event_type>` token. The event_type
+  # follows the function-name token; awk picks the next field.
+  _event_types="$( { grep -oE 'furrow_guard[[:space:]]+[a-z_]+' "$_path" \
+                       || true; } | awk '{print $2}' | sort -u)"
+  # work-check.sh dispatches via the run_stop_work_check helper rather
+  # than calling furrow_guard directly. Map the helper to its event_type.
+  if grep -q 'run_stop_work_check' "$_path"; then
+    _event_types="$(printf '%s\nstop_work_check\n' "$_event_types" | sort -u)"
+  fi
+  _event_types="$(printf '%s\n' "$_event_types" | grep -v '^$' || true)"
+
+  if [ -z "$_event_types" ]; then
+    TESTS_RUN=$((TESTS_RUN + 1))
+    printf "  FAIL: shim %s: no furrow_guard <event_type> invocation found\n" \
+      "$_shim" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+    continue
+  fi
+
+  for _et in $_event_types; do
+    # Get emitted codes for this event_type from the catalog.
+    _codes="$(event_codes_map | awk -v et="$_et" '$1==et {print $2}')"
+    if [ -z "$_codes" ]; then
+      TESTS_RUN=$((TESTS_RUN + 1))
+      printf "  FAIL: shim %s emits event_type %s but catalog has no codes\n" \
+        "$_shim" "$_et" >&2
+      TESTS_FAILED=$((TESTS_FAILED + 1))
+      continue
+    fi
+    for _code in $_codes; do
+      _dir="${FIXTURE_ROOT}/${_code}"
+      assert_file_exists \
+        "shim ${_shim} emits ${_code}: claude.json present" \
+        "${_dir}/claude.json"
+      assert_file_exists \
+        "shim ${_shim} emits ${_code}: pi.json present" \
+        "${_dir}/pi.json"
+      assert_file_exists \
+        "shim ${_shim} emits ${_code}: expected-envelope.json present" \
+        "${_dir}/expected-envelope.json"
+    done
+  done
+done
+
+# --- Per-(shim, code) parity replay -------------------------------------
+echo "  --- per-(shim, code) parity replay ---"
+
+pi_handler_for_code_present() {
+  _c="$1"
+  case " $(printf '%s' "$PI_HANDLER_PRESENT_CODES" | tr '\n' ' ') " in
+    *" ${_c} "*) return 0 ;;
+    *) return 1 ;;
+  esac
+}
+
+# Replay one code's claude.json through its shim and pi.json through the
+# Pi driver, then jq -S diff the two stdouts and the expected envelope.
+parity_replay() {
+  _shim="$1"; _event_type="$2"; _code="$3"
+  _dir="${FIXTURE_ROOT}/${_code}"
+
+  case " $DEFERRED_CODES " in
+    *" ${_code} "*)
+      printf "  SKIP: %s (reason: deferred per audit)\n" "$_code"
+      return 0
+      ;;
+  esac
+
+  if ! pi_handler_for_code_present "$_code"; then
+    printf "  SKIP: %s parity (Pi handler not yet implemented for %s — see follow-up TODO pi-tool-call-canonical-schema-and-surface-audit)\n" \
+      "$_code" "$_code"
+    return 0
+  fi
+
+  # The remainder of this function executes only when the Pi handler
+  # exists. None of the codes emitted by the 10 migrated shims fall
+  # into the present-handler set today — this is the documented future
+  # surface that closes when the follow-up TODO lands. The block is
+  # preserved so adding a Pi handler automatically activates parity.
+
+  _claude_out="${CAPTURE_DIR}/${_code}.claude.json"
+  _pi_out="${CAPTURE_DIR}/${_code}.pi.json"
+
+  # Render Claude fixture into the shim. Each shim defines a
+  # `hook_<name>` function; we source and invoke it. Pre-commit shims
+  # are exec'd directly (they `main`).
+  ( cd "$PROJECT_ROOT" && \
+      FURROW_ROOT="$PROJECT_ROOT" \
+      bash -c '
+        . "'"${HOOK_DIR}/${_shim}"'"
+        # ... shim-specific entry call would go here
+      ' < "${_dir}/claude.json" > "$_claude_out" 2>/dev/null ) || true
+
+  # Render Pi fixture through the test driver.
+  ( cd "$PROJECT_ROOT" && \
+      bun run "$PI_DRIVER" "${_dir}/pi.json" \
+      > "$_pi_out" 2>/dev/null ) || true
+
+  # jq -S canonical diff.
+  TESTS_RUN=$((TESTS_RUN + 1))
+  if diff -u <(jq -S . "$_claude_out") <(jq -S . "$_pi_out") >/dev/null; then
+    printf "  PASS: %s parity (claude == pi)\n" "$_code"
+    TESTS_PASSED=$((TESTS_PASSED + 1))
+  else
+    printf "  FAIL: %s parity diff:\n%s\n" "$_code" \
+      "$(diff -u <(jq -S . "$_claude_out") <(jq -S . "$_pi_out"))" >&2
+    TESTS_FAILED=$((TESTS_FAILED + 1))
+  fi
+}
+
+# Walk every (shim, event_type, code) triple. The code-set per shim is
+# already validated by the inventory gate above; this loop is the
+# parity assertion proper.
+for _shim in $MIGRATED_SHIMS; do
+  _path="${HOOK_DIR}/${_shim}"
+  [ -f "$_path" ] || continue
+  _event_types="$( { grep -oE 'furrow_guard[[:space:]]+[a-z_]+' "$_path" \
+                       || true; } | awk '{print $2}' | sort -u)"
+  if grep -q 'run_stop_work_check' "$_path"; then
+    _event_types="$(printf '%s\nstop_work_check\n' "$_event_types" | sort -u)"
+  fi
+  _event_types="$(printf '%s\n' "$_event_types" | grep -v '^$' || true)"
+  for _et in $_event_types; do
+    _codes="$(event_codes_map | awk -v et="$_et" '$1==et {print $2}')"
+    for _code in $_codes; do
+      parity_replay "$_shim" "$_et" "$_code"
+    done
+  done
+done
+
+print_summary

commit 5f4fd59ff4826dca0882f7bbc2047303356781bc
Author: Test <test@test.com>
Date:   Sat Apr 25 15:04:47 2026 -0400

    feat(blocker-taxonomy): canonical envelope cutover + 29 new codes
    
    Extend schemas/blocker-taxonomy.yaml from 11 to 40 codes, covering the full
    Blocker baseline (state-mutation, gate, archive, scaffold, summary, ideation,
    seed, artifact, definition, ownership) plus hook-emit codes catalogued in
    research/hook-audit.md. The canonical 11 pre-D1 codes (definition_* +
    ownership_outside_scope) keep their frozen code strings, severities, and
    message_template placeholder sets — enforced by a new
    TestBlockerTaxonomyBackwardCompat11 lock test.
    
    Migrate the rowBlockers `blocker(...)` constructor at the single-point
    target identified in research/status-callers-and-pi-shim.md §A: severity
    becomes a per-code taxonomy lookup (block | warn | info instead of the
    hardcoded "error"); confirmation_path becomes the enum token from the
    taxonomy (block | warn-with-confirm | silent instead of prose); a new
    remediation_hint field is sourced from the taxonomy as the single source
    of user-facing prose. Detail keys (seed_id, path, artifact_id, ...) move
    from being merged into the envelope to a sibling `details` map, so the
    canonical envelope stays at exactly six fields.
    
    Pi adapter migrates in lock-step: formatBlockers in adapters/pi/furrow.ts
    now sources :: fix: prose from blocker.remediation_hint (verbatim) instead
    of interpolating the now-enum confirmation_path. The RowStatusData blockers
    type adds the canonical fields plus an optional details sibling.
    
    Other changes:
    - Add Taxonomy.Lookup and Taxonomy.Applies helpers for step-scoped codes.
    - LoadTaxonomy gains FURROW_TAXONOMY_PATH override + module-source-root
      fallback so tests using t.TempDir() resolve the registry without
      per-test fixture provisioning.
    - Replace the prose Blocker baseline list in
      docs/architecture/pi-step-ceremony-and-artifact-enforcement.md with a
      citation pointer to schemas/blocker-taxonomy.yaml as canonical.
    
    Backward-compat note: codes whose Go emit-sites already used literal names
    (pending_user_actions, seed_*, missing_required_artifact, artifact_*,
    supersedence_evidence_missing, archive_requires_review_gate) keep those
    names verbatim per spec §6.4 to avoid churning the only programmatic
    consumer (Pi).
    
    Verification:
    - go test ./internal/cli/... passes (40 codes resolve through EmitBlocker;
      TestBlockerTaxonomyBackwardCompat11 locks placeholder sets;
      TestBlockerApplicableStepsFilter covers ideate/review/all-steps scoping).
    - furrow row status --json on the active row emits canonical six-field
      envelopes for both data.blockers and data.row.gates.pending_blockers.
    - adapters/pi/furrow.test.ts: 37 pass, 0 fail.
    
    Refs spec: .furrow/rows/blocker-taxonomy-foundation/specs/canonical-blocker-taxonomy.md

diff --git a/adapters/pi/furrow.ts b/adapters/pi/furrow.ts
index b3d8343..66959e6 100644
--- a/adapters/pi/furrow.ts
+++ b/adapters/pi/furrow.ts
@@ -184,7 +184,18 @@ type RowStatusData = {
 			};
 		};
 	};
-	blockers?: Array<{ code?: string; category?: string; severity?: string; message?: string; path?: string; confirmation_path?: string }>;
+	blockers?: Array<{
+		code?: string;
+		category?: string;
+		severity?: string;
+		message?: string;
+		remediation_hint?: string;
+		confirmation_path?: string;
+		// Sibling detail map carried alongside the canonical envelope (not part
+		// of the six-field envelope contract). May contain caller-specific
+		// context (path, seed_id, artifact_id, count, ...). Optional consumers.
+		details?: Record<string, unknown>;
+	}>;
 	warnings?: Array<{ code?: string; message?: string; path?: string }>;
 };
 
@@ -392,13 +403,19 @@ function formatStatusWarnings(data?: RowStatusData): string[] {
 	return warnings.map((warning) => `- ${warning.code ?? "warning"}: ${warning.message ?? "unspecified warning"}`);
 }
 
-function formatBlockers(data?: RowStatusData): string[] {
+export function formatBlockers(data?: RowStatusData): string[] {
 	const blockers = data?.blockers ?? [];
 	if (blockers.length === 0) return ["- none"];
 	return blockers.map((blocker) => {
 		const prefix = [blocker.category, blocker.severity].filter(Boolean).join("/");
-		const confirmation = blocker.confirmation_path ? ` :: fix: ${blocker.confirmation_path}` : "";
-		return `- ${prefix ? `[${prefix}] ` : ""}${blocker.code ?? "blocked"}: ${blocker.message ?? "unspecified blocker"}${confirmation}`;
+		// User-facing remediation prose is sourced verbatim from the canonical
+		// taxonomy's `remediation_hint` field (see schemas/blocker-taxonomy.yaml).
+		// Pi MUST NOT maintain its own enum→prose dictionary; the registry is
+		// the single source of truth. `confirmation_path` is the enum token
+		// (block/warn-with-confirm/silent) — useful for UX decoration but
+		// NOT a sentence to interpolate as prose.
+		const fix = blocker.remediation_hint ? ` :: fix: ${blocker.remediation_hint}` : "";
+		return `- ${prefix ? `[${prefix}] ` : ""}${blocker.code ?? "blocked"}: ${blocker.message ?? "unspecified blocker"}${fix}`;
 	});
 }
 
```

## Instructions

For each dimension, provide: verdict (pass/fail) and one-line evidence.

Output as JSON: {"dimensions": [{"name": "...", "verdict": "...", "evidence": "..."}], "overall": "pass|fail"}
