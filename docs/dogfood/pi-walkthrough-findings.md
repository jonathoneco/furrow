# Pi Dogfood Walkthrough — Findings Log

Live log. Sections appear in execution order, not plan order. Each entry:
- **Verdict**: WORKS / PARTIAL / VAPORWARE
- **Evidence**: command + observed output (trimmed)
- **Disposition**: PATCHED here / DEFERRED to Phase 5 / NEW TODO filed / NOT-A-BUG

---

## STEP 0 — Prerequisites & entrypoint

### 0.1 Tool versions — WORKS
- pi 0.70.2, bun 1.3.11, go 1.25.4 all present.

### 0.2 Entrypoint reachable — WORKS
- `adapters/pi/furrow.ts` present (51 KB), `.pi/extensions/furrow.ts` shim re-exports.
- 5 `registerCommand` calls confirmed at lines 967, 1253, 1292, 1328, 1379.

### 0.3 bun install — WORKS
- 252 packages resolved in 3.66s. Pi peer deps + subagents installed.

### 0.4 bun test — WORKS
- 41 pass / 0 fail / 102 expect() calls across 2 files.
- furrow.test.ts: 37 pass, 90 expect()
- dispatch.test.ts: 4 pass (R5 shell-injection-safety regressions), 12 expect()
- test-driver-blocker-parity.ts is a test-driver, not a suite — run via tests/integration/test-blocker-parity.sh, deferred to Section 4.

### 0.5 backend buildable — WORKS
- `furrow help` returns full subcommand surface: row, gate, review, almanac, seeds, validate, context, handoff, render, hook, merge, doctor, guard, init.

### 0.6 Pi smoke launch — WORKS
- `pi --no-extensions -e ./adapters/pi/furrow.ts --no-session -p "/furrow-overview"`
- Returns formatted overview: Focused row=`pre-write-validation-go-first`, Total=49, Active=1, Archived=48.
- The Go backend is reached, envelope is parsed, `formatOverview` renders correctly.

---

## Section 1 — Pi install & startup with the Furrow adapter loaded

---

## Findings

### LG-1 — VAPORWARE → PATCHED: layer-guard fails closed when invoked from any non-root cwd

**Verdict**: VAPORWARE (security boundary fails closed in a hard-bricking
way). **Patched in this session.**

**Trigger**: persistent shell cwd ≠ repo root. After 0.3 ran
`cd adapters/pi && bun install`, my Bash cwd remained at `adapters/pi/`.
From that point, every Bash, Edit, Write, SendMessage, Agent, TaskUpdate
failed with `PreToolUse:Bash hook error: [furrow hook layer-guard]: No
stderr output` — including commands containing no deny substrings (`pwd`,
`echo test`, `true`).

**Root cause**: `internal/cli/app.go:225` constructed a cwd-relative policy
path (`filepath.Join(".furrow", "layer-policy.yaml")`). `layer.Load` then
called `os.ReadFile(policyPath)` — failed when cwd wasn't repo root.
`RunLayerGuard` emitted `block:true` with reason `layer_policy_invalid: ...`
and exited 2. Claude harness saw exit 2 + empty stderr → "No stderr output".

**Why it's worse than a bug**:
- `internal/cli/util.go:17` already provides `findFurrowRoot()` (walks up
  from cwd looking for `.furrow/`). app.go:225 just didn't use it.
- Pi's TypeScript adapter walks up correctly
  (`adapters/pi/furrow.ts:324`) — so the Pi side has been right; the Go
  hook driver was the regression.
- **Self-bricking**: once locked, Edit is also gated by the same hook,
  so I couldn't patch the file that would have fixed the brick. Required
  out-of-band recovery (team-lead patched + rebuilt from operator pane).

**Distinct from existing TODO `layer-guard-silent-rejection-on-top-layer-integrat`**:
that TODO tracks agent-type→engine fall-through (classification bug). LG-1
is policy-file-resolution. Both fail-close to engine, but the fixes are
independent.

**Patch landed** (uncommitted on main at the time of writing this entry):
- `internal/cli/app.go` runHook("layer-guard"): walk-up via
  `findFurrowRoot()`; env override (`FURROW_LAYER_POLICY_PATH`) still wins;
  legacy relative-path fallback retained for back-compat.
- Two regression tests in `internal/cli/app_test.go`:
  - `TestRunHook_LayerGuard_PolicyResolvesFromSubdirectory`
  - `TestRunHook_LayerGuard_PolicyPathEnvOverride`

**Verification**: `go test ./internal/cli/ -count=1` — all green.

### LG-2 — VAPORWARE: layer-guard verdict written to stdout, harness reads stderr

**Verdict**: VAPORWARE (debuggability gap that hid LG-1 root cause for
~30 minutes during the session).

