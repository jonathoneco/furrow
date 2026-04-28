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

### 1.1 Headless one-shot via `-e ./adapters/pi/furrow.ts` — WORKS
- (covered by 0.6 above) `/furrow-overview` returns formatted output.

### 1.2 `/furrow-next` — WORKS
- Returns rich, well-formatted output: Row, Title, Resolution=`latest_active`,
  Step, Step status, Deliverables, Blockers (with category/severity/code),
  Seed (missing seed linkage surfaced), Current-step artifacts,
  Checkpoint, Doctor summary, Row warnings, Recommended next action.
- Two warnings surface correctly (and identify a separate finding RM-1 below):
  - `focused_row: focused row "pre-write-validation-go-first" is archived`
  - `[fail] almanac_validation: almanac validation found errors`

### 1.3 Auto-discovery via `.pi/extensions/furrow.ts` shim — WORKS
- `pi --no-session -p "/furrow-overview"` returns identical output to the
  explicit `-e` form. Shim re-export confirmed end-to-end.

### 1.4 Interactive TUI launch — DEFERRED (visual confirmation, can't script)

Section 1 verdict: **WORKS**. Pi loads the adapter, registers the five
commands, reaches the Go backend, parses the canonical envelope, and
formats it correctly.

---

## Adjacent findings surfaced during Section 1

### RM-1 — VAPORWARE: roadmap.yaml has 14 dangling validation errors

**Verdict**: VAPORWARE (almanac integrity gap; main ships with a failing
`furrow doctor`).

**Surface**: `furrow almanac validate` reports
`/home/jonco/src/furrow/.furrow/almanac/roadmap.yaml: fail (14 findings)`:
- 11 edge dangling references to nodes that don't exist:
  `parallel-agent-orchestration-adoption`, `cli-architecture-overhaul`
  (×4), `default-supervised-gating` (×2), `install-architecture-overhaul`
  (×2), `go-cli-contract-v1`, `migration-operating-mode`.
- 3 roadmap-TODO sync gaps for nodes that exist in roadmap.yaml but have
  no matching todos.yaml entry: `archive-pi-adapter-foundation-as-superseded`,
  `pi-step-ceremony-deliverables-backfill` (referenced 2×).

**Likely cause**: Phase reshuffling commits (35e3369, 18a82cc, 2cb51d0)
renamed/absorbed phase nodes (e.g., `cli-architecture-overhaul` →
`cli-architecture-overhaul-slice-2`) but didn't update the edge targets
or the TODO sync.

**Distinct from `frw doctor` parallel-batch invariant**: that check
passes (`Roadmap phasing (parallel-batch invariant): PASS`). RM-1 is the
*Go* `furrow almanac validate` integrity check, which `furrow doctor`
inherits as `almanac_validation: fail`. The two checks are independent.

**Disposition**: TODO needed (operator-only — engine layer cannot mutate
`.furrow/`). Two probable patch options:
- (a) Fix edges to point to renamed targets (e.g., `cli-architecture-overhaul`
  → `cli-architecture-overhaul-slice-2`).
- (b) Add the missing nodes back if they represent real future work.
- For the missing TODOs: either add the entries to `todos.yaml` or remove
  the roadmap references that orphan-link them.

Without intent context, this is operator/team-lead's call. Not patching
from this session.

**Draft TODO entry** (for team-lead to add to `.furrow/almanac/todos.yaml`):

```yaml
- id: roadmap-yaml-dangling-edges-and-orphan-refs
  title: roadmap.yaml has 14 validation errors after phase reshuffling
  status: active
  source_type: dogfood-finding
  urgency: medium
  impact: medium
  effort: small
  context: |
    `furrow almanac validate` reports 14 findings on
    .furrow/almanac/roadmap.yaml: 11 edges referencing missing nodes
    (cli-architecture-overhaul, parallel-agent-orchestration-adoption,
    default-supervised-gating, install-architecture-overhaul,
    go-cli-contract-v1, migration-operating-mode) plus 3 roadmap nodes
    referencing missing TODOs (archive-pi-adapter-foundation-as-superseded,
    pi-step-ceremony-deliverables-backfill). `furrow doctor` rolls these
    up as a single `almanac_validation: fail` check. Likely from phase
    reshuffling in 35e3369, 18a82cc, 2cb51d0 where nodes were renamed
    but edges/TODOs not updated.
  files_touched:
    - .furrow/almanac/roadmap.yaml
    - .furrow/almanac/todos.yaml
  work_needed: |
    For each dangling edge: confirm whether the target was renamed
    (e.g., to *-slice-2) and update the edge, or add the missing
    node if it represents real future work, or remove the edge if
    cruft. For each missing TODO: add the entry or remove the
    roadmap reference. After: `furrow almanac validate` should
    return pass.
```

