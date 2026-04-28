# Pi Dogfood Walkthrough Plan

A concrete, runnable walkthrough to confirm what's shipped end-to-end vs. what
is code-shaped vaporware. Default verdict before evidence: **NEEDS WORK**.

Read this top-to-bottom before executing. Sections are ordered by dependency:
if STEP 0 fails, everything below is moot.

## Conventions

- Working directory for every command: `/home/jonco/src/furrow`.
- "Furrow root" = a directory containing a `.furrow/` directory.
- All Pi commands assume the canonical extension entrypoint:
  `adapters/pi/furrow.ts` (re-exported by `.pi/extensions/furrow.ts`).
- All backend invocations are `go run ./cmd/furrow ...` per
  `adapters/pi/README.md` lines 19-24.

## Verdict rubric (apply per section)

| Verdict | Meaning |
| --- | --- |
| **WORKS** | Command runs, produces expected envelope/output, observable side effects match docs. |
| **PARTIAL** | Command runs but output is degraded (missing field, stub data, warning the docstring did not mention) OR side effect is observable but not enforced for every layer the brief implies. |
| **VAPORWARE** | Entry point missing/broken, command not implemented, or hook claimed to fire never actually intercepts. |

Record verdict, command, and the literal first ~20 lines of stdout/stderr in
the walkthrough log. Do not auto-fix anything found broken in this pass.

---

## STEP 0 — Confirm prerequisites and entrypoint exist

Before any walkthrough runs, the harness must be loadable. **If any check
below fails, STOP. Everything else in this document is moot until STEP 0 is
green.**

### Pre-flight risks already detected (before walkthrough begins)

The following were inspected during plan authoring against the live tree:

1. **Pi binary** — installed at `/home/jonco/.local/share/mise/installs/node/24.11.1/bin/pi`, version `0.70.2`. ✓
2. **Bun** — installed at `/home/jonco/.local/share/mise/installs/bun/1.3.11/bin/bun`, version `1.3.11`. ✓
3. **Go** — installed at `/home/jonco/.local/share/mise/installs/go/1.25.4/bin/go`, version `1.25.4`. ✓
4. **`adapters/pi/node_modules/`** — DOES NOT EXIST. The peer dep
   `@mariozechner/pi-coding-agent` and main dep `@tintinweb/pi-subagents` are
   un-installed. `bun test` and `bun typecheck` will fail until `bun install`
   runs. **First action of the walkthrough.**
5. **Hook-coverage gap (HIGH-PRIORITY VAPORWARE RISK)** — the brief lists six
   hooks to verify in Pi (state-guard, validate-definition, ownership-warn,
   layer-guard, correction-limit, presentation-check). Reading
   `adapters/pi/furrow.ts` (the file Pi actually loads) shows only **three**
   `tool_call` handlers wired:
   - state-guard at lines 911-927
   - validate-definition at lines 933-946
   - ownership-warn at lines 952-965

   The other three are NOT wired into the canonical Pi extension:
   - **layer-guard** is implemented at `adapters/pi/extension/index.ts`
     (`FurrowPiAdapter.onToolCall`), but that file is a factory module and is
     not loaded by `.pi/extensions/furrow.ts` (which re-exports
     `adapters/pi/furrow.ts` only). In Pi today, layer-guard is dead code.
   - **correction-limit** has no `pi.on("tool_call", ...)` handler in
     `adapters/pi/furrow.ts`.
   - **presentation-check** is a Stop-hook concern; Pi has no equivalent
     lifecycle hook wired in `furrow.ts`.

   Section 3 below splits hook verification into "wired in Pi" (will get a
   real verdict) and "absent in Pi" (auto-VAPORWARE for Pi; verify via Claude
   adapter or via direct CLI invocation only).

6. **Layer-guard IS active in *this Claude Code session*** (independent
   evidence, not Pi). During plan authoring, `Bash` calls containing
   `.furrow/` as a substring were blocked by `furrow hook layer-guard`. My
   `agent_type` is unknown to `.furrow/layer-policy.yaml` so it falls through
   to the `engine` layer, whose `bash_deny_substrings` includes `.furrow/`.
   This proves the Go hook works; it does NOT prove it is wired into Pi.

