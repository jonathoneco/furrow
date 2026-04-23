# /furrow:triage [--full]

Generate or update `.furrow/almanac/roadmap.yaml` (and optional `.furrow/almanac/roadmap.md`) from `.furrow/almanac/todos.yaml` with dependency-aware phase grouping and worktree parallelism strategy.

## Syntax

```
/furrow:triage        → Incremental: preserve completed phases, update remaining
/furrow:triage --full → Full regeneration: re-evaluate all phases from scratch
```

---

## Behavior

### 1. Validate Inputs

- Check `.furrow/almanac/todos.yaml` exists. Error if not: "No .furrow/almanac/todos.yaml found. Create TODOs first with `/work-todos --new`."
- Run `alm validate`. If invalid, show errors and abort.

### 2. Resolve Template

Check in order, use first found:
1. `furrow.yaml` key `roadmap.template` → use that path
2. `.claude/roadmap.tmpl` → project-level override
3. `templates/roadmap.md.tmpl` → Furrow default

Read `templates/roadmap-sections.yaml` for section registry (names, order, required/optional, repeating).

If no template found: error "No roadmap template found. Expected at templates/roadmap.md.tmpl".

### 3. Run Triage Script

```sh
alm triage
```

Parse JSON output containing:
- `todos`: array of active TODOs with triage metadata
- `graph`: topological order and wave assignments
- `conflicts`: file overlap pairs within same wave

If script exits non-zero (cycles, dangling deps): show error output, abort.

If `todos` array is empty: "All TODOs are completed or deferred. Nothing to roadmap."

### 4. Preserve Completed Phases (incremental mode only)

Skip this step if `--full` flag is set.

If `.furrow/almanac/roadmap.yaml` exists:
- Read it and identify phase sections
- Phases where ALL associated TODOs have `status: done` → mark as completed
- Preserve completed phase content verbatim in the output
- Only regenerate phases with active/blocked TODOs

### 5. Triage Missing Metadata

For each TODO missing `urgency`, `impact`, or `effort`:

Read its `context` and `work_needed` prose fields. Assess:

- **Urgency**: Is this blocking other work? Is there a time constraint?
  - `critical`: blocks multiple other TODOs or has an external deadline
  - `high`: blocks at least one other TODO
  - `medium`: important but not blocking
  - `low`: nice-to-have, can defer

- **Impact**: How many other items does this unblock?
  - `high`: unblocks 2+ downstream TODOs or enables a new capability
  - `medium`: unblocks 1 downstream or improves an existing workflow
  - `low`: self-contained improvement

- **Effort**: How many sessions would this take?
  - `small`: single session, 1-2 files
  - `medium`: 1-2 sessions, 3-5 files
  - `large`: 3+ sessions or cross-cutting

For TODOs missing `depends_on`: infer from prose. If `work_needed` or `context` references another TODO by name or describes a prerequisite relationship, add the dependency.

For TODOs missing `files_touched`: infer from `references` array and `work_needed` prose. Extract file paths and glob patterns mentioned.

#### 5a. Infer Foundational Dependencies

Beyond explicit prose references, reason about **structural dependencies** — cases where one TODO's changes would ripple into another TODO's merge or execution path:

- **Infrastructure TODOs**: A TODO that modifies shared infrastructure (bin/frw.d/, bin/rws, gate pipeline, state management, bin/alm, merge-to-main) is potentially foundational. Every other TODO that will eventually merge through that infrastructure has an implicit ordering constraint.
- **Merge implications**: If TODO A changes how branches merge, how gates evaluate, or how step transitions work, then TODOs B/C/D that will merge their worktree branches through that modified pipeline should land **after** A. Otherwise B/C/D are built against stale infrastructure and may need rework.
- **Enforcement layer effects**: A TODO that adds new validation, enforcement, or checks (e.g., beans integration, schema validation) raises the bar for all subsequent work. Schedule it early so downstream TODOs comply from the start rather than needing retrofits.

Mark inferred structural dependencies as `depends_on` entries with a `# inferred: merge-implication` or `# inferred: foundational` comment in .furrow/almanac/todos.yaml.

### 6. Group into Phases and Rows

Start with wave assignments from the triage script (dependency-based ordering).

#### 6a. Consolidate TODOs into Rows

Related TODOs should share a single branch (row) rather than each getting their own worktree. Consolidate when:

- **Same subsystem**: TODOs touch the same files or adjacent files in the same module
- **Sequential dependency**: TODO B builds directly on TODO A's output — land on one branch
- **Coherent theme**: TODOs address different facets of the same capability gap
- **Small + small = one session**: Multiple small-effort TODOs that share a theme are better as one row than N tiny branches

Each row gets a branch name (`work/{descriptive-name}`) and contains 1-N TODOs.

#### 6b. Order Phases

Refine wave ordering with these constraints (in priority order):

1. **Foundational-first**: TODOs that modify shared infrastructure (merge pipeline, gate evaluation, step transitions, enforcement layers) must land before TODOs that flow through that infrastructure. A TODO that changes how branches merge is a prerequisite for every other branch.
2. **Rename/namespace-first when applicable**: A project-wide rename or namespace change touches `*` and conflicts with everything. If planned, either schedule it very early (before others create branches against the old names) or very late (after all other work merges). Early is usually better — the longer you wait, the more branches need rebasing against the rename.
3. **File conflicts within a phase**: If two rows in the same phase have overlapping `files_touched`, they cannot safely parallelize. Either split into separate phases or note the conflict with a merge strategy.
4. **Logical coupling**: Group related rows even if graph-independent.
5. **Quick wins first**: Within dependency constraints, front-load small-effort + high-impact work.
6. **Critical path**: Identify the longest dependency chain and prioritize it.

