# Spec: command-skill

## Interface Contract
- **File**: `commands/work-roadmap.md`
- **Invocation**: `/work-roadmap [--full]`
- **Reads**: `todos.yaml`, existing `ROADMAP.md` (if present), template files
- **Writes**: `ROADMAP.md`, updated triage fields in `todos.yaml`
- **Side effects**: Git commit on success

## Command Structure

```markdown
# /work-roadmap [--full]

Generate or update ROADMAP.md from todos.yaml with dependency-aware phase
grouping and worktree parallelism strategy.

## Syntax

/work-roadmap        → Incremental: preserve completed phases, update remaining
/work-roadmap --full → Full regeneration: re-evaluate everything from scratch
```

## Behavior: Incremental (default)

1. **Validate inputs**
   - Check `todos.yaml` exists. Error if not: "No todos.yaml found."
   - Run `scripts/validate-todos.sh`. Error if invalid.

2. **Resolve template**
   - Check `harness.yaml` for `roadmap.template` key → use if set
   - Check `.claude/roadmap.tmpl` → use if exists
   - Fall back to `templates/roadmap.md.tmpl`
   - Read `templates/roadmap-sections.yaml` for section registry

3. **Run triage script**
   - Execute `scripts/triage-todos.sh todos.yaml`
   - Parse JSON output: todos with triage data, dependency graph, file conflicts

4. **Preserve completed phases**
   - If `ROADMAP.md` exists, read it
   - Identify phases where all TODOs have `status: done` → mark as completed
   - Preserve completed phase content verbatim

5. **Triage missing metadata**
   - For each TODO missing urgency/impact/effort: read its `context` and `work_needed` prose
   - Assess using Claude reasoning, considering:
     - What other TODOs does this block? (dependency graph)
     - How many files does it touch? (effort signal)
     - Is it on the critical path? (urgency signal)
     - What is the blast radius? (impact signal)
   - Record reasoning inline

6. **Group into phases**
   - Start with wave assignments from triage script (dependency-based)
   - Refine using Claude reasoning:
     - File conflicts within a wave → split into separate phases or note conflict
     - Logical coupling → group related TODOs even if graph-independent
     - Completed phases → preserve numbering
   - Each phase gets: number, title (generated from grouped TODO themes), status

7. **Generate ROADMAP.md**
   - Follow template section order from `roadmap-sections.yaml`
   - For each section, generate content:
     - **header**: title, date, status summary
     - **dependency-dag**: ASCII graph from triage script data
     - **conflict-zones**: table from triage script conflicts (omit if none)
     - **phase** (repeat per phase): tracks with branch, files, conflict risk, rationale
     - **worktree-commands**: shell commands per phase for parallel execution

8. **Present for confirmation**
   - Show phase grouping proposal with numbered phases
   - For each phase: TODOs included, rationale, worktree strategy
   - User responds: `ok` (accept), `{N}: {adjustment}` (override), `cancel` (abort)

9. **Write outputs**
   - Update triage fields in `todos.yaml` (depends_on, files_touched, urgency, impact, effort, phase, status)
   - Write `ROADMAP.md` (atomic: temp file + move)
   - Run `scripts/validate-todos.sh` — error and rollback if invalid

10. **Commit**
    - Git commit: `docs: refresh ROADMAP.md`
    - Stage: `ROADMAP.md`, `todos.yaml`

## Behavior: Full (--full)

Same as incremental except:
- Skip step 4 (no phase preservation)
- All phases regenerated from scratch
- Git commit: `docs: regenerate ROADMAP.md (full)`

## Error Conditions
- No `todos.yaml`: error with suggestion to create one
- Invalid `todos.yaml`: error with validation output
- Triage script failure (cycles, dangling deps): show error, abort
- Template not found: error with resolution path tried
- No active TODOs (all done/deferred): "All TODOs are completed or deferred. Nothing to roadmap."

## Acceptance Criteria
1. Command file at `commands/work-roadmap.md` follows standard command pattern
2. Full pipeline: triage + group + sequence + generate in one invocation
3. Calls `scripts/triage-todos.sh` for dependency graph and file conflict data
4. Claude reads script output + todo prose to make grouping/phasing decisions
5. Outputs ROADMAP.md using template system with section ordering
6. Bare invocation preserves completed phases, --full regenerates everything
7. Inline reasoning: each phase includes triage rationale
8. Worktree commands generated for parallel phases
