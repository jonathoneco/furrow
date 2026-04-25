# Research: pi-row-audit-cleanup

Research closes the three open questions surfaced by the ideate-step recommendations:

1. Where do `validation.md` / `handoff.md` enumerate the deliverables that shipped in commit `e4adef5`? (informs **pi-step-ceremony-backfill** manifest content)
2. Where does the archive command surface live, and where should supersedence-evidence rejection be enforced? (informs **pi-adapter-foundation-archive** implementation site)
3. What is the canonical `bin/rws` → Go delegation pattern? (informs **repair-deliverables-cli** shim acceptance criterion)

---

## Topic 1 — pi-step-ceremony deliverables and evidence (informs `pi-step-ceremony-backfill`)

### Canonical deliverable list

The archived row's own `definition.yaml` is the source of truth for deliverable names. Three deliverables — not "5+" as the source TODO prose loosely claimed:

| Name | Status | Commit | Evidence path |
|---|---|---|---|
| `backend-work-loop-support` | completed | e4adef5 | `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/validation.md:3-45` (test coverage), `:63-72` (post-spec validation), `handoff.md:9-16` (outcome summary) |
| `pi-work-command` | completed | e4adef5 (with prior fcb901f, c05edaf in same session) | `validation.md:46-52` (headless `/work`), `:53-61` (supervised loop), `:86-92` (spec→decompose), `:152-156` (archived-row blocking) |
| `validation-and-doc-drift` | completed | e4adef5 | `validation.md:1-173` (full test coverage), `:73-84` (almanac + doctor passes), `handoff.md:25-48` (files changed) |

### Manifest construction notes

- All three deliverables map cleanly to commit `e4adef5`. No deliverable spans pre-e4adef5 commits requiring a different `commit` field; the `pi-work-command` deliverable's prior commits (fcb901f, c05edaf) are part of the same logical change but the row's archive checkpoint references `e4adef5` as the consolidating commit.
- No `decompose.md` exists for pi-step-ceremony-and-artifact-enforcement; deliverable names come exclusively from `definition.yaml`. This is fine — the manifest schema (per ideate Decision 2) takes deliverable names directly, not via decompose-step reconstruction.
- `validation.md` and `handoff.md` are internally consistent. No discrepancies to reconcile.

### Sources Consulted (Topic 1)

- **Primary**: `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/definition.yaml` (deliverable names), `validation.md` (evidence anchors), `handoff.md` (outcome summary), `git show --stat e4adef5` (commit reachability + scope confirmation)
- **Tier**: Primary throughout. No secondary sources needed.

---

## Topic 2 — Archive surface and rejection site (informs `pi-adapter-foundation-archive`)

### Current archive surface map

| Surface | Path | Role |
|---|---|---|
| Go canonical | `internal/cli/row.go:400-510` (`runRowArchive`) + `internal/cli/app.go:94-95` (entry) | Validates preconditions (step=review, step_status=completed, no incomplete deliverables, passing implement→review gate); calls `rowBlockers()` (`internal/cli/row_workflow.go:994-1038`); writes gate evidence to `gates/review-to-archive.json`; atomic state.json update |
| Shell legacy | `bin/rws:1958-2020` (`rws_archive`) | Duplicates Go preconditions; does NOT call `rowBlockers()`; updates state.json directly without evidence JSON |
| Slash command | `commands/archive.md:1-66` | Orchestrates: learnings promotion → component promotion → TODO extraction → archive ceremony → `rws archive` (line 59) → summary regen → git commit. Final mutation goes through shell, not Go. |

**Implication for D3 file_ownership:** the file `internal/cli/row_archive.go` named in the current `definition.yaml` does not exist and should not be created — archive logic already lives in `internal/cli/row.go` and the blocker hook in `internal/cli/row_workflow.go`. The plan step should revise file_ownership to `internal/cli/row_workflow.go` (where the supersedence-evidence blocker is added) and `internal/cli/row.go` (only if `runRowArchive` needs adjustment to surface the blocker; likely already does via `rowBlockers()`). The `bin/rws` ownership entry stays (the shell shim mirroring stays minimal).

**Also surfaced:** `commands/archive.md` final delegation to `rws archive` (shell), not `furrow row archive` (Go). The Go path is feature-richer (blockers, gate evidence) but is bypassed by the slash command. Out-of-scope for this row, but worth a follow-up TODO at archive time: route `commands/archive.md` through Go instead of shell.

### Recommended rejection site

**`rowBlockers()` in `internal/cli/row_workflow.go:994-1038`.**

Rationale:
- This is where archive preconditions are enforced systematically (pending_user_actions, seed state, artifact validation, review-gate existence).
- It already returns `[]map[string]any` blockers consumed by `runRowArchive()` at `row.go:436`. Adding a new blocker type (`code: "supersedence_evidence_missing"`) is additive and zero-coupling to other surfaces.
- Honors clean-swap: rejection in Go, shell `rws archive` remains unmodified (and increasingly should be deprecated, but that's not this row's scope).

### Existing `archive.json` shape

Per `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/gates/review-to-archive.json`:

```json
{
  "boundary": "review->archive",
  "overall": "pass",
  "reviewer": "furrow row archive",
  "timestamp": "...",
  "phase_a": {
    "review_gate": {...},
    "seed": {...},
    "artifacts": [],
    "artifact_validation": {...},
    "archive_ceremony": {...},
    "blockers": []
  }
}
```

No existing `supersedence_evidence` field. Implementation can stay schema-stable: rejection lives in `phase_a.blockers` array (already the rejection enforcement point — `len(blockers) > 0 → fail`). No `state.schema.json` change required, which honors the constraint "Manifest schema is additive — does not modify state.schema.json."

