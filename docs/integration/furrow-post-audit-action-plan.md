# Furrow Post-Audit Action Plan

Date: 2026-04-28

Purpose: convert the philosophy audit and truth hardening review into concrete
work. This is an execution plan, not another audit.

## 1. Executive decision

What we are doing next:

- Replace the current Phase 5 with a narrower deletion/collapse phase.
- First simplify the planning source of truth and advertised command surface.
- Keep only protections that force truth: row state, evidence, context bundle,
  layer policy, handoff isolation, checkpoint readiness, and archive readiness.
- Treat Pi and Claude as adapters over backend-owned decisions. Adapter parity
  claims only count through loaded runtime paths.
- Convert large audit findings into 4 bounded rows. Anything else is backlog or
  dead.

What we are explicitly not doing next:

- No new almanac, roadmap, TODO, dashboard, TUI, or planning UX.
- No new abstract architecture layer.
- No new audit layer.
- No new semantic behavior in shell CLIs.
- No broad Pi parity claim beyond loaded main-thread paths.
- No canonical Pi handler schema document before handler scope is reduced.
- No research rows unless they land or kill a concrete implementation decision.

Phase 5 decision:

- Current Phase 5 does not proceed as written.
- It is replaced by `Phase 5: Post-audit collapse`.
- Only layer-guard rejection hardening stays in the immediate path because it
  protects the operator from invisible enforcement failures.
- Pi state/correction guard expansion, correction-limit visibility, session
  reground, and canonical Pi handler schema are removed from Phase 5.

## 2. Action principles

- No new semantic behavior in shell CLIs. Shell stays compatibility-only until
  deletion.
- Every transitional surface needs a cutoff, owner, and protection that remains
  after removal.
- Planning memory is preserved only if it feeds row selection, dependency
  checks, or truth gates.
- Adapter parity means live loaded path only. Fixtures for absent handlers are
  inventory, not evidence.
- Backend owns truth decisions; adapters translate runtime events and render UX.
- Delete or hide advertised stubs before implementing new command families.
- Completion evidence outranks TODO capture. A TODO cannot make a false claim
  true.
- Always-on context must fit the core harness contract: real ask, evidence,
  context bundle, layer, handoff, checkpoint, archive.

## 3. Next 4 work units

### Work Unit 1: Collapse Active Planning Surface

Goal:

- Reduce the roadmap to the next concrete rows and demote the large TODO graph
  to backlog input.

Concrete scope:

- Edit `.furrow/almanac/roadmap.yaml` after this plan is approved.
- Replace current Phase 5 with the post-audit collapse phase.
- Move current Phases 6-15 behind a single `post-collapse backlog` marker or
  equivalent deferred section.
- Mark rows that add roadmap/TODO UX as blocked until source-of-truth
  simplification lands.
- Do not convert todos to seeds in this row.

Files/surfaces likely touched:

- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/todos.yaml` only for status or dependency wording if the
  roadmap validator requires it
- `docs/integration/furrow-post-audit-action-plan.md` only as reference

What gets deleted/collapsed:

- Collapse 15 planned phases into the next 3-5 executable rows plus deferred
  backlog.
- Remove Phase 5's bundled Pi UX/schema work from immediate execution.
- Collapse planning authority from roadmap-plus-TODO-product to roadmap as row
  selector and TODOs as backlog input.

What protection is preserved:

- Work identity, dependency visibility, and row selection remain.
- Completion evidence still forces roadmap/TODO wording updates when claims are
  downgraded.
- Almanac validation remains the check against broken references.

What is explicitly out of scope:

- No seed migration.
- No Pi planning UI.
- No TODO schema redesign.
- No deletion of `todos.yaml`.
- No new planning command.

Verification:

- `furrow almanac validate`
- `rg -n "State \\+ correction guards|state-and-correction-guards|Pi tool_call extends|footer widget|session-resume reground" .furrow/almanac/roadmap.yaml`
- Manual check that the first executable phase contains only collapse/protection
  work.

Exit criteria:

- Roadmap shows Phase 5 as post-audit collapse, not state/correction guards.
- Next 3-5 rows are concrete enough to start from branch names and file
  surfaces.
- No roadmap row introduces new almanac/TODO UX before source-of-truth
  simplification.

### Work Unit 2: Hide or Label Vaporware Command Surface

Goal:

- Stop advertising command behavior that is not implemented.

Concrete scope:

- Inventory Go CLI help and command markdown for `gate`, `seeds`, `merge`, and
  row leaves that return `not_implemented`.
- Either remove those commands from user-facing help or label them `reserved`
  with no operational promise.
- Update command markdown references that still instruct `rws transition`,
  `rws status`, or `alm validate` where a Go-backed command is canonical.

Files/surfaces likely touched:

- `internal/cli/`
- `cmd/furrow/`
- `commands/*.md`
- `.claude/CLAUDE.md`
- tests covering CLI help or command output

What gets deleted/collapsed:

- User-facing help entries for stub commands.
- Command markdown that acts like a second implementation of backend behavior.
- Shell-era command references where Go command equivalents exist.

What protection is preserved:

- Backend-owned command behavior remains canonical.
- Thin adapter docs can still route users to supported commands.
- Existing compatibility wrappers remain only as wrappers.

What is explicitly out of scope:

- Do not implement `gate`, `seeds`, or `merge`.
- Do not rewrite the whole command system.
- Do not remove shell wrappers yet.

Verification:

- `go test ./...`
- CLI help snapshot or equivalent test proving stubs are not advertised as live.
- `rg -n "not_implemented|rws transition|rws status|alm validate" commands .claude internal cmd`

Exit criteria:

- A user cannot discover a stub command as if it were supported behavior.
- Remaining shell command mentions are explicitly compatibility or historical.

### Work Unit 3: Layer-Guard Rejection Hardening

Goal:

- Preserve layer protection while making rejections diagnosable and recoverable.

Concrete scope:

- Fix silent rejection: blocked layer-guard decisions must emit meaningful
  stderr while preserving stdout JSON for adapters.
- Distinguish policy-load failure from policy-decision block in the verdict.
- Add narrow recovery behavior only for authentic policy-load failures if the
  current hook chain would otherwise self-brick.
- Keep loaded-path Pi/Claude behavior honest.

Files/surfaces likely touched:

- `internal/cli/hook/layer_guard.go`
- `internal/cli/hook/layer_guard_test.go`
- `internal/cli/layer/`
- `.claude/settings.json` only if hook invocation needs no-op wording change
- `adapters/pi/furrow.ts` only if stderr/stdout handling must be preserved

What gets deleted/collapsed:

- Collapse overlapping `layer-guard-silent-rejection...`,
  `layer-guard-verdict-reason...`, and hook-chain self-brick work into one
  protection row.
- Do not create a new layer policy abstraction.

What protection is preserved:

- Engines still cannot mutate harness state through denied paths.
- Backend layer decision remains canonical.
- Adapter paths still call the backend decision surface.

What is explicitly out of scope:

- No Pi subagent parity.
- No tokenization-aware bash hardening unless needed for the diagnostic fix.
- No canonical handler schema.
- No broader layer-policy redesign.

Verification:

- `go test ./...`
- Existing layer policy integration tests.
- A negative hook fixture that proves stderr contains the rejection reason.
- A policy-load-failure fixture that proves recovery behavior is narrow.

Exit criteria:

- Rejections are visible to the operator.
- Policy-load failures no longer create an unrecoverable edit block.
- Real policy blocks still block.

### Work Unit 4: Source Field and Vocabulary Collapse

Goal:

- Remove duplicate row vocabulary that expands validators and planning
  reasoning.

Concrete scope:

- Canonicalize `source_todos` as the array field. Read `source_todo` only as a
  migration fallback.
- Canonicalize one branch field in backend row state. Adapters may render aliases
  only at boundaries.
- Identify `rows` versus `work_units` vocabulary in active schemas/docs and
  collapse active surfaces to `row`.

Files/surfaces likely touched:

- `schemas/definition.schema.json`
- row validation code in `internal/cli/`
- `.furrow/rows/*/definition.yaml` migrations if required
- tests for row definition validation
- active docs that describe current schema fields

What gets deleted/collapsed:

- `source_todo` as an active field.
- Duplicate `branch`/`branch_name` authority.
- Active `work_unit` terminology where it means row.

What protection is preserved:

- Existing archived rows remain readable.
- Source work traceability remains through the canonical array.
- Branch traceability remains through the backend-owned field.

What is explicitly out of scope:

- No sweeping schema audit.
- No seeds migration.
- No roadmap restructuring beyond references needed for schema truth.

Verification:

- `go test ./...`
- Schema validation for migrated/current rows.
- `furrow almanac validate`
- `rg -n "source_todo:|branch_name|work_units" schemas internal docs .furrow/rows`

Exit criteria:

- New rows have one source field and one branch field.
- Legacy forms are read-only migration compatibility.
- Validator code is smaller or no larger than before.

## 4. Phase 5 decision

Current `work/state-and-correction-guards` breakdown:

| Scope item | Classification | Decision |
| --- | --- | --- |
| Pi `tool_call` state guards for bash `rm`/`cp`/`mv` | narrow | Keep only if tied to an existing false-state-mutation path. Do not expand handler families speculatively. Move after layer-guard hardening. |
| Correction-limit visibility | defer | Visibility only. Backend already blocks at completion. Defer until repeated Pi grinding is current user pain after collapse work. |
| Session reground | defer | Useful UX, not truth simplification. Defer until command/context surface is smaller. |
| Canonical Pi handler schema | drop for now | It creates a new architecture surface before handler scope is reduced. Reconsider only if multiple live loaded handlers remain after collapse. |
| Layer-guard rejection hardening | keep now | Silent blocks and self-bricking damage the protection itself. Fold related layer-guard TODOs into one row. |

Revised Phase 5 scope:

- `work/post-audit-planning-collapse`
- `work/hide-vaporware-command-surface`
- `work/layer-guard-rejection-hardening`
- `work/source-field-vocabulary-collapse`

No Pi UX row is in revised Phase 5. No seed cutover is in revised Phase 5.

## 5. Deletion/collapse backlog

Immediate deletes/collapses:

- Collapse current Phase 5 bundle into the revised Phase 5 rows.
  Protection remaining: layer guard still blocks real violations; backend
  correction/archive gates remain.
- Hide or label stub Go command groups.
  Protection remaining: users see only supported backend behavior.
- Freeze shell CLIs against new semantic behavior.
  Protection remaining: compatibility remains while canonical Go paths mature.
- Collapse layer-guard diagnostic TODOs into one row.
  Protection remaining: same policy, clearer failures.

Near-term deletes/collapses:

- Collapse `source_todo`/`source_todos`.
  Protection remaining: source traceability through one array field.
- Collapse `branch`/`branch_name`.
  Protection remaining: branch traceability through one backend field.
- Collapse command markdown from procedural implementation into thin adapter
  docs.
  Protection remaining: backend command contracts own behavior.
- Delete or archive `team-plan.md` as an active concept.
  Protection remaining: handoff and review artifacts remain row-local.
- Collapse always-on shared protocol text into one core contract plus lazy
  references.
  Protection remaining: decision-point references still load when needed.

Explicitly postponed deletes/collapses:

- Delete `todos.yaml` as canonical planning primitive.
  Protection remaining after eventual removal: one canonical work source plus
  derived views. Postponed because the source-of-truth cutover has not shipped.
- Remove `bin/rws`, `bin/alm`, `bin/sds`, and `bin/frw.d/hooks/`.
  Protection remaining after eventual removal: Go backend commands and adapter
  shims. Postponed until parity is proven for each protected path.
- Archive `bin/frw.d/scripts/`.
  Protection remaining after eventual removal: Go worktree, merge, install, and
  phase lifecycle commands. Postponed until those commands exist.
- Pi correction footer and session reground.
  Protection remaining while postponed: backend correction limits and current
  row/context artifacts.
- Pi subagent layer parity.
  Protection remaining while postponed: loaded main-thread Pi enforcement and
  documented limitation.

## 6. Roadmap edit recommendation

Make these exact roadmap changes after this plan is approved:

- Rename Phase 5 from `State + correction guards (single row)` to
  `Post-audit collapse`.
- Replace Phase 5 rationale with:
  `The audit found Furrow's truth protections worth keeping but the planning,
  command, shell, and adapter surfaces overgrown. This phase narrows the next
  work to deletion/collapse rows before any new roadmap/TODO UX, Pi UX, or
  seed cutover work.`
- Replace the single Phase 5 row `work/state-and-correction-guards` with four
  rows:
  - `work/post-audit-planning-collapse`
  - `work/hide-vaporware-command-surface`
  - `work/layer-guard-rejection-hardening`
  - `work/source-field-vocabulary-collapse`
- Remove these todos from Phase 5:
  - `pi-correction-limit-visibility`
  - `pi-session-resume-reground`
  - `pi-tool-call-canonical-schema-and-surface-audit`
  - `state-guard-rm-coverage`
- Move `layer-guard-silent-rejection-on-top-layer-integrat` into
  `work/layer-guard-rejection-hardening`.
- Add `layer-guard-verdict-reason-should-also-write-to-st` and
  `hook-chain-must-allow-edit-on-recovery-paths-when` to
  `work/layer-guard-rejection-hardening` if roadmap references require todos.
- Add a roadmap note before Phase 6:
  `Phases after Phase 5 are provisional until planning source-of-truth
  simplification lands. Do not add almanac/TODO UX before that cutoff.`
- Mark rows adding roadmap/TODO UX as blocked by
  `work/post-audit-planning-collapse`.
- Keep `todos.yaml` canonical until an approved source-of-truth cutover row
  replaces it. Do not move to seeds as part of this edit.

Do not edit `.furrow/almanac/roadmap.yaml` in this session.

## 7. First implementation prompt

Copy-paste prompt for the next Codex/Furrow session:

```text
You are in /home/jonco/src/furrow.

