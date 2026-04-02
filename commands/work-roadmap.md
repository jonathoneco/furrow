# /work-roadmap [--full]

Generate or update ROADMAP.md from `todos.yaml` with dependency-aware phase grouping and worktree parallelism strategy.

## Syntax

```
/work-roadmap        → Incremental: preserve completed phases, update remaining
/work-roadmap --full → Full regeneration: re-evaluate all phases from scratch
```

---

## Behavior

### 1. Validate Inputs

- Check `todos.yaml` exists at project root. Error if not: "No todos.yaml found. Create TODOs first with `/work-todos --new`."
- Run `scripts/validate-todos.sh todos.yaml`. If invalid, show errors and abort.

### 2. Resolve Template

Check in order, use first found:
1. `harness.yaml` key `roadmap.template` → use that path
2. `.claude/roadmap.tmpl` → project-level override
3. `templates/roadmap.md.tmpl` → harness default

Read `templates/roadmap-sections.yaml` for section registry (names, order, required/optional, repeating).

If no template found: error "No roadmap template found. Expected at templates/roadmap.md.tmpl".

### 3. Run Triage Script

```sh
scripts/triage-todos.sh todos.yaml
```

Parse JSON output containing:
- `todos`: array of active TODOs with triage metadata
- `graph`: topological order and wave assignments
- `conflicts`: file overlap pairs within same wave

If script exits non-zero (cycles, dangling deps): show error output, abort.

If `todos` array is empty: "All TODOs are completed or deferred. Nothing to roadmap."

### 4. Preserve Completed Phases (incremental mode only)

Skip this step if `--full` flag is set.

If `ROADMAP.md` exists:
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

### 6. Group into Phases

Start with wave assignments from the triage script (dependency-based ordering).

Refine using reasoning about the TODOs:

- **File conflicts within a wave**: If two TODOs in the same wave have overlapping `files_touched`, they cannot safely parallelize in separate worktrees. Either split into separate phases or note the conflict with a merge strategy.
- **Logical coupling**: Group related TODOs even if graph-independent. Example: two TODOs that both improve the review system belong in the same phase even if neither depends on the other.
- **Quick wins first**: Within dependency constraints, front-load small-effort + high-impact TODOs.
- **Critical path**: Identify TODOs that are on the longest dependency chain and prioritize them.

Each phase gets:
- **Number**: sequential integer (0-indexed or continuing from completed phases)
- **Title**: generated from the grouped TODO themes (e.g., "Foundation Scripts" or "Review System Improvements")
- **Status**: `DONE` | `IN PROGRESS` | `PLANNED`
- **Rationale**: 1-2 sentences explaining why these TODOs are grouped and ordered this way

### 7. Generate ROADMAP.md

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
Generate ASCII graph from triage script data showing TODO relationships. Use:
- `──` for hard dependency
- `···` for independent (no dependency)
- `[terminal]` for end-of-chain items
- Phase grouping with labels

**legend** (optional — include if DAG has dependencies):
```
Legend: `──` hard dependency · `···` independent · `[terminal]` = end of chain
```

**conflict-zones** (optional — include if conflicts detected):
```markdown
## File Conflict Zones

| Zone | Files | TODOs affected |
|------|-------|----------------|
```

**phase** (required, repeating — one per phase):
```markdown
## Phase {N} — {Title} — {Status}

{Rationale paragraph}

### {TODO-ID}: {TODO Title}
- **Branch**: `work/{todo-id}`
- **Key files**: {files_touched list}
- **Conflict risk**: {none | low | high — based on file overlaps}
- **Effort**: {effort} | **Impact**: {impact} | **Urgency**: {urgency}
```

**worktree-commands** (required):
```markdown
## Worktree Quick Reference
```
Generate shell command blocks per phase. For phases with parallel TODOs:
```sh
# Phase N — {Title}
git worktree add ../wt-{todo-id} -b work/{todo-id}
```

### 8. Present for Confirmation

Display the phase grouping proposal:

```
Proposed roadmap: {N} phases

Phase 0 — {Title} — {Status}
  {todo-id-1}: {title} (effort: {e}, impact: {i}, urgency: {u})
  {todo-id-2}: {title} (effort: {e}, impact: {i}, urgency: {u})
  Rationale: {brief rationale}

Phase 1 — {Title} — {Status}
  ...

Review the proposal. Respond:
  ok          — accept and generate ROADMAP.md
  {N}: {adj}  — adjust phase N (e.g., "1: move task-b to phase 2")
  cancel      — abort, no writes
```

### 9. Write Outputs

After confirmation:
1. Update triage fields in `todos.yaml`: write `depends_on`, `files_touched`, `urgency`, `impact`, `effort`, `phase`, `status` for each active TODO. Bump `updated_at`.
2. Write `ROADMAP.md` (atomic: write to temp file, then move).
3. Run `scripts/validate-todos.sh todos.yaml`. If invalid, revert todos.yaml and error.

### 10. Commit

Stage and commit:
- `ROADMAP.md`
- `todos.yaml`

Commit message:
- Incremental: `docs: refresh ROADMAP.md`
- Full: `docs: regenerate ROADMAP.md (full)`

---

## Error Conditions

| Condition | Message | Exit |
|-----------|---------|------|
| No todos.yaml | "No todos.yaml found. Create TODOs first with `/work-todos --new`." | abort |
| Invalid todos.yaml | Show validation errors | abort |
| Triage script cycle | "Dependency cycle detected: {details}" | abort |
| Triage script dangling dep | "Dangling dependency: {details}" | abort |
| No template found | "No roadmap template found. Expected at templates/roadmap.md.tmpl" | abort |
| All TODOs done/deferred | "All TODOs are completed or deferred. Nothing to roadmap." | clean exit |
| User cancels | "Roadmap generation cancelled." | clean exit |
| Validation fails after write | Revert todos.yaml, show errors | abort |

---

## Constraints

- Read-only for `state.json` — this command does not modify harness state
- `todos.yaml` is the source of truth for TODO status and triage metadata
- ROADMAP.md is a sprint artifact — `--full` regenerates from scratch for strategic re-evaluation
- Template provides structural guidance; Claude generates the actual content
- Worktree branch convention: `work/{todo-id}`