### STEP 0 commands

```sh
# 0.1  Verify tool versions
pi --version                                # expect ≥ 0.70.x
bun --version                               # expect ≥ 1.3.x
go version                                  # expect ≥ 1.21
which pi bun go

# 0.2  Confirm canonical Pi extension is reachable
ls -la adapters/pi/furrow.ts                # expected file
cat .pi/extensions/furrow.ts                # expected re-export shim
grep -n "registerCommand" adapters/pi/furrow.ts | head -10
# Expect 5 commands: work, furrow-overview, furrow-next, furrow-complete,
# furrow-transition.

# 0.3  Install Pi adapter dependencies (FIRST WRITE OF THE WALKTHROUGH)
cd adapters/pi && bun install && cd ../..

# 0.4  Run the unit tests for the wired Pi handlers
cd adapters/pi && bun test && cd ../..
# Expected: furrow.test.ts and dispatch.test.ts pass.

# 0.5  Confirm backend is buildable (the Pi adapter shells out to it)
go run ./cmd/furrow --help

# 0.6  Smoke-launch Pi with the adapter, headless, no session, no UI
pi --no-extensions -e ./adapters/pi/furrow.ts --no-session -p "/furrow-overview"
# Expected: a "Furrow overview" block listing active rows from .furrow/rows/.
# If output is "No .furrow root found" — STOP. Pi is not seeing the project.
```

**Verdict gate**: every 0.x command must succeed before continuing.

**Where to look for evidence**:
- 0.1–0.2: stdout
- 0.3: `adapters/pi/node_modules/` exists, `bun.lockb` updated
- 0.4: bun test summary
- 0.5: subcommand listing including `row`, `validate`, `hook`, `context`, `handoff`, `doctor`
- 0.6: `[furrow]` rendered banner + "Active rows" section

---

## SECTION 1 — Pi install & startup with the Furrow adapter loaded

**What we expect**: launching `pi` from the repo root finds `.pi/extensions/furrow.ts`, loads `adapters/pi/furrow.ts`, registers the five slash commands, registers three `tool_call` handlers, and (if launched with UI) sets a `furrow:<row> <step>/<status>` status line via `refreshStatus`.

**Exact commands**:

```sh
# 1.1 Headless one-shot — proves the adapter parses, registers commands, and
#     reaches the Go backend.
pi --no-extensions -e ./adapters/pi/furrow.ts --no-session -p "/furrow-overview"

# 1.2 Same but verbose — confirm the canonical envelope is being parsed.
pi --no-extensions -e ./adapters/pi/furrow.ts --no-session -p "/furrow-next"
# Expected: "Furrow next" block with Row, Step, Blockers, Seed, Current-step
# artifacts, Checkpoint, and Recommended next action sections (see formatNextGuidance).

# 1.3 Auto-discovery path — proves the .pi/extensions/furrow.ts shim re-exports.
pi --no-session -p "/furrow-overview"
# Expected: identical output to 1.1.

# 1.4 Interactive launch (visual confirmation that status line wires up)
pi
#   In the TUI: type `/furrow-next` → expect the same block; status line shows
#   "furrow:<row> <step>/<status>" colored accent or warning depending on blockers.
```

**Where to look for evidence**:
- Stdout includes the `[furrow]` accented prefix from `registerMessageRenderer` (line 899-905).
- Each command output starts with the literal title strings `Furrow overview`, `Furrow next`, etc.
- If launched without `--no-session`, Pi's status bar shows `furrow:<name> <step>/<status>` (set by `ctx.ui.setStatus("furrow", ...)` at line 892).

**Rubric application**:
- WORKS = 1.1, 1.2, 1.3 all return the expected sections; 1.4 shows status bar.
- PARTIAL = commands run but output sections missing (e.g., empty `Blockers:` rendered as `- none` is fine; missing entire section is not).
- VAPORWARE = `No .furrow root found` from any of these despite running from repo root, OR `pi` exits non-zero, OR commands not registered.

