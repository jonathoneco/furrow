# Research: Test Infrastructure and Contradiction Passages

Row: `blocker-taxonomy-foundation`
Scope: Questions C (existing test infra for D4) and D (exact contradiction passages for D5).
Date: 2026-04-25.

---

## Section C — Existing Test Infrastructure

### C.1 Layout summary

```
tests/
├── fixtures/
│   └── make-legacy-install.sh         # shared cross-test fixture builder
└── integration/
    ├── run-all.sh                     # POSIX-sh runner (invoked by CI)
    ├── helpers.sh                     # bash assertion + setup library
    ├── lib/
    │   └── sandbox.sh                 # POSIX-sh sandbox isolation
    ├── fixtures/
    │   └── merge-e2e/                 # per-test fixture sub-tree
    │       └── full-pipeline/{baseline,worktree-feature}/
    └── test-*.sh                      # 47 test scripts
```

There is no top-level `Makefile` and no `.github/workflows/` directory in this checkout. CI is wired by invoking `tests/integration/run-all.sh` directly. Acceptance criterion D4.5 ("wired into the project test runner — Makefile, CI script, or equivalent") therefore means: drop the new tests as `tests/integration/test-blocker-coverage.sh` and `tests/integration/test-blocker-parity.sh`; `run-all.sh`'s glob (`for _test in "${SCRIPT_DIR}"/test-*.sh`) auto-discovers them. **No additional CI wiring is required.** Adding a `Makefile` target is not a precondition — but if the deliverable's `file_ownership` insists on `Makefile`, it should be created with a single `test:` target invoking `tests/integration/run-all.sh`, not as the wiring source of truth.

### C.2 `run-all.sh` conventions (`tests/integration/run-all.sh:1-62`)

- Shebang: `#!/bin/sh` (POSIX, not bash).
- Invariants enforced by the runner:
  1. `git status --porcelain` must be empty before the suite (`run-all.sh:21-25`).
  2. Each `test-*.sh` runs in its own subshell with `set -e` (`run-all.sh:32-44`).
  3. `git status --porcelain` must be empty after the suite (`run-all.sh:51-56`).
- Exit `0` only on clean pre-check + all tests pass + clean post-check.
- Output format: `>>> <test-name>` per test, then a totals banner.

**Implication for D4 tests**: any temp files, fixture-derived state, or stray writes leak as worktree mutation. New tests must clean up in a trap, or operate purely under `$(mktemp -d)`.

### C.3 Two representative existing tests

#### `tests/integration/test-rws.sh` (canonical pattern — sandboxed)

- Shebang: `#!/bin/bash` (uses bash-isms via `helpers.sh`).
- Sources `helpers.sh` from `${SCRIPT_DIR}` (`test-rws.sh:5-7`).
- Calls `setup_test_env` which creates `$TEST_DIR=$(mktemp -d)`, initializes a git repo, prepends `bin/` to `PATH`, and creates `.furrow/{rows,almanac}` skeleton + minimal `furrow.yaml` + skill stubs (`helpers.sh:37-77`).
- Uses assertions from `helpers.sh`: `assert_exit_code`, `assert_file_exists`, `assert_file_contains`, `assert_json_field`, `assert_output_contains`, `assert_ge`, `assert_not_empty`.
- Invokes harness binaries by bare name (`rws init`, `sds init`) via `PATH`.
- Trap cleans up `$TEST_DIR` on EXIT/INT/TERM (`helpers.sh:76`).

#### `tests/integration/test-ownership-warn-hook.sh` (in-checkout pattern — operates on live row)

- Shebang: `#!/usr/bin/env bash`.
- Does **not** source `helpers.sh`; defines its own `assert_contains` / `assert_not_contains` and `pass_count`/`fail_count`.
- Operates against a real row in the live worktree (`pre-write-validation-go-first`) because the hook body shells out via `go run ./cmd/furrow` and needs a real Go module to resolve.
- Snapshots `.furrow/.focused` and restores it on EXIT (`test-ownership-warn-hook.sh:28-40`) — this is how it stays compatible with `run-all.sh`'s post-check invariant.
- Exits with `${fail_count}`.