Mission: implement the first post-audit collapse row: work/post-audit-planning-collapse.

Read first:
- docs/integration/furrow-post-audit-action-plan.md
- docs/integration/furrow-philosophy-audit.md
- docs/integration/roadmap-truth-hardening-audit.md
- .furrow/almanac/roadmap.yaml
- .furrow/almanac/todos.yaml

Constraints:
- Implement only the roadmap/planning collapse row.
- Edit .furrow/almanac/roadmap.yaml only after grounding in current git state.
- Do not implement code.
- Do not migrate todos to seeds.
- Do not add roadmap/TODO UX.
- Do not create another audit or planning doc.
- Preserve row selection, dependency visibility, completion evidence, and almanac validation.
- Replace current Phase 5 with the revised post-audit collapse scope from the action plan.
- Make later phases explicitly provisional until planning source-of-truth simplification lands.

Verification:
- furrow almanac validate
- rg -n "State \\+ correction guards|state-and-correction-guards|Pi tool_call extends|footer widget|session-resume reground" .furrow/almanac/roadmap.yaml
- git diff -- .furrow/almanac/roadmap.yaml .furrow/almanac/todos.yaml

Exit criteria:
- Phase 5 is post-audit collapse, not state/correction guards.
- The next rows are concrete and bounded.
- No new almanac/TODO UX is introduced.
- Roadmap validates.
```

POST_AUDIT_ACTION_PLAN_COMPLETE