---

## SECTION 2 — Row lifecycle (7 steps, fresh row)

**What we expect**: a fresh row named `dogfood-walkthrough` can be created, advanced through all 7 steps (`ideate → research → plan → spec → decompose → implement → review`), and archived. At each transition, the backend writes `state.json`, advertises `next_valid_transitions`, and Pi surfaces the supervised-checkpoint confirmation when `step_status: completed` plus a checkpoint exists.

**Note**: `KNOWN_STEPS` in `furrow.ts:12` enforces the canonical 7-step sequence client-side; the Go row workflow enforces it server-side (`internal/cli/row_workflow.go`).

**Exact commands**:

```sh
# 2.0 Snapshot existing rows so we don't conflate the test row with real work
go run ./cmd/furrow row list --json > /tmp/rows-before.json
jq '.data.summary' /tmp/rows-before.json

# 2.1 Create + focus the test row via the /work command (Pi path).
pi --no-extensions -e ./adapters/pi/furrow.ts --no-session \
  -p "/work dogfood walkthrough confirm pi works end to end"
# Expected: row name slug "dogfood-walkthrough-confirm-pi-works-end-to-end"
# (slugifyDescription truncates to 40 chars). Use --row in step 2.2 onward.

# 2.2 Read status directly via backend (cross-check the Pi envelope shape).
go run ./cmd/furrow row status dogfood-walkthrough-confirm-pi-works-end-to-en --json | jq '.data.row | {name,step,step_status,next_valid_transitions}'

# 2.3 Walk all 7 transitions. For each step, run /work --complete then
#     /furrow-transition --confirm.
for step in research plan spec decompose implement review; do
  echo "=== complete current step ==="
  pi --no-extensions -e ./adapters/pi/furrow.ts --no-session \
    -p "/work --complete --switch dogfood-walkthrough-confirm-pi-works-end-to-en"
  echo "=== transition to $step ==="
  pi --no-extensions -e ./adapters/pi/furrow.ts --no-session \
    -p "/furrow-transition dogfood-walkthrough-confirm-pi-works-end-to-en --step $step --confirm"
done

# 2.4 Inspect state after each transition (compare to advertised next_valid).
go run ./cmd/furrow row status dogfood-walkthrough-confirm-pi-works-end-to-en --json | jq '.data.row.gates.transition_history'

# 2.5 Final archive checkpoint
pi --no-extensions -e ./adapters/pi/furrow.ts --no-session \
  -p "/work --switch dogfood-walkthrough-confirm-pi-works-end-to-en --confirm"
# When checkpoint.action == "archive", --confirm should trigger row archive
# (see furrow.ts lines 1192-1206).
```

**Where to look for evidence**:
- `.furrow/rows/dogfood-walkthrough-…/state.json` — `step` field updates after each transition.
- `gates.transition_history` array in row status grows by one entry per transition.
- `current_step.artifacts` differs by step (definition.yaml at ideate, plan.md at plan, etc.).
- Final archive: `archived: true`, `archived_at` populated.

**Rubric application**:
- WORKS = all 7 transitions succeed, `transition_history` length = 7, archive succeeds.
- PARTIAL = transitions advance but artifacts not scaffolded (missing `current_step.artifacts` for some step), OR archive ceremony evidence (`archive_ceremony.review`, `learnings`) absent.
- VAPORWARE = transition rejected for a step that the brief lists as supported, OR `next_valid_transitions` is empty mid-flow.

---

## SECTION 3 — Hook enforcement

The brief lists six hooks. Three are wired into Pi; three are not. Verify each
class separately and **do not record a Pi WORKS for a hook that has no Pi
handler** — that would be vaporware certification.

### 3A — Hooks wired in `adapters/pi/furrow.ts` (real Pi verdict)

#### 3A.1 state-guard (lines 911-927)

**Trigger**: any `Edit`/`Write` to `.furrow/.focused` or `.furrow/rows/*/state.json`.