---

## Sections 4-6 — Blocker taxonomy / Context routing / Handoff render

### 4 Blocker taxonomy & canonical envelope — WORKS (with one stale doc)

- `furrow guard <event-type>` is wired for all 10 event types in
  `schemas/blocker-event.yaml`: pre_write_state_json, pre_write_verdict,
  pre_write_correction_limit, pre_bash_internal_script,
  pre_commit_bakfiles, pre_commit_typechange, pre_commit_script_modes,
  stop_ideation_completeness, stop_summary_validation, stop_work_check.
- Each event correctly validates required payload keys per the schema
  (e.g., `pre_bash_internal_script` errors with `missing required
  payload key "command"`).
- `pre_write_state_json` with a real `.furrow/...state.json` path emits
  the canonical 6-field envelope: code=state_json_direct_write,
  category=state-mutation, severity=block, message, remediation_hint,
  confirmation_path=block. ✓

**Minor finding G-1**: `furrow guard --help` claims only one event type
(pre_bash_internal_script). The other 9 work but aren't documented.
Stale `--help` text. Low priority — file as a docs TODO.

### 5 Context routing (`furrow context for-step`) — PARTIAL → PATCHED (focused-row), one VAPORWARE remains

- `furrow context for-step <step> --row <name> --json` returns a 7-field
  bundle conforming to `schemas/context-bundle.schema.json`: row, step,
  target, skills, references, prior_artifacts, decisions. WORKS.
- 61.5KB output for a real ideate-step bundle (skills inlined as
  full content, references resolved). Substantial.

#### C-1 — VAPORWARE → PATCHED in this session: focused-row file lookup used wrong filename

`internal/cli/context/cmd.go:271` read `.furrow/focus` (no leading dot).
The canonical filename is `.furrow/.focused` (with leading dot) — used
correctly by `internal/cli/util.go:38`, `internal/cli/row_workflow.go:105`,
and `adapters/pi/furrow.ts:380` (`isCanonicalStatePath`).

Result: every `furrow context for-step <step>` invocation without an
explicit `--row` failed with `read focus file: open
/home/jonco/src/furrow/.furrow/focus: no such file or directory`. Caller
silently forced to always pass `--row`.

**Patched in this session**:
- `internal/cli/context/cmd.go` readFocusedRow → uses `.focused`.
- New `internal/cli/context/focused_test.go` with 3 regression tests:
  CanonicalFilename, RejectsLegacyFilename, EmptyFile.
- Verified: `furrow context for-step ideate --json` (no --row) now
  returns the bundle for the focused row.

#### C-2 — VAPORWARE: context emitBlocker emits non-canonical envelope shape

`internal/cli/context/cmd.go:235` (`emitBlocker`) emits this shape on
blocker:

```json
{
  "blocker": {
    "code": "...",
    "message": "...",
    "context": null,
    "confirmation_path": ".furrow/blockers/<code>.json"
  }
}
```

Compared to canonical (per `schemas/blocker-event.schema.json` and what
`furrow guard` produces):

- Wraps in extra `{blocker: ...}` envelope. Canonical is unwrapped.
- Missing `category`, `severity`, `remediation_hint`.
- `confirmation_path` is a *file path*, not the canonical enum
  (block / warn-with-confirm / silent).

The Pi adapter (`adapters/pi/furrow.ts:411-419`) explicitly comments:
"`confirmation_path` is the enum token (block/warn-with-confirm/silent)
— useful for UX decoration but NOT a sentence to interpolate as prose."
This implementation directly contradicts that contract.

