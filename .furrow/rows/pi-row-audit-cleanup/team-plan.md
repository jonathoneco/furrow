# Team Plan: pi-row-audit-cleanup

## Scope Analysis

Three deliverables; one shared theme (audit-cleaning Phase 3's row recording layer). Linear dependency chain — D1 provides the CLI surface, D2 consumes it once on a single row, D3 builds the archive-time enforcement and runs the live archive. No parallel wave is possible: D2's verification depends on D1's binary being built; D3's pre-archive transitions depend on D2 having corrected the sibling row's deliverables map (so the supersedence acknowledgement points at a row whose state matches the audit trail).

Code spans:
- Go: D1 + D3 share `internal/cli/`. D1 adds `row_repair.go` (new), modifies `app.go`. D3 modifies `row_workflow.go` (rowBlockers + struct), `row.go` (runRowArchive call site + flag plumbing), `app.go` (different surface from D1's edit). Both D1 and D3 carry test files.
- Schemas: D1 adds `schemas/repair-deliverables-manifest.schema.json` (new). D3 modifies `schemas/definition.schema.json` (additive `supersedes` block).
- Row data: D2 writes one manifest YAML; D3 writes one supersedes block in pi-adapter-foundation's definition.yaml plus modifies handoff.md in the sibling row.
- Shell: D1 adds one `case` to `bin/rws`. D3 does not touch `bin/rws` (Go-side flag only).

Vertical slicing: each deliverable is independently testable. D1 has 9 unit/integration scenarios (happy/sad/edge per AC). D2 has 4 operational scenarios (precheck, write, run, verify). D3 has 7 scenarios (3 negative, 1 positive, 1 guard, 1 live, 1 handoff/focus check). The chain is not parallelizable, but each slice is reviewable in isolation.

## Team Composition

Two specialists across three waves; one specialist multi-tasks. All effort fits within the supervised gate policy (human approves each step boundary).

| Specialist | Domain | Source template | Waves owned | Model hint |
|---|---|---|---|---|
| go-specialist | Go idioms, concurrency, interface design, error propagation | `specialists/go-specialist.md` | Wave 1 (D1) | sonnet (default) |
| harness-engineer | Workflow harness infrastructure: shell scripts, hooks, schemas, validation pipelines | `specialists/harness-engineer.md` | Wave 2 (D2), Wave 3 (D3) | sonnet (default) |

Rationale for harness-engineer on D3 (not go-specialist): D3 is primarily harness-shape work — schema additions, definition.yaml grammar, blocker taxonomy extension, gate evidence semantics, archive ceremony. The Go code is the implementation surface, but the architectural decisions (declarative supersedes, blocker emission, gate evidence echo) sit in harness-engineer's domain. Go-specialist owns Wave 1's brand-new CLI surface where Go idioms (parseArgs pattern, atomic writes, schema validation) dominate.

`test-driven-specialist` skill attached to D1 and D3 — both have non-trivial test surfaces with explicit per-AC scenarios documented in the spec. D2 has no `test-driven-specialist` attachment because its "tests" are operational verifications (jq probes after a one-shot run), not unit/integration tests.

## Task Assignment

### Wave 1 — D1 `repair-deliverables-cli` (go-specialist)

**Owned files:** `internal/cli/row_repair.go` (new), `internal/cli/row_repair_test.go` (new), `schemas/repair-deliverables-manifest.schema.json` (new), `internal/cli/app.go` (one new `case "repair-deliverables":`), `bin/rws` (one new shim block after line 2954).

**Spec entry point:** `specs/repair-deliverables-cli.md`. Implementation-ready; all signatures, exit codes, and schema body present.

**Done definition:**
- All 11 refined ACs satisfied
- 9 test scenarios pass (run via `go test ./internal/cli/... -run TestRowRepair`)
- `furrow row repair-deliverables --help` documents flags, exit codes
- Conventional commit: `feat(cli): add furrow row repair-deliverables manifest-driven CLI`
- bin/rws shim landed in same commit (additive, single line block)

### Wave 2 — D2 `pi-step-ceremony-backfill` (harness-engineer)

**Owned files:** `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml` (new), `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json` (mutated via D1's CLI; not edited directly).

**Spec entry point:** `specs/pi-step-ceremony-backfill.md`. Manifest content is verbatim in the spec; run sequence is 5 steps.

**Done definition:**
- Precheck `git cat-file -e e4adef5` exits 0
- Manifest written exactly as spec'd (3 deliverables, evidence_paths arrays per spec)
- `furrow row repair-deliverables pi-step-ceremony-and-artifact-enforcement --manifest .furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-manifest.yaml` exits 0
- `jq '.deliverables | keys | length' .furrow/rows/pi-step-ceremony-and-artifact-enforcement/state.json` returns 3
- `tail -1 .furrow/rows/pi-step-ceremony-and-artifact-enforcement/repair-audit.jsonl | jq '.entries_added | length'` returns 3
- `rws status pi-step-ceremony-and-artifact-enforcement` reports 3 deliverables
- Conventional commit: `chore(furrow): backfill pi-step-ceremony-and-artifact-enforcement deliverables map`

### Wave 3 — D3 `pi-adapter-foundation-archive` (harness-engineer, with test-driven-specialist skill)

**Owned files:** `internal/cli/row_workflow.go`, `internal/cli/row.go`, `internal/cli/app.go`, `internal/cli/row_workflow_test.go`, `schemas/definition.schema.json`, `.furrow/rows/pi-adapter-foundation/definition.yaml`, `.furrow/rows/pi-adapter-foundation/state.json`, `.furrow/rows/pi-adapter-foundation/gates/review-to-archive.json`, `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`.

**Spec entry point:** `specs/pi-adapter-foundation-archive.md`. The most complex deliverable; rowBlockersOpts struct + 4 call-site updates + flag wiring + schema addition + live archive.

**Sub-tasks (commit ordering enforced per spec input #8):**

1. **D3a — schema + code (commit 1)**:
   - Extend `schemas/definition.schema.json` with optional `supersedes: { commit, row }` block
   - Add `rowBlockersOpts` struct in `internal/cli/row_workflow.go`
   - Update `rowBlockers()` signature; update all 4 call sites (3 pass zero value, 1 — runRowArchive — passes populated opts)
   - Insert supersedence-evidence-missing blocker logic
   - Register `--supersedes-confirmed` flag in `runRowArchive` parseArgs
   - Add unit tests covering 5 scenarios (negative-missing-flag, negative-mismatch-commit, negative-mismatch-row, positive-match, guard-no-supersedes-block)
   - Conventional commit: `feat(cli): add supersedes block + --supersedes-confirmed flag with rowBlockers enforcement`

2. **D3b — definition.yaml + live archive (commit 2)**:
   - Add `supersedes: { commit: e4adef5, row: pi-step-ceremony-and-artifact-enforcement }` block to `.furrow/rows/pi-adapter-foundation/definition.yaml`
   - Run pre-archive transitions: `rws transition pi-adapter-foundation pass manual "phantom row, scope satisfied by sibling row pi-step-ceremony-and-artifact-enforcement (commit e4adef5)"` to advance implement→review; `rws complete-step pi-adapter-foundation`; verify `step=review, step_status=completed`
   - Run live archive: `furrow row archive pi-adapter-foundation --supersedes-confirmed e4adef5:pi-step-ceremony-and-artifact-enforcement`
   - Verify exit 0, `state.json.archived_at` non-null, `gates/review-to-archive.json.phase_a.blockers == []`, `phase_a.notes` contains `"supersedence confirmed: e4adef5:pi-step-ceremony-and-artifact-enforcement"`
   - Run `furrow row focus --clear` if `.focused` points at pi-adapter-foundation
   - Edit `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/handoff.md`: remove the `## Recommended next slice` block (lines 60-67 per spec)
   - Conventional commit: `chore(furrow): archive pi-adapter-foundation as superseded by pi-step-ceremony-and-artifact-enforcement (e4adef5)`

**Done definition:** All 12 ACs (11 from definition.yaml + AC-Guard) satisfied; 7 scenarios pass; both commits land in order; pi-adapter-foundation no longer shows in `rws list`.

## Coordination

- **Sequential, not parallel.** Wave N+1 begins only after Wave N's commit lands and tests pass. The supervised gate policy means each step boundary requires human approval before proceeding.
- **Shared file safety:**
  - `internal/cli/app.go` — Wave 1 adds `case "repair-deliverables":` to `runRow()`; Wave 3 modifies a separate surface (`runRowArchive`'s flag plumbing). Both edits are additive to different switch cases. No conflict.
  - `bin/rws` — Wave 1 only. Wave 3 confirmed not to touch `bin/rws` per spec input #4.
  - `internal/cli/row_workflow.go` — Wave 3 only. Wave 1 does not touch this file.
- **State.json mutation discipline (per `.claude/rules/cli-mediation.md`):**
  - Wave 2's state.json mutation goes through D1's CLI (the whole point of D1).
  - Wave 3's state.json mutations go through `rws transition` and `furrow row archive` — never direct edits.
  - The repair-manifest.yaml file (Wave 2 output) is not state; it's input to D1's CLI.
- **Audit trail expectations:**
  - D1's CLI writes `.furrow/rows/<row>/repair-audit.jsonl` (sidecar, not state.json) per locked Spec B2.
  - D3's archive writes `gates/review-to-archive.json` via `runRowArchive`'s existing path; supersedence echo lands in `phase_a.notes`.
- **Escalation path:**
  - If D1 schema validation cannot be inlined cleanly without external deps: implementer flags as a follow-up, not a workaround. Spec mandates manual validation in Go.
  - If D3b's `rws transition` blocks pi-adapter-foundation on missing implement-step artifacts: escalate to human; do not bypass the gate. Spec is explicit about this.

## Skills

| Skill | Applied to | Why |
|---|---|---|
| `test-driven-specialist` | D1, D3 | Both deliverables have explicit per-AC test scenarios in the spec; tests-first reasoning ensures every refined AC gets a verification before code lands. |
| `migration-strategist` | D3 (advisory) | The schema addition + definition.yaml extension is a small, in-place migration. The advisor's lens is appropriate when designing the supersedes block to avoid breaking existing definition.yaml files. |
| `complexity-skeptic` | D3 (advisory) | The rowBlockersOpts struct introduction is the kind of architectural choice the skeptic should re-validate at implement time — verify no over-engineering crept in between spec and code. |

The `harness-engineer` specialist itself carries domain expertise on schema additivity, gate evidence semantics, and the cli-mediation rule. The advisory skills above supplement that lens.

## Validation

- Every deliverable in definition.yaml appears in exactly one wave. ✓ (3 deliverables, 3 waves)
- `depends_on` ordering respected: D2 depends_on D1 → wave 2 follows wave 1; D3 depends_on D2 → wave 3 follows wave 2. ✓
- File ownership globs do not overlap within a wave (each wave has one deliverable, so trivially satisfied). ✓
- Cross-wave file overlap (`internal/cli/app.go`) documented as additive at non-overlapping switch cases. ✓
- All specialists referenced exist in `specialists/`. ✓
- Pre-step gate-check (decompose): supervised, multi-deliverable — pre-step does not trivially auto-advance. ✓