```sh
# Run from inside Pi (interactive) or via a -p prompt that triggers a tool call.
# Easiest reproducible: have Pi write to .furrow/rows/<row>/state.json via a /file
# tool. Alternatively, a manual write outside Pi DOES NOT exercise the Pi handler.
pi --no-extensions -e ./adapters/pi/furrow.ts \
  -p "Use the write tool to write '{}' to .furrow/rows/dogfood-walkthrough-confirm-pi-works-end-to-en/state.json"
```

Expected: Pi blocks the tool call with reason starting "Canonical Furrow state is backend-mediated…" (line 925-926).

#### 3A.2 validate-definition (lines 933-946)

```sh
# Provoke an invalid definition.yaml write.
pi --no-extensions -e ./adapters/pi/furrow.ts \
  -p "Use the write tool to write 'name: bogus\nsteps: not-a-list' to .furrow/rows/dogfood-walkthrough-confirm-pi-works-end-to-en/definition.yaml"
```

Expected: pre-write handler shells out to `furrow validate definition --path … --json`, receives `verdict: invalid`, blocks with the validator's `errors[].message` joined by `; ` (line 47-53 in `validate-actions.ts`).

#### 3A.3 ownership-warn (lines 952-965)

```sh
# Write to a path outside any deliverable's file_ownership in the active row.
pi --no-extensions -e ./adapters/pi/furrow.ts \
  -p "Use the write tool to write 'x' to /tmp/ownership-out-of-scope.txt"
```

Expected (UI): `ctx.ui.confirm` prompt asking permission. If declined, blocks with the validator's envelope message. If no UI (`--no-session -p ...`), `decideOwnershipAction` degrades to silent allow (`{block:false}`) per `validate-actions.ts:118-119` — **document this as PARTIAL by design**, not vaporware.

### 3B — Hooks NOT wired in `adapters/pi/furrow.ts` (auto-VAPORWARE for Pi)

These three are absent from the Pi extension Pi actually loads. For each, do
two things: (a) record VAPORWARE for the Pi runtime; (b) verify the Go hook
exists and works via direct CLI invocation, since the same binary is
cross-adapter.

#### 3B.1 layer-guard

Pi-runtime status: VAPORWARE (the wired implementation lives in
`adapters/pi/extension/index.ts` `FurrowPiAdapter.onToolCall`, but
`.pi/extensions/furrow.ts` does not import that module).

Direct binary check:

```sh
# Engine layer should be denied a `furrow ...` Bash invocation.
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"furrow row list"},"agent_id":"a","agent_type":"engine:freeform"}' \
  | go run ./cmd/furrow hook layer-guard
echo "exit=$?"
# Expected: exit 2, JSON stdout '{"block":true,"reason":"layer_tool_violation: Bash in layer engine: ..."}'
```

#### 3B.2 correction-limit

Pi-runtime status: VAPORWARE. No `pi.on("tool_call", ...)` handler in
`furrow.ts` references the correction-limit logic in
`internal/cli/correction_limit.go`.

Direct binary check (only if a `furrow hook correction-limit` subcommand
exists — verify with `go run ./cmd/furrow hook --help`). If the subcommand is
absent, the correction limit is enforced only inside the Go row workflow, not
as a host-side write blocker. Record this as a documentation gap.

#### 3B.3 presentation-check

Pi-runtime status: VAPORWARE. This is a Stop-hook concept (Claude PostToolUse/Stop). Pi's lifecycle does not include an equivalent hook in `furrow.ts`.

Direct binary check (mirror 3B.2): `go run ./cmd/furrow hook --help` to confirm presentation-check is a registered subcommand, then drive it via stdin payload per `internal/cli/hook/presentation_check.go` test fixtures.

### 3 — Verdict

For each of the six hooks, the result is one of:
- 3A.* — record WORKS / PARTIAL / VAPORWARE based on actual Pi behavior.
- 3B.* — Pi-runtime verdict is fixed at VAPORWARE; record a separate
  verdict for the Go binary itself.

---