**The hook test is the closest precedent for the new D4 work**: feeding canned event JSON to a shim and asserting on canonical envelope output. The blocker-coverage/parity tests should follow this pattern (snapshot any live state mutated, restore in trap, exit with failure count) but should prefer driving the Go binary directly with normalized event fixtures rather than mutating live row state.

### C.4 Go binary invocation convention

- The only place a Go binary is shelled out from a hook today is `bin/frw.d/hooks/ownership-warn.sh:61`:

  ```sh
  result_json="$(go run ./cmd/furrow validate ownership --path "$target_path" --row "$row_name" --json 2>/dev/null)" || return 0
  ```

- There is no compiled `bin/furrow` in `bin/`; the canonical invocation is `go run ./cmd/furrow <subcommand>`.
- `cmd/furrow/main.go` is the binary entrypoint; `internal/cli/` houses subcommand logic including `blocker_envelope.go` (already present).

**Recommendation for D4**: drive the new normalized-event Go entry point (deliverable D2 introduces this; AC suggests `furrow guard <event-type> --json` or an internal emit subcommand) as `go run ./cmd/furrow guard <event-type> --json < fixture.json`. Keep `go run` (not a pre-built binary) for parity with existing hook conventions and to avoid build-step ordering in the test runner.

### C.5 Helpers usable as-is

From `helpers.sh:131-265`:

- `assert_json_field "<desc>" <file> <jq-expr> <expected>` — perfect for asserting `.code`, `.severity`, `.category` on emitted envelopes.
- `assert_output_contains "<desc>" "$output" "<pattern>"` — for envelope JSON streamed on stdout.
- `assert_file_exists`, `assert_file_contains` — for fixture-presence checks.
- `print_summary` — exits 0/1 based on counters; pairs with `run_test`.

`assert_json_field` requires `jq` (already a hard dependency of the suite, used in 12+ tests). Acceptable to require it for the new tests.

### C.6 Recommended fixture layout

Based on `tests/integration/fixtures/merge-e2e/<scenario>/<phase>/` precedent (per-test sub-tree, per-scenario sub-dir), the natural shape for D4 is:

```
tests/integration/fixtures/blocker-events/
├── <code>/
│   ├── normalized.json        # canonical normalized event (D2 schema shape)
│   ├── claude.json            # Claude-shape host event (parity test input)
│   ├── pi.json                # Pi-shape host event (parity test input)
│   └── expected-envelope.json # canonical BlockerEnvelope expected output
```

Rationale: one directory per code keeps the `for code in $(yq '.[].code' schemas/blocker-taxonomy.yaml)` loop in the coverage test trivial — `tests/integration/fixtures/blocker-events/${code}/` either exists (driven through Go) or is in a documented skip list. Per-runtime files (`claude.json`, `pi.json`) match the parity test's two-input contract per AC D4.2 directly.

D4 already declares `tests/integration/fixtures/blocker-events/**` as owned, so this layout is consistent with the deliverable's `file_ownership`.

### C.7 Recommended file naming and conventions for D4

- `tests/integration/test-blocker-coverage.sh` — `#!/bin/bash`, sources `helpers.sh`, uses `assert_json_field` / `assert_output_contains` / `print_summary`.
- `tests/integration/test-blocker-parity.sh` — same pattern; iterates over migrated codes only (skip-list for any deferred per D3 audit), feeds Claude and Pi shapes, diffs envelope output.
- Both tests must be self-contained — operate under `$(mktemp -d)` if they write any files. The suite-wide `git status --porcelain` post-check will fail otherwise.
- Skip mechanism for deferred codes: a literal skip list constant at the top of each script (e.g., `DEFERRED_CODES="<code1> <code2>"`) and a logged `SKIP: <code> (reason: deferred per audit)` line — keeps the test deterministic without depending on parsing the audit report. The audit report (D3) becomes the source of truth for *why* a code is on the skip list; the test's skip list is the operational mirror.
- The "shim-doesn't-fake-output" assertion (D4.3) can be implemented by `grep -L 'go run ./cmd/furrow\|furrow guard' <hook>.sh` returning empty for each migrated hook, plus an `assert_file_not_contains` against hard-coded envelope fragments (e.g., `'"code":'` literal) in shim bodies.