#### 6c. Phase Metadata

Each phase gets:
- **Number**: sequential integer (continuing from completed phases)
- **Title**: generated from the grouped row themes
- **Status**: `DONE` | `IN PROGRESS` | `PLANNED`
- **Rationale**: 1-2 sentences explaining why these rows are grouped and ordered this way
- **Parallelism**: which rows within the phase can run concurrently

### 7. Generate Roadmap

Follow the template section order from `roadmap-sections.yaml`:

**header** (required):
```markdown
# Roadmap

> Last updated: {date} | {N} phases, {done}/{total} complete
```

**dependency-dag** (required):
```markdown
## Dependency DAG (active items only)
```
Generate ASCII graph from triage script data showing row relationships. Use:
- `──` for hard dependency (explicit `depends_on`)
- `~~` for inferred dependency (foundational/merge-implication)
- `···` for independent (no dependency)
- `[terminal]` for end-of-chain items
- Phase grouping with labels

**legend** (optional — include if DAG has dependencies):
```
Legend: `──` hard dep · `~~` inferred (foundational/merge) · `···` independent · `[terminal]` end of chain
```

**conflict-zones** (optional — include if conflicts detected):
```markdown
## File Conflict Zones

| Zone | Files | TODOs affected |
|------|-------|----------------|
```

**active-observations** (optional — include only when `.furrow/almanac/roadmap.yaml` has a non-empty `active_observations` key):

Placement: after the phase table / conflict-zones block, before the per-phase detail sections. Omit entirely if the key is absent or empty.

```markdown
## Active Observations

Observations whose triggers have fired — re-examination pending user action.

- `{id}` (`{kind}`) — {title}
  - _Activation_: {activation_reason}
  - Resolve: `alm observe resolve {id} ...` • Dismiss: `alm observe dismiss {id} ...`
```

**phase** (required, repeating — one per phase):
```markdown
## Phase {N} — {Title} — {Status}

{Rationale paragraph}

### work/{branch-name} ({N} TODOs, ~{sessions} sessions)
{todo-id-1}: {title}
{todo-id-2}: {title}
...
- **Key files**: {combined files_touched}
- **Conflict risk**: {none | low | high — based on file overlaps with other rows in this phase}
- **Why together**: {1 sentence on why these TODOs share a branch}
```

**worktree-commands** (required):
```markdown
## Worktree Quick Reference
```
Generate shell command blocks per phase. Branches map to rows, not individual TODOs:
```sh
# Phase N — {Title}
git worktree add ../{project_name}-{branch-name} -b work/{branch-name}
```

### 8. Present for Confirmation

Display the phase grouping proposal with rows:

```
Proposed roadmap: {N} phases, {M} rows

Phase {N} — {Title} — {Status}
  work/{branch-1} (~{sessions} sessions):
    {todo-id-1}: {title} (effort: {e}, impact: {i}, urgency: {u})
    {todo-id-2}: {title} (effort: {e}, impact: {i}, urgency: {u})
  work/{branch-2} (~{sessions} sessions):
    {todo-id-3}: {title} (effort: {e}, impact: {i}, urgency: {u})
  Parallelism: {branch-1} || {branch-2}
  Rationale: {brief rationale}

Phase {N+1} — ...

Review the proposal. Respond:
  ok          — accept and generate roadmap.yaml (+ optional roadmap.md)
  {N}: {adj}  — adjust phase N (e.g., "4: move beans-integration before rename")
  cancel      — abort, no writes
```

### 9. Write Outputs

After confirmation:
1. Update triage fields in `.furrow/almanac/todos.yaml`: write `depends_on`, `files_touched`, `urgency`, `impact`, `effort`, `status` for each active TODO. Bump `updated_at`.
2. Write `.furrow/almanac/roadmap.yaml` (primary, machine-readable — atomic: write to temp file, then move).
3. Optionally write `.furrow/almanac/roadmap.md` (human-readable companion — same content, markdown format).
4. Run `alm validate`. If invalid, revert .furrow/almanac/todos.yaml and error.

### 10. Commit

Stage and commit:
- `.furrow/almanac/roadmap.yaml`
- `.furrow/almanac/roadmap.md` (if generated)
- `.furrow/almanac/todos.yaml`

Commit message:
- Incremental: `docs: refresh roadmap via /furrow:triage`
- Full: `docs: regenerate roadmap (full) via /furrow:triage`

---

## Error Conditions

| Condition | Message | Exit |
|-----------|---------|------|
| No .furrow/almanac/todos.yaml | "No .furrow/almanac/todos.yaml found. Create TODOs first with `/work-todos --new`." | abort |
| Invalid .furrow/almanac/todos.yaml | Show validation errors | abort |
| Triage script cycle | "Dependency cycle detected: {details}" | abort |
| Triage script dangling dep | "Dangling dependency: {details}" | abort |
| No template found | "No roadmap template found. Expected at templates/roadmap.md.tmpl" | abort |
| All TODOs done/deferred | "All TODOs are completed or deferred. Nothing to roadmap." | clean exit |
| User cancels | "Roadmap generation cancelled." | clean exit |
| Validation fails after write | Revert .furrow/almanac/todos.yaml, show errors | abort |

---

## Constraints

- Read-only for `state.json` — this command does not modify Furrow state
- `.furrow/almanac/todos.yaml` is the source of truth for TODO status and triage metadata
- `.furrow/almanac/roadmap.yaml` is the primary roadmap artifact; `.furrow/almanac/roadmap.md` is an optional human-readable companion
- `--full` regenerates from scratch for strategic re-evaluation
- Template provides structural guidance; Claude generates the actual content
- Worktree branch convention: `work/{row-name}` (rows consolidate related TODOs onto one branch)
