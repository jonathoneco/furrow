You are reviewing deliverable 'driver-architecture' for quality.

## Acceptance Criteria

- Driver definitions at .furrow/drivers/driver-{step}.yaml — 7 files (ideate, research, plan, spec, decompose, implement, review). Static, runtime-agnostic. Schema: { name: 'driver:{step}', step: '{step}', tools_allowlist: [...], model: 'opus|sonnet|haiku' }. Persona is implicit by convention (skills/{step}.md is the driver brief)
- schemas/driver-definition.schema.json validates the YAML structure (additionalProperties:false). furrow validate driver-definitions --json command checks every .furrow/drivers/driver-{step}.yaml against the schema and emits blocker code driver_definition_invalid (registered by D3 alongside other validation codes — see joint ownership note)
- skills/shared/layer-protocol.md is the canonical contract: defines operator (whole-row, user-facing, state-mutating), phase driver (one-step, session-scoped, runtime-managed), engine (one-shot, Furrow-unaware). Defines handoff exchange (driver→engine via D1's render command), engine-team-composed-at-dispatch model (drivers compose engine teams per dispatch, not at planning-time), and runtime-agnostic message-passing semantics. Cross-references skills/shared/specialist-delegation.md
- skills/shared/specialist-delegation.md rewritten for driver→engine dispatch (replacing the operator→specialist framing). References skills/shared/layer-protocol.md for boundaries; references furrow handoff render --target=engine:* for the dispatch primitive; documents engine-team composition (a driver can dispatch multiple engines in parallel for one deliverable)
- skills/work-context.md updated to describe the operator's per-row context (per-step context moves to driver context via furrow context for-step)
- All 7 skills/{step}.md (ideate, research, plan, spec, decompose, implement, review) reframed as driver briefs — addressed to the phase driver, not the operator. Driver responsibilities: run step ceremony, dispatch engine team, assemble EOS-report. User-facing presentation logic moves out of skills/{step}.md and into commands/work.md.tmpl (operator owns user dialog)
- skills/plan.md update: removes the team-plan.md prescription. Reframes planning step around layered model — engine teams composed at dispatch-time by drivers, not planning-time by operator. plan.json keeps wave/file_ownership/specialist-hint surface; team-plan.md is dropped from the row artifact set entirely (this row's existing team-plan.md will be deleted)
- commands/work.md.tmpl is a Go text/template (not a static markdown file) with runtime branches: {{ if eq .Runtime "claude" }} ... TeamCreate/Agent/SendMessage block ... {{ else if eq .Runtime "pi" }} ... pi-subagents primitives + tree-branch nav block ... {{ end }}. Rendered at install time by furrow render adapters --runtime=<claude|pi>
- furrow render adapters --runtime=<claude|pi> Go util (internal/cli/render/adapters.go) renders runtime-specific files from the runtime-agnostic definitions: (a) commands/work.md.tmpl → commands/work.md per runtime; (b) for Claude, .furrow/drivers/driver-{step}.yaml → .claude/agents/driver-{step}.md (subagent definition with tools/model frontmatter + skills/{step}.md as system prompt body); (c) any other runtime-specific renderings
- Operator session-resume protocol is RUNTIME-CONCERN, not Furrow-concern: the operator skill (rendered for Claude or Pi) instructs the LLM on the appropriate session-resume detection. Claude block: read ~/.claude/teams/{row-name}/config.json; detect stale members; re-spawn via TeamCreate. Pi block: @tintinweb/pi-subagents handles its own session resume. Furrow backend has NO session_id awareness, NO drivers.json, NO per-row driver registry
- Adapter integration in this row is minimal-but-functioning on BOTH adapters: at row close, an end-to-end smoke (operator spawns one driver, that driver dispatches one engine, full layer-guard active throughout, leakage test passes) succeeds on both runtimes. Deeper hardening (per-driver model routing, parallel engine teams, dashboard UX) is captured as follow-up rows
- Pi adapter package adoption: adapters/pi/package.json declares dep on @tintinweb/pi-subagents (pinned at the latest stable, currently 0.6.x — exact version locked at spec time after a quick npm registry check) and @mariozechner/pi-coding-agent peer dep (pinned 0.70.x). Wrapped behind a thin Furrow PiAdapter interface (internal package boundary) so the dep is swappable. adapters/pi/extension/index.ts hooks tool_call → exec `furrow hook layer-guard` with stdin JSON; before_agent_start → setActiveTools(driver.tools_allowlist) + return {systemPrompt: skills/{step}.md content}; bridges Furrow row state ↔ pi-subagents lifecycle
- Recursive-spawn verification: as a spec-time pre-implementation sanity check, read @tintinweb/pi-subagents src/agent-runner.ts to confirm subagents can themselves spawn subagents (driver→engine path). If broken, the engine-dispatch path needs fallback (subprocess subagent per pi-mono example). Spec captures the verification result; implementation may pivot if blocked
- Integration test (tests/integration/test-driver-architecture.sh): exercises layered dispatch end-to-end on a fixture row — operator spawns a driver for one step, driver dispatches an engine, engine returns EOS-report, driver returns phase result, operator presents to user. Asserts each layer made only its allowed tool calls (operator: rws/alm; driver: read-only; engine: none). Runs against BOTH adapter modes (Claude via in-process Agent stub; Pi via @tintinweb/pi-subagents)
- All step skills pass evals/skills/ structural checks (front-matter present, named sections per skills/shared/skill-template.md if extant, step-mechanics block present). D3 owns the layer: front-matter additions in a subsequent wave

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
commit bb64f753fa752f500f7be4977237d9704fbf2076
Author: Test <test@test.com>
Date:   Mon Apr 27 10:52:23 2026 -0400

    feat(presentation): add D6 artifact-presentation-protocol (canonical section-with-markers + presentation-check Go hook + skill retrofits + integration test)
    
    Ships the complete D6 deliverable: presentation-protocol.md canonical reference doc,
    furrow hook presentation-check Go subcommand (advisory Stop hook, exit 0 always,
    severity warn/silent), settings.json Stop hook wiring, additive presentation
    references in skills/{plan,spec,review}.md, work.md.tmpl Presentation section,
    and integration test replaying fixture transcripts (operator violation, marked
    clean pass, engine-turn skip). All 8 integration assertions pass; go test ./... green.

diff --git a/internal/cli/app.go b/internal/cli/app.go
index 347bd71..b1f6922 100644
--- a/internal/cli/app.go
+++ b/internal/cli/app.go
@@ -207,10 +207,10 @@ func (a *App) runStubLeaf(command string, args []string) int {
 // runHook dispatches `furrow hook <subcommand>` — runtime adapter hooks.
 //
 // D3 ships: layer-guard (PreToolUse boundary enforcement).
-// D6 will add: presentation-check.
+// D6 ships: presentation-check (Stop hook advisory scan).
 func (a *App) runHook(args []string) int {
 	if len(args) == 0 {
-		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard")
+		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard, presentation-check")
 		return 0
 	}
 	switch args[0] {
@@ -221,8 +221,10 @@ func (a *App) runHook(args []string) int {
 			policyPath = override
 		}
 		return hook.RunLayerGuard(context.Background(), policyPath, a.stdin, a.stdout)
+	case "presentation-check":
+		return hook.RunPresentationCheck(context.Background(), a.stdin, a.stdout)
 	case "help", "-h", "--help":
-		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard")
+		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard, presentation-check")
 		return 0
 	default:
 		return a.fail("furrow hook", &cliError{
@@ -281,7 +283,7 @@ Commands:
   context   Context bundle assembly (for-step)
   handoff   Handoff render and validate contract surface
   render    Render runtime-specific files from definitions
-  hook      Runtime adapter hooks (layer-guard)
+  hook      Runtime adapter hooks (layer-guard, presentation-check)
   merge     Merge pipeline contract surface
   doctor    Environment and adapter readiness checks
   init      Repo bootstrap and migration entrypoint
diff --git a/skills/plan.md b/skills/plan.md
index 7e03092..7f78ea4 100644
--- a/skills/plan.md
+++ b/skills/plan.md
@@ -81,6 +81,13 @@ Read these when relevant to your current action:
 - `skills/shared/layer-protocol.md` — layer boundaries; engine-team-composed-at-dispatch model
 - `skills/shared/summary-protocol.md` — before completing step
 
+**Presentation**: when surfacing this step's artifact for user review, render it
+using the canonical mode defined in `skills/shared/presentation-protocol.md` —
+section markers `<!-- presentation:section:{name} -->` immediately preceding
+each section per the artifact's row in the protocol's section-break table. The
+operator owns this rendering; phase drivers return structured results, not
+user-facing markdown.
+
 ## Step Mechanics
 Transition out: gate record `plan->spec` with outcome `pass` required.
 Pre-step shell check (`rws gate-check`): 1 deliverable, no depends_on, not
diff --git a/skills/review.md b/skills/review.md
index 1a2eb76..8168366 100644
--- a/skills/review.md
+++ b/skills/review.md
@@ -64,6 +64,13 @@ After all deliverable reviews complete:
 - `skills/shared/layer-protocol.md` — layer boundaries
 - `skills/shared/summary-protocol.md` — before completing step
 
+**Presentation**: when surfacing this step's artifact for user review, render it
+using the canonical mode defined in `skills/shared/presentation-protocol.md` —
+section markers `<!-- presentation:section:{name} -->` immediately preceding
+each section per the artifact's row in the protocol's section-break table. The
+operator owns this rendering; phase drivers return structured results, not
+user-facing markdown.
+
 ## Step Mechanics
 Review is the final step. No pre-step evaluation — review always runs.
 Post-step gate evaluates Phase A and Phase B results across all deliverables.
diff --git a/skills/spec.md b/skills/spec.md
index 3856710..ee42454 100644
--- a/skills/spec.md
+++ b/skills/spec.md
@@ -69,6 +69,13 @@ Read these when relevant to your current action:
 - `skills/shared/layer-protocol.md` — layer boundaries
 - `skills/shared/summary-protocol.md` — before completing step
 
+**Presentation**: when surfacing this step's artifact for user review, render it
+using the canonical mode defined in `skills/shared/presentation-protocol.md` —
+section markers `<!-- presentation:section:{name} -->` immediately preceding
+each section per the artifact's row in the protocol's section-break table. The
+operator owns this rendering; phase drivers return structured results, not
+user-facing markdown.
+
 ## Step Mechanics
 Transition out: gate record `spec->decompose` with outcome `pass` required.
 Pre-step shell check (`rws gate-check`): 1 deliverable, >=2 ACs, not supervised,

commit cd5b0221e5e6dc117d2b2cc825c61524d9884ec6
Author: Test <test@test.com>
Date:   Sun Apr 26 02:50:48 2026 -0400

    feat(boundary): add D3 boundary-enforcement (layer-policy authority + hook layer-guard Go subcommand + skill front-matter + leakage/parity/e2e tests + arch doc)
    
    Ships the security-critical layer-policy enforcement layer for the
    orchestration-delegation-contract row (W5):
    
    - schemas/layer-policy.schema.json: JSON Schema draft 2020-12 for layer policy
    - .furrow/layer-policy.yaml: canonical single-source policy (operator/driver/engine)
    - internal/cli/layer/policy.go: typed loader + LookupLayer + Decide verdict function
    - internal/cli/hook/layer_guard.go: furrow hook layer-guard Go subcommand (exit 0=allow, 2=block)
    - internal/cli/validate_layer_policy.go: furrow validate layer-policy
    - internal/cli/validate_skill_layers.go: furrow validate skill-layers
    - internal/cli/validate_driver_definitions.go: furrow validate driver-definitions
    - internal/cli/app.go: register hook + 3 new validate subcommands
    - schemas/blocker-taxonomy.yaml: +5 D3 codes (skill_layer_unset, layer_policy_invalid, layer_tool_violation, engine_furrow_leakage, driver_definition_invalid)
    - skills/: layer: front-matter added to all 21 skill files (driver/operator/engine/shared)
    - .claude/settings.json: layer-guard registered on Write|Edit, Bash, SendMessage|Agent|TaskCreate|TaskUpdate
    - adapters/pi/extension/index.ts: tool_call hook fully wired to furrow hook layer-guard
    - tests/integration/test-boundary-leakage.sh: NON-NEGOTIABLE leakage smoke alarm (0 matches)
    - tests/integration/test-layer-policy-parity.sh: 10 fixtures × 2 verdicts = 20/20 pass
    - tests/integration/test-layered-dispatch-e2e.sh: 24/24 pass
    - docs/architecture/orchestration-delegation-contract.md: canonical D1/D2/D3/D4/D5 reference

diff --git a/adapters/pi/extension/index.ts b/adapters/pi/extension/index.ts
index 089645e..2c18c78 100644
--- a/adapters/pi/extension/index.ts
+++ b/adapters/pi/extension/index.ts
@@ -157,20 +157,36 @@ function readSkill(root: string, step: string): string | undefined {
 // Layer-guard hook integration (forward-compatible stub for D3)
 // ---------------------------------------------------------------------------
 
-/** Attempt to call `furrow hook layer-guard` with the given payload.
- * Returns the verdict, or undefined if the command is not yet available (D3 W5). */
+/** Call `furrow hook layer-guard` with the given payload.
+ *
+ * Implements D3 boundary enforcement for the Pi adapter. The payload shape
+ * is identical to Claude's PreToolUse hook JSON, ensuring cross-adapter parity:
+ * both adapters call the same Go binary with the same stdin shape, so verdict
+ * logic is never duplicated.
+ *
+ * Exit-code semantics mirror Claude hook protocol:
+ *   - exit 0 (or error from binary not found) → allow
+ *   - exit 2 with JSON stdout containing block:true → block
+ *
+ * Pi capability gap: this hook fires on main-thread tool calls only.
+ * Subprocess-spawned subagents are blind to the parent hook bus — see module
+ * docstring and docs/architecture/orchestration-delegation-contract.md §7.
+ */
 function callLayerGuard(payload: LayerGuardPayload): LayerGuardVerdict | undefined {
+  const input = JSON.stringify(payload);
+  const res = execFileSync("furrow", ["hook", "layer-guard"], {
+    input,
+    encoding: "utf-8",
+    timeout: 2000,
+  });
+  // furrow hook layer-guard exits 0 and emits nothing on allow.
+  // If we reach here (no thrown error), the call succeeded with exit 0 → allow.
   try {
-    const input = JSON.stringify(payload);
-    const result = execFileSync("furrow", ["hook", "layer-guard"], {
-      input,
-      encoding: "utf-8",
-      timeout: 2000,
-    });
-    return JSON.parse(result) as LayerGuardVerdict;
+    const verdict = JSON.parse(res) as LayerGuardVerdict;
+    return verdict;
   } catch {
-    // D3 not yet installed — treat as allow (no block).
-    return undefined;
+    // Exit 0 with empty/non-JSON stdout → allow.
+    return { block: false, reason: "" };
   }
 }
 
@@ -235,7 +251,19 @@ export class FurrowPiAdapter {
     };
   }
 
-  /** Handle tool_call for layer-guard enforcement (D3 W5 forward-compatible). */
+  /**
+   * Handle tool_call for layer-guard enforcement (D3).
+   *
+   * Normalizes Pi's tool_call event into Claude's PreToolUse JSON shape and
+   * executes `furrow hook layer-guard` synchronously. Identical payload shape
+   * ensures cross-adapter parity: same Go binary, same stdin structure, same
+   * verdict logic — no duplication.
+   *
+   * Enforcement scope: main-thread (operator) tool calls only. Subprocess
+   * subagents spawned via pi-subagents are invisible to the parent hook bus.
+   * See Pi capability gap documentation in
+   * docs/architecture/orchestration-delegation-contract.md §7.
+   */
   async onToolCall(
     ctx: ToolCallContext,
     event: ToolCallEvent,
@@ -243,14 +271,32 @@ export class FurrowPiAdapter {
     const payload: LayerGuardPayload = {
       hook_event_name: "PreToolUse",
       tool_name: event.tool_name,
-      tool_input: event.tool_input,
+      tool_input: event.tool_input ?? {},
       agent_id: ctx.agentId,
-      agent_type: ctx.agentName,
+      agent_type: ctx.agentName,  // "driver:{step}" | "engine:{id}" | "operator"
     };
 
-    const verdict = callLayerGuard(payload);
-    if (verdict?.block) {
-      return { block: true, reason: verdict.reason };
+    try {
+      const verdict = callLayerGuard(payload);
+      if (verdict?.block) {
+        return { block: true, reason: verdict.reason };
+      }
+    } catch (err: unknown) {
+      // execFileSync throws on non-zero exit. Parse stdout from the error for
+      // the block reason (furrow hook layer-guard exits 2 + JSON on block).
+      const anyErr = err as { stdout?: string; status?: number };
+      if (anyErr.status === 2 && anyErr.stdout) {
+        try {
+          const verdict = JSON.parse(anyErr.stdout) as LayerGuardVerdict;
+          if (verdict.block) {
+            return { block: true, reason: verdict.reason };
+          }
+        } catch {
+          return { block: true, reason: `layer_tool_violation: layer-guard exited 2` };
+        }
+      }
+      // furrow binary not installed or other error → fail-open (allow).
+      // Log but do not block — avoids breaking Pi usage in non-Furrow projects.
     }
     return undefined;
   }
diff --git a/internal/cli/app.go b/internal/cli/app.go
index 6c642af..347bd71 100644
--- a/internal/cli/app.go
+++ b/internal/cli/app.go
@@ -1,14 +1,18 @@
 package cli
 
 import (
+	"context"
 	"encoding/json"
 	"errors"
 	"fmt"
 	"io"
+	"os"
+	"path/filepath"
 	"strings"
 
 	ctx "github.com/jonathoneco/furrow/internal/cli/context"
 	"github.com/jonathoneco/furrow/internal/cli/handoff"
+	"github.com/jonathoneco/furrow/internal/cli/hook"
 	"github.com/jonathoneco/furrow/internal/cli/render"
 
 	// Blank-import triggers init() registration of all 7 step strategies.
@@ -20,6 +24,7 @@ const contractVersion = "v1alpha1"
 type App struct {
 	stdout io.Writer
 	stderr io.Writer
+	stdin  io.Reader
 }
 
 type envelope struct {
@@ -46,7 +51,12 @@ type cliError struct {
 func (e *cliError) Error() string { return e.message }
 
 func New(stdout, stderr io.Writer) *App {
-	return &App{stdout: stdout, stderr: stderr}
+	return &App{stdout: stdout, stderr: stderr, stdin: os.Stdin}
+}
+
+// NewWithStdin creates an App with an explicit stdin (used in tests).
+func NewWithStdin(stdout, stderr io.Writer, stdin io.Reader) *App {
+	return &App{stdout: stdout, stderr: stderr, stdin: stdin}
 }
 
 func (a *App) Run(args []string) int {
@@ -80,6 +90,8 @@ func (a *App) Run(args []string) int {
 		return a.runHandoff(args[1:])
 	case "render":
 		return a.runRender(args[1:])
+	case "hook":
+		return a.runHook(args[1:])
 	case "merge":
 		return a.runStubGroup("furrow merge", args[1:], []string{"plan", "run", "validate"})
 	case "doctor":
@@ -192,6 +204,35 @@ func (a *App) runStubLeaf(command string, args []string) int {
 	return a.fail(command, &cliError{exit: 4, code: "not_implemented", message: command + " is not implemented in the Go CLI draft yet"}, flags.json)
 }
 
+// runHook dispatches `furrow hook <subcommand>` — runtime adapter hooks.
+//
+// D3 ships: layer-guard (PreToolUse boundary enforcement).
+// D6 will add: presentation-check.
+func (a *App) runHook(args []string) int {
+	if len(args) == 0 {
+		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard")
+		return 0
+	}
+	switch args[0] {
+	case "layer-guard":
+		policyPath := filepath.Join(".furrow", "layer-policy.yaml")
+		// Allow override via env for testing.
+		if override := os.Getenv("FURROW_LAYER_POLICY_PATH"); override != "" {
+			policyPath = override
+		}
+		return hook.RunLayerGuard(context.Background(), policyPath, a.stdin, a.stdout)
+	case "help", "-h", "--help":
+		_, _ = fmt.Fprintln(a.stdout, "furrow hook\n\nAvailable subcommands: layer-guard")
+		return 0
+	default:
+		return a.fail("furrow hook", &cliError{
+			exit:    1,
+			code:    "usage",
+			message: fmt.Sprintf("unknown hook subcommand %q", args[0]),
+		}, false)
+	}
+}
+
 func (a *App) okJSON(command string, data any) int {
 	return a.writeJSON(envelope{OK: true, Command: command, Version: contractVersion, Data: data}, 0)
 }
@@ -236,9 +277,11 @@ Commands:
   review    Review orchestration contract surface
   almanac   Planning and knowledge contract surface
   seeds     Seed/task primitive contract surface
+  validate  Schema and policy validation (definition, layer-policy, skill-layers, driver-definitions)
   context   Context bundle assembly (for-step)
   handoff   Handoff render and validate contract surface
   render    Render runtime-specific files from definitions
+  hook      Runtime adapter hooks (layer-guard)
   merge     Merge pipeline contract surface
   doctor    Environment and adapter readiness checks
   init      Repo bootstrap and migration entrypoint
diff --git a/skills/decompose.md b/skills/decompose.md
index 1c51219..08e8a50 100644
--- a/skills/decompose.md
+++ b/skills/decompose.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Decompose
 
 You are the decompose phase driver. Your role is to run the decomposition step
diff --git a/skills/ideate.md b/skills/ideate.md
index 0bcead5..b80a1ac 100644
--- a/skills/ideate.md
+++ b/skills/ideate.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Ideate
 
 You are the ideate phase driver. Your role is to run the ideation step ceremony,
diff --git a/skills/implement.md b/skills/implement.md
index 36b61a0..972756b 100644
--- a/skills/implement.md
+++ b/skills/implement.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Implement
 
 You are the implement phase driver. Your role is to run the implement step
diff --git a/skills/plan.md b/skills/plan.md
index 90c0747..7e03092 100644
--- a/skills/plan.md
+++ b/skills/plan.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Plan
 
 You are the plan phase driver. Your role is to run the planning step ceremony,
diff --git a/skills/research.md b/skills/research.md
index f73673d..0eb7340 100644
--- a/skills/research.md
+++ b/skills/research.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Research
 
 You are the research phase driver. Your role is to run the research step ceremony,
diff --git a/skills/review.md b/skills/review.md
index bb30cbc..1a2eb76 100644
--- a/skills/review.md
+++ b/skills/review.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Review
 
 You are the review phase driver. Your role is to run the review step ceremony,
diff --git a/skills/shared/layer-protocol.md b/skills/shared/layer-protocol.md
index 2cae52b..24051ff 100644
--- a/skills/shared/layer-protocol.md
+++ b/skills/shared/layer-protocol.md
@@ -1,3 +1,6 @@
+---
+layer: shared
+---
 # Layer Protocol
 
 Canonical contract for the 3-layer orchestration model. All runtime adapters
diff --git a/skills/shared/specialist-delegation.md b/skills/shared/specialist-delegation.md
index f994c1d..a46cc51 100644
--- a/skills/shared/specialist-delegation.md
+++ b/skills/shared/specialist-delegation.md
@@ -1,3 +1,6 @@
+---
+layer: shared
+---
 # Specialist Delegation Protocol (Driver→Engine)
 
 **Audience**: phase drivers. This document replaces the former operator→specialist
diff --git a/skills/spec.md b/skills/spec.md
index 94f7ddf..3856710 100644
--- a/skills/spec.md
+++ b/skills/spec.md
@@ -1,3 +1,6 @@
+---
+layer: driver
+---
 # Phase Driver Brief: Spec
 
 You are the spec phase driver. Your role is to run the spec step ceremony,
diff --git a/skills/work-context.md b/skills/work-context.md
index 2aad5d1..66f8696 100644
--- a/skills/work-context.md
+++ b/skills/work-context.md
@@ -1,3 +1,6 @@
+---
+layer: operator
+---
 # Work Context (Operator Layer)
 
 Loaded when a row is active. Provides the operator's per-row context: task

commit f17efb20e671926ff973a7c4223f75a0f254fc59
Author: Test <test@test.com>
Date:   Sat Apr 25 20:54:49 2026 -0400

    feat(driver): add D2 driver architecture (7 driver YAMLs + skill reframe + commands.tmpl + render util + pi adapter scaffold)
    
    Deliverable: driver-architecture (Wave 4 of 6)
    
    - .furrow/drivers/driver-{ideate,research,plan,spec,decompose,implement,review}.yaml: 7 static, runtime-agnostic driver definitions (schema: name/step/tools_allowlist/model). research=opus, all others=sonnet. implement adds Edit+Write.
    - schemas/driver-definition.schema.json: JSON Schema draft 2020-12, additionalProperties:false, name pattern + step enum validation.
    - skills/shared/layer-protocol.md: canonical 3-layer contract (operator/phase-driver/engine), handoff exchange, engine-team-composed-at-dispatch, runtime-agnostic primitives table.
    - skills/shared/specialist-delegation.md: rewritten for driver->engine framing (replaces operator->specialist). Dispatch primitive, curation checklist, return contract.
    - skills/work-context.md: narrowed to operator per-row context; per-step context delegated to furrow context for-step.
    - skills/{ideate,research,plan,spec,decompose,implement,review}.md: all 7 reframed as driver briefs (addressed to phase driver, not operator). User-facing presentation lifted to commands/work.md.tmpl. EOS-report assembly section added. team-plan.md prescription removed from plan.md and decompose.md.
    - commands/work.md.tmpl: Go text/template with {{ if eq .Runtime "claude" }} / {{ else if eq .Runtime "pi" }} runtime branches. Claude block: Agent dispatch, session-resume detection, driver handoff. Pi block: pi-subagents spawn/sendMessage.
    - internal/cli/render/adapters.go: Runtime typed enum (RuntimeClaude/RuntimePi), RenderCtx, RenderAdapters() util. Renders work.md.tmpl -> commands/work.md; for Claude, renders driver YAMLs -> .claude/agents/driver-{step}.md with YAML frontmatter + skills/{step}.md body.
    - internal/cli/render/adapters_test.go: 9 table-driven tests (claude/pi work.md content, 7 agent files, idempotency, stable order, handler error cases).
    - internal/cli/app.go: registers 'render' top-level command group (additive after D1 handoff, D4 context).
    - internal/cli/doctor.go: adds CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 check (warn if absent in claude/auto host mode) — AC11.
    - adapters/pi/package.json: adds @tintinweb/pi-subagents@0.6.1 (pinned exact), @mariozechner/pi-coding-agent peer dep, typescript/node devDeps.
    - adapters/pi/tsconfig.{json,bun.json,extension.json}: split configs (bun for furrow.ts/tests, NodeNext for extension/).
    - adapters/pi/extension/index.ts: FurrowPiAdapter thin interface; before_agent_start hook (injects driver system prompt + tool allowlist from driver YAML); tool_call hook (forwards to furrow hook layer-guard — D3 forward-compatible stub); dispatchEngineAsSubprocess fallback. Documents recursive-spawn FALLBACK_NEEDED verdict.
    - tests/integration/test-driver-architecture.sh: 106 assertions across 15 test functions covering all ACs.
    
    Recursive-spawn verdict: FALLBACK_NEEDED — @tintinweb/pi-subagents 0.6.1 strips Agent tool from subagent sessions via EXCLUDED_TOOL_NAMES constant in agent-runner.ts. Engine dispatch falls back to subprocess per pi-mono pattern.
    
    go test ./... ok | go vet ./... ok | tsc --project tsconfig.extension.json: clean

diff --git a/.furrow/drivers/driver-decompose.yaml b/.furrow/drivers/driver-decompose.yaml
new file mode 100644
index 0000000..200a62b
--- /dev/null
+++ b/.furrow/drivers/driver-decompose.yaml
@@ -0,0 +1,14 @@
+name: driver:decompose
+step: decompose
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: sonnet
diff --git a/.furrow/drivers/driver-ideate.yaml b/.furrow/drivers/driver-ideate.yaml
new file mode 100644
index 0000000..fb50bf6
--- /dev/null
+++ b/.furrow/drivers/driver-ideate.yaml
@@ -0,0 +1,14 @@
+name: driver:ideate
+step: ideate
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: sonnet
diff --git a/.furrow/drivers/driver-implement.yaml b/.furrow/drivers/driver-implement.yaml
new file mode 100644
index 0000000..8793ca6
--- /dev/null
+++ b/.furrow/drivers/driver-implement.yaml
@@ -0,0 +1,16 @@
+name: driver:implement
+step: implement
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - Edit
+  - Write
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: sonnet
diff --git a/.furrow/drivers/driver-plan.yaml b/.furrow/drivers/driver-plan.yaml
new file mode 100644
index 0000000..e2804a3
--- /dev/null
+++ b/.furrow/drivers/driver-plan.yaml
@@ -0,0 +1,14 @@
+name: driver:plan
+step: plan
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: sonnet
diff --git a/.furrow/drivers/driver-research.yaml b/.furrow/drivers/driver-research.yaml
new file mode 100644
index 0000000..3574780
--- /dev/null
+++ b/.furrow/drivers/driver-research.yaml
@@ -0,0 +1,16 @@
+name: driver:research
+step: research
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - WebFetch
+  - WebSearch
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: opus
diff --git a/.furrow/drivers/driver-review.yaml b/.furrow/drivers/driver-review.yaml
new file mode 100644
index 0000000..5b75cad
--- /dev/null
+++ b/.furrow/drivers/driver-review.yaml
@@ -0,0 +1,14 @@
+name: driver:review
+step: review
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: sonnet
diff --git a/.furrow/drivers/driver-spec.yaml b/.furrow/drivers/driver-spec.yaml
new file mode 100644
index 0000000..f298f0d
--- /dev/null
+++ b/.furrow/drivers/driver-spec.yaml
@@ -0,0 +1,14 @@
+name: driver:spec
+step: spec
+tools_allowlist:
+  - Read
+  - Grep
+  - Glob
+  - Agent
+  - SendMessage
+  - Bash(rws:*)
+  - Bash(alm:*)
+  - Bash(sds:*)
+  - Bash(furrow:context for-step:*)
+  - Bash(furrow:handoff render:*)
+model: sonnet
diff --git a/adapters/pi/extension/index.ts b/adapters/pi/extension/index.ts
new file mode 100644
index 0000000..089645e
--- /dev/null
+++ b/adapters/pi/extension/index.ts
@@ -0,0 +1,314 @@
+/**
+ * Furrow Pi Extension — driver/engine lifecycle bridge.
+ *
+ * Integrates @tintinweb/pi-subagents into the Furrow 3-layer orchestration model
+ * (operator → phase driver → engine).
+ *
+ * ## Recursive-Spawn Verification (0.6.1)
+ *
+ * VERDICT: FALLBACK_NEEDED
+ *
+ * Read: node_modules/@tintinweb/pi-subagents/src/agent-runner.ts
+ *
+ * Finding: `EXCLUDED_TOOL_NAMES = ["Agent", "get_subagent_result", "steer_subagent"]`
+ * is applied at session creation time (line ~287):
+ *   `if (EXCLUDED_TOOL_NAMES.includes(t)) return false`
+ * This strips the `Agent` tool from every spawned subagent's active tool set,
+ * preventing recursive spawn via the Agent tool.
+ *
+ * Additionally, the parent's `tool_call` extension event bus does not reach inside
+ * subprocess-spawned subagents — only main-thread tool calls fire extension hooks.
+ *
+ * Implication for driver→engine path:
+ * - Drivers CANNOT dispatch engines by calling the `Agent` tool from within pi-subagents.
+ * - Fallback: engines are dispatched as separate `pi` subprocess invocations
+ *   (per the pi-mono example pattern), receiving the EngineHandoff markdown as input.
+ * - Engine isolation is preserved by D1's EngineHandoff content discipline (no .furrow/ paths)
+ *   plus D3's post-hoc boundary leakage test.
+ *
+ * This limitation is documented here; D3 owns the full capability-gap documentation
+ * in docs/architecture/orchestration-delegation-contract.md.
+ *
+ * ## Architecture
+ *
+ * This extension hooks two Pi lifecycle events:
+ *
+ * 1. `before_agent_start` — when Pi starts a subagent named "driver:{step}":
+ *    - Reads .furrow/drivers/driver-{step}.yaml for tools_allowlist and model
+ *    - Reads skills/{step}.md for the driver brief (system prompt)
+ *    - Returns { systemPrompt, tools } to Pi for session configuration
+ *
+ * 2. `tool_call` — forwards each tool call to `furrow hook layer-guard` (D3) via
+ *    stdin JSON matching Claude's PreToolUse hook payload shape. When D3's
+ *    `furrow hook layer-guard` is not yet installed (W5), this is a no-op.
+ *    Forward-compatible: when D3 ships, the exec just works.
+ *
+ * ## PiAdapter Interface (internal boundary)
+ *
+ * The exported `FurrowPiAdapter` class wraps the @tintinweb/pi-subagents API
+ * behind a thin interface so the dep is swappable per constraint.
+ */
+
+import { execFileSync, execSync } from "node:child_process";
+import { existsSync, readFileSync } from "node:fs";
+import { join, resolve } from "node:path";
+
+// ---------------------------------------------------------------------------
+// Internal types (forward-compatible with D3's layer-guard hook)
+// ---------------------------------------------------------------------------
+
+/** Payload shape matching Claude's PreToolUse hook input (and Pi's tool_call mirror). */
+interface LayerGuardPayload {
+  hook_event_name: "PreToolUse";
+  tool_name: string;
+  tool_input: unknown;
+  agent_id: string;
+  /** driver:{step} | engine:{id} | operator */
+  agent_type: string;
+}
+
+/** Response from `furrow hook layer-guard`. */
+interface LayerGuardVerdict {
+  block: boolean;
+  reason: string;
+}
+
+// ---------------------------------------------------------------------------
+// YAML micro-parser (no external dep — drivers only use simple scalar values)
+// ---------------------------------------------------------------------------
+
+interface DriverDef {
+  name: string;
+  step: string;
+  tools_allowlist: string[];
+  model: string;
+}
+
+/** Minimal YAML parser for driver YAML files (scalar strings + string arrays only). */
+function parseDriverYaml(yaml: string): DriverDef {
+  const lines = yaml.split("\n");
+  const result: Record<string, string | string[]> = {};
+  let inList: string | null = null;
+  const list: string[] = [];
+
+  for (const line of lines) {
+    if (line.trim().startsWith("#") || !line.trim()) continue;
+    const listItem = line.match(/^\s+-\s+(.+)$/);
+    if (listItem && inList) {
+      list.push(listItem[1]!.trim());
+      continue;
+    }
+    if (inList !== null) {
+      result[inList] = [...list];
+      list.length = 0;
+      inList = null;
+    }
+    const kv = line.match(/^([a-z_]+):\s*(.*)$/);
+    if (!kv) continue;
+    const key = kv[1]!;
+    const val = kv[2]!.trim();
+    if (val === "") {
+      inList = key;
+    } else {
+      result[key] = val;
+    }
+  }
+  if (inList !== null) result[inList] = [...list];
+
+  return {
+    name: String(result["name"] ?? ""),
+    step: String(result["step"] ?? ""),
+    tools_allowlist: Array.isArray(result["tools_allowlist"]) ? result["tools_allowlist"] : [],
+    model: String(result["model"] ?? "sonnet"),
+  };
+}
+
+// ---------------------------------------------------------------------------
+// Path helpers
+// ---------------------------------------------------------------------------
+
+function findFurrowRoot(cwd: string): string | undefined {
+  let current = resolve(cwd);
+  for (;;) {
+    if (existsSync(join(current, ".furrow"))) return current;
+    const parent = join(current, "..");
+    if (parent === current) return undefined;
+    current = parent;
+  }
+}
+
+function readDriverYaml(root: string, agentName: string): DriverDef | undefined {
+  // agentName expected: "driver:{step}"
+  const match = agentName.match(/^driver:([a-z]+)$/);
+  if (!match) return undefined;
+  const step = match[1]!;
+  const driverPath = join(root, ".furrow", "drivers", `driver-${step}.yaml`);
+  if (!existsSync(driverPath)) return undefined;
+  return parseDriverYaml(readFileSync(driverPath, "utf-8"));
+}
+
+function readSkill(root: string, step: string): string | undefined {
+  const skillPath = join(root, "skills", `${step}.md`);
+  if (!existsSync(skillPath)) return undefined;
+  return readFileSync(skillPath, "utf-8");
+}
+
+// ---------------------------------------------------------------------------
+// Layer-guard hook integration (forward-compatible stub for D3)
+// ---------------------------------------------------------------------------
+
+/** Attempt to call `furrow hook layer-guard` with the given payload.
+ * Returns the verdict, or undefined if the command is not yet available (D3 W5). */
+function callLayerGuard(payload: LayerGuardPayload): LayerGuardVerdict | undefined {
+  try {
+    const input = JSON.stringify(payload);
+    const result = execFileSync("furrow", ["hook", "layer-guard"], {
+      input,
+      encoding: "utf-8",
+      timeout: 2000,
+    });
+    return JSON.parse(result) as LayerGuardVerdict;
+  } catch {
+    // D3 not yet installed — treat as allow (no block).
+    return undefined;
+  }
+}
+
+// ---------------------------------------------------------------------------
+// PiAdapter — thin interface wrapping @tintinweb/pi-subagents
+// ---------------------------------------------------------------------------
+
+/** Minimal context shape passed by Pi to before_agent_start. */
+interface AgentStartContext {
+  agentName: string;
+  agentId: string;
+  cwd: string;
+}
+
+/** Return value for before_agent_start hook — overrides system prompt and tools. */
+interface AgentStartOverrides {
+  systemPrompt?: string;
+  tools?: string[];
+}
+
+/** Minimal context shape passed by Pi to tool_call hook. */
+interface ToolCallContext {
+  agentName: string;
+  agentId: string;
+  cwd: string;
+}
+
+/** Tool call event from Pi. */
+interface ToolCallEvent {
+  tool_name: string;
+  tool_input: unknown;
+}
+
+/** Deny result — returned to block a tool call. */
+interface DenyResult {
+  block: true;
+  reason: string;
+}
+
+/**
+ * FurrowPiAdapter — internal interface boundary for Pi adapter functionality.
+ * Wraps @tintinweb/pi-subagents so the dep is swappable.
+ *
+ * NOTE: Recursive-spawn (driver→engine via Agent tool) is NOT supported by
+ * @tintinweb/pi-subagents 0.6.1 — see module-level docstring for fallback.
+ */
+export class FurrowPiAdapter {
+  /** Handle before_agent_start for Furrow-managed drivers. */
+  async beforeAgentStart(
+    ctx: AgentStartContext,
+  ): Promise<AgentStartOverrides | undefined> {
+    const root = findFurrowRoot(ctx.cwd);
+    if (!root) return undefined;
+
+    const driverDef = readDriverYaml(root, ctx.agentName);
+    if (!driverDef) return undefined; // not a Furrow driver agent
+
+    const skill = readSkill(root, driverDef.step);
+    return {
+      systemPrompt: skill ?? `# Phase Driver Brief: ${driverDef.step}\n\nYou are the ${driverDef.step} phase driver.`,
+      tools: driverDef.tools_allowlist,
+    };
+  }
+
+  /** Handle tool_call for layer-guard enforcement (D3 W5 forward-compatible). */
+  async onToolCall(
+    ctx: ToolCallContext,
+    event: ToolCallEvent,
+  ): Promise<DenyResult | undefined> {
+    const payload: LayerGuardPayload = {
+      hook_event_name: "PreToolUse",
+      tool_name: event.tool_name,
+      tool_input: event.tool_input,
+      agent_id: ctx.agentId,
+      agent_type: ctx.agentName,
+    };
+
+    const verdict = callLayerGuard(payload);
+    if (verdict?.block) {
+      return { block: true, reason: verdict.reason };
+    }
+    return undefined;
+  }
+
+  /**
+   * Dispatch an engine as a subprocess (fallback for recursive-spawn limitation).
+   *
+   * Because @tintinweb/pi-subagents strips the `Agent` tool from subagents,
+   * engine dispatch must be done via a separate `pi` process invocation.
+   * The engine receives the EngineHandoff markdown as its input prompt.
+   *
+   * Engine isolation is preserved by D1's EngineHandoff content discipline.
+   */
+  dispatchEngineAsSubprocess(
+    engineHandoffMarkdown: string,
+    options: { cwd?: string; timeout?: number } = {},
+  ): string {
+    try {
+      const result = execSync(`pi -p "${engineHandoffMarkdown.replace(/"/g, '\\"')}"`, {
+        cwd: options.cwd,
+        timeout: options.timeout ?? 120000,
+        encoding: "utf-8",
+      });
+      return result;
+    } catch (err: unknown) {
+      throw new Error(
+        `Engine subprocess dispatch failed: ${err instanceof Error ? err.message : String(err)}`,
+      );
+    }
+  }
+}
+
+// ---------------------------------------------------------------------------
+// Pi extension entry point
+// ---------------------------------------------------------------------------
+
+// The extension export pattern depends on the pi-subagents version and the Pi
+// runtime's extension API. Since @tintinweb/pi-subagents 0.6.1 does not
+// export a `defineExtension` factory (the pattern is internal to pi-mono),
+// we export a factory function that accepts the Pi extension registration API.
+//
+// When integrated with the Pi runtime, wire this via the pi-subagents
+// before_agent_start and tool_call hooks documented in pi-mono.
+
+/** Factory: create and register the Furrow extension hooks. */
+export function createFurrowExtension() {
+  const adapter = new FurrowPiAdapter();
+
+  return {
+    name: "furrow",
+
+    /** Wire before_agent_start to inject driver system prompt and tool allowlist. */
+    before_agent_start: (ctx: AgentStartContext) => adapter.beforeAgentStart(ctx),
+
+    /** Wire tool_call to forward to furrow hook layer-guard (D3 W5 stub). */
+    tool_call: (ctx: ToolCallContext, event: ToolCallEvent) =>
+      adapter.onToolCall(ctx, event),
+  };
+}
+
+export default createFurrowExtension;
diff --git a/adapters/pi/package.json b/adapters/pi/package.json
index ac7f9ec..ce538c6 100644
--- a/adapters/pi/package.json
+++ b/adapters/pi/package.json
@@ -4,8 +4,19 @@
   "private": true,
   "type": "module",
   "scripts": {
-    "test": "bun test"
+    "test": "bun test",
+    "typecheck": "tsc --noEmit --project tsconfig.extension.json"
   },
-  "description": "Pi (Tabby) adapter integration tests for the Furrow validate handlers.",
-  "comment": "Bun is the runtime; bun test is built-in (no devDependencies needed). Bootstrapped by D4 of pre-write-validation-go-first."
+  "description": "Pi (Tabby) adapter for the Furrow harness. Integrates @tintinweb/pi-subagents for driver/engine lifecycle management.",
+  "dependencies": {
+    "@tintinweb/pi-subagents": "0.6.1"
+  },
+  "peerDependencies": {
+    "@mariozechner/pi-coding-agent": "^0.70.0"
+  },
+  "devDependencies": {
+    "typescript": "^5.6.0",
+    "@types/node": "^22.0.0"
+  },
+  "comment": "Bun is the runtime; bun test is built-in. D2 adds @tintinweb/pi-subagents for driver/engine lifecycle. D3 will wire layer-guard hook in extension/index.ts."
 }
diff --git a/adapters/pi/tsconfig.json b/adapters/pi/tsconfig.json
index 6130935..a6c446a 100644
--- a/adapters/pi/tsconfig.json
+++ b/adapters/pi/tsconfig.json
@@ -1,14 +1,7 @@
 {
-  "compilerOptions": {
-    "target": "ES2022",
-    "module": "ESNext",
-    "moduleResolution": "bundler",
-    "strict": true,
-    "esModuleInterop": true,
-    "skipLibCheck": true,
-    "noEmit": true,
-    "allowImportingTsExtensions": true,
-    "types": ["bun-types"]
-  },
-  "include": ["*.ts"]
+  "files": [],
+  "references": [
+    { "path": "./tsconfig.bun.json" },
+    { "path": "./tsconfig.extension.json" }
+  ]
 }
diff --git a/commands/work.md.tmpl b/commands/work.md.tmpl
index 8dd3c17..278dcd8 100644
--- a/commands/work.md.tmpl
+++ b/commands/work.md.tmpl
@@ -1,77 +1,149 @@
-# /work Command Template — Operator Skill Shell-Out Stub
-#
-# D4 (W3) — initial stub demonstrating the shell-out pattern.
-# D2 (W4) will overlay broader template structure and layered dispatch.
-# D3 (W5) will add the skill-layer-context wrapper.
-# D6 (W6) will add the presentation section.
-#
-# Variables available in this template:
-#   .Row    — row name (kebab-case)
-#   .Step   — current workflow step
-#   .Target — rendering target (operator|driver|engine|specialist:{id})
+# /work — Operator Skill
+{{- /*
+  D4 (W3) — initial shell-out stub.
+  D2 (W4) — full layered dispatch with Claude + Pi runtime branches.
+  D3 (W5) — adds skill-layer-context lifecycle wrapper.
+  D6 (W6) — adds presentation section.
 
-# {{ .Row }} — {{ .Step }} step context
+  Template variables (RenderCtx):
+    .Runtime    — Runtime enum: "claude" | "pi"
+    .RowName    — row name (kebab-case), or placeholder for unrendered template
+    .ProjectDir — absolute path to project root
+*/ -}}
 
-## Context Loading
+You are the **operator** — the whole-row orchestration layer. You address the user,
+manage row state, spawn and prime phase drivers, and present phase results.
 
-This operator skill shells out to the context-routing CLI to obtain a
-fully-assembled, layer-filtered context bundle for the current step.
+You do not implement deliverables directly. You orchestrate drivers that do.
 
-Run the following command to load your context bundle:
+See `skills/shared/layer-protocol.md` for the full 3-layer boundary contract.
+
+---
+
+## Step 1 — Load Operator Bundle
+
+Detect the active row name from `.furrow/focus` or the row name passed at invocation.
+Then load your context bundle:
 
 ```sh
-furrow context for-step {{ .Step }} --target operator --json
+furrow context for-step <step> --target operator --row <row> --json
 ```
 
-The bundle's `skills[]` array supplies your driver brief, work-context, and any
-shared-layer skills. Render `prior_artifacts.summary_sections` for context recovery.
+The bundle's `prior_artifacts.state` tells you the current step. The bundle's
+`prior_artifacts.summary_sections` gives synthesized context from prior steps.
+Skills filtered to `layer:operator|shared` are included in `skills[]`.
+
+---
 
-## Bundle Shape
+## Step 2 — Detect Step + Dispatch Driver
 
-The emitted bundle conforms to `schemas/context-bundle.schema.json`:
+{{ if eq .Runtime "claude" -}}
+### Claude Runtime
 
+**Session-resume detection**: read `~/.claude/teams/{{ "{{ROW_NAME}}" }}/config.json`.
+If absent or `members[].agent_id` is stale (no live process), re-spawn the driver.
+
+**Spawn driver**:
 ```
-{
-  "row":    "{{ .Row }}",
-  "step":   "{{ .Step }}",
-  "target": "operator",
-  "skills": [{ "path": "...", "layer": "operator|shared", "content": "..." }],
-  "references": [{ "path": "..." }],
-  "prior_artifacts": {
-    "state": { ... },
-    "summary_sections": { "<heading>": "<content>" },
-    "gate_evidence": { "gates": [...] },
-    "learnings": [{ "id": "...", "body": "...", "broadly_applicable": true|false }]
-  },
-  "decisions": [{ "source": "settled_decisions", "from_step": "...", "to_step": "...", "outcome": "pass|fail|unknown", "rationale": "...", "ordinal": 0 }],
-  "step_strategy_metadata": { ... }
-}
+Agent(
+  subagent_type="driver:{step}",
+  description="<concise task description for this step>",
+  prompt="<priming message body — see below>"
+)
 ```
 
-## Operator→Driver Dispatch
+Claude Code's `Agent` tool dispatches to the pre-registered subagent definition at
+`.claude/agents/driver-{step}.md`. That definition's frontmatter provides the
+`tools` allowlist and `model` — do NOT pass them as inline arguments. The definition
+is rendered from `.furrow/drivers/driver-{step}.yaml` + `skills/{step}.md` by:
 
-When spawning or messaging a driver for this step, prime it with:
+```sh
+furrow render adapters --runtime=claude --write
+```
 
+**Prime the driver** after spawn:
+```
+SendMessage(
+  to=agent_id,
+  body=<bundle from: furrow context for-step {step} --target driver --json>
+)
+```
+
+**Persist driver handoff artifact**:
 ```sh
-furrow context for-step {{ .Step }} --target driver --json
+furrow handoff render --target driver:{step} --row <row> --step <step> --write
 ```
+Artifact written to `.furrow/rows/<row>/handoffs/{step}-to-driver.md`.
 
-The driver consumes `skills[]` (layer:driver|shared) and `prior_artifacts`.
+**On driver return**: receive phase EOS-report via `SendMessage` from driver.
+Present to user per `skills/shared/presentation-protocol.md` (D6).
+Confirm gate with user. Call `rws transition <row> pass manual "<evidence>"`.
 
-## Driver→Engine/Specialist Dispatch
+**Experimental teams flag**: if `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS` ≠ `1`,
+warn the user — multi-agent dispatch requires this flag.
+{{- else if eq .Runtime "pi" -}}
+### Pi Runtime
 
-When the driver dispatches a specialist engine:
+**Session-resume detection**: `@tintinweb/pi-subagents` manages session-tree
+branches natively. Resume detection is handled by the Pi adapter — no config.json
+check needed.
+
+**Spawn driver**:
+```
+pi-subagents spawn({
+  name: "driver:{step}",
+  systemPrompt: <contents of skills/{step}.md>,
+  tools: <tools_allowlist from .furrow/drivers/driver-{step}.yaml>
+})
+```
+
+The `adapters/pi/extension/index.ts` `before_agent_start` hook automatically
+injects the correct `systemPrompt` and `tools` from the driver YAML — you do not
+need to pass them manually if the extension is active.
+
+**Prime the driver**:
+```
+pi-subagents sendMessage(handle, <bundle from: furrow context for-step {step} --target driver --json>)
+```
+
+**Persist driver handoff artifact**:
+```sh
+furrow handoff render --target driver:{step} --row <row> --step <step> --write
+```
+
+**On driver return**: receive phase EOS-report as agent return value.
+Present to user per `skills/shared/presentation-protocol.md` (D6).
+Confirm gate with user. Call `rws transition <row> pass manual "<evidence>"`.
+{{- end }}
+
+---
+
+## Step 3 — Driver→Engine Context
+
+When the driver dispatches engines, it uses:
 
 ```sh
-furrow context for-step {{ .Step }} --target specialist:{id} --json
+furrow context for-step <step> --target specialist:{id} --json
 ```
 
 Replace `{id}` with the specialist identifier (e.g., `go-specialist`).
 The specialist brief at `specialists/{id}.md` must exist or the command exits 3
-with blocker code `context_input_missing`.
+with blocker code `context_input_missing`. The driver curates the bundle before
+passing it to the engine handoff — engines receive no Furrow internals.
+
+---
+
+## Step 4 — Presentation
+
+Present all phase results to the user using `skills/shared/presentation-protocol.md` (D6).
+
+Use section markers: `<!-- {step}:section:{name} -->` before each artifact block.
+Never dump raw file contents without markers.
+
+---
 
 ## Caching
 
 The CLI caches bundles under `.furrow/cache/context-bundles/`. The cache
-invalidates automatically when `state.json` changes or any input file is
-modified. Pass `--no-cache` to bypass caching.
+invalidates automatically when `state.json` changes or any input file is modified.
+Pass `--no-cache` to bypass caching.
diff --git a/internal/cli/app.go b/internal/cli/app.go
index 510f8d8..6c642af 100644
--- a/internal/cli/app.go
+++ b/internal/cli/app.go
@@ -9,6 +9,7 @@ import (
 
 	ctx "github.com/jonathoneco/furrow/internal/cli/context"
 	"github.com/jonathoneco/furrow/internal/cli/handoff"
+	"github.com/jonathoneco/furrow/internal/cli/render"
 
 	// Blank-import triggers init() registration of all 7 step strategies.
 	_ "github.com/jonathoneco/furrow/internal/cli/context/strategies"
@@ -77,6 +78,8 @@ func (a *App) Run(args []string) int {
 		return a.runContext(args[1:])
 	case "handoff":
 		return a.runHandoff(args[1:])
+	case "render":
+		return a.runRender(args[1:])
 	case "merge":
 		return a.runStubGroup("furrow merge", args[1:], []string{"plan", "run", "validate"})
 	case "doctor":
@@ -168,6 +171,11 @@ func (a *App) runHandoff(args []string) int {
 	return h.Run(args)
 }
 
+func (a *App) runRender(args []string) int {
+	h := render.New(a.stdout, a.stderr)
+	return h.Run(args)
+}
+
 func (a *App) runStubGroup(command string, args []string, children []string) int {
 	if len(args) == 0 {
 		_, _ = fmt.Fprintf(a.stdout, "%s\n\nAvailable subcommands: %s\n", command, strings.Join(children, ", "))
@@ -230,6 +238,7 @@ Commands:
   seeds     Seed/task primitive contract surface
   context   Context bundle assembly (for-step)
   handoff   Handoff render and validate contract surface
+  render    Render runtime-specific files from definitions
   merge     Merge pipeline contract surface
   doctor    Environment and adapter readiness checks
   init      Repo bootstrap and migration entrypoint
diff --git a/internal/cli/render/adapters.go b/internal/cli/render/adapters.go
new file mode 100644
index 0000000..780225e
--- /dev/null
+++ b/internal/cli/render/adapters.go
@@ -0,0 +1,325 @@
+// Package render implements the `furrow render` command group. It renders
+// runtime-specific files from the runtime-agnostic Furrow definitions:
+//   - commands/work.md.tmpl → commands/work.md (per runtime)
+//   - .furrow/drivers/driver-{step}.yaml → .claude/agents/driver-{step}.md (Claude only)
+//
+// Rendering is idempotent: same inputs produce identical bytes.
+// Without --write, all rendered output is emitted to stdout as a manifest.
+package render
+
+import (
+	"bytes"
+	"fmt"
+	"io"
+	"os"
+	"path/filepath"
+	"sort"
+	"strings"
+	"text/template"
+
+	"gopkg.in/yaml.v3"
+)
+
+// Runtime identifies the adapter target for template rendering.
+// D3 and D6 extend RenderCtx additively (new fields only).
+type Runtime string
+
+const (
+	// RuntimeClaude targets Claude Code's subagent/Agent dispatch model.
+	RuntimeClaude Runtime = "claude"
+	// RuntimePi targets the Pi @tintinweb/pi-subagents extension model.
+	RuntimePi Runtime = "pi"
+)
+
+// RenderCtx is the template execution context. Templates compare
+// {{ if eq .Runtime "claude" }} against the underlying string value.
+// The typed enum gives compile-time safety in Go callers while keeping
+// template syntax simple.
+type RenderCtx struct {
+	Runtime    Runtime
+	RowName    string
+	ProjectDir string
+}
+
+// driverDef is the in-memory representation of a .furrow/drivers/driver-{step}.yaml.
+type driverDef struct {
+	Name           string   `yaml:"name"`
+	Step           string   `yaml:"step"`
+	ToolsAllowlist []string `yaml:"tools_allowlist"`
+	Model          string   `yaml:"model"`
+}
+
+// RenderedFile is one item in the render manifest.
+type RenderedFile struct {
+	// Path is the project-relative output path.
+	Path string
+	// Content is the rendered bytes.
+	Content []byte
+}
+
+// Handler implements `furrow render adapters`.
+type Handler struct {
+	stdout io.Writer
+	stderr io.Writer
+}
+
+// New returns a Handler writing to stdout/stderr.
+func New(stdout, stderr io.Writer) *Handler {
+	return &Handler{stdout: stdout, stderr: stderr}
+}
+
+// Run dispatches `furrow render <subcommand> [args...]`.
+func (h *Handler) Run(args []string) int {
+	if len(args) == 0 {
+		h.printHelp()
+		return 0
+	}
+	switch args[0] {
+	case "adapters":
+		return h.runAdapters(args[1:])
+	case "help", "-h", "--help":
+		h.printHelp()
+		return 0
+	default:
+		_, _ = fmt.Fprintf(h.stderr, "unknown render subcommand %q\n", args[0])
+		return 1
+	}
+}
+
+func (h *Handler) printHelp() {
+	_, _ = fmt.Fprintln(h.stdout, `furrow render
+
+Usage:
+  furrow render adapters --runtime=<claude|pi> [--write]
+
+Subcommands:
+  adapters   Render runtime-specific files from runtime-agnostic definitions
+
+Use "furrow render <subcommand> --help" for subcommand-specific help.`)
+}
+
+func (h *Handler) runAdapters(args []string) int {
+	var runtime, projectDir string
+	write := false
+
+	for i := 0; i < len(args); i++ {
+		arg := args[i]
+		switch {
+		case strings.HasPrefix(arg, "--runtime="):
+			runtime = strings.TrimPrefix(arg, "--runtime=")
+		case arg == "--runtime":
+			if i+1 >= len(args) {
+				_, _ = fmt.Fprintln(h.stderr, "missing value for --runtime")
+				return 1
+			}
+			i++
+			runtime = args[i]
+		case strings.HasPrefix(arg, "--project-dir="):
+			projectDir = strings.TrimPrefix(arg, "--project-dir=")
+		case arg == "--project-dir":
+			if i+1 >= len(args) {
+				_, _ = fmt.Fprintln(h.stderr, "missing value for --project-dir")
+				return 1
+			}
+			i++
+			projectDir = args[i]
+		case arg == "--write":
+			write = true
+		case arg == "--help", arg == "-h":
+			h.printAdaptersHelp()
+			return 0
+		default:
+			_, _ = fmt.Fprintf(h.stderr, "unknown flag %q\n", arg)
+			return 1
+		}
+	}
+
+	if runtime == "" {
+		_, _ = fmt.Fprintln(h.stderr, "required flag --runtime is missing (claude|pi)")
+		return 1
+	}
+
+	var rt Runtime
+	switch runtime {
+	case string(RuntimeClaude):
+		rt = RuntimeClaude
+	case string(RuntimePi):
+		rt = RuntimePi
+	default:
+		_, _ = fmt.Fprintf(h.stderr, "unknown runtime %q (valid: claude, pi)\n", runtime)
+		return 1
+	}
+
+	if projectDir == "" {
+		// Default: find .furrow root relative to cwd.
+		cwd, err := os.Getwd()
+		if err != nil {
+			_, _ = fmt.Fprintln(h.stderr, "cannot determine working directory: "+err.Error())
+			return 1
+		}
+		projectDir = cwd
+	}
+
+	ctx := RenderCtx{
+		Runtime:    rt,
+		RowName:    "{{ROW_NAME}}",
+		ProjectDir: projectDir,
+	}
+
+	files, err := RenderAdapters(ctx, projectDir)
+	if err != nil {
+		_, _ = fmt.Fprintln(h.stderr, "render error: "+err.Error())
+		return 1
+	}
+
+	if write {
+		for _, f := range files {
+			outPath := filepath.Join(projectDir, f.Path)
+			if err := os.MkdirAll(filepath.Dir(outPath), 0o755); err != nil {
+				_, _ = fmt.Fprintf(h.stderr, "mkdir %s: %v\n", filepath.Dir(outPath), err)
+				return 1
+			}
+			if err := os.WriteFile(outPath, f.Content, 0o644); err != nil {
+				_, _ = fmt.Fprintf(h.stderr, "write %s: %v\n", outPath, err)
+				return 1
+			}
+			_, _ = fmt.Fprintf(h.stdout, "wrote %s\n", f.Path)
+		}
+		return 0
+	}
+
+	// Stdout manifest: path → content blocks.
+	for _, f := range files {
+		_, _ = fmt.Fprintf(h.stdout, "=== %s ===\n%s\n", f.Path, f.Content)
+	}
+	return 0
+}
+
+func (h *Handler) printAdaptersHelp() {
+	_, _ = fmt.Fprintln(h.stdout, `furrow render adapters
+
+Renders runtime-specific files from runtime-agnostic Furrow definitions.
+
+Usage:
+  furrow render adapters --runtime=<claude|pi> [--write] [--project-dir=<dir>]
+
+Flags:
+  --runtime=<claude|pi>   Target adapter runtime (required)
+  --write                 Write rendered files to disk (default: emit to stdout)
+  --project-dir=<dir>     Project root directory (default: cwd)
+
+Outputs (Claude):
+  commands/work.md              Rendered operator skill
+  .claude/agents/driver-{step}.md   Subagent definitions (×7)
+
+Outputs (Pi):
+  commands/work.md              Rendered operator skill (Pi block)`)
+}
+
+// RenderAdapters renders all runtime-specific files for the given ctx and
+// returns them as a stable-ordered slice of RenderedFile. It does NOT write
+// to disk; callers that need writing use --write via the CLI.
+//
+// Idempotent: same inputs → identical bytes.
+func RenderAdapters(ctx RenderCtx, projectDir string) ([]RenderedFile, error) {
+	var files []RenderedFile
+
+	// 1. Render commands/work.md.tmpl → commands/work.md
+	workMd, err := renderWorkTemplate(ctx, projectDir)
+	if err != nil {
+		return nil, fmt.Errorf("render work.md.tmpl: %w", err)
+	}
+	files = append(files, RenderedFile{Path: "commands/work.md", Content: workMd})
+
+	// 2. Claude-specific: render driver YAMLs → .claude/agents/driver-{step}.md
+	if ctx.Runtime == RuntimeClaude {
+		agentFiles, err := renderClaudeAgents(ctx, projectDir)
+		if err != nil {
+			return nil, fmt.Errorf("render claude agents: %w", err)
+		}
+		files = append(files, agentFiles...)
+	}
+
+	// Sort for stable output order.
+	sort.Slice(files, func(i, j int) bool { return files[i].Path < files[j].Path })
+	return files, nil
+}
+
+// renderWorkTemplate reads commands/work.md.tmpl and executes it with ctx.
+func renderWorkTemplate(ctx RenderCtx, projectDir string) ([]byte, error) {
+	tmplPath := filepath.Join(projectDir, "commands", "work.md.tmpl")
+	tmplBytes, err := os.ReadFile(tmplPath)
+	if err != nil {
+		return nil, fmt.Errorf("read %s: %w", tmplPath, err)
+	}
+
+	tmpl, err := template.New("work.md.tmpl").Parse(string(tmplBytes))
+	if err != nil {
+		return nil, fmt.Errorf("parse template: %w", err)
+	}
+
+	var buf bytes.Buffer
+	if err := tmpl.Execute(&buf, ctx); err != nil {
+		return nil, fmt.Errorf("execute template: %w", err)
+	}
+	return buf.Bytes(), nil
+}
+
+// renderClaudeAgents reads each .furrow/drivers/driver-{step}.yaml and renders
+// a .claude/agents/driver-{step}.md subagent definition. The output format is:
+//
+//	---
+//	name: driver:{step}
+//	description: Phase driver for the {step} step
+//	tools: [...]
+//	model: {model}
+//	---
+//	{contents of skills/{step}.md}
+func renderClaudeAgents(ctx RenderCtx, projectDir string) ([]RenderedFile, error) {
+	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
+	var files []RenderedFile
+
+	for _, step := range steps {
+		driverPath := filepath.Join(projectDir, ".furrow", "drivers", fmt.Sprintf("driver-%s.yaml", step))
+		driverBytes, err := os.ReadFile(driverPath)
+		if err != nil {
+			return nil, fmt.Errorf("read %s: %w", driverPath, err)
+		}
+
+		var def driverDef
+		if err := yaml.Unmarshal(driverBytes, &def); err != nil {
+			return nil, fmt.Errorf("parse %s: %w", driverPath, err)
+		}
+
+		skillPath := filepath.Join(projectDir, "skills", fmt.Sprintf("%s.md", step))
+		skillBytes, err := os.ReadFile(skillPath)
+		if err != nil {
+			return nil, fmt.Errorf("read %s: %w", skillPath, err)
+		}
+
+		// Build YAML frontmatter. Tools list is sorted for stable output.
+		tools := make([]string, len(def.ToolsAllowlist))
+		copy(tools, def.ToolsAllowlist)
+		sort.Strings(tools)
+
+		var toolLines []string
+		for _, t := range tools {
+			toolLines = append(toolLines, fmt.Sprintf("  - %q", t))
+		}
+
+		frontmatter := fmt.Sprintf(`---
+name: %q
+description: "Phase driver for the %s step — runs step ceremony, dispatches engine teams, assembles EOS-report"
+tools:
+%s
+model: %q
+---
+`, def.Name, step, strings.Join(toolLines, "\n"), def.Model)
+
+		content := []byte(frontmatter + string(skillBytes))
+		outPath := fmt.Sprintf(".claude/agents/driver-%s.md", step)
+		files = append(files, RenderedFile{Path: outPath, Content: content})
+	}
+
+	return files, nil
+}
diff --git a/internal/cli/render/adapters_test.go b/internal/cli/render/adapters_test.go
new file mode 100644
index 0000000..ffedff0
--- /dev/null
+++ b/internal/cli/render/adapters_test.go
@@ -0,0 +1,246 @@
+package render_test
+
+import (
+	"os"
+	"path/filepath"
+	"strings"
+	"testing"
+
+	"github.com/jonathoneco/furrow/internal/cli/render"
+)
+
+// buildFixtureDir creates a minimal project tree sufficient for RenderAdapters tests.
+func buildFixtureDir(t *testing.T) string {
+	t.Helper()
+	dir := t.TempDir()
+
+	// commands/work.md.tmpl
+	if err := os.MkdirAll(filepath.Join(dir, "commands"), 0o755); err != nil {
+		t.Fatal(err)
+	}
+	tmpl := `# /work{{if eq .Runtime "claude"}}
+Claude block: Agent(name="driver:{step}")
+{{- else if eq .Runtime "pi"}}
+Pi block: pi-subagents
+{{- end}}`
+	mustWrite(t, filepath.Join(dir, "commands", "work.md.tmpl"), tmpl)
+
+	// .furrow/drivers/driver-{step}.yaml
+	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
+	if err := os.MkdirAll(filepath.Join(dir, ".furrow", "drivers"), 0o755); err != nil {
+		t.Fatal(err)
+	}
+	for _, step := range steps {
+		content := "name: driver:" + step + "\nstep: " + step + "\ntools_allowlist:\n  - Read\nmodel: sonnet\n"
+		mustWrite(t, filepath.Join(dir, ".furrow", "drivers", "driver-"+step+".yaml"), content)
+	}
+
+	// skills/{step}.md
+	if err := os.MkdirAll(filepath.Join(dir, "skills"), 0o755); err != nil {
+		t.Fatal(err)
+	}
+	for _, step := range steps {
+		mustWrite(t, filepath.Join(dir, "skills", step+".md"), "# Phase Driver Brief: "+step+"\n\nYou are the "+step+" phase driver.\n")
+	}
+
+	return dir
+}
+
+func mustWrite(t *testing.T, path, content string) {
+	t.Helper()
+	if err := os.WriteFile(path, []byte(content), 0o644); err != nil {
+		t.Fatal(err)
+	}
+}
+
+func TestRenderAdapters_Claude_WorkMd(t *testing.T) {
+	dir := buildFixtureDir(t)
+	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}
+
+	files, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("RenderAdapters: %v", err)
+	}
+
+	var workMd *render.RenderedFile
+	for i := range files {
+		if files[i].Path == "commands/work.md" {
+			workMd = &files[i]
+			break
+		}
+	}
+	if workMd == nil {
+		t.Fatal("commands/work.md not found in rendered output")
+	}
+
+	content := string(workMd.Content)
+	if !strings.Contains(content, `Agent(name="driver:{step}")`) {
+		t.Errorf("Claude work.md missing Claude block; got:\n%s", content)
+	}
+	if strings.Contains(content, "pi-subagents") {
+		t.Errorf("Claude work.md should not contain pi-subagents; got:\n%s", content)
+	}
+}
+
+func TestRenderAdapters_Pi_WorkMd(t *testing.T) {
+	dir := buildFixtureDir(t)
+	ctx := render.RenderCtx{Runtime: render.RuntimePi, RowName: "test-row", ProjectDir: dir}
+
+	files, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("RenderAdapters: %v", err)
+	}
+
+	var workMd *render.RenderedFile
+	for i := range files {
+		if files[i].Path == "commands/work.md" {
+			workMd = &files[i]
+			break
+		}
+	}
+	if workMd == nil {
+		t.Fatal("commands/work.md not found in rendered output")
+	}
+
+	content := string(workMd.Content)
+	if !strings.Contains(content, "pi-subagents") {
+		t.Errorf("Pi work.md missing pi-subagents block; got:\n%s", content)
+	}
+	if strings.Contains(content, `Agent(name="driver:{step}")`) {
+		t.Errorf("Pi work.md should not contain Claude Agent block; got:\n%s", content)
+	}
+}
+
+func TestRenderAdapters_Claude_AgentFiles(t *testing.T) {
+	dir := buildFixtureDir(t)
+	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}
+
+	files, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("RenderAdapters: %v", err)
+	}
+
+	steps := []string{"ideate", "research", "plan", "spec", "decompose", "implement", "review"}
+	agentPaths := make(map[string]bool)
+	for _, f := range files {
+		agentPaths[f.Path] = true
+	}
+
+	for _, step := range steps {
+		path := ".claude/agents/driver-" + step + ".md"
+		if !agentPaths[path] {
+			t.Errorf("missing expected agent file: %s", path)
+			continue
+		}
+
+		var agent *render.RenderedFile
+		for i := range files {
+			if files[i].Path == path {
+				agent = &files[i]
+				break
+			}
+		}
+		content := string(agent.Content)
+
+		// Must contain YAML frontmatter fields.
+		if !strings.Contains(content, `"driver:`+step+`"`) {
+			t.Errorf("%s: missing name field in frontmatter", path)
+		}
+		if !strings.Contains(content, "model:") {
+			t.Errorf("%s: missing model field in frontmatter", path)
+		}
+		if !strings.Contains(content, "tools:") {
+			t.Errorf("%s: missing tools field in frontmatter", path)
+		}
+
+		// Body must contain the skill content.
+		if !strings.Contains(content, "phase driver") {
+			t.Errorf("%s: skill body not embedded (missing 'phase driver')", path)
+		}
+	}
+}
+
+func TestRenderAdapters_Pi_NoAgentFiles(t *testing.T) {
+	dir := buildFixtureDir(t)
+	ctx := render.RenderCtx{Runtime: render.RuntimePi, RowName: "test-row", ProjectDir: dir}
+
+	files, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("RenderAdapters: %v", err)
+	}
+
+	for _, f := range files {
+		if strings.HasPrefix(f.Path, ".claude/agents/") {
+			t.Errorf("Pi render should not produce .claude/agents files, got: %s", f.Path)
+		}
+	}
+}
+
+func TestRenderAdapters_Idempotent(t *testing.T) {
+	dir := buildFixtureDir(t)
+	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}
+
+	files1, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("first RenderAdapters: %v", err)
+	}
+	files2, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("second RenderAdapters: %v", err)
+	}
+
+	if len(files1) != len(files2) {
+		t.Fatalf("idempotency: file count differs: %d vs %d", len(files1), len(files2))
+	}
+	for i := range files1 {
+		if files1[i].Path != files2[i].Path {
+			t.Errorf("idempotency: path[%d] differs: %q vs %q", i, files1[i].Path, files2[i].Path)
+		}
+		if string(files1[i].Content) != string(files2[i].Content) {
+			t.Errorf("idempotency: content differs for %s", files1[i].Path)
+		}
+	}
+}
+
+func TestRenderAdapters_StableOrder(t *testing.T) {
+	dir := buildFixtureDir(t)
+	ctx := render.RenderCtx{Runtime: render.RuntimeClaude, RowName: "test-row", ProjectDir: dir}
+
+	files, err := render.RenderAdapters(ctx, dir)
+	if err != nil {
+		t.Fatalf("RenderAdapters: %v", err)
+	}
+
+	for i := 1; i < len(files); i++ {
+		if files[i].Path < files[i-1].Path {
+			t.Errorf("output not sorted: files[%d]=%q < files[%d]=%q", i, files[i].Path, i-1, files[i-1].Path)
+		}
+	}
+}
+
+func TestHandler_Run_NoArgs(t *testing.T) {
+	var out, errOut strings.Builder
+	h := render.New(&out, &errOut)
+	code := h.Run(nil)
+	if code != 0 {
+		t.Errorf("expected exit 0, got %d (stderr: %s)", code, errOut.String())
+	}
+}
+
+func TestHandler_Run_UnknownRuntime(t *testing.T) {
+	var out, errOut strings.Builder
+	h := render.New(&out, &errOut)
+	code := h.Run([]string{"adapters", "--runtime=bogus"})
+	if code == 0 {
+		t.Error("expected non-zero exit for unknown runtime")
+	}
+}
+
+func TestHandler_Run_MissingRuntime(t *testing.T) {
+	var out, errOut strings.Builder
+	h := render.New(&out, &errOut)
+	code := h.Run([]string{"adapters"})
+	if code == 0 {
+		t.Error("expected non-zero exit for missing --runtime")
+	}
+}
diff --git a/schemas/driver-definition.schema.json b/schemas/driver-definition.schema.json
new file mode 100644
index 0000000..a57c5b5
--- /dev/null
+++ b/schemas/driver-definition.schema.json
@@ -0,0 +1,33 @@
+{
+  "$schema": "https://json-schema.org/draft/2020-12/schema",
+  "$id": "https://furrow.dev/schemas/driver-definition.schema.json",
+  "title": "DriverDefinition",
+  "description": "Static, runtime-agnostic driver definition for a Furrow phase driver. Persona is implicit: skills/{step}.md is the driver brief.",
+  "type": "object",
+  "additionalProperties": false,
+  "required": ["name", "step", "tools_allowlist", "model"],
+  "properties": {
+    "name": {
+      "type": "string",
+      "pattern": "^driver:(ideate|research|plan|spec|decompose|implement|review)$",
+      "description": "Driver identifier — driver:{step}. Must match the step field."
+    },
+    "step": {
+      "type": "string",
+      "enum": ["ideate", "research", "plan", "spec", "decompose", "implement", "review"],
+      "description": "The Furrow workflow step this driver executes."
+    },
+    "tools_allowlist": {
+      "type": "array",
+      "items": { "type": "string" },
+      "minItems": 1,
+      "uniqueItems": true,
+      "description": "Tool names the driver is allowed to invoke. Bash invocations use Bash(cmd:*) notation for prefix matching."
+    },
+    "model": {
+      "type": "string",
+      "enum": ["opus", "sonnet", "haiku"],
+      "description": "Model tier for this driver. opus for deep reasoning (research, review); sonnet for structured execution."
+    }
+  }
+}
diff --git a/skills/decompose.md b/skills/decompose.md
index c9f58db..1c51219 100644
--- a/skills/decompose.md
+++ b/skills/decompose.md
@@ -1,68 +1,91 @@
-# Step: Decompose
+# Phase Driver Brief: Decompose
+
+You are the decompose phase driver. Your role is to run the decomposition step
+ceremony, produce the wave plan, and assemble the phase EOS-report for the operator.
+You do not address the user directly — that is the operator's responsibility.
 
 ## What This Step Does
 Break spec into executable work items with concurrency map (waves).
 
 ## What This Step Produces
 - `plan.json` with wave assignments and specialist mappings
-- `team-plan.md` with coordination strategy
+
+Note: `team-plan.md` is retired under the layered model. Engine teams are composed
+at dispatch-time by the implement phase driver — not prescribed at decompose-time.
+`plan.json`'s `specialist:` field per deliverable is a dispatch hint, not a binding
+contract. This is an architectural decision codified for all future rows: decompose
+produces `plan.json` only, not `team-plan.md`.
 
 ## Model Default
 model_default: sonnet
 
-## Step-Specific Rules
+## Step Ceremony
+
 - Every deliverable must appear in exactly one wave.
 - `depends_on` ordering must be respected across waves.
 - `file_ownership` globs must not overlap within a wave.
-- Read `summary.md` for spec context.
-- Prefer vertical slices (each deliverable is independently testable). See red-flags.md and the `vertical-slicing` eval dimension.
+- Read plan decisions from context bundle `prior_artifacts.summary_sections`.
+- Prefer vertical slices (each deliverable is independently testable). See `skills/shared/red-flags.md`.
+
+## Engine Dispatch
+
+Dispatch a decomposition engine when structural analysis is needed for complex plans.
+This step is typically small enough to execute directly without engine dispatch.
+
+If dispatching:
+1. Build engine handoff via `furrow handoff render --target engine:specialist:{id}`
+2. Grounding: spec files, definition.yaml deliverables, dependency graph
+3. Engine returns: suggested wave assignment and ownership globs
 
-### Step-Level Specialist Modifier
-When working with a specialist during decomposition, emphasize wave strategy,
-dependency ordering, and file ownership scoping. The specialist should reason
-about parallelism opportunities and minimize cross-deliverable coupling. The
-specialist's domain expertise applies to scope decisions: what belongs together,
-what can run concurrently, what order minimizes rework.
+**Dispatch protocol**: `skills/shared/specialist-delegation.md`
 
-## Agent Dispatch Metadata
-- **Dispatch pattern**: None — orchestrator writes plan.json and team-plan.md directly
-- **Agent model**: N/A
-- **Rationale**: Decomposition is a small coordination task that reads specs and produces a wave map. Dispatching an agent adds overhead without value.
+## plan.json Shape
+
+```json
+{
+  "waves": [
+    {
+      "wave": 1,
+      "deliverables": [
+        {
+          "name": "...",
+          "specialist": "...",
+          "file_ownership": ["..."],
+          "depends_on": []
+        }
+      ]
+    }
+  ]
+}
+```
+
+`specialist` is a hint for the implement phase driver, not a binding assignment.
+The implement driver composes actual engine teams at dispatch-time.
 
 ## Shared References
 - `skills/shared/red-flags.md` — before finalizing decomposition
 - `skills/shared/git-conventions.md` — before any commit
 - `skills/shared/learnings-protocol.md` — when capturing learnings
-- `skills/shared/context-isolation.md` — when planning agent teams
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — engine-team-composed-at-dispatch model
 - `skills/shared/summary-protocol.md` — before completing step
-- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol
-
-## Team Planning
-Write `team-plan.md` before dispatching sub-agents (>1 deliverable).
-Sections: Scope Analysis, Team Composition, Task Assignment, Coordination, Skills.
-Team sizing: 2-3 specialists for 2-3 deliverables; 4+: 2-3 agents multi-tasking.
-Validate: every deliverable assigned, ownership globs match, skills exist.
-Resolve specialist templates from `specialists/*.md` by domain value.
-When assigning specialists, read `model_hint` from frontmatter and include it
-in team-plan.md task assignments. Resolution: specialist `model_hint` > step `model_default` > sonnet.
 
 ## Step Mechanics
 Transition out: gate record `decompose->implement` with `pass` required.
 Pre-step shell check (`rws gate-check`): <=2 deliverables, no depends_on, same
 specialist type, not supervised, not force-stopped.
 Pre-step evaluator (`evals/gates/decompose.yaml`): wave-triviality — can all
-deliverables execute in a single wave without coordination? Per `skills/shared/gate-evaluator.md`.
+deliverables execute in a single wave without coordination?
 At this boundary, `rws init` (with branch creation) creates the work branch.
-Next step expects: `plan.json` with waves, `team-plan.md` with coordination.
-
-## Supervised Transition Protocol
-Before requesting a step transition:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-2. Present work to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to advance to implement?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
-6. On "no": ask what needs to change, address feedback, return to step 2.
+Next step expects: `plan.json` with waves.
+
+## EOS-Report Assembly
+
+Assemble phase EOS-report per `templates/handoffs/return-formats/decompose.json`.
+Include: plan.json path, wave count, deliverable list with specialist hints,
+dependency ordering, any structural notes.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value).
 
 ## Learnings
 Append reusable insights to `.furrow/rows/{name}/learnings.jsonl`.
diff --git a/skills/ideate.md b/skills/ideate.md
index 72de2de..0bcead5 100644
--- a/skills/ideate.md
+++ b/skills/ideate.md
@@ -1,4 +1,8 @@
-# Step: Ideate
+# Phase Driver Brief: Ideate
+
+You are the ideate phase driver. Your role is to run the ideation step ceremony,
+dispatch engine teams where needed, and assemble the phase EOS-report for the operator.
+You do not address the user directly — that is the operator's responsibility.
 
 ## What This Step Does
 Explore the problem space. Produce a validated `definition.yaml` as the work contract.
@@ -9,7 +13,8 @@ Explore the problem space. Produce a validated `definition.yaml` as the work con
 ## Model Default
 model_default: sonnet
 
-## Step-Specific Rules
+## Step Ceremony
+
 Run the 6-part ceremony in order:
 
 1. **Brainstorm** — explore dimensions of the problem. Surface at least 3 angles.
@@ -21,50 +26,44 @@ Run the 6-part ceremony in order:
 2. **Premise challenge** — apply three-layer analysis: conventional wisdom, search
    for prior art in the codebase, first-principles reasoning.
 3. **Questions before research** — surface design decisions as named options
-   (Option A/B/C) with a stated lean. Wait for user response in supervised mode.
+   (Option A/B/C) with a stated lean. Return these to the operator for user response.
    Emit `<!-- ideation:section:{name} -->` before each decision block.
-4. **Section-by-section approval** — build `definition.yaml` incrementally. Present
+4. **Section-by-section approval** — build `definition.yaml` incrementally. Produce
    each section individually: objective, each deliverable, context pointers,
    constraints, gate policy. Emit section markers before each.
    If `state.json` has a non-null `source_todo`, include it in `definition.yaml`.
    If `state.json` has a non-null `gate_policy_init`, use it as the default for
-   `gate_policy` in `definition.yaml` (user can override during approval).
-5. **Dual outside voice** — run both reviewers in parallel against the completed
-   `definition.yaml`:
-   a. Fresh same-model subagent (isolated context) for problem framing review.
-   b. Cross-model review via `frw cross-model-review --ideation <name>` if `cross_model.provider`
-      is configured in `furrow.yaml`. If absent, skip cross-model.
-   Synthesize findings from both. Record in gate evidence. Revise definition if needed.
+   `gate_policy` in `definition.yaml`.
+5. **Dual outside voice** — dispatch engine reviewers in parallel against the completed
+   `definition.yaml`. Use `skills/shared/specialist-delegation.md` for dispatch protocol.
+   Compose engine handoff via `furrow handoff render --target engine:specialist:reviewer`.
+   Dispatch:
+   a. Fresh same-model engine (isolated context) for problem framing review.
+   b. Cross-model review engine via `frw cross-model-review --ideation <name>` if
+      `cross_model.provider` is configured in `furrow.yaml`. If absent, skip.
+   Collect EOS-reports. Synthesize findings. Record in gate evidence. Revise definition if needed.
 6. **Hard gate** — validate definition with `frw validate-definition`.
-   Gate record required in `state.json` before advancing.
-
-Mode adaptations:
-- **Supervised**: user responds to each decision and approves each section.
-- **Delegated**: agent self-answers decisions; user approves final definition.
-- **Autonomous**: evaluator validates instead of human; escalates on failure.
+   Gate record required before returning phase result to operator.
 
 ## Collaboration Protocol
 
-Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.
+Record decisions using `skills/shared/decision-format.md`. Return decisions to
+operator for user response — do not self-answer decisions in supervised mode.
 
 **Decision categories** for ideation:
 - **Scope boundaries** — what's in vs out of this work
 - **Success criteria** — what "done" looks like concretely
 - **Constraint priorities** — which constraints are hard vs soft/negotiable
 
-**High-value question examples** (ask these, not "does this look right?"):
-- "I see two framings — {X} (scope-limited) and {Y} (scope-expanded). Which aligns with your intent?"
-- "Is {constraint} a hard requirement or negotiable if it conflicts with {goal}?"
-- "What does 'done' look like — {concrete outcome A} or {concrete outcome B}?"
-
 Mid-step iteration is expected; `step_status` remains `in_progress` throughout.
 
-## Agent Dispatch Metadata
-- **Dispatch pattern**: Optional — fresh reviewer subagent for dual outside voice
-- **Agent model**: sonnet (reviewer is structured evaluation, not novel reasoning)
-- **Context to agent**: Problem framing summary, definition.yaml draft, review dimensions
-- **Context excluded**: Full 6-part ceremony conversation, user decision history
-- **Returns**: Structured review findings for orchestrator synthesis
+## Engine Dispatch
+
+Engine dispatch for dual outside voice (step 5):
+- Build engine handoffs via `furrow handoff render --target engine:specialist:{id}`
+- Grounding: problem framing summary, definition.yaml draft, review dimensions
+- Exclude: full 6-part ceremony conversation, user decision history
+- Receive: structured review findings for driver synthesis
 
 ## Shared References
 Read these when relevant to your current action:
@@ -72,23 +71,22 @@ Read these when relevant to your current action:
 - `skills/shared/learnings-protocol.md` — when capturing learnings
 - `skills/shared/git-conventions.md` — before any commit
 - `skills/shared/summary-protocol.md` — Open Questions only at this step
-- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — layer boundaries and handoff exchange
 
 ## Step Mechanics
 Transition out: gate record `ideate->research` with outcome `pass` required.
-No pre-step evaluation — ideation always runs. Post-step gate evaluates
-completeness, alignment, feasibility, and cross-model evidence.
-Reference: `evals/gates/ideate.yaml` post_step, per `skills/shared/gate-evaluator.md`.
+No pre-step evaluation — ideation always runs.
 Next step expects: validated `definition.yaml` and initialized `state.json`.
 
-## Supervised Transition Protocol
-Before requesting a step transition:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-2. Present work to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to advance to research?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
-6. On "no": ask what needs to change, address feedback, return to step 2.
+## EOS-Report Assembly
+
+Assemble phase EOS-report per `templates/handoffs/return-formats/ideate.json`.
+Include: validated definition.yaml path, gate evidence summary, dual-reviewer
+synthesis, any open questions, decisions made.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value). Do not present to user — the operator handles presentation
+per `skills/shared/presentation-protocol.md` (D6).
 
 ## Learnings
 When you discover a reusable insight (pattern, pitfall, preference, convention,
diff --git a/skills/implement.md b/skills/implement.md
index 25d2141..36b61a0 100644
--- a/skills/implement.md
+++ b/skills/implement.md
@@ -1,7 +1,12 @@
-# Step: Implement
+# Phase Driver Brief: Implement
+
+You are the implement phase driver. Your role is to run the implement step
+ceremony, dispatch per-deliverable engine teams (parallel where allowed), and
+assemble the phase EOS-report for the operator. You do not address the user
+directly — that is the operator's responsibility.
 
 ## What This Step Does
-Execute decomposed work items against specs using specialist agents.
+Execute decomposed work items against specs using engine teams.
 
 ## What This Step Produces
 Code mode: code changes in git. Research mode: knowledge artifact in deliverables/.
@@ -9,181 +14,79 @@ Code mode: code changes in git. Research mode: knowledge artifact in deliverable
 ## Model Default
 model_default: sonnet
 
-## Step-Specific Rules
-- Each specialist works within its `file_ownership` boundaries.
-- All acceptance criteria from `definition.yaml` must be addressed.
-- Read `summary.md` for decompose context and wave assignments.
-
-## Shared References
-- `skills/shared/red-flags.md` — before any file write
-- `skills/shared/git-conventions.md` — before any commit
-- `skills/shared/learnings-protocol.md` — when capturing learnings
-- `skills/shared/context-isolation.md` — when coordinating agent teams
-- `skills/shared/summary-protocol.md` — before completing step
+## Step Ceremony
 
-## Specialist Loading (Mandatory)
-Before dispatching any agent for a deliverable, you MUST attempt to load the
-specialist template from `specialists/{specialist}.md` as assigned in plan.json.
-If the file does not exist, warn on stderr and proceed without it — this is
-degraded mode, not normal operation. Note the missing specialist in the
-deliverable's review evidence so the review step can flag it.
+- Each engine works within its `file_ownership` boundaries.
+- All acceptance criteria from `definition.yaml` must be addressed.
+- Load context bundle from operator prime message (includes wave assignments from plan.json).
 
-### Step-Level Specialist Modifier
-When working with a specialist during implementation, emphasize incremental
-correctness, testability, and adherence to the spec over exploratory design.
-The specialist's reasoning patterns apply to implementation decisions: which
-pattern to use, how to structure the code, what anti-patterns to avoid.
+## Engine Dispatch
 
-## Dispatch Decision Tree
+Compose engine teams **at dispatch-time** based on `plan.json` hints and the work at hand.
+`plan.json`'s `specialist:` field is a starting hint — adapt composition as needed.
 
-Read `plan.json`. Count deliverables and inspect their assignments. Follow the
-first matching branch — do not skip ahead.
+**Dispatch Decision Tree** (for each wave, for each deliverable):
 
 ```
-plan.json has 1 deliverable?
-  YES → SOLO execution.
-         Load specialist as a skill into current agent context.
-         Execute the deliverable directly.
-
-plan.json has >1 deliverable, ALL share the same specialist, ALL in wave 1?
-  YES → SOLO execution with specialist skill loaded.
-         Execute deliverables sequentially in the current agent.
-         NOTE: Branch 2 applies only when all deliverables are in wave 1.
-         Any plan with multiple waves falls through to branch 3 regardless
-         of specialist diversity.
-
-plan.json has >1 deliverable with DIFFERENT specialists OR >1 wave?
-  YES → MULTI-AGENT dispatch.
-         Follow the Dispatch Checklist below.
-```
-
-No other paths exist. Every plan.json falls into exactly one branch.
-
-## Agent() Tool Call Example
-
-When dispatching a sub-agent for a deliverable, use this pattern. Every field
-shown is required — omitting any field is a dispatch error.
+Deliverable is self-contained, single domain?
+  YES → dispatch one engine
 
-> **Note**: The block below is pseudocode showing prompt composition structure,
-> not literal tool syntax. Substitute `{placeholders}` with actual values before
-> invoking the Agent tool.
+Deliverable spans multiple domains (e.g., implementation + tests)?
+  YES → dispatch parallel engines with disjoint file_ownership
 
+Engine A's output feeds engine B?
+  YES → dispatch serially; pass engine A EOS-report as grounding to engine B
 ```
-Agent(
-  prompt="""
-You are a {specialist_name} implementing the "{deliverable_name}" deliverable.
-
-## Specialist Domain
-{contents of specialists/{specialist}.md — full markdown body}
-
-## Your Assignment
-Deliverable: {deliverable_name}
-File ownership (you may ONLY write to these paths):
-{one glob pattern per line from plan.json assignments[deliverable].file_ownership}
-
-## Acceptance Criteria (from definition.yaml)
-{paste the acceptance_criteria entries for this deliverable}
-
-## Context
-{summary.md contents — Key Findings and Recommendations sections}
-{curated files per specialist Context Requirements: Required items always, Helpful items when relevant}
-
-## Rules
-- Write ONLY within your file_ownership globs. Any write outside is a violation.
-- Read skills/shared/red-flags.md before any file write.
-- Read skills/shared/git-conventions.md before any commit.
-- Do not read or write state.json.
-- Do not reference other deliverables or other agents' work.
-""",
-  model="{resolved_model}"
-)
-```
-
-**Model resolution order** (use first non-empty value):
-1. Specialist template YAML frontmatter `model_hint`
-2. Step `model_default` (sonnet)
-3. Project default (sonnet)
-
-Valid model values: `opus`, `sonnet`, `haiku`.
-
-## Dispatch Checklist
-
-Execute these steps in exact order. Do not skip or reorder.
-
-1. **Read plan.json.** Parse `waves` array. Store wave count and all assignments.
 
-2. **Validate wave ordering.** Waves must execute in numeric order (wave 1, then
-   wave 2, etc.). Deliverables within a wave execute concurrently.
+For each engine:
+1. Load specialist brief from `specialists/{specialist}.md` (hint from plan.json).
+   If file missing: warn, record in review evidence, proceed in degraded mode.
+2. Build engine handoff via `furrow handoff render --target engine:specialist:{id}`
+3. Grounding: spec for this deliverable, file ownership globs, summary context
+4. Exclude: other deliverables' specs, wave N+1 plans
+5. Engine returns: EOS-report with artifact paths, AC verification, any blockers
 
-3. **For each wave** (in order, wave 1 first):
+**Dispatch protocol**: `skills/shared/specialist-delegation.md`
 
-   a. **For each deliverable in this wave** (concurrently):
-      - Read `specialists/{specialist}.md` for this deliverable's assigned specialist.
-      - If the specialist file is missing: warn on stderr, record in review evidence,
-        proceed without specialist template (degraded mode).
-      - Read the specialist's `model_hint` from YAML frontmatter.
-      - Curate context per the specialist's Context Requirements section:
-        Required items always included, Helpful items when relevant, Exclude items omitted.
-      - Build the Agent prompt using the Agent() example above.
-      - Spawn the agent. Pass `model` using the model resolution order.
+## Wave Execution
 
-   b. **Wait for all agents in this wave to complete.**
+Execute waves in numeric order. Deliverables within a wave execute concurrently
+(parallel engine dispatch). Between waves, run Wave Inspection Protocol.
 
-   c. **Run Wave Inspection Protocol** (below) before advancing to the next wave.
+### Wave Inspection Protocol
 
-4. **After all waves complete:** verify every deliverable in plan.json has been
-   addressed. Update deliverable statuses via `rws complete-deliverable`.
+After each wave, before launching next:
 
-## Wave Inspection Protocol
+1. **Verify artifacts exist** (blocking): for each deliverable, confirm at least
+   one file matching `file_ownership` was created or modified. Failures block next wave.
 
-Run after each wave completes, before launching the next wave.
+2. **Check ownership violations** (non-blocking): run `git diff --name-only`.
+   Files changed outside ownership globs are warnings, not blocks. Log for review evidence.
 
-### 1. Verify deliverable artifacts exist (blocking)
-For each deliverable in the completed wave:
-- List the files matching its `file_ownership` globs.
-- Confirm at least one file was created or modified.
-- If no artifacts found: flag the deliverable as incomplete. Do not proceed to next wave.
-  **Step 1 failures block the next wave.**
+3. **Curate context for next wave**: summarize wave N results; pass to wave N+1 engine
+   prompts. Do not pass orchestrator's full conversation.
 
-### 2. Check for file_ownership violations (non-blocking)
-- Run `git diff --name-only` for the wave's changes.
-- For each changed file, confirm it falls within exactly one deliverable's
-  `file_ownership` globs for this wave.
-- A file changed outside all ownership globs is a violation. Log it as a
-  warning in review evidence. It does not block the next wave but must be
-  reported in the implement-to-review gate evidence.
-  **Step 2 violations are warnings, not blocks.**
+After all waves: verify every deliverable addressed. Record via `rws complete-deliverable`.
 
-### 3. Curate context for the next wave
-- For each deliverable in wave N+1, determine which wave N outputs it needs.
-- Follow the between-wave curation protocol in `skills/shared/context-isolation.md`.
-- Summarize wave N results into the next wave's agent prompts. Do not pass
-  the orchestrator's full conversation.
-
-## Team Planning
-Write `team-plan.md` if not created during decompose. Ownership: each
-specialist works ONLY within `plan.json` globs (no overlap within a wave).
-Unplanned changes are warnings, not blocks — Phase A review audits them.
-Skill injection order: code-quality, specialist skills, implement, task.
+## Shared References
+- `skills/shared/red-flags.md` — before any file write
+- `skills/shared/git-conventions.md` — before any commit
+- `skills/shared/learnings-protocol.md` — when capturing learnings
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — layer boundaries; engine-team-composed-at-dispatch
 
 ## Step Mechanics
 Transition out: gate record `implement->review` with `pass` required.
-No pre-step evaluation — implementation always runs. Post-step gate evaluates
-artifact presence, acceptance criteria, and quality dimensions.
-Reference: `evals/gates/implement.yaml` post_step, per `skills/shared/gate-evaluator.md`.
+No pre-step evaluation — implementation always runs.
 Next step expects: all deliverables implemented, status updated in state.json.
 
-## Supervised Transition Protocol
-Before requesting a step transition:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-2. Present work to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to advance to review?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
-6. On "no": ask what needs to change, address feedback, return to step 2.
+## EOS-Report Assembly
 
-## Worktree-Complete Hook
-When a tmux session exits after worktree work, `launch-phase.sh` fires `rws generate-reintegration <row>` via `tmux set-hook session-closed`. This produces `.furrow/rows/<row>/reintegration.json` — the handoff artifact for `/furrow:merge`. Do not run `rws generate-reintegration` manually during implement; it runs automatically on session close.
+Assemble phase EOS-report per `templates/handoffs/return-formats/implement.json`.
+Include: per-deliverable artifact paths, AC verification results, ownership violation
+warnings, engine team composition (for audit), open questions.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value).
 
 ## Learnings
 Append reusable insights to `.furrow/rows/{name}/learnings.jsonl`.
@@ -198,4 +101,3 @@ When `state.json.mode` is `"research"`:
 - Update `research/sources.md` as sources are discovered.
 - Unsourced claims marked `[unverified]` or `[assumption]`.
 - Read `references/research-mode.md` for citation format and source types.
-- Research mode: no pre-step evaluation — implementation always runs.
diff --git a/skills/plan.md b/skills/plan.md
index ecf0bad..90c0747 100644
--- a/skills/plan.md
+++ b/skills/plan.md
@@ -1,4 +1,8 @@
-# Step: Plan
+# Phase Driver Brief: Plan
+
+You are the plan phase driver. Your role is to run the planning step ceremony,
+dispatch engine teams where needed, and assemble the phase EOS-report for the operator.
+You do not address the user directly — that is the operator's responsibility.
 
 ## What This Step Does
 Synthesize research into architecture decisions and execution strategy.
@@ -7,103 +11,97 @@ Synthesize research into architecture decisions and execution strategy.
 - Architecture decisions recorded in `summary.md`
 - `plan.json` if parallel execution is needed (multiple deliverables).
   Use `templates/plan.json` as the schema reference for plan.json structure.
-- `team-plan.md` if agent teams will be used
+
+Note: `team-plan.md` is retired. Engine teams are composed at dispatch-time
+by drivers when entering the implement step, not at planning-time. `plan.json`'s
+`specialist:` field per deliverable is a hint for the implementing driver,
+not a binding contract.
 
 ## Model Default
 model_default: sonnet
 
-## Step-Specific Rules
+## Step Ceremony
+
 - Every deliverable from `definition.yaml` must have a clear implementation path.
 - Architecture decisions must reference research findings, not assumptions.
-- Ensure `skills/work-context.md` is loaded.
-- Read `summary.md` for research context.
-- CC plan mode (EnterPlanMode) may be used to explore the codebase and get
-  clarity from the user for this step's decisions. It must not produce artifacts
-  that span or replace the spec, decompose, or implement steps.
+- Load context bundle from operator prime message (includes research synthesis).
+- Read `summary.md` for research context via bundle `prior_artifacts.summary_sections`.
+- CC plan mode (EnterPlanMode) may be used to explore the codebase for this step's
+  decisions. It must not produce artifacts that span or replace spec, decompose, or implement.
+
+## Engine Dispatch
+
+Dispatch codebase exploration engine when architecture investigation is needed.
+
+1. Build engine handoff via `furrow handoff render --target engine:specialist:{id}`
+2. Grounding: exploration question, file/symbol targets, research findings summary
+3. Exclude: trade-off discussions, risk tolerance decisions
+4. Engine returns: codebase findings (file structures, patterns, dependencies)
+
+**Dispatch protocol**: `skills/shared/specialist-delegation.md`
 
 ## Collaboration Protocol
 
-Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.
+Record decisions using `skills/shared/decision-format.md`. Return decisions to operator.
 
 **Decision categories** for planning:
 - **Architecture trade-offs** — simplicity vs extensibility, performance vs maintainability
 - **Dependency ordering** — what blocks what and why
 - **Risk tolerance** — acceptable failure modes and mitigation level
 
-**High-value question examples** (ask these, not "does this look right?"):
-- "This trades simplicity for extensibility. Given the project scope, which do you prefer?"
-- "I see two dependency orders — {A then B} or {B then A}. Any reason to prefer one?"
-- "This approach has {risk}. Is that acceptable, or should we add mitigation?"
-
 Mid-step iteration is expected; `step_status` remains `in_progress` throughout.
 
-### Step-Level Specialist Modifier
-When working with a specialist during planning, emphasize architectural framing
-over implementation detail. The specialist should reason about component boundaries,
-dependency direction, and trade-off analysis. Prefer options analysis (A vs B
-with trade-offs stated) over prescriptive solutions. The specialist's domain
-expertise applies to architecture decisions: what interfaces exist, what coupling
-to accept, what patterns to follow.
-
-## Agent Dispatch Metadata
-- **Dispatch pattern**: Optional — codebase exploration agent for architecture investigation
-- **Agent model**: sonnet (structured codebase reading, not architectural reasoning)
-- **Context to agent**: Exploration question, file/symbol targets, research findings summary
-- **Context excluded**: Trade-off discussions, risk tolerance decisions
-- **Returns**: Codebase findings (file structures, patterns, dependencies)
+## Layered Model and plan.json
+
+Under the layered model, engine teams are composed at dispatch-time:
+- `plan.json`'s `waves` and `file_ownership` remain authoritative for execution order and ownership.
+- `plan.json`'s `specialist:` field per deliverable is a **hint** — the implementing driver
+  uses it as a starting point and may adapt team composition at dispatch-time.
+- Parallel engines within a deliverable are legitimate; `file_ownership` prevents conflicts.
+
+## Dual-Reviewer Protocol
+
+Before returning phase result, dispatch both reviewers in parallel:
+1. **Fresh reviewer engine** — isolated context, receives: plan.json, definition.yaml.
+   Excludes: summary.md, conversation history, state.json.
+   Engine handoff via `furrow handoff render --target engine:specialist:reviewer`.
+2. **Cross-model reviewer** — `frw cross-model-review {name} --plan`
+   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
+Synthesize findings: flag disagreements, note unique findings, record
+both sources in gate evidence.
 
 ## Shared References
 Read these when relevant to your current action:
 - `skills/shared/red-flags.md` — before finalizing plan
 - `skills/shared/learnings-protocol.md` — when capturing learnings
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — layer boundaries; engine-team-composed-at-dispatch model
 - `skills/shared/summary-protocol.md` — before completing step
-- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol
-
-## Team Planning
-When `plan.json` has multiple deliverables, create `team-plan.md` with specialist
-assignments per deliverable. Read `references/specialist-template.md` for format.
-Assign `file_ownership` globs to prevent cross-specialist conflicts in waves.
-
-## Research Mode
-When `state.json.mode` is `"research"`:
-- Define knowledge artifact structure: sections, sub-topics, evidence requirements.
-- `file_ownership` targets `.furrow/rows/{name}/deliverables/` paths, not git tree globs.
-- No parallel waves needed — research deliverables are authored sequentially or by section.
-- Specialist assignment uses research roles (domain-researcher, synthesis-writer).
-- Read `references/research-mode.md` for artifact formats.
 
 ## Step Mechanics
 Transition out: gate record `plan->spec` with outcome `pass` required.
 Pre-step shell check (`rws gate-check`): 1 deliverable, no depends_on, not
 supervised, not force-stopped.
-Pre-step evaluator (`evals/gates/plan.yaml`): complexity-assessment — does the
-deliverable need architectural decisions beyond definition.yaml? Per `skills/shared/gate-evaluator.md`.
 Next step expects: architecture decisions in `summary.md`, `plan.json` if
 parallel execution needed, and clear implementation path per deliverable.
 
-## Dual-Reviewer Protocol
-Before requesting transition, run both reviewers in parallel:
-1. **Fresh Claude reviewer** — `claude -p --bare` with plan artifacts,
-   definition.yaml ACs, and `evals/dimensions/plan.yaml` dimensions.
-   Specialist template included if specialist was delegated during this step.
-   Receives: plan.json, team-plan.md (if exists), definition.yaml.
-   Excludes: summary.md, conversation history, state.json.
-2. **Cross-model reviewer** — `frw cross-model-review {name} --plan`
-   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
-Synthesize findings: flag disagreements, note unique findings, record
-both sources in gate evidence. Address or explicitly reject all findings
-before requesting transition.
-
-## Supervised Transition Protocol
-Before requesting a step transition:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-2. Present work to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to advance to spec?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
-6. On "no": ask what needs to change, address feedback, return to step 2.
+## EOS-Report Assembly
+
+Assemble phase EOS-report per `templates/handoffs/return-formats/plan.json`.
+Include: plan.json path, architecture decisions summary, reviewer findings,
+dependency ordering rationale, open questions.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value).
 
 ## Learnings
 When you discover a reusable insight (pattern, pitfall, preference, convention,
 or dependency quirk), append it to `.furrow/rows/{name}/learnings.jsonl` using the
 learning schema. Read `skills/shared/learnings-protocol.md` for format.
+
+## Research Mode
+When `state.json.mode` is `"research"`:
+- Define knowledge artifact structure: sections, sub-topics, evidence requirements.
+- `file_ownership` targets `.furrow/rows/{name}/deliverables/` paths, not git tree globs.
+- No parallel waves needed — research deliverables are authored sequentially or by section.
+- Specialist assignment uses research roles (domain-researcher, synthesis-writer).
+- Read `references/research-mode.md` for artifact formats.
diff --git a/skills/research.md b/skills/research.md
index 4d412cf..f73673d 100644
--- a/skills/research.md
+++ b/skills/research.md
@@ -1,4 +1,8 @@
-# Step: Research
+# Phase Driver Brief: Research
+
+You are the research phase driver. Your role is to run the research step ceremony,
+dispatch parallel research engine teams, and assemble the phase EOS-report for the operator.
+You do not address the user directly — that is the operator's responsibility.
 
 ## What This Step Does
 Investigate prior art, architecture options, and constraints identified during ideation.
@@ -11,76 +15,65 @@ Investigate prior art, architecture options, and constraints identified during i
 ## Model Default
 model_default: opus
 
-## Step-Specific Rules
+## Step Ceremony
+
 - All questions from ideation must be addressed or explicitly deferred.
 - Research must reference `definition.yaml` deliverables by name.
-- Ensure `skills/work-context.md` is loaded.
-- Read `summary.md` for ideation context (do not re-read raw definition discussions).
+- Load context bundle from operator prime message (includes `prior_artifacts.summary_sections` from ideation).
 - Source hierarchy: primary (official docs, source code, changelogs, `--help`) >
   secondary (blogs, tutorials, StackOverflow) > tertiary (training data).
   Training data is acceptable for well-established facts (language syntax, stdlib).
   Version-specific, behavior-specific, or config-specific claims require primary source verification.
 - Claims about external software that cannot be verified against a primary source must be flagged as **unverified**.
 
+## Engine Dispatch
+
+Dispatch parallel research engines per topic. Compose engine team at dispatch-time.
+
+For each research topic from the definition:
+1. Build engine handoff via `furrow handoff render --target engine:specialist:{id}`
+2. Grounding: research question, definition.yaml deliverable names, source hierarchy rules, synthesis from ideation
+3. Exclude: source-trust decisions from other topics, user validation conversations
+4. Engine returns: per-topic research document with Sources Consulted section
+
+Collect all per-topic EOS-reports. Synthesize into `research/synthesis.md`.
+
+**Dispatch protocol**: `skills/shared/specialist-delegation.md`
+
 ## Collaboration Protocol
 
-Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.
+Record decisions using `skills/shared/decision-format.md`. Return decisions and
+findings to operator — do not self-answer trust decisions.
 
 **Decision categories** for research:
 - **Source trust** — which sources to rely on when findings conflict
 - **Finding validation** — whether findings match the user's domain knowledge
 - **Coverage sufficiency** — when to stop researching and move on
 
-**High-value question examples** (ask these, not "does this look right?"):
-- "Source A says {X}, Source B says {Y}. Which should we trust for this project?"
-- "Does this finding match your domain experience, or should I dig deeper into {area}?"
-- "I've covered {areas}. Is there a dimension I'm missing, or is this sufficient?"
-
 Mid-step iteration is expected; `step_status` remains `in_progress` throughout.
 
-### Step-Level Specialist Modifier
-When working with a specialist during research, emphasize investigation breadth
-and source triangulation over depth in any single approach. The specialist should
-identify what is unknown and what claims require primary source verification.
-The specialist's domain expertise applies to knowing where to look and what to
-distrust in secondary sources.
-
-## Agent Dispatch Metadata
-- **Dispatch pattern**: Parallel agents per research topic
-- **Agent model**: opus (multi-source investigation requires deep reasoning)
-- **Context to agent**: Research question, definition.yaml deliverable names, source hierarchy rules, summary.md context from ideation
-- **Context excluded**: Source-trust decisions from other topics, user validation conversations
-- **Returns**: Per-topic research document with Sources Consulted section
-
 ## Shared References
 Read these when relevant to your current action:
 - `skills/shared/red-flags.md` — before concluding research
 - `skills/shared/learnings-protocol.md` — when capturing learnings
-- `skills/shared/context-isolation.md` — when dispatching research sub-agents
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — layer boundaries
 - `skills/shared/summary-protocol.md` — before completing step
-- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol
-
-## Team Planning
-When definition has multiple deliverables or >3 research questions, dispatch
-parallel sub-agents per topic. Read `skills/shared/context-isolation.md`.
 
 ## Step Mechanics
 Transition out: gate record `research->plan` with outcome `pass` required.
 Pre-step shell check (`rws gate-check`): 1 deliverable, code mode, path-referencing
 ACs, no directory context pointers, not supervised, not force-stopped.
-Pre-step evaluator (`evals/gates/research.yaml`): path-relevance — are referenced
-paths sufficient without broader investigation? Per `skills/shared/gate-evaluator.md`.
 Next step expects: research findings addressing all ideation questions, recorded
 in `research.md` or `research/` directory with `synthesis.md`.
 
-## Supervised Transition Protocol
-Before requesting a step transition:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-2. Present work to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to advance to plan?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
-6. On "no": ask what needs to change, address feedback, return to step 2.
+## EOS-Report Assembly
+
+Assemble phase EOS-report per `templates/handoffs/return-formats/research.json`.
+Include: per-topic research file paths, synthesis.md path, source tiers used,
+unverified claims flagged, open questions, coverage gaps.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value).
 
 ## Learnings
 When you discover a reusable insight (pattern, pitfall, preference, convention,
diff --git a/skills/review.md b/skills/review.md
index e1aac98..bb30cbc 100644
--- a/skills/review.md
+++ b/skills/review.md
@@ -1,4 +1,9 @@
-# Step: Review
+# Phase Driver Brief: Review
+
+You are the review phase driver. Your role is to run the review step ceremony,
+dispatch reviewer engines, assemble the review rollup, and return the phase
+EOS-report for the operator. You do not address the user directly — that is the
+operator's responsibility.
 
 ## What This Step Does
 Evaluate implementation against spec and audit plan completion.
@@ -8,97 +13,78 @@ Evaluate implementation against spec and audit plan completion.
 - Gate record in `state.json` with overall verdict
 
 ## Model Default
-model_default: opus
+model_default: sonnet
+
+## Step Ceremony
 
-## Step-Specific Rules
-- **Phase A** (in-session): verify artifacts exist, acceptance criteria met, planned files touched.
-  Deterministic shell checks — runs in the current session.
-- **Phase B** (fresh-session): evaluate quality dimensions per artifact type.
-  Runs via `claude -p --bare` as an isolated process with no conversation context.
+- **Phase A** (in-driver): verify artifacts exist, acceptance criteria met, planned files touched.
+  Deterministic shell checks — runs within the driver session.
+- **Phase B** (engine dispatch): evaluate quality dimensions per artifact type.
+  Dispatch isolated reviewer engines per deliverable.
   See `commands/review.md` for the invocation protocol.
 - `overall` is `pass` only when both phases pass.
+- Load context bundle from operator prime message.
 - Read `references/review-methodology.md` and `references/eval-dimensions.md`.
 
-### Step-Level Specialist Modifier
-When working with a specialist during review, emphasize acceptance criteria
-verification, anti-pattern detection per the specialist's table, and quality
-dimension coverage. The specialist's reasoning patterns apply to review
-judgments: what to check, what constitutes a violation, what quality bar to hold.
+## Engine Dispatch
+
+Dispatch reviewer engines per deliverable. Two parallel reviewers per deliverable:
+
+1. **Fresh reviewer engine** — dispatch via `furrow handoff render --target engine:specialist:reviewer`.
+   Grounding: review prompt template, artifact paths, eval dimensions ONLY.
+   Excludes: summary.md, state.json, conversation history, CLAUDE.md.
+   Engine returns: per-deliverable review verdict with dimension scores.
+
+2. **Cross-model reviewer** — run `frw cross-model-review {name} {deliverable}`.
+   Reads `cross_model.provider` from `furrow.yaml`. Skip if absent.
+
+After both engines return, **synthesize**: flag dimension disagreements,
+note unique findings, produce final `reviews/{deliverable}.json` with `reviewers` field.
+
+**Dispatch protocol**: `skills/shared/specialist-delegation.md`
 
-## Agent Dispatch Metadata
-- **Dispatch pattern**: Phase B isolated evaluators (fresh Claude + cross-model)
-- **Agent model**: opus (quality judgment requires deep reasoning)
-- **Context to agent**: Review prompt template, artifact paths, eval dimensions ONLY
-- **Context excluded**: summary.md, state.json, conversation history, CLAUDE.md (generator-evaluator separation)
-- **Returns**: Per-deliverable review verdict with dimension scores
+## Review Rollup
+
+After all deliverable reviews complete:
+1. Aggregate per-deliverable verdicts.
+2. Determine overall pass/fail (any Phase A or Phase B fail → overall fail).
+3. Surface any decisions conditional on post-ship evidence:
+   record via `alm observe add --kind decision-review ...`
+4. Assemble phase EOS-report (see below).
 
 ## Shared References
 - `skills/shared/red-flags.md` — before any verdict
 - `skills/shared/eval-protocol.md` — evaluator guidelines
 - `skills/shared/git-conventions.md` — when reviewing commit quality
 - `skills/shared/learnings-protocol.md` — when capturing learnings
-- `skills/shared/context-isolation.md` — when dispatching review sub-agents
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — layer boundaries
 - `skills/shared/summary-protocol.md` — before completing step
 
-## Dual-Reviewer Protocol
-Every review runs **two independent reviewers in parallel**:
-1. **Fresh Claude reviewer** — `claude -p --bare` for generator-evaluator separation.
-   Receives ONLY the review prompt template + artifact paths + eval dimensions.
-   Does NOT receive: `summary.md`, `state.json`, conversation history, or CLAUDE.md.
-2. **Cross-model reviewer** — run `frw cross-model-review {name} {deliverable}`.
-   Reads `cross_model.provider` from `furrow.yaml`. If no provider configured, skip.
-
-Both reviewers evaluate the same deliverable against the same dimensions.
-After both complete, **synthesize** — flag any dimension where reviewers disagree,
-note unique findings from each, and produce the final `reviews/{deliverable}.json`
-with a `reviewers` field recording both sources.
-
-Agent tool subagents (used for gate evaluations) are isolated from conversation
-history but inherit system context — adequate for gates, not for final review.
-See `skills/shared/gate-evaluator.md` Isolation Verification section.
-
-## Team Planning
-For multi-deliverable work, Phase B runs one `claude -p` invocation per deliverable.
-Each invocation is fully independent — no shared state between deliverable reviews.
-
 ## Step Mechanics
 Review is the final step. No pre-step evaluation — review always runs.
 Post-step gate evaluates Phase A and Phase B results across all deliverables.
-Reference: `evals/gates/review.yaml` post_step, per `skills/shared/gate-evaluator.md`.
 On pass: row ready for archive. On fail: returns to implement step.
 
-## Supervised Transition Protocol
-Before completing review:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-   Before updating: check whether any decisions in this row are conditional on
-   post-ship evidence. If yes, record each via `alm observe add --kind decision-review ...`.
-2. Present review findings to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to archive?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": proceed with archive per `/furrow:archive` command.
-6. On "no": ask what needs to change, address feedback, return to step 2.
-
-### Consent Isolation
-Each question requiring user input is an independent decision — a "yes" to
-one question does NOT carry over to subsequent questions. Archive approval,
-TODO extraction, learning promotion, and any other user-facing decisions are
-separate consent gates. Do not interpret prior user responses as approval for
-unrelated subsequent decisions (e.g., "yes to archive" does not mean "yes to
-skip TODOs" or "yes to promote learnings").
+## EOS-Report Assembly
+
+Assemble phase EOS-report per `templates/handoffs/return-formats/review.json`.
+Include: per-deliverable review JSON paths, overall verdict, phase A/B pass/fail
+per deliverable, dimension scores summary, reviewer synthesis notes, learnings to promote.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value). The operator presents findings to user and requests archive approval.
 
 ## Learnings
 Append reusable insights to `.furrow/rows/{name}/learnings.jsonl`.
 Read `skills/shared/learnings-protocol.md` for schema and categories.
 After review, scan artifacts for promotion candidates (architecture decisions,
-patterns, specialist defs, eval dimensions). Present each with rationale.
+patterns, specialist defs, eval dimensions). Include in EOS-report.
 
 ## Research Mode
 When `state.json.mode` is `"research"`:
-- Implement step: load `evals/dimensions/research-implement.yaml`.
-- Spec step: load `evals/dimensions/research-spec.yaml`.
 - Phase A: verify `.furrow/rows/{name}/deliverables/` files exist, match
   `plan.json` ownership, meet acceptance criteria from definition.yaml.
 - Phase B: evaluate coverage, evidence-basis, synthesis-quality,
   internal-consistency, actionability. Verify citations.
-- Scan deliverables for promotion candidates to flag at archive.
+- Load `evals/dimensions/research-implement.yaml` and `evals/dimensions/research-spec.yaml`.
 - Read `references/research-mode.md` for dimension selection logic.
diff --git a/skills/shared/layer-protocol.md b/skills/shared/layer-protocol.md
new file mode 100644
index 0000000..2cae52b
--- /dev/null
+++ b/skills/shared/layer-protocol.md
@@ -0,0 +1,143 @@
+# Layer Protocol
+
+Canonical contract for the 3-layer orchestration model. All runtime adapters
+(Claude, Pi) implement this protocol. Furrow backend is runtime-agnostic.
+
+Cross-references: `skills/shared/specialist-delegation.md` (driver→engine dispatch),
+D1 `schemas/handoff-driver.schema.json` + `schemas/handoff-engine.schema.json`,
+D3 `.furrow/layer-policy.yaml` (enforcement matrix).
+
+---
+
+## Purpose
+
+Furrow's orchestration model has three named layers. Each layer has a distinct
+scope, tool surface, and accountability boundary. Layers communicate via
+structured handoffs — never via shared mutable state. Runtime-agnostic semantics
+are defined here in terms of "spawn", "message", and "return"; each adapter maps
+these to its own primitives.
+
+```
+operator  ──handoff──▶  phase driver  ──handoff──▶  engine(s)
+   ◀──phase result──        ◀──EOS-report──
+```
+
+---
+
+## Operator
+
+**Scope**: whole-row lifecycle. **Session**: long-running (persists across steps).
+**State**: the only layer that calls `rws`/`alm`/`sds` and reads/writes row state.
+**User dialog**: the only layer that addresses the user. Presentation follows
+`skills/shared/presentation-protocol.md` (D6).
+
+Responsibilities:
+- Load operator bundle via `furrow context for-step <step> --target operator`.
+- Detect current step from row state.
+- Spawn the phase driver for the current step (runtime primitive: Claude `Agent`,
+  Pi `pi-subagents spawn`).
+- Prime the driver with its context bundle via `furrow context for-step <step> --target driver`.
+- Persist the driver handoff artifact via `furrow handoff render --target driver:{step} --write`.
+- Receive the phase result (EOS-report) from the driver.
+- Present phase results to user per `skills/shared/presentation-protocol.md`.
+- Request step transition via `rws transition` after user approval.
+
+Session-resume: **runtime concern**. Claude operator reads `~/.claude/teams/{row}/config.json`
+and re-spawns stale drivers via `Agent`. Pi operator: `@tintinweb/pi-subagents` handles
+session-tree resume natively. Furrow backend has no session-id awareness.
+
+---
+
+## Phase Driver
+
+**Scope**: one step. **Session**: session-scoped (runtime-managed).
+**State**: read-only access to row state (via bundle); no direct `rws` writes.
+**Persona**: implicit — `skills/{step}.md` is the driver brief (D3 adds `layer: driver` front-matter in W5).
+
+Tools constrained by `.furrow/drivers/driver-{step}.yaml` `tools_allowlist`.
+See `schemas/driver-definition.schema.json` for schema.
+
+Responsibilities:
+- Load driver context bundle (provided by operator prime message).
+- Run the step ceremony per `skills/{step}.md`.
+- Compose an engine team at dispatch-time (not at planning-time). See
+  `skills/shared/specialist-delegation.md` for dispatch protocol.
+- Dispatch engine teams via `furrow handoff render --target engine:{specialist-id}`.
+- Collect EOS-reports from engines; assemble phase result.
+- Return phase result to operator via runtime primitive (Claude: `SendMessage` to lead;
+  Pi: agent return value).
+
+Engine team composition is per-dispatch, not per-plan. `plan.json`'s `specialist:` field
+is a hint only — drivers compose teams based on the work at hand.
+
+---
+
+## Engine
+
+**Scope**: one deliverable (one-shot). **Session**: ephemeral.
+**State**: Furrow-unaware. No `.furrow/` reads. No Furrow vocab in inputs.
+
+Engines receive only an `EngineHandoff` (D1 schema) — an isolated task brief
+containing source-tree grounding paths, a task-scoped objective, deliverables
+with acceptance criteria, and engine-scoped constraints. No row, no step, no
+gate policy, no Furrow internals.
+
+Enforcement:
+- D1 `EngineHandoff` schema rejects `.furrow/` paths and Furrow vocab in any field.
+- D3 `furrow hook layer-guard` enforces tool allowlist at runtime (Claude: PreToolUse hook;
+  Pi: `tool_call` extension event).
+- D3 post-hoc boundary leakage test asserts zero Furrow leakage in engine artifacts.
+
+Engines return an EOS-report per `templates/handoffs/return-formats/{step}.json`.
+The driver assembles per-deliverable rollups before returning the phase result.
+
+---
+
+## Handoff Exchange
+
+Driver→engine dispatch uses D1's render command:
+
+```sh
+furrow handoff render --target engine:specialist:{id} --row <name> --step <step> [--write]
+```
+
+This builds an `EngineHandoff` value (driver-curated; driver provides structured
+value via stdin or args). Rendered markdown is the engine's input.
+
+For the operator→driver handoff:
+
+```sh
+furrow handoff render --target driver:{step} --row <name> --step <step> [--write]
+```
+
+Artifacts written to `.furrow/rows/{name}/handoffs/{step}-to-{target}.md` when `--write` is passed.
+
+---
+
+## Engine-Team-Composed-at-Dispatch
+
+Drivers compose engine teams **at dispatch-time**, not at planning-time. This means:
+
+- `plan.json`'s `specialist:` field per deliverable is a **hint** for the driver, not a contract.
+- A driver may dispatch multiple engines in parallel for one deliverable.
+- Team composition adapts to the work at hand — research might spawn 3 parallel research
+  engines; implement might spawn 1 implementer + 1 test-engineer concurrently.
+- No planning artifact (team-plan.md etc.) binds team membership. `team-plan.md` is retired.
+
+---
+
+## Runtime-Agnostic Message-Passing
+
+Layer transitions are defined in terms of three primitives. Adapters provide implementations.
+
+| Primitive | Claude adapter | Pi adapter |
+|-----------|---------------|------------|
+| `spawn(agent, config)` | `Agent(subagent_type="driver:{step}", ...)` | `pi-subagents spawn({name, systemPrompt, tools})` |
+| `message(handle, body)` | `SendMessage(to=agent_id, body=...)` | `pi-subagents sendMessage(handle, body)` |
+| `return(result)` | `SendMessage` back to operator | agent return value |
+
+The `.claude/agents/driver-{step}.md` subagent definitions are rendered from
+`.furrow/drivers/driver-{step}.yaml` + `skills/{step}.md` by `furrow render adapters --runtime=claude`.
+Pi adapter reads the same driver YAML via `adapters/pi/extension/index.ts` `before_agent_start` hook.
+
+Furrow backend has no concept of session-id, no `drivers.json`, no per-row driver registry.
diff --git a/skills/shared/specialist-delegation.md b/skills/shared/specialist-delegation.md
index cffb02f..f994c1d 100644
--- a/skills/shared/specialist-delegation.md
+++ b/skills/shared/specialist-delegation.md
@@ -1,47 +1,100 @@
-# Specialist Delegation Protocol
-
-When a step involves domain-specific reasoning, select and delegate to specialists:
-
-1. **Scan** — read `specialists/_meta.yaml` scenarios index. Match `When` descriptions
-   against the current task context (definition.yaml objective, deliverable names, file patterns).
-2. **Consult preferred-specialist overrides** — for each role implied by the match
-   (e.g. `harness`, `test-engineer`, `shell`), call
-   `resolve_config_value "preferred_specialists.<role>"` via
-   `bin/frw.d/lib/common.sh`. If the resolver returns a specialist name (exit 0),
-   prefer that specialist over the scenario's default. If the resolver exits 1,
-   fall through to the scenario-based selection from step 1.
-3. **Select** — choose specialists whose scenarios (or preferred-specialist overrides)
-   are relevant. Prefer fewer specialists (1-2) over broad coverage. When no scenario
-   matches and no override is set, proceed without specialist delegation.
-4. **Delegate** — dispatch selected specialists as **sub-agents** (never load into the
-   orchestration session). Include the specialist template (`specialists/{name}.md`) in
-   the sub-agent's context alongside the task-specific artifacts.
-5. **Record** — note specialist selections in `summary.md` key-findings with rationale
-   (e.g., "Selected go-specialist — scenario: error chain design for new CLI commands"
-   or "Selected harness-engineer-beta via preferred_specialists.harness override").
-
-The Step-Level Specialist Modifier in each step skill defines the emphasis shift
-when working with a specialist at that step. Delegation is advisory at early steps
-(ideate, research) and authoritative at later steps (decompose, implement).
-
-## Preferred-specialist lookup (reference implementation)
-
-The preferred-specialists override is the first runtime consumer of the
-`preferred_specialists` XDG config field (previously write-only at install time).
+# Specialist Delegation Protocol (Driver→Engine)
+
+**Audience**: phase drivers. This document replaces the former operator→specialist
+framing. Operators do not delegate directly to engines — drivers do.
+
+Cross-reference: `skills/shared/layer-protocol.md` for layer boundaries and definitions.
+
+---
+
+## Why This Exists
+
+Engines run Furrow-unaware. They receive no row context, no step reference, no
+`.furrow/` paths. The **driver bears curation responsibility**: it must distil the
+relevant work context into a clean `EngineHandoff` (D1 schema) before dispatch.
+
+---
+
+## Composing an Engine Team at Dispatch
+
+One driver may dispatch **N engines in parallel** for a single deliverable. Team
+membership is decided **per-dispatch**, not per-plan. `plan.json`'s `specialist:` field
+is a hint — use it as a starting point but adapt to the work at hand.
+
+Composition guidelines:
+- **Solo engine**: one deliverable, single domain, self-contained — dispatch one engine.
+- **Parallel engines**: one deliverable spanning multiple domains (e.g., implementation + tests)
+  — dispatch parallel engines with disjoint `file_ownership`.
+- **Sequential engines**: deliverable where output of engine A feeds engine B — dispatch
+  serially, passing engine A's EOS-report as grounding to engine B.
+- **Team size**: prefer 1-3 engines per deliverable. Coordination cost rises with team size.
+
+---
+
+## Dispatch Primitive
+
+Build and dispatch an engine handoff:
 
 ```sh
-# In a selection context where $role is e.g. "harness", "test-engineer":
-#   PROJECT_ROOT and FURROW_ROOT must be exported (done by bin/frw and bin/rws).
-. "${FURROW_ROOT}/bin/frw.d/lib/common.sh"
-
-if override="$(resolve_config_value "preferred_specialists.${role}")"; then
-  specialist="$override"          # project/XDG/compiled-in override wins
-else
-  specialist="$default_for_role"  # fall back to scenario-matched default
-fi
+furrow handoff render \
+  --target engine:specialist:{id} \
+  --row <row-name> \
+  --step <step> \
+  [--write]
+```
+
+This renders an `EngineHandoff` markdown document. The driver provides the structured
+value (objective, deliverables, constraints, grounding) via stdin or args. D1's schema
+enforces that no `.furrow/` paths and no Furrow vocab appear in the output.
+
+Runtime spawn primitive receives the rendered markdown as the engine's input:
+- Claude: `Agent(subagent_type="engine:specialist:{id}", prompt=<rendered-handoff>)`
+- Pi: `pi-subagents spawn({name: "engine:{id}", systemPrompt: <specialist-brief>, tools: <allowlist>})`
+  then `pi-subagents sendMessage(handle, <rendered-handoff>)`
+
+---
+
+## Curation Checklist
+
+Before dispatching an engine, verify:
+
+- [ ] **Grounding paths** are source-tree relative (no `.furrow/` in any path).
+- [ ] **Constraints** use engine-scoped vocabulary — no `rws`, `alm`, `blocker`, `gate_policy`,
+  `deliverable`, `almanac`, `step`, `row`.
+- [ ] **Objective** is task-scoped, not row-scoped. No mention of Furrow row or step.
+- [ ] **Deliverables** enumerate `file_ownership` globs and `acceptance_criteria`.
+- [ ] **return_format** references a schema in `templates/handoffs/return-formats/`.
+
+If any check fails, revise the handoff before dispatch. Do not trust that schema
+validation alone will catch all curation errors — the schema enforces structure,
+not correctness.
+
+---
+
+## Return Contract
+
+Engines return an EOS-report per `templates/handoffs/return-formats/{step}.json`.
+The driver:
+
+1. Collects EOS-reports from all engines in the team.
+2. Assembles a per-deliverable rollup (merging findings, artifacts, open questions).
+3. Returns the phase result to the operator via runtime primitive
+   (Claude: `SendMessage` to operator lead; Pi: agent return value).
+
+The operator is responsible for presenting phase results to the user per
+`skills/shared/presentation-protocol.md` (D6). Drivers do NOT address the user.
+
+---
+
+## Driver Dispatches — Not the Operator
+
+```
+operator  ──spawn + prime──▶  driver
+                               driver  ──handoff──▶  engine(s)
+                               driver  ◀──EOS-report──
+operator  ◀──phase result──  driver
 ```
 
-Resolution order (first hit wins): project `.furrow/furrow.yaml` → XDG
-`${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml` → compiled-in
-`${FURROW_ROOT}/.furrow/furrow.yaml`. See
-`docs/architecture/config-resolution.md` for the full three-tier contract.
+The operator does not know which engines were dispatched, how many ran in parallel,
+or what their individual EOS-reports contained. It receives only the assembled phase
+result from the driver. This keeps operator context lean and engine details encapsulated.
diff --git a/skills/spec.md b/skills/spec.md
index e833ce1..94f7ddf 100644
--- a/skills/spec.md
+++ b/skills/spec.md
@@ -1,4 +1,8 @@
-# Step: Spec
+# Phase Driver Brief: Spec
+
+You are the spec phase driver. Your role is to run the spec step ceremony,
+dispatch per-deliverable spec-writer engines, and assemble the phase EOS-report
+for the operator. You do not address the user directly — that is the operator's responsibility.
 
 ## What This Step Does
 Define exactly what should be built in enough detail to implement.
@@ -12,85 +16,70 @@ Define exactly what should be built in enough detail to implement.
 ## Model Default
 model_default: sonnet
 
-## Step-Specific Rules
+## Step Ceremony
+
 - Every acceptance criterion from `definition.yaml` must be addressed.
 - Specs must be implementation-ready — no ambiguous requirements.
 - For each deliverable, produce test scenarios (WHEN/THEN + verification command)
   that supplement the ACs. Trivially testable ACs may omit scenarios.
   See `templates/spec.md` for the scenario format.
-- Ensure `skills/work-context.md` is loaded.
-- Read `summary.md` for plan context.
+- Load context bundle from operator prime message (includes plan decisions).
+
+## Engine Dispatch
+
+Dispatch per-deliverable spec-writer engines in parallel for multi-deliverable work.
+
+For each deliverable:
+1. Build engine handoff via `furrow handoff render --target engine:specialist:{id}`
+2. Grounding: plan decisions for this component, definition.yaml ACs, relevant research findings
+3. Exclude: other components' specs, plan trade-off discussions
+4. Engine returns: component spec with refined ACs and test scenarios
 
-### Step-Level Specialist Modifier
-When working with a specialist during spec, emphasize contract completeness,
-boundary definition, and constraint enumeration over implementation pragmatism.
-The specialist's reasoning patterns apply to specification decisions: what
-interfaces to define, what invariants to enforce, what edge cases to address.
+**Dispatch protocol**: `skills/shared/specialist-delegation.md`
 
 ## Collaboration Protocol
 
-Record decisions using `skills/shared/decision-format.md`. Don't assume — ask.
+Record decisions using `skills/shared/decision-format.md`. Return decisions to operator.
 
 **Decision categories** for spec:
 - **Acceptance criteria precision** — how specific is "enough" to implement and test
 - **Edge case coverage** — which edge cases matter vs which are out of scope
 - **Testability approach** — how to verify each criterion (unit, integration, manual)
 
-**High-value question examples** (ask these, not "does this look right?"):
-- "Is '{criterion}' specific enough to test, or should I tighten it to {more specific version}?"
-- "Should we cover {edge case}, or is it out of scope for this work?"
-- "How should we verify this — unit test, integration test, or manual check?"
-
 Mid-step iteration is expected; `step_status` remains `in_progress` throughout.
 
-## Agent Dispatch Metadata
-- **Dispatch pattern**: Parallel agents per component (multi-deliverable)
-- **Agent model**: sonnet (structured spec writing from plan decisions)
-- **Context to agent**: Plan decisions for this component, definition.yaml ACs, relevant research findings, specialist template (if assigned)
-- **Context excluded**: Other components' specs, plan trade-off discussions
-- **Returns**: Component spec with refined ACs and test scenarios
+## Dual-Reviewer Protocol
+
+Before returning phase result, dispatch both reviewers in parallel:
+1. **Fresh reviewer engine** — isolated context. Receives: spec.md or specs/ directory, definition.yaml.
+   Excludes: summary.md, conversation history, state.json.
+   Engine handoff via `furrow handoff render --target engine:specialist:reviewer`.
+2. **Cross-model reviewer** — `frw cross-model-review {name} --spec`
+   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
+Synthesize findings; address or explicitly reject all findings before returning phase result.
 
 ## Shared References
 Read these when relevant to your current action:
 - `skills/shared/red-flags.md` — before finalizing specs
 - `skills/shared/learnings-protocol.md` — when capturing learnings
-- `skills/shared/context-isolation.md` — when dispatching spec sub-agents
+- `skills/shared/specialist-delegation.md` — driver→engine dispatch protocol
+- `skills/shared/layer-protocol.md` — layer boundaries
 - `skills/shared/summary-protocol.md` — before completing step
-- `skills/shared/specialist-delegation.md` — specialist selection and delegation protocol
-
-## Team Planning
-For multi-deliverable work, dispatch spec sub-agents per component. Read `skills/shared/context-isolation.md`.
 
 ## Step Mechanics
 Transition out: gate record `spec->decompose` with outcome `pass` required.
 Pre-step shell check (`rws gate-check`): 1 deliverable, >=2 ACs, not supervised,
 not force-stopped.
-Pre-step evaluator (`evals/gates/spec.yaml`): testability — are ACs specific enough
-to implement without refinement? Per `skills/shared/gate-evaluator.md`.
 Next step expects: implementation-ready specs in `spec.md` or `specs/` with
 refined acceptance criteria per deliverable.
 
-## Dual-Reviewer Protocol
-Before requesting transition, run both reviewers in parallel:
-1. **Fresh Claude reviewer** — `claude -p --bare` with spec artifacts,
-   definition.yaml ACs, and `evals/dimensions/spec.yaml` dimensions.
-   Specialist template included if specialist was delegated during this step.
-   Receives: spec.md or specs/ directory, definition.yaml.
-   Excludes: summary.md, conversation history, state.json.
-2. **Cross-model reviewer** — `frw cross-model-review {name} --spec`
-   if `cross_model.provider` configured in `furrow.yaml`. Skip if absent.
-Synthesize findings: flag disagreements, note unique findings, record
-both sources in gate evidence. Address or explicitly reject all findings
-before requesting transition.
-
-## Supervised Transition Protocol
-Before requesting a step transition:
-1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
-2. Present work to user per `skills/shared/summary-protocol.md`.
-3. Ask explicitly: "**Ready to advance to decompose?** Yes / No"
-4. Wait for user response. Do NOT proceed without explicit approval.
-5. On "yes": call `rws transition <name> pass manual "<evidence summary>"`.
-6. On "no": ask what needs to change, address feedback, return to step 2.
+## EOS-Report Assembly
+
+Assemble phase EOS-report per `templates/handoffs/return-formats/spec.json`.
+Include: spec file paths, refined ACs per deliverable, reviewer findings,
+testability assessment, open questions.
+Return to operator via runtime primitive (Claude: `SendMessage` to operator lead;
+Pi: agent return value).
 
 ## Learnings
 When you discover a reusable insight (pattern, pitfall, preference, convention,
@@ -104,8 +93,5 @@ When `state.json.mode` is `"research"`:
   required evidence types (primary/secondary/quantitative/qualitative),
   minimum source count, and format (report/synthesis/recommendation/comparison).
 - Define cross-section consistency requirements.
-- Refine acceptance criteria into testable conditions with measurable
-  thresholds (counts, presence checks, citation requirements).
-- Avoid subjective language ("thorough", "comprehensive") without thresholds.
-- Review with `evals/dimensions/research-spec.yaml` dimensions.
+- Refine acceptance criteria into testable conditions with measurable thresholds.
 - Read `references/research-mode.md` for deliverable formats.
diff --git a/skills/work-context.md b/skills/work-context.md
index 7d1d6f9..2aad5d1 100644
--- a/skills/work-context.md
+++ b/skills/work-context.md
@@ -1,7 +1,14 @@
-# Work Context (Work Layer)
+# Work Context (Operator Layer)
 
-Loaded when a row is active. Provides task discovery, state conventions,
-and command entry points. Does NOT contain step-specific guidance.
+Loaded when a row is active. Provides the operator's per-row context: task
+discovery, state conventions, and command entry points.
+
+Per-step context is NOT loaded here. It is obtained at runtime via:
+```sh
+furrow context for-step <step> --target operator --row <row> --json
+```
+This delegates to D4's context-routing CLI, which filters skills by layer and
+assembles the structured bundle for the current step.
 
 ## Commands
 
@@ -34,6 +41,29 @@ All rows traverse all 7 steps. No steps are skipped. Pre-step evaluation
 may determine a step adds no information and record a `prechecked` gate, advancing
 without user input (unless `gate_policy: supervised`).
 
+## Operator Responsibilities
+
+The operator is the only layer that:
+- Addresses the user directly
+- Calls `rws`/`alm`/`sds` CLI commands
+- Reads and mutates row state
+- Spawns and primes phase drivers
+- Presents phase results per `skills/shared/presentation-protocol.md` (D6)
+- Requests step transitions after user approval
+
+See `skills/shared/layer-protocol.md` for the full 3-layer boundary contract.
+
+## Driver Dispatch
+
+For each step, the operator spawns a phase driver and primes it:
+
+1. Load driver context: `furrow context for-step <step> --target driver --json`
+2. Persist driver handoff: `furrow handoff render --target driver:{step} --write`
+3. Spawn driver (runtime-specific — see `commands/work.md` for Claude and Pi branches)
+4. Prime driver with context bundle via `message` primitive
+5. Receive phase result (EOS-report) from driver
+6. Present to user; request `rws transition`
+
 ## File Path Conventions
 
 | Element | Convention | Example |
@@ -45,6 +75,7 @@ without user input (unless `gate_policy: supervised`).
 | Spec files | `specs/{component}.md` | `specs/middleware-design.md` |
 | Review results | `reviews/{deliverable}.json` | `reviews/rate-limiter-middleware.json` |
 | Gate evidence | `gates/{from}-to-{to}.json` | `gates/plan-to-spec.json` |
+| Handoff artifacts | `handoffs/{step}-to-{target}.md` | `handoffs/plan-to-driver.md` |
 | Schema fields | snake_case | `step_status`, `created_at` |
 
 ## Write Ownership
@@ -56,19 +87,23 @@ without user input (unless `gate_policy: supervised`).
 | `plan.json` | Coordinator (write-once) | All agents, Furrow |
 | `summary.md` | Harness + step agent | Next step, reground |
 | `reviews/*.json` | Review agent | Harness, human |
+| `handoffs/*.md` | Furrow CLI (`--write`) | Drivers, engines |
 
 ## Core Files
 
 Every row has: `definition.yaml`, `state.json`, `summary.md`, `reviews/`.
-Conditional files created by steps: `plan.json`, `team-plan.md`, `research.md`,
-`spec.md`, `gates/`.
+Conditional files created by steps: `plan.json`, `research.md`,
+`spec.md`, `gates/`, `handoffs/`.
+
+Note: `team-plan.md` is retired. Engine teams are composed at dispatch-time
+by drivers, not at planning-time by the operator. See `skills/shared/layer-protocol.md`.
 
 ## Context Recovery
 
 After compaction or session break, read ONLY:
 - `state.json` (step, progress, gates)
 - `summary.md` (synthesized context)
-- Current step's skill (`skills/{step}.md`)
+- Reload operator bundle: `furrow context for-step <step> --target operator --json`
 
 NEVER re-read: raw research notes, previous handoff prompts, gate evidence, transcripts.
 
@@ -83,13 +118,12 @@ from the user, explore the codebase, design the approach for this step's work).
 Incorrect usage: plan mode produces artifacts that span or replace multiple
 Furrow steps (e.g., a single plan that covers spec + decompose + implement).
 
-Each Furrow step exists to produce a specific artifact with a specific gate.
-Plan mode helps you do the current step well. It does not skip steps.
-
 ## Step Skill Loading
 
-Each step has a skill at `skills/{step}.md`. Only the current step's skill is active.
-At step boundaries, the previous skill is replaced (not appended).
+Each step has a driver brief at `skills/{step}.md`. Only the current step's brief
+is injected into the driver's context. At step boundaries, the previous brief is
+replaced (not appended). The operator's per-step skill is filtered from the bundle
+by `--target operator`.
 
 ## Component Rationale
 
@@ -110,11 +144,6 @@ Step transitions produce gate records in `state.json.gates[]`:
 - `decided_by`: `manual` | `evaluated` | `prechecked`
 - Append-only — never modified after creation.
 
-Vocabulary:
-- `manual`: human reviewed and approved the gate
-- `evaluated`: isolated subagent evaluated, trust gradient auto-approved
-- `prechecked`: pre-step evaluation determined step not needed
-
 Gate evaluation flow:
 1. Phase A (deterministic, shell): `rws gate-check` checks structural criteria
 2. Phase B (judgment, isolated subagent): evaluator assesses quality dimensions from `evals/gates/{step}.yaml`
@@ -122,16 +151,11 @@ Gate evaluation flow:
 
 ## Trust Gradient
 
-`gate_policy` in `definition.yaml` controls human oversight of evaluator verdicts
-(not whether evaluation happens — evaluation always runs):
+`gate_policy` in `definition.yaml` controls human oversight of evaluator verdicts:
 - `supervised`: evaluator runs, verdict presented to human for approval (`decided_by: manual`)
-- `delegated`: evaluator verdict accepted for most gates (`decided_by: evaluated`); human reviews implement->review and review->archive (`decided_by: manual`)
+- `delegated`: evaluator verdict accepted for most gates (`decided_by: evaluated`)
 - `autonomous`: evaluator verdict accepted for all gates (`decided_by: evaluated`)
 
-Pre-step evaluation that determines a step is trivially skippable records `decided_by: prechecked`.
-
-Per-deliverable `gate` field overrides the top-level policy for that deliverable.
-
 ## Reference Documents
 
 Detailed protocols live in `references/` (NOT injected — read on demand):
@@ -141,6 +165,5 @@ Detailed protocols live in `references/` (NOT injected — read on demand):
 - `references/eval-dimensions.md` — dimension definitions
 - `references/specialist-template.md` — specialist format
 - `references/definition-shape.md` — complexity mapping
-- `references/deduplication-strategy.md` — context dedup rules
 - `references/research-mode.md` — research mode conventions
 - `references/row-layout.md` — directory layout conventions
diff --git a/tests/integration/test-driver-architecture.sh b/tests/integration/test-driver-architecture.sh
new file mode 100755
index 0000000..e5b5b8f
--- /dev/null
+++ b/tests/integration/test-driver-architecture.sh
@@ -0,0 +1,256 @@
+#!/bin/bash
+# test-driver-architecture.sh — Integration tests for D2 driver architecture.
+#
+# Tests the following ACs:
+#   AC1/AC2  — 7 driver YAMLs exist and match schema (structural check)
+#   AC3      — skills/shared/layer-protocol.md has required sections
+#   AC4      — skills/shared/specialist-delegation.md rewritten for driver→engine framing
+#   AC5      — all 7 step skills addressed to phase driver
+#   AC6      — team-plan.md creation prescriptions removed from skills/ and commands/
+#   AC7      — commands/work.md.tmpl renders for both runtimes (Claude + Pi blocks)
+#   AC8      — furrow render adapters --runtime=claude produces .claude/agents/ files
+#   AC12     — go build/vet/test pass
+
+set -euo pipefail
+
+# shellcheck source=helpers.sh
+. "$(dirname "$0")/helpers.sh"
+
+DRIVER_DIR="$PROJECT_ROOT/.furrow/drivers"
+SKILLS_DIR="$PROJECT_ROOT/skills"
+SCHEMAS_DIR="$PROJECT_ROOT/schemas"
+
+# Build the furrow binary once into a temp file for all render tests
+FURROW_BIN=""
+
+setup_furrow_bin() {
+  FURROW_BIN="$(mktemp)"
+  go build -o "$FURROW_BIN" "$PROJECT_ROOT/cmd/furrow" >/dev/null 2>&1
+}
+
+teardown_furrow_bin() {
+  if [ -n "$FURROW_BIN" ] && [ -f "$FURROW_BIN" ]; then
+    rm -f "$FURROW_BIN"
+  fi
+}
+
+# ---------------------------------------------------------------------------
+# AC1: 7 driver YAMLs exist
+# ---------------------------------------------------------------------------
+test_driver_yaml_count() {
+  local count
+  count=$(find "$DRIVER_DIR" -name "driver-*.yaml" | wc -l | tr -d ' ')
+  assert_ge "7 driver YAMLs exist" "$count" 7
+}
+
+# ---------------------------------------------------------------------------
+# AC1: each driver YAML has required fields
+# ---------------------------------------------------------------------------
+test_driver_yaml_schema() {
+  local steps="ideate research plan spec decompose implement review"
+  for step in $steps; do
+    local path="$DRIVER_DIR/driver-${step}.yaml"
+    assert_file_exists "driver-${step}.yaml exists" "$path"
+    assert_file_contains "driver-${step}.yaml has name field" "$path" "^name: driver:${step}"
+    assert_file_contains "driver-${step}.yaml has step field" "$path" "^step: ${step}"
+    assert_file_contains "driver-${step}.yaml has tools_allowlist" "$path" "^tools_allowlist:"
+    assert_file_contains "driver-${step}.yaml has model field" "$path" "^model:"
+  done
+}
+
+# ---------------------------------------------------------------------------
+# AC2: schema has additionalProperties: false and correct enum values
+# ---------------------------------------------------------------------------
+test_driver_schema_strictness() {
+  local schema="$SCHEMAS_DIR/driver-definition.schema.json"
+  assert_file_exists "driver-definition.schema.json exists" "$schema"
+  assert_file_contains "schema has additionalProperties: false" "$schema" '"additionalProperties": false'
+  assert_file_contains "schema has name pattern constraint" "$schema" '"pattern"'
+  local steps="ideate research plan spec decompose implement review"
+  for step in $steps; do
+    assert_file_contains "schema enumerates step '$step'" "$schema" "\"${step}\""
+  done
+}
+
+# ---------------------------------------------------------------------------
+# AC3: layer-protocol.md has required sections
+# ---------------------------------------------------------------------------
+test_layer_protocol_sections() {
+  local doc="$SKILLS_DIR/shared/layer-protocol.md"
+  assert_file_exists "layer-protocol.md exists" "$doc"
+  assert_file_contains "layer-protocol.md has ## Operator section" "$doc" "^## Operator"
+  assert_file_contains "layer-protocol.md has ## Phase Driver section" "$doc" "## Phase Driver"
+  assert_file_contains "layer-protocol.md has ## Engine section" "$doc" "^## Engine"
+  assert_file_contains "layer-protocol.md has ## Handoff Exchange section" "$doc" "## Handoff Exchange"
+  assert_file_contains "layer-protocol.md has ## Engine-Team-Composed-at-Dispatch section" "$doc" "## Engine-Team-Composed-at-Dispatch"
+}
+
+# ---------------------------------------------------------------------------
+# AC4: specialist-delegation.md rewritten for driver→engine framing
+# ---------------------------------------------------------------------------
+test_specialist_delegation_rewritten() {
+  local doc="$SKILLS_DIR/shared/specialist-delegation.md"
+  assert_file_exists "specialist-delegation.md exists" "$doc"
+  assert_file_not_contains "specialist-delegation.md no longer has 'operator dispatches'" "$doc" "operator dispatches"
+  assert_file_contains "specialist-delegation.md references driver" "$doc" "driver"
+  assert_file_contains "specialist-delegation.md references engine" "$doc" "engine"
+  assert_file_contains "specialist-delegation.md references dispatch primitive" "$doc" "furrow handoff render"
+}
+
+# ---------------------------------------------------------------------------
+# AC5: all 7 step skills addressed to phase driver
+# ---------------------------------------------------------------------------
+test_step_skills_addressed_to_driver() {
+  local steps="ideate research plan spec decompose implement review"
+  for step in $steps; do
+    local path="$SKILLS_DIR/${step}.md"
+    assert_file_exists "${step}.md exists" "$path"
+    assert_file_contains "${step}.md contains 'phase driver'" "$path" "phase driver"
+  done
+}
+
+# ---------------------------------------------------------------------------
+# AC6: team-plan.md creation prescriptions removed
+# AC7 (plan.md): plan.md does not prescribe creating team-plan.md
+# ---------------------------------------------------------------------------
+test_team_plan_md_dropped_from_plan() {
+  local path="$SKILLS_DIR/plan.md"
+  assert_file_not_contains "plan.md does not prescribe creating team-plan.md" "$path" "create.*team-plan"
+  # plan.md should note team-plan.md is retired
+  assert_file_contains "plan.md notes team-plan.md is retired" "$path" "retired"
+}
+
+test_team_plan_md_dropped_from_decompose() {
+  local path="$SKILLS_DIR/decompose.md"
+  assert_file_not_contains "decompose.md does not prescribe creating team-plan.md" "$path" "create.*team-plan"
+  assert_file_contains "decompose.md notes team-plan.md is retired" "$path" "retired"
+}
+
+# ---------------------------------------------------------------------------
+# AC8: commands/work.md.tmpl has runtime branches
+# ---------------------------------------------------------------------------
+test_work_tmpl_has_runtime_branches() {
+  local tmpl="$PROJECT_ROOT/commands/work.md.tmpl"
+  assert_file_exists "commands/work.md.tmpl exists" "$tmpl"
+  assert_file_contains "work.md.tmpl has Claude runtime branch" "$tmpl" 'eq .Runtime "claude"'
+  assert_file_contains "work.md.tmpl has Pi runtime branch" "$tmpl" '"pi"'
+  assert_file_contains "work.md.tmpl references pi-subagents in Pi block" "$tmpl" "pi-subagents"
+  assert_file_contains "work.md.tmpl references Agent() in Claude block" "$tmpl" "Agent("
+}
+
+# ---------------------------------------------------------------------------
+# AC9: furrow render adapters --runtime=claude produces manifested output
+# ---------------------------------------------------------------------------
+test_render_adapters_claude() {
+  if [ -z "$FURROW_BIN" ]; then
+    setup_furrow_bin
+    trap teardown_furrow_bin EXIT
+  fi
+
+  local output
+  output=$("$FURROW_BIN" render adapters --runtime=claude --project-dir="$PROJECT_ROOT" 2>&1)
+  assert_output_contains "Claude render output includes driver-ideate.md" "$output" "driver-ideate.md"
+  assert_output_contains "Claude render output includes driver-research.md" "$output" "driver-research.md"
+  assert_output_contains "Claude render output includes driver-implement.md" "$output" "driver-implement.md"
+  assert_output_contains "Claude render output includes driver-review.md" "$output" "driver-review.md"
+  assert_output_contains "Claude render output has name frontmatter" "$output" '"driver:'
+  assert_output_contains "Claude render output has model frontmatter" "$output" 'model:'
+  assert_output_contains "Claude render work.md has Agent() call" "$output" "Agent("
+}
+
+# ---------------------------------------------------------------------------
+# AC9: furrow render adapters --runtime=pi produces pi work.md (no agents/)
+# ---------------------------------------------------------------------------
+test_render_adapters_pi() {
+  if [ -z "$FURROW_BIN" ]; then
+    setup_furrow_bin
+    trap teardown_furrow_bin EXIT
+  fi
+
+  local output
+  output=$("$FURROW_BIN" render adapters --runtime=pi --project-dir="$PROJECT_ROOT" 2>&1)
+  assert_output_contains "Pi render work.md has pi-subagents reference" "$output" "pi-subagents"
+  assert_file_not_contains "Pi render has no .claude/agents/ paths in output" <(echo "$output") ".claude/agents/"
+}
+
+# ---------------------------------------------------------------------------
+# Model defaults per spec
+# ---------------------------------------------------------------------------
+test_driver_model_defaults() {
+  assert_file_contains "driver-research.yaml uses opus" "$DRIVER_DIR/driver-research.yaml" "^model: opus"
+  local sonnet_steps="ideate plan spec decompose implement review"
+  for step in $sonnet_steps; do
+    assert_file_contains "driver-${step}.yaml uses sonnet" "$DRIVER_DIR/driver-${step}.yaml" "^model: sonnet"
+  done
+}
+
+# ---------------------------------------------------------------------------
+# implement driver has Edit and Write tools
+# ---------------------------------------------------------------------------
+test_implement_driver_tools() {
+  local path="$DRIVER_DIR/driver-implement.yaml"
+  assert_file_contains "driver-implement.yaml has Edit tool" "$path" "Edit"
+  assert_file_contains "driver-implement.yaml has Write tool" "$path" "Write"
+}
+
+# ---------------------------------------------------------------------------
+# Pi extension: exists and documents recursive-spawn verdict
+# ---------------------------------------------------------------------------
+test_pi_extension_exists() {
+  local ext="$PROJECT_ROOT/adapters/pi/extension/index.ts"
+  assert_file_exists "adapters/pi/extension/index.ts exists" "$ext"
+  assert_file_contains "extension documents FALLBACK_NEEDED verdict" "$ext" "FALLBACK_NEEDED"
+  assert_file_contains "extension documents EXCLUDED_TOOL_NAMES finding" "$ext" "EXCLUDED_TOOL_NAMES"
+  assert_file_contains "extension has before_agent_start hook" "$ext" "before_agent_start"
+  assert_file_contains "extension has tool_call hook" "$ext" "tool_call"
+}
+
+# ---------------------------------------------------------------------------
+# AC12: go build + go vet + go test pass
+# ---------------------------------------------------------------------------
+test_go_toolchain() {
+  local build_out
+  if build_out=$(go build ./... 2>&1); then
+    assert_not_empty "go build succeeded" "ok"
+  else
+    assert_not_empty "go build FAILED: $build_out" ""
+  fi
+
+  local vet_out
+  if vet_out=$(go vet ./... 2>&1); then
+    assert_not_empty "go vet succeeded" "ok"
+  else
+    assert_not_empty "go vet FAILED: $vet_out" ""
+  fi
+
+  local test_out
+  if test_out=$(go test ./... 2>&1); then
+    assert_not_empty "go test ./... succeeded" "ok"
+  else
+    assert_not_empty "go test ./... FAILED: $test_out" ""
+  fi
+}
+
+# ---------------------------------------------------------------------------
+# Run all tests
+# ---------------------------------------------------------------------------
+setup_furrow_bin
+trap teardown_furrow_bin EXIT
+
+run_test test_driver_yaml_count
+run_test test_driver_yaml_schema
+run_test test_driver_schema_strictness
+run_test test_layer_protocol_sections
+run_test test_specialist_delegation_rewritten
+run_test test_step_skills_addressed_to_driver
+run_test test_team_plan_md_dropped_from_plan
+run_test test_team_plan_md_dropped_from_decompose
+run_test test_work_tmpl_has_runtime_branches
+run_test test_render_adapters_claude
+run_test test_render_adapters_pi
+run_test test_driver_model_defaults
+run_test test_implement_driver_tools
+run_test test_pi_extension_exists
+run_test test_go_toolchain
+
+print_summary

commit 89aed6b4ab6f80c34d115db18c821d0b30c27c72
Author: Test <test@test.com>
Date:   Sat Apr 25 20:36:19 2026 -0400

    feat(context): add D4 context-routing CLI implementing D5 contracts (7 strategies + Builder/Chain + bundle schema)
    
    Ships the complete `furrow context for-step` primitive:
    - Builder/Chain/Registry: concrete BundleBuilder, 3-node chain (Defaults→Artifact→TargetFilter), strategy registry with init()-based registration
    - 7 strategies (ideate/research/plan/spec/decompose/implement/review): one file per step, each self-registers via init(), each passes D5 conformance harness
    - FileContextSource: reads state.json, summary.md (section parser), learnings.jsonl, skills/ (layer: front-matter extraction), references/
    - Decisions extractor: settledRe + fallbackRe, de-dup last-wins preserving first-occurrence ordinal
    - Cache: sha256 content-addressed, mtime invalidation (state.json coarse + per-input fine), atomic temp-rename writes
    - cmd.go: `furrow context for-step <step> --row --target --json --no-cache` (exit 0/2/3); skill_layer_unset blocker; specialist brief validation
    - app.go: registers `context` command group + blank-imports strategies package
    - schemas/context-bundle.schema.json: additionalProperties:false at every level
    - tests/integration/test-context-routing.sh: 10 assertions covering AC §1-§13
    - commands/work.md.tmpl: initial stub demonstrating shell-out pattern (D2 will overlay)
    - .furrow/rows/context-routing-test-fixture/: minimal fixture row for integration tests
    
    go test ./... passes; D5 conformance: 7/7 strategies; decisions: 7 from pre-write-validation-go-first fixture (plan->spec de-duped); cache round-trip verified.

diff --git a/commands/work.md.tmpl b/commands/work.md.tmpl
new file mode 100644
index 0000000..8dd3c17
--- /dev/null
+++ b/commands/work.md.tmpl
@@ -0,0 +1,77 @@
+# /work Command Template — Operator Skill Shell-Out Stub
+#
+# D4 (W3) — initial stub demonstrating the shell-out pattern.
+# D2 (W4) will overlay broader template structure and layered dispatch.
+# D3 (W5) will add the skill-layer-context wrapper.
+# D6 (W6) will add the presentation section.
+#
+# Variables available in this template:
+#   .Row    — row name (kebab-case)
+#   .Step   — current workflow step
+#   .Target — rendering target (operator|driver|engine|specialist:{id})
+
+# {{ .Row }} — {{ .Step }} step context
+
+## Context Loading
+
+This operator skill shells out to the context-routing CLI to obtain a
+fully-assembled, layer-filtered context bundle for the current step.
+
+Run the following command to load your context bundle:
+
+```sh
+furrow context for-step {{ .Step }} --target operator --json
+```
+
+The bundle's `skills[]` array supplies your driver brief, work-context, and any
+shared-layer skills. Render `prior_artifacts.summary_sections` for context recovery.
+
+## Bundle Shape
+
+The emitted bundle conforms to `schemas/context-bundle.schema.json`:
+
+```
+{
+  "row":    "{{ .Row }}",
+  "step":   "{{ .Step }}",
+  "target": "operator",
+  "skills": [{ "path": "...", "layer": "operator|shared", "content": "..." }],
+  "references": [{ "path": "..." }],
+  "prior_artifacts": {
+    "state": { ... },
+    "summary_sections": { "<heading>": "<content>" },
+    "gate_evidence": { "gates": [...] },
+    "learnings": [{ "id": "...", "body": "...", "broadly_applicable": true|false }]
+  },
+  "decisions": [{ "source": "settled_decisions", "from_step": "...", "to_step": "...", "outcome": "pass|fail|unknown", "rationale": "...", "ordinal": 0 }],
+  "step_strategy_metadata": { ... }
+}
+```
+
+## Operator→Driver Dispatch
+
+When spawning or messaging a driver for this step, prime it with:
+
+```sh
+furrow context for-step {{ .Step }} --target driver --json
+```
+
+The driver consumes `skills[]` (layer:driver|shared) and `prior_artifacts`.
+
+## Driver→Engine/Specialist Dispatch
+
+When the driver dispatches a specialist engine:
+
+```sh
+furrow context for-step {{ .Step }} --target specialist:{id} --json
+```
+
+Replace `{id}` with the specialist identifier (e.g., `go-specialist`).
+The specialist brief at `specialists/{id}.md` must exist or the command exits 3
+with blocker code `context_input_missing`.
+
+## Caching
+
+The CLI caches bundles under `.furrow/cache/context-bundles/`. The cache
+invalidates automatically when `state.json` changes or any input file is
+modified. Pass `--no-cache` to bypass caching.
diff --git a/internal/cli/app.go b/internal/cli/app.go
index ccde9fb..510f8d8 100644
--- a/internal/cli/app.go
+++ b/internal/cli/app.go
@@ -7,7 +7,11 @@ import (
 	"io"
 	"strings"
 
+	ctx "github.com/jonathoneco/furrow/internal/cli/context"
 	"github.com/jonathoneco/furrow/internal/cli/handoff"
+
+	// Blank-import triggers init() registration of all 7 step strategies.
+	_ "github.com/jonathoneco/furrow/internal/cli/context/strategies"
 )
 
 const contractVersion = "v1alpha1"
@@ -69,6 +73,8 @@ func (a *App) Run(args []string) int {
 		return a.runStubGroup("furrow seeds", args[1:], []string{"create", "update", "show", "list", "close"})
 	case "validate":
 		return a.runValidate(args[1:])
+	case "context":
+		return a.runContext(args[1:])
 	case "handoff":
 		return a.runHandoff(args[1:])
 	case "merge":
@@ -152,6 +158,11 @@ func (a *App) runInit(args []string) int {
 	return a.fail("furrow init", &cliError{exit: 4, code: "not_implemented", message: "init is not implemented in the Go CLI draft yet", details: details}, flags.json)
 }
 
+func (a *App) runContext(args []string) int {
+	h := ctx.New(a.stdout, a.stderr)
+	return h.Run(args)
+}
+
 func (a *App) runHandoff(args []string) int {
 	h := handoff.New(a.stdout, a.stderr)
 	return h.Run(args)
@@ -217,6 +228,7 @@ Commands:
   review    Review orchestration contract surface
   almanac   Planning and knowledge contract surface
   seeds     Seed/task primitive contract surface
+  context   Context bundle assembly (for-step)
   handoff   Handoff render and validate contract surface
   merge     Merge pipeline contract surface
   doctor    Environment and adapter readiness checks

commit 95a2b44d56d2a773072d7d20f564814953069834
Author: Test <test@test.com>
Date:   Sat Apr 25 20:21:37 2026 -0400

    feat(handoff): add D1 forked DriverHandoff/EngineHandoff schemas + render/validate commands
    
    Ships Wave 2 D1 of the orchestration-delegation-contract row:
    
    - schemas/handoff-driver.schema.json: JSON Schema draft 2020-12 for DriverHandoff (7 fields, Furrow-aware)
    - schemas/handoff-engine.schema.json: JSON Schema draft 2020-12 for EngineHandoff (6 fields, Furrow-unaware, .furrow/ and vocab rejection)
    - templates/handoff-driver.md.tmpl + templates/handoff-engine.md.tmpl: stable-section-order markdown templates
    - templates/handoffs/return-formats/: phase-eos-report.json + engine-eos-report.json return-format schemas
    - internal/cli/handoff/: schema.go (structs), vocab.go (FurrowVocabPattern single source), render.go (RenderDriver/RenderEngine), validate.go (ValidateFile/ValidateDriverJSON/ValidateEngineJSON), cmd.go (furrow handoff render|validate)
    - internal/cli/handoff/handoff_test.go: table-driven coverage for all 12 ACs
    - internal/cli/handoff/vocab_test.go: 25-pass benign + 25-fail Furrow-laden corpus
    - internal/cli/app.go: additive 'handoff' case registration
    - schemas/blocker-taxonomy.yaml: appended 3 handoff codes (handoff_schema_invalid, handoff_required_field_missing, handoff_unknown_field)

diff --git a/internal/cli/app.go b/internal/cli/app.go
index 81deb2a..ccde9fb 100644
--- a/internal/cli/app.go
+++ b/internal/cli/app.go
@@ -6,6 +6,8 @@ import (
 	"fmt"
 	"io"
 	"strings"
+
+	"github.com/jonathoneco/furrow/internal/cli/handoff"
 )
 
 const contractVersion = "v1alpha1"
@@ -67,6 +69,8 @@ func (a *App) Run(args []string) int {
 		return a.runStubGroup("furrow seeds", args[1:], []string{"create", "update", "show", "list", "close"})
 	case "validate":
 		return a.runValidate(args[1:])
+	case "handoff":
+		return a.runHandoff(args[1:])
 	case "merge":
 		return a.runStubGroup("furrow merge", args[1:], []string{"plan", "run", "validate"})
 	case "doctor":
@@ -148,6 +152,11 @@ func (a *App) runInit(args []string) int {
 	return a.fail("furrow init", &cliError{exit: 4, code: "not_implemented", message: "init is not implemented in the Go CLI draft yet", details: details}, flags.json)
 }
 
+func (a *App) runHandoff(args []string) int {
+	h := handoff.New(a.stdout, a.stderr)
+	return h.Run(args)
+}
+
 func (a *App) runStubGroup(command string, args []string, children []string) int {
 	if len(args) == 0 {
 		_, _ = fmt.Fprintf(a.stdout, "%s\n\nAvailable subcommands: %s\n", command, strings.Join(children, ", "))
@@ -208,6 +217,7 @@ Commands:
   review    Review orchestration contract surface
   almanac   Planning and knowledge contract surface
   seeds     Seed/task primitive contract surface
+  handoff   Handoff render and validate contract surface
   merge     Merge pipeline contract surface
   doctor    Environment and adapter readiness checks
   init      Repo bootstrap and migration entrypoint
```

## Instructions

For each dimension, provide: verdict (pass/fail) and one-line evidence.

Output as JSON: {"dimensions": [{"name": "...", "verdict": "...", "evidence": "..."}], "overall": "pass|fail"}