## SECTION 4 — Blocker taxonomy & canonical envelope

**What we expect**: every hook block above produces a six-field envelope per
`schemas/blocker-event.schema.json` and `schemas/blocker-taxonomy.yaml`. Pi
surfaces the canonical fields (`code`, `category`, `severity`, `message`,
`remediation_hint`, `confirmation_path`) without inventing prose.

**Exact commands**:

```sh
# 4.1 Validate the schema files load and parse.
go run ./cmd/furrow validate --help                  # confirm validate subcommand surface
jq '.required, .properties | keys' schemas/blocker-event.schema.json
jq '.required, .properties | keys' schemas/blocker-taxonomy.schema.json

# 4.2 Provoke 3-5 distinct blockers and capture envelopes.
# (a) state_json_direct_write (state-guard)
echo '{"hook_event_name":"PreToolUse","tool_name":"Write","tool_input":{"file_path":".furrow/rows/x/state.json"},"agent_id":"a","agent_type":"operator"}' \
  | go run ./cmd/furrow guard pre_write_state_json
# (b) layer_tool_violation (layer-guard, engine layer + furrow CLI)
echo '{"hook_event_name":"PreToolUse","tool_name":"Bash","tool_input":{"command":"furrow row list"},"agent_id":"a","agent_type":"engine:freeform"}' \
  | go run ./cmd/furrow hook layer-guard
# (c) definition_invalid_*  via the bad definition.yaml from 3A.2
echo '{"target_path":".furrow/rows/x/definition.yaml"}' \
  | go run ./cmd/furrow validate definition --path .furrow/rows/x/definition.yaml --json
# (d, e) Two more drawn from emitted_codes catalog in schemas/blocker-event.yaml.

# 4.3 For each captured envelope, jq-validate against the schema:
for f in /tmp/blocker-*.json; do
  jq -e 'has("code") and has("category") and has("severity") and has("message") and has("remediation_hint") and has("confirmation_path")' "$f" \
    || echo "FAIL: $f missing canonical fields"
done
```

**Where to look for evidence**: stdout JSON. Compare each envelope's `code`
field against the closed catalog in `schemas/blocker-event.yaml`
(`emitted_codes` per event_type) and `schemas/blocker-taxonomy.yaml`.

**Rubric application**:
- WORKS = ≥3 distinct codes captured, every envelope passes the six-field jq check, codes are in the taxonomy.
- PARTIAL = envelopes are returned but `remediation_hint` is empty for some codes, OR taxonomy lookup misses (code not in `schemas/blocker-taxonomy.yaml`).
- VAPORWARE = canonical envelope shape is not produced (e.g., plain string error instead of JSON).

---

## SECTION 5 — Context routing (`furrow context for-step`)

**What we expect**: `furrow context for-step <step>` produces a JSON context
bundle conforming to `schemas/context-bundle.schema.json`, suitable for an
agent (driver or engine) to ingest at handoff time.

**Exact commands**:

```sh
go run ./cmd/furrow context --help
go run ./cmd/furrow context for-step ideate --json | jq '.data | keys'
go run ./cmd/furrow context for-step plan   --json | jq '.data | keys'
go run ./cmd/furrow context for-step review --json | jq '.data | keys'

# Schema-validate against context-bundle.schema.json
go run ./cmd/furrow context for-step ideate --json | jq '.data' > /tmp/ctx.json
# (use a JSON Schema validator; jq alone can't enforce $ref chains)
```

**Where to look for evidence**: presence of fields enumerated in
`schemas/context-bundle.schema.json` (read it as part of this step). Pi
ingestion is verified separately under section 1; this section verifies the
producer.

**Rubric application**:
- WORKS = bundle returned for at least 3 different steps, all conform to schema.
- PARTIAL = bundle returned but missing optional fields advertised in schema, OR same bundle returned regardless of step argument.
- VAPORWARE = subcommand absent or returns non-JSON.

---

## SECTION 6 — Handoff schemas (`furrow handoff render`)