### Implementation hints

- Add blocker case in `rowBlockers()` after seed checks (~line 1013) and before artifact checks (~line 1014).
- Detection pattern: when row name == `pi-adapter-foundation`, require gate evidence to name commit `e4adef5` and row `pi-step-ceremony-and-artifact-enforcement`. **Do not hardcode the row name** — generalize via a row-level "requires_supersedence_evidence" marker (likely in definition.yaml or an archive-time CLI flag like `--supersedes <commit>:<row>`). Spec step should decide.
- Use existing helpers: `latestPassingReviewGate()` (`row_workflow.go:749`) for gate fetch, `loadJSONMap()` (`row_semantics.go:689`) for evidence-path payload deserialization.
- Negative test: archive without supersedence flag → blocker raised → exit non-zero. Positive test: archive with valid supersedence → exit zero, archived_at set.

### Unverified / deferred to spec

- Whether the supersedence requirement is row-specific (only triggered for `pi-adapter-foundation` by name) or generalized via a flag/marker. Recommend the latter; spec step decides.
- Whether the slash command `commands/archive.md` line 59 should be updated to pass `--supersedes` through. Out of scope for this row; flag as follow-up.

### Sources Consulted (Topic 2)

- **Primary**: `internal/cli/row.go`, `internal/cli/row_workflow.go`, `internal/cli/app.go`, `bin/rws`, `commands/archive.md`, `.furrow/rows/pi-step-ceremony-and-artifact-enforcement/gates/review-to-archive.json` (live archive evidence example), `schemas/state.schema.json`
- **Tier**: All primary. No external docs needed; archive surface is fully repo-internal.

---

## Topic 3 — `bin/rws` → Go shim pattern (informs `repair-deliverables-cli` AC 8)

### Existing Go subcommands (cmd/furrow)

Registered in `cmd/furrow/main.go` + `internal/cli/app.go`:

- `row` (status, list, transition, complete, archive, init, focus, scaffold) — full
- `review`, `almanac validate`, `doctor` — full
- `gate` (run, evaluate, status, list) — stubbed
- `seeds` (create, update, show, list, close) — stubbed
- `merge` (plan, run, validate) — stubbed

### Delegation pattern in bin/rws today

**None.** `bin/rws` (lines 2937-2968) uses pure POSIX shell `case` dispatch:

```
init) rws_init "$@" ;;
transition) rws_transition "$@" ;;
complete-deliverable) rws_complete_deliverable "$@" ;;
```

Each subcommand maps to a shell function defined earlier in the file. `bin/alm` and `bin/sds` are similarly pure shell. Despite Go subcommands existing in `cmd/furrow`, **no shell entry currently delegates to Go** — the Go path is reachable only via `furrow ...` directly, not via `rws ...`. **This row introduces the first such shim**, which makes its shape load-bearing for future ports (Phase 7 row 1 `cli-introspection-and-history` will follow this pattern at scale).

### Canonical shim pattern (D1 acceptance criterion 8)

Insertion point: after `bin/rws:2954` (after the `complete-deliverable` case). Pattern:

```sh
repair-deliverables)
  FURROW_BIN="${FURROW_BIN:-${FURROW_ROOT}/bin/furrow}"
  if [ ! -x "$FURROW_BIN" ]; then
    die "furrow binary not found at $FURROW_BIN; run 'go build ./cmd/furrow'"
  fi
  exec "$FURROW_BIN" row repair-deliverables "$@"
  ;;
```

Key elements:
- `FURROW_BIN` env var override with default to `${FURROW_ROOT}/bin/furrow`. `FURROW_ROOT` is already established in bin/rws context — verify exact env var name during implement step.
- Existence check fails fast with `die` (existing helper in bin/rws) and a build hint.
- `exec` (not function call) preserves exit codes and avoids shell-process overhead.
- Pure passthrough — no validation, no state read, no sed/awk post-processing.

### Anti-patterns to avoid

- No kebab-case validation, no gate checks in the shim — Go owns input validation.
- No state.json reads/writes in the shim.
- No output transformation — Go's stdout/stderr/exit-code passes through.
- Shim should NOT also accept `--manifest` validation flags as a courtesy; the Go binary owns flag parsing entirely.

### Sources Consulted (Topic 3)

- **Primary**: `bin/rws` (full file scan), `bin/frw`, `bin/alm`, `bin/sds`, `cmd/furrow/main.go`, `internal/cli/app.go`. Verified absence of any current shell→Go delegation via grep for `exec.*furrow` and `command furrow`.
- **Tier**: All primary. Pattern is novel to this codebase — no secondary source applies.

---

## Cross-topic synthesis

Three definition.yaml revisions are warranted before plan step (to be applied via the plan step's spec output, since definition is gate-locked):

1. **D2 manifest content is fully determined** — the three deliverable names + evidence anchors are concrete. Plan step can write the exact manifest skeleton.
2. **D3 file_ownership needs adjustment** — `internal/cli/row_archive.go` (named in definition.yaml) does not exist and should not be created. Replace with `internal/cli/row_workflow.go` (blocker addition) and confirm `internal/cli/row.go` (if `runRowArchive` needs adjustments). Plan step decides; spec step formalizes.
3. **D3 generalization** — the supersedence-evidence requirement should be parameterized (row marker or `--supersedes` flag), not hardcoded to `pi-adapter-foundation`. Spec step decides the parameter shape.

No blockers to advance to plan. All three research questions are closed with primary-source citations.

## Sources Consulted (overall)

- See per-topic Sources Consulted sections above. All primary; no unverified claims requiring tertiary-source caveat.