**Disposition**: NEW TODO. Patch is non-trivial — requires importing/
reusing the canonical envelope construction shared between `furrow guard`
and the validate-* paths. Not patching from this session because:
- Phase 5 owns `pi-tool-call-canonical-schema-and-surface-audit`, which
  may already cover the cross-CLI envelope-shape audit. Risk of churn.
- Engine layer can't probe live conflict in Phase 5 worktree.

#### D-1 — DUPLICATE: `findFurrowRoot()` re-implemented in context package

`internal/cli/context/cmd.go:250-267` reimplements walk-up search that
already exists in `internal/cli/util.go:17`. Same algorithm, same
behavior. Different package; needs an export to share, or a small
shared package. Low-priority cleanup — file as TODO.

### 6 Handoff schemas (`furrow handoff render`) — WORKS (one UX papercut)

- Driver target: `furrow handoff render --target driver:plan --row ...
  --step plan --json` returns object with all 7 schema-required fields:
  target, step, row, objective, grounding, constraints, return_format. ✓
- Engine target: requires JSON payload on stdin (per
  `internal/cli/handoff/cmd.go:179` "For engine targets, read
  EngineHandoff JSON from stdin"). When invoked without piped input,
  fails with `<stdin>: invalid JSON: unexpected end of JSON input` —
  surfaces the canonical 6-field envelope correctly, but the message is
  cryptic for a CLI user. Working as designed; UX papercut only.

**Minor finding H-1**: `furrow handoff render --help` (or its absence)
should make explicit that engine targets require stdin. Low priority.

---

## Draft TODOs to file (consolidated)

For team-lead to paste into `.furrow/almanac/todos.yaml`. The first three
are from the LG- series (Section above). These are new since:

```yaml
- id: roadmap-yaml-dangling-edges-and-orphan-refs            # see RM-1 above
  # ... (full block above)

- id: furrow-context-cmd-non-canonical-blocker-shape
  title: furrow context cmd emits non-canonical blocker envelope
  status: active
  source_type: dogfood-finding
  urgency: low
  impact: medium
  effort: small
  related:
    - pi-tool-call-canonical-schema-and-surface-audit       # Phase 5 — may absorb
  context: |
    internal/cli/context/cmd.go emitBlocker wraps the verdict in
    {blocker: ...}, omits category/severity/remediation_hint, and
    misuses confirmation_path as a file path instead of the canonical
    enum (block/warn-with-confirm/silent). Diverges from `furrow guard`
    output and from the contract Pi adapter expects (adapters/pi/furrow.ts
    formatBlockers comment). Found 2026-04-28 dogfood.
  files_touched:
    - internal/cli/context/cmd.go
  work_needed: |
    Reuse the canonical envelope construction from internal/cli/guard.go
    (or factor a shared helper). Drop the {blocker: ...} wrapper. Emit
    all 6 canonical fields. Confirm against schemas/blocker-event.schema.json.

- id: findFurrowRoot-duplicated-across-packages
  title: findFurrowRoot reimplemented in context package
  status: active
  source_type: dogfood-finding
  urgency: low
  impact: low
  effort: small
  context: |
    internal/cli/context/cmd.go:250-267 duplicates the walk-up logic
    from internal/cli/util.go:17. The Pi adapter has a third
    implementation (TS) at adapters/pi/furrow.ts:324 — that one is
    unavoidable (different language). The two Go implementations should
    converge. Either export from internal/cli or factor into a shared
    pkg. Found 2026-04-28 dogfood.
  files_touched:
    - internal/cli/context/cmd.go
    - internal/cli/util.go

- id: furrow-guard-help-text-stale
  title: `furrow guard --help` only documents 1 of 10 event types
  status: active
  source_type: dogfood-finding
  urgency: low
  impact: low
  effort: small
  context: |
    `furrow guard --help` shows "Event types: pre_bash_internal_script"
    but the binary handles 10 event types per schemas/blocker-event.yaml.
    Found 2026-04-28 dogfood.
  files_touched:
    - internal/cli/guard.go (or wherever --help is rendered)
```



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

