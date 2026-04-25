# Research: pre-write-validation-go-first

Resolves the 5 Open Questions carried forward from ideate. Empirical-only; all answers from in-tree primary sources (code, schemas, repo layout). No external research required.

References definition.yaml deliverables: D1 (validate-definition-go), D2 (validate-ownership-go), D3 (blocker-taxonomy-schema), D4 (pi-validate-definition-handler), D5 (pi-ownership-warn-handler), D6 (claude-ownership-warn-parity).

---

## Q1 — Pi adapter test infrastructure: exists or zero?

**Verdict: ZERO. D4 must bootstrap from scratch.**

`adapters/pi/` contains only `furrow.ts` (48KB), `README.md`, `_meta.yaml`. No `package.json`, no `tsconfig.json`, no `bun.lockb`, no `vitest.config.*`, no `*.test.ts`, no `node_modules/`. Sibling adapters (`adapters/claude-code/`, `adapters/agent-sdk/`) likewise have no TypeScript/Node test scaffolding.

**Implication for D4**: D4's existing acceptance ("if no test runner exists today, D4 establishes the minimum viable scaffolding") is the active path, not a fallback. Concrete scaffold:
- `adapters/pi/package.json` with `"scripts": { "test": "bun test" }` (or vitest if user prefers — Bun is the default test runner per `runFurrowJson`'s shell-out style, no extra dep)
- `adapters/pi/tsconfig.json` — minimum config so `furrow.ts` and `furrow.test.ts` typecheck during test
- `adapters/pi/furrow.test.ts` — first test file exercising D4's valid/invalid handler branches against fixture rows

**Secondary finding**: This row sets the test-runner precedent for the other two Pi-style adapters too. Future test work in `adapters/claude-code/` and `adapters/agent-sdk/` likely reuses this scaffold. Worth flagging but **out of scope** — D4 sets up its own adapter only.

---

## Q2 — parity-verification.md: location and existing patterns?

**Verdict: NO prior pattern. Row-local path (`.furrow/rows/<name>/parity-verification.md`) is correct. This row sets the precedent.**

Searched: `tests/`, `tests/integration/`, `.furrow/rows/*/`, `docs/architecture/`, full git log. Zero files matching `*parity*`, `*cross-adapter*`, `*cross-host*`, `*both-runtimes*`, `*-verification.md` (except `docs/architecture/pi-parity-ladder.md` which documents *parity milestones* across the migration roadmap, not paired test results — different artifact entirely).

`docs/architecture/migration-stance.md:86-89` invariant #7 establishes the *principle* ("Pi and Claude-compatible flows do not silently diverge on canonical workflow semantics") but no test convention codifies how to *verify* the principle.

**Implication for D5/D6**: definition.yaml's existing path `.furrow/rows/pre-write-validation-go-first/parity-verification.md` is the right call (row-local artifact, follows row-self-contained model). No alternative location is more discoverable; the row-cluster-machine-readable representation effort (separate row) will surface row artifacts uniformly when it ships.

---

## Q3 — runFurrowJson cold-start latency: baseline?

**Verdict: ~45ms median per call, ~90ms double-fire per Write/Edit. Under the 100ms-per-call threshold from ideate Recommendations — pi-adapter-binary-caching follow-up stays low-priority background.**

`time go run ./cmd/furrow <subcommand> --json` measured at 41ms / 45ms / 52ms across 3 runs. Cold-start dominates; subcommand work is negligible. `cmd/furrow/main.go` already exists (delegates to `internal/cli.New()`); D1/D2 do NOT introduce a new entry point — they add subcommands inside the existing one.

**Per-write overhead under D4+D5**: 2 × 45ms = ~90ms wall clock for a Write/Edit that hits both validators (any write to a `.furrow/rows/<name>/<file>` triggers ownership; writes to `*/definition.yaml` additionally trigger validate-definition). 90ms is user-detectable but not painful — comparable to network round-trip.

**Implication for follow-up**: The summary.md Recommendation said "promote pi-adapter-binary-caching if median per-call >100ms." Per-call is 45ms (under threshold). Double-fire 90ms is not "per-call." Follow-up stays low-priority per existing schedule. No reframing of D4/D5 acceptance needed.

**Secondary finding**: `bin/frw` is a shell dispatcher, not a Go binary. There is no precompiled `furrow` binary anywhere in the repo today. The pi-adapter-binary-caching todo will need to add a build step (or use `go build -o ./bin/furrow ./cmd/furrow` lazily on adapter init).

---

## Q4 — internal/cli/row_semantics.go currently emits blockers?

**Verdict: NO. row_semantics.go is a helper template with zero call sites. The actual emitter is `internal/cli/row_workflow.go`'s `rowBlockers()` function (lines 1005-1084), with 9 distinct hardcoded codes today.**

**Existing emissions** (from `rowBlockers()` in `row_workflow.go:1005-1084`):

| Code | Category |
|---|---|
| `pending_user_actions` | user_action |
| `seed_store_unavailable` | seed |
| `missing_seed_record` | seed |
| `closed_seed` | seed |
| `seed_status_mismatch` | seed |
| `missing_required_artifact` | artifact |
| `artifact_scaffold_incomplete` | artifact |
| `artifact_validation_failed` | artifact |
| `archive_requires_review_gate` | archive |

`row_semantics.go` provides `blocker()` (struct constructor, lines 46-58) and `blockerConfirmationPath()` (code→message map for the 9 codes, lines 60-77) but is **never called** — `grep -n 'blocker(' internal/cli/row_semantics.go` returns the definition only, not invocations. `review_semantics.go` likewise emits no blockers (`grep -n blocker` empty).

**Implication for D3 boundary**: The current definition.yaml constraint cites `row_semantics.go` as the don't-touch file. Empirically, the *real* emitter is `row_workflow.go`. The catch-all clause "or any other existing blocker emitter" still correctly covers row_workflow.go, so the boundary is not broken — but it should be tightened to name the actual emitter for clarity. **Recommend updating the D3 constraint and AC to cite `row_workflow.go` (the real emitter, 9 codes) and `row_semantics.go` (the helper template) explicitly.**

**Implication for the future taxonomy-completion row**: The 9 codes above are exactly the next batch of taxonomy migrations. The schema D3 ships must accommodate `applicable_steps`-style fields these will use (e.g., `archive_requires_review_gate` is review→archive specific). Confirm D3's schema fields cover this vocabulary — they do per the existing AC (`applicable_steps` optional array).

---

## Q5 — existing cross-adapter parity test pattern?

**Verdict: NONE. This row is the first to formally test backend output consistency across Pi and Claude adapters.**

`tests/integration/` exists and contains shell integration tests for merge workflow, install, migration, doctor, etc. — but no shared-fixture cross-runtime pattern. `bin/frw.d/scripts/cross-model-review.sh` exists but is for cross-LLM diff review (codex vs claude), not cross-host adapter behavior.

`adapters/` is structured as three parallel implementations (`claude-code/`, `agent-sdk/`, `pi/`) with `adapters/shared/schemas/` holding common types. No `adapters/shared/tests/` or similar cross-adapter test runner.

**Implication**: D5/D6's parity-verification.md sets the convention. Format should be sturdy enough that a future row could promote it from per-row markdown to a shared-fixture test runner without rewriting all rows. Recommend: tabular markdown with columns `(scenario, input_path, input_row, go_validator_verdict, pi_handler_outcome, claude_hook_outcome, parity_assertion_passed)`. The plan step finalizes the format; structure proposed here.

---

## Recommendations into plan

1. **Tighten D3 boundary in plan/spec**: cite `internal/cli/row_workflow.go` (real emitter, 9 codes) explicitly, alongside `row_semantics.go` (helper template). Treat both as off-limits.
2. **D4 scaffold scope confirmed**: package.json (bun test) + tsconfig.json + furrow.test.ts. No upstream blockers; scaffold is genuinely from-zero.
3. **parity-verification.md format**: row-local path is right; recommend tabular markdown with paired Pi/Claude outcome columns (proposed structure above).
4. **Cold-start latency stays low-priority**: 45ms per-call < 100ms threshold; pi-adapter-binary-caching todo remains background.
5. **No definition.yaml amendments needed during research**: the catch-all clause covers row_workflow.go; the boundary is correct, just imprecise. Plan step can either amend definition.yaml or encode the precise file list in plan.json — leave that decision for plan.

---

## Sources Consulted

- **Primary (in-tree code, repo layout, measured commands)**: 
  - `adapters/pi/` directory listing, file existence checks (`ls`, `find`)
  - `adapters/claude-code/`, `adapters/agent-sdk/` directory listings (sibling adapter scaffolding)
  - `internal/cli/row_workflow.go:1005-1084` (rowBlockers function, blocker emission grep)
  - `internal/cli/row_semantics.go:46-77` (blocker helper template, callsite grep returns zero)
  - `internal/cli/review_semantics.go` (blocker grep — empty)
  - `cmd/furrow/main.go` (entry point existence check)
  - `time go run ./cmd/furrow ... --json` × 3 runs (latency measurement)
  - `git log --oneline --all | grep -i parity` (cross-adapter test history search — empty)
  - `tests/integration/` directory listing (shell-only test infrastructure)
  - `bin/frw`, `bin/frw.d/scripts/cross-model-review.sh` (existing tooling scope)
  - `adapters/shared/schemas/` (cross-adapter shared schema location)
- **Primary (in-tree docs)**:
  - `.furrow/rows/migration-state-of-the-union/research.md` §8/§9 (empirical pain ranking, locked scope source)
  - `docs/architecture/migration-stance.md:86-89` (invariant #7 — design principle, not test convention)
  - `docs/architecture/pi-parity-ladder.md` (parity *milestones*, not paired test results — different artifact)
  - `.furrow/almanac/rationale.yaml:182-215` (dual-runtime adapter structure documentation)
- **No secondary or tertiary sources required**: all questions resolvable from in-repo primary sources. No claims about external software in this research.

## Contribution by tier

| Source | Tier | Contributed to |
|---|---|---|
| `adapters/pi/` directory listing | primary | Q1 (zero test infra) |
| `internal/cli/row_workflow.go` grep | primary | Q4 (real emitter identified) |
| `time go run` measurements | primary | Q3 (45ms baseline) |
| migration-stance.md:86-89 | primary | Q2 invariant context, Q5 principle vs convention |
| Cross-model review (reviews/ideation-cross.json from ideate step) | primary | Q4 motivation (codex flagged the boundary issue) |