**Surface**: `internal/cli/hook/layer_guard.go:40` `emit()` writes the
JSON verdict envelope `{block, reason}` to stdout. Claude Code's PreToolUse
hook protocol reads block reasons from stderr; stdout is treated as logs.
Result: when LG-1 fired, the harness surfaced only `[furrow hook
layer-guard]: No stderr output` — the actual `layer_policy_invalid: read
".furrow/layer-policy.yaml": no such file or directory` was on stdout
where the harness ignored it.

**Disposition**: NEW TODO needed — see draft below. Independent of LG-1
fix, would have made debugging LG-1 ~10x faster.

**Likely fix**: also write the reason to stderr (safe — harness already
parses stderr; adapters that read stdout JSON keep working). Confirm
against the canonical envelope contract (`schemas/blocker-event.schema.json`)
that adding a stderr line doesn't violate it; should be additive.

### LG-3 — VAPORWARE (architectural): hook chain self-bricking is unrecoverable

**Verdict**: VAPORWARE (class-level reliability gap).

**Surface**: when any PreToolUse hook fails-closed for any reason, ALL
subsequent PreToolUse hooks fail too (because they all use the same broken
gate path). This includes Edit — meaning the agent cannot patch the broken
component. Recovery requires out-of-band human intervention.

**Likely fix** (sketched by team-lead during unbrick): when the verdict
source is `policy-load-failure` (vs `policy-decision-block`), allow Edit on
specific recovery paths:
- `internal/cli/**`
- `schemas/**`
- `.furrow/layer-policy.yaml`

That's a more invasive change than LG-1/LG-2 — requires distinguishing
load-failure from decision-block in the verdict envelope, and threading a
"rescue allow" through the harness. Not blocking for Phase 5; file as a
follow-up TODO with `effort: medium` or `large`.

### Draft TODO entries (for team-lead to add to `.furrow/almanac/todos.yaml` — engine layer can't mutate harness state)

```yaml
- id: layer-guard-cwd-relative-policy-path-self-brick
  title: layer-guard policy-path resolution must be cwd-independent
  status: done       # patched in pi-dogfood-guide session 2026-04-28
  source_type: dogfood-finding
  urgency: high
  impact: high
  effort: small
  context: |
    `furrow hook layer-guard` resolved `.furrow/layer-policy.yaml`
    relative to the binary's cwd. When a tool call fired from any
    subdirectory of the repo (e.g., adapters/pi/ after `cd adapters/pi
    && bun install`), os.ReadFile errored, RunLayerGuard fail-closed,
    and every subsequent PreToolUse hook (Edit included) was blocked —
    self-bricking the agent session.
  files_touched:
    - internal/cli/app.go
    - internal/cli/app_test.go
  related:
    - layer-guard-silent-rejection-on-top-layer-integrat  # different cause, same symptom class
    - layer-guard-stderr-vs-stdout-debuggability          # see below
    - hook-chain-self-brick-recovery                      # see below
  work_needed: |
    Use findFurrowRoot() walk-up; keep FURROW_LAYER_POLICY_PATH env
    override; retain cwd-relative fallback for back-compat. (DONE.)

- id: layer-guard-stderr-vs-stdout-debuggability
  title: layer-guard verdict reason should also write to stderr
  status: active
  source_type: dogfood-finding
  urgency: medium
  impact: medium
  effort: small
  context: |
    Claude Code PreToolUse hooks surface block reasons from stderr.
    `internal/cli/hook/layer_guard.go:emit` writes the JSON verdict
    envelope to stdout only. When the hook fail-closes, the harness
    reports "No stderr output" — the actual reason (e.g.,
    layer_policy_invalid) is invisible. Hid LG-1 root cause for ~30
    minutes during dogfood session 2026-04-28.
  files_touched:
    - internal/cli/hook/layer_guard.go
    - internal/cli/hook/layer_guard_test.go
  work_needed: |
    Mirror the reason text to stderr on block (keep stdout JSON for
    adapters that parse it). Confirm with schemas/blocker-event.schema.json
    that the addition is non-breaking.

- id: hook-chain-self-brick-recovery
  title: Hook chain must allow Edit on recovery paths when load-failure detected
  status: active
  source_type: dogfood-finding
  urgency: medium
  impact: high
  effort: medium
  context: |
    When any PreToolUse hook fail-closes (e.g., policy load failure),
    every subsequent hook including Edit also fails — leaving the
    agent unable to patch the broken component. Required out-of-band
    human intervention to unbrick during dogfood session 2026-04-28.
  related:
    - layer-guard-cwd-relative-policy-path-self-brick
  work_needed: |
    Distinguish policy-load-failure from policy-decision-block in the
    verdict envelope. On load-failure verdict, allow Edit on a
    narrow set of recovery paths (internal/cli/**, schemas/**,
    .furrow/layer-policy.yaml) so the agent can self-recover. Threat
    model: load-failure must be authentic (not user-provoked) — bound
    the rescue allow to a session-local kill-switch only.
```