### C.8 CI wiring recommendation

- **Primary**: rely on `run-all.sh`'s glob — no action required beyond placing the test files. This is how every other integration test is discovered.
- **Optional `Makefile`**: if D4's `file_ownership` for `Makefile` must materialize, the smallest viable shape is:
  ```make
  .PHONY: test
  test:
  	@tests/integration/run-all.sh
  ```
  This documents the entrypoint without changing its semantics. Do not add per-test targets — they would duplicate `run-all.sh`'s discovery.

---

## Section D — Exact Contradiction Passages for D5

### D.0 Source TODO text

`.furrow/almanac/todos.yaml:3824-3840` (id: `doc-contradiction-reconciliation`):

> **context**: `'Three doc-vs-doc tensions surfaced by gap audit: (1) seed timing — pi-almanac-operating-model.md:150 says ''seeds replace TODOs as canonical'' but Phase 5 deferral means seeds are not canonical yet; rows that bypass TODOs and try seeds-only could split-brain. (2) Blocker enforcement split — Pi-side defined; Claude-side undefined. (3) Artifact validation scope creep — go-cli-contract.md:385-388 says ''does NOT enforce X'' vs pi-step-ceremony-and-artifact-enforcement.md:375-380 says ''enforces X''. Need explicit reconciliation per case.'`
>
> **work_needed**: `'Per contradiction: write a reconciliation note in the involved docs that names the conflict and resolves it (or explicitly defers with date+condition). For (1): document transitional rule clearly so seeds/TODOs coexistence is unambiguous. For (2): close via claude-blocker-enforcement-parity todo. For (3): close via artifact-validation-per-step-schema todo. Update docs/architecture/documentation-authority-taxonomy.md if a meta-pattern emerges.'`

---

### D.1 Contradiction (1) — Seed-timing canonical claim

#### Side A: "seeds replace TODOs as canonical" claim

`docs/architecture/pi-almanac-operating-model.md:148-159`:

```
148  ## Seed-backed planning model
149
150  ## Seeds replace TODOs
151
152  Furrow should converge to **A1**:
153  - seeds replace TODOs as the canonical planning primitive
154  - `todos.yaml` is retired rather than preserved as a permanent parallel system
155  - roadmap and triage read from the seed graph
156  - almanac stops being the canonical task registry
157
158  `todos.yaml` may remain temporarily only as migration compatibility, but Pi
159  should not be designed around it as the long-term model.
```

#### Side B: Phase 5 deferral

Same file, `docs/architecture/pi-almanac-operating-model.md:319-327` (existing transitional rule, weak):

```
319  ## Transitional rule
320
321  Current Furrow still has TODO-backed almanac surfaces. During migration:
322  - existing TODO-backed commands may remain as compatibility shims
323  - new long-term Pi planning UX should be designed against the seed-backed target
324  - no major new investment should deepen `todos.yaml` as a permanent authority
325
326  If a temporary TODO-backed Pi surface is needed before seeds lands, it should be
327  labeled as transitional and shaped to collapse cleanly into seed-backed flows.
```

And `docs/architecture/pi-almanac-operating-model.md:383-391`:

```
383  This document does **not** change the immediate priority:
384  - first restore Pi's staged `/work` loop and ceremony (`Phase 3`)
385
386  But it does change the target shape of later planning work:
387  - seeds should land as the canonical work graph (`Phase 5`)
388  - Pi almanac/planning surfaces should be built against that seed-backed model
389  - TODO-backed planning should be treated as transitional compatibility only
390  - post-parity Pi-native leverage should build on top of this split, not replace
391  - it
```

#### The contradiction in plain language

Lines 150-156 declare the present-tense canonical primitive ("seeds replace TODOs as the canonical planning primitive"; "almanac stops being the canonical task registry"). Lines 387-389 defer the seed-as-canonical-work-graph cutover to Phase 5 and label TODO-backed planning as "transitional compatibility only" — but the existing transitional rule (321-327) does **not** state which side is authoritative *today*. A row reading line 150 in isolation could reasonably conclude `todos.yaml` is already retired and operate seeds-only, splitting the planning brain.