**What we expect**: `furrow handoff render` produces driver and/or engine
handoff documents conforming to `schemas/handoff-driver.schema.json` and
`schemas/handoff-engine.schema.json`.

```sh
go run ./cmd/furrow handoff --help
# Likely subcommand surface: handoff render driver|engine ...
go run ./cmd/furrow handoff render driver --step plan --json | jq 'keys'
go run ./cmd/furrow handoff render engine --specialist test-engineer --json | jq 'keys'
```

**Where to look for evidence**: top-level keys match the `required` arrays in
the two schema files. Sentinel-fields like `EngineHandoff` markdown wrapping
should be present per `adapters/pi/extension/index.ts:309-329` (engine
subprocess fallback expects markdown input).

**Rubric application**:
- WORKS = both driver and engine renders pass schema; markdown round-trips.
- PARTIAL = one of the two renders works but the other returns a stub.
- VAPORWARE = subcommand absent.

---

## SECTION 7 — Almanac & Roadmap CLIs (`alm`, `rws`, `sds`)

**What we expect**: the three repo-local CLIs in `bin/` can be invoked
directly (they are shell wrappers) and complement the Pi adapter. The Pi
adapter does NOT call them — it goes via `go run ./cmd/furrow` — so the goal
here is to confirm they exist and are runnable as a parallel surface.

```sh
bin/alm --help     ; bin/alm validate ; bin/alm list
bin/rws --help     ; bin/rws list     ; bin/rws status dogfood-walkthrough-confirm-pi-works-end-to-en
bin/sds --help     ; bin/sds list
```

**Where to look for evidence**: usage banners + JSON or text envelopes per
each CLI's contract. Cross-check `bin/rws status` envelope against the same
data Pi reads via `go run ./cmd/furrow row status` (sections 1.2 and 2.4).

**Rubric application**:
- WORKS = all three CLIs run and produce sensible output for their flagship subcommand.
- PARTIAL = one CLI produces a stub or "not implemented" path, OR `bin/rws status` and `furrow row status` disagree on the same row.
- VAPORWARE = CLI script missing/broken, or `--help` errors.

---

## Cleanup

```sh
# Optional: archive the test row to keep the active list clean.
go run ./cmd/furrow row archive dogfood-walkthrough-confirm-pi-works-end-to-en --json

# Or, if the walkthrough left a half-completed row, delete it manually:
# (no `furrow row delete` known — flag this as a missing CLI if you need it).
```

---

## Walkthrough log template

Keep findings in a sibling file `docs/dogfood/pi-walkthrough-log.md` (do NOT
write that file as part of planning — it gets created during execution).

```
## Section <n.x> — <title>
Verdict: WORKS | PARTIAL | VAPORWARE
Command:
$ <literal command>
Output (first ~20 lines):
<paste>
Notes:
- <observation>
```

## Open risks & instrumentation gaps surfaced during planning

1. The brief implies six hooks fire in Pi; only three do (Section 3B). Recommend a follow-up todo to either (a) wire layer-guard / correction-limit into `adapters/pi/furrow.ts` or (b) update the brief to reflect the Claude-only hooks honestly.
2. `validate-definition` and `ownership-warn` shell out via `go run ./cmd/furrow ...` per write — README notes ~45ms cold start, ~90ms compounded. The walkthrough should informally time these (e.g., `time pi -p ...` on definition writes) and record numbers; the existing almanac todo `pi-adapter-binary-caching` is the optimization fix.
3. Engine-layer Bash classification: my own session's `agent_type` ("pi-dogfood-guide") is not in `.furrow/layer-policy.yaml`, falling through to `engine`, which is why `.furrow/`-substring Bash is being blocked right now. This is independent confirmation that layer-guard works in *Claude*; it does not say anything about Pi. If we want layer-guard to fire in Pi, `extension/index.ts` must be loaded (currently it isn't).
4. The shim at `.pi/extensions/furrow.ts` re-exports `adapters/pi/furrow.ts` only. There is no path that auto-loads `adapters/pi/extension/index.ts`. Section 1 of the walkthrough should explicitly note this when reporting which handlers fired.