#### Proposed reconciliation insertion (per D5 AC.1)

Insert an explicit transitional rule directly under the heading at line 150, before the "Furrow should converge to **A1**" framing — or strengthen the existing `## Transitional rule` block at lines 319-327. AC D5.1 mandates the insertion **in `pi-almanac-operating-model.md`**. The minimal new wording (to be placed immediately after line 156, before the existing `todos.yaml may remain temporarily` line):

> **Until the Phase 5 cutover (see "Sequencing" below) `todos.yaml` remains the authoritative planning registry. Rows MUST read TODOs and MAY consult seeds; rows MUST NOT operate seeds-only. The "seeds replace TODOs" target above is the post-cutover end state, not the current authority.**

This satisfies "rows must read TODOs and may consult seeds, never the inverse" verbatim from D5 AC.1.

---

### D.2 Contradiction (2) — Blocker enforcement split

#### Side A: shared semantics mandate

`docs/architecture/migration-stance.md:86-89`:

```
86  ### 7. Shared semantics across hosts remain real
87
88  Pi and Claude-compatible flows do not need identical UX, but they should not
89  silently diverge on canonical workflow semantics.
```

#### Side B: current state (Pi defined / Claude undefined)

This contradiction is structural rather than textual: `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` (referenced in this row's `definition.yaml:104-105` as "Section 'Blocker baseline' (lines 267-300) is source-of-truth for the required code inventory") defines the Pi-side blocker codes in detail, while no equivalent canonical Claude-side enumeration exists in the doc tree. This is the asymmetry the source-TODO calls out as "(2) Blocker enforcement split — Pi-side defined; Claude-side undefined."

The `migration-stance.md` invariant 7 forbids exactly this kind of silent divergence, so the split *is* a contradiction with the canonical invariant — not just a gap.

#### Proposed reconciliation insertion (per D5 AC.2)

Add a reconciliation note in `docs/architecture/migration-stance.md` immediately after line 89 (within the `### 7. Shared semantics across hosts remain real` subsection), before line 91's `## Non-invariants` heading. Suggested wording:

> **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**: the asymmetry where Pi-side blocker codes were canonically enumerated in `pi-step-ceremony-and-artifact-enforcement.md` while Claude-side enforcement was undefined is closed by the deliverables `canonical-blocker-taxonomy` + `normalized-blocker-event-and-go-emission-path` + `hook-migration-and-quality-audit` + `coverage-and-parity-tests` of that row. The durable anti-drift mechanism is `tests/integration/test-blocker-parity.sh`, which fails CI when the two adapters produce non-identical canonical envelopes for any migrated code.

This wording cites all four deliverables and names the parity test path verbatim per AC D5.2.

---

### D.3 Contradiction (3) — Artifact validation scope

#### Side A: "does NOT enforce" (go-cli-contract.md)

`docs/architecture/go-cli-contract.md:381-399`:

```
381  That record is intentionally provisional and does **not** imply full lifecycle
382  semantics. The current implementation now additionally enforces a narrow blocker
383  baseline before mutation:
384
385  - `step_status=completed` required before advancement
386  - current-step required artifact presence
387  - incomplete scaffold-template detection
388  - backend structural validation for the currently supported step artifacts
389  - linked-seed validity / sync when a seed is present
390  - durable checkpoint evidence written under `gates/`
391
392  It still does **not** enforce:
393
394  - evaluator-grade semantic validation or full gate-engine parity
395  - full gate-policy enforcement beyond adapter-driven supervised confirmation
396  - summary regeneration
397  - conditional/fail outcomes
398  - broader review orchestration behavior
399  - richer merge/archive ceremony beyond the narrow archive checkpoint path
```

Note: the source TODO points at `go-cli-contract.md:385-388` for the "does NOT enforce X" passage. Reading the surrounding block, the **does-NOT-enforce list is at lines 392-399**; lines 385-388 are the *does-enforce* list. The TODO author appears to have inverted the citation — the actual contradicting "does NOT" passage is **lines 392-399**, and that is what needs to be reconciled. Lines 385-388 (the does-enforce list) are not contradicted; they describe the same narrow scope as the Pi document.

#### Side B: "enforces X" (pi-step-ceremony-and-artifact-enforcement.md)

`docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:374-388`:

```
374  - current-step artifacts now expose backend validation data, and
375    `row complete` / `row transition` block on validation failures rather than
376    only missing files or incomplete scaffold sentinels
377  - the plan step now has a scaffoldable/validatable `implementation-plan.md`
378    artifact in the same backend contract surface
379  - coordinated `implement` rows now validate carried decompose artifacts such as
380    `plan.json` and `team-plan.md` before allowing the boundary to review
381  - `review` rows now treat durable review artifacts under `reviews/` as
382    first-class current-step artifacts and require recognizable passing review
383    evidence before archive can proceed
384  - the backend now also exposes `furrow review status --json` and
385    `furrow review validate --json` read surfaces that normalize review artifacts
386    into Phase A / Phase B / overall verdict summaries, synthesized-override
387    detection, severity summaries, and follow-up/disposition signals
388  - `furrow row status` now exposes checkpoint action/evidence, latest gate
```

#### The contradiction in plain language

`go-cli-contract.md:392-399` declares the backend "does NOT enforce" full gate-policy enforcement, conditional/fail outcomes, broader review orchestration, or richer merge/archive ceremony. `pi-step-ceremony-and-artifact-enforcement.md:374-388` describes the backend *enforcing* per-step artifact validation, plan/decompose artifact validation, review artifact validation as a precondition to archive, and `furrow review validate --json` orchestration — features that overlap with "review orchestration" and "conditional/fail outcomes" called out as not-enforced in the contract doc.

This is scope creep: the Pi-step-ceremony doc has accreted enforcement claims that broaden past the contract surface declared in `go-cli-contract.md`.

#### Proposed reconciliation insertion (per D5 AC.3)

Per AC D5.3, the deferral note is dated **2026-04-25** and names `artifact-validation-per-step-schema` as the closing TODO. The cleanest insertion site is `go-cli-contract.md`, immediately after line 399 (i.e., at the end of the "still does not enforce" block, before "Current exit behavior" at line 401):

> **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**: there is currently scope ambiguity between the not-enforced list above and `pi-step-ceremony-and-artifact-enforcement.md:374-388`, which describes per-step artifact validation, decompose-artifact validation, and review-artifact validation as enforced preconditions. The boundary between "narrow blocker baseline" (this contract) and "per-step artifact validation" (Pi-step-ceremony) is left to TODO `artifact-validation-per-step-schema` (`.furrow/almanac/todos.yaml`), which will define `schemas/step-artifact-requirements.yaml` and bind both documents to a single authoritative spec. Until that TODO closes, treat per-step artifact validation as in-scope for the backend and `pi-step-ceremony-and-artifact-enforcement.md:374-388` as the operative description.

D5's `file_ownership` includes `docs/architecture/go-cli-contract.md` but **not** `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md` (see `definition.yaml:84-88`). The reconciliation note must therefore land in `go-cli-contract.md`. No symmetric edit to the Pi-step-ceremony doc is in scope for D5.

#### Note on TODO citation accuracy

The source TODO cites `go-cli-contract.md:385-388` and `pi-step-ceremony-and-artifact-enforcement.md:375-380`. As verified above:
- `go-cli-contract.md:385-388` is the *does-enforce* list, not the does-NOT-enforce list. The actual "does NOT enforce" passage is at **lines 392-399**.
- `pi-step-ceremony-and-artifact-enforcement.md:375-380` falls inside the broader enforcement-claim block at **lines 374-388**.

The implement step should treat `go-cli-contract.md:392-399` and `pi-step-ceremony-and-artifact-enforcement.md:374-388` as the canonical contradicting passages, and may note the TODO's off-by-N line citation as a research-step finding (not a doc edit — D5 does not own `todos.yaml`).

---

### D.4 Meta-pattern check (per D5 AC.4)

D5 AC.4: *"`docs/architecture/documentation-authority-taxonomy.md` is updated only if at least 2 of the 3 reconciliations exhibit the same anti-pattern."*

Anti-patterns by contradiction:
1. **Seed-timing**: target-state-stated-as-current-state — a future-tense canonical claim ("seeds replace TODOs as the canonical planning primitive") written without temporal qualification, leaving readers to infer it applies now.
2. **Blocker-enforcement split**: asymmetric specification — one host's enforcement enumerated canonically, the other left implicit, in violation of the shared-semantics invariant.
3. **Artifact validation scope creep**: scope-creep-via-implementation-doc — a how-it-works doc (`pi-step-ceremony-and-artifact-enforcement.md`) accumulated enforcement claims that broadened past the contract doc (`go-cli-contract.md`).

(1) and (3) share a structural pattern: a canonical/contract document states a tighter scope; a sibling document (planning-target in (1), implementation-state in (3)) states a looser/forward-leaning scope; no temporal or authority qualifier reconciles them. This is "**target-or-implementation doc overrides contract doc without explicit precedence rule**."

(2) is structurally distinct (silent gap in one host vs explicit invariant), so the shared anti-pattern is only between (1) and (3).

**Recommendation**: D5 AC.4 says "if at least 2 of the 3" — (1) and (3) qualify. A small note in `docs/architecture/documentation-authority-taxonomy.md` is justified, capturing the meta-rule: *"When a target-state or implementation-state document states a scope that exceeds the canonical contract document, the contract document wins until an explicit precedence rule (date, phase, or TODO closure) is added to the target/implementation doc."*

D5's `file_ownership` includes `docs/architecture/documentation-authority-taxonomy.md` (`definition.yaml:88`), so this update is in scope. Keep it brief — AC.4 explicitly forbids speculative additions.

---

## Sources Consulted

| Path | Tier | Purpose |
|---|---|---|
| `tests/integration/run-all.sh` | primary | CI runner conventions (Section C) |
| `tests/integration/helpers.sh` | primary | Shared assertion library (Section C) |
| `tests/integration/lib/sandbox.sh` | primary | Sandbox isolation contract (Section C) |
| `tests/integration/test-rws.sh` | primary | Canonical sandboxed-test pattern (Section C) |
| `tests/integration/test-ownership-warn-hook.sh` | primary | Live-row hook-test pattern + Go invocation example (Section C) |
| `tests/integration/fixtures/merge-e2e/` (listing) | primary | Existing fixture-tree precedent (Section C) |
| `bin/frw.d/hooks/ownership-warn.sh:61` | primary | `go run ./cmd/furrow ...` invocation idiom (Section C) |
| `cmd/furrow/main.go` (presence) | primary | Go binary entrypoint (Section C) |
| `internal/cli/blocker_envelope.go` (listing) | primary | Existing taxonomy types (Section C) |
| `Makefile` / `.github/workflows/` | primary (absent) | Confirmed neither exists; CI = `run-all.sh` (Section C) |
| `.furrow/almanac/todos.yaml:3824-3840` | primary | Source TODO `doc-contradiction-reconciliation` text (Section D.0) |
| `docs/architecture/pi-almanac-operating-model.md:148-159` | primary | Side A of contradiction (1) (Section D.1) |
| `docs/architecture/pi-almanac-operating-model.md:319-327` | primary | Existing transitional rule (Section D.1) |
| `docs/architecture/pi-almanac-operating-model.md:383-391` | primary | Phase 5 deferral, Side B of contradiction (1) (Section D.1) |
| `docs/architecture/migration-stance.md:86-89` | primary | Side A of contradiction (2) — shared-semantics invariant (Section D.2) |
| `docs/architecture/go-cli-contract.md:381-399` | primary | Side A of contradiction (3) — "does NOT enforce" (Section D.3) |
| `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:374-388` | primary | Side B of contradiction (3) — enforcement claims (Section D.3) |
| `.furrow/rows/blocker-taxonomy-foundation/definition.yaml` | primary | D4/D5 acceptance criteria + file_ownership (Sections C, D) |
| `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md:267-300` (referenced) | secondary | "Blocker baseline" section cited by definition.yaml as source-of-truth for blocker codes (background for D5.2) |
