# Team Plan: infra-fixes

## Model Hints

All specialists use `sonnet` (shell-specialist, harness-engineer).

## Coordination

- Wave 1 must complete and commit before wave 2 starts
- Wave 2 deliverables run in parallel — no file ownership overlap
- Cross-wave file sharing: generate-plan.sh and run-ci-checks.sh appear in both waves but changes target different lines
- Each deliverable gets its own commit for clean git history

## Wave 1: Foundation (sequential)

### project-root-resolution (shell-specialist, model: sonnet)

**Goal**: Introduce `PROJECT_ROOT` variable, fix 11 project-relative FURROW_ROOT bugs.

**Changes**:
1. `bin/frw`: Add `PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"` + `export PROJECT_ROOT` after FURROW_ROOT definition (after line 10)
2. Fix 11 references in 8 scripts (see research/project-root-resolution.md for exact lines):
   - generate-plan.sh:29,30
   - check-artifacts.sh:32
   - evaluate-gate.sh:28
   - select-gate.sh:22
   - select-dimensions.sh:26
   - run-gate.sh:39
   - run-ci-checks.sh:25,30
   - cross-model-review.sh:23,26
3. Update ambiguous defaults in measure-context.sh:10 and doctor.sh:18 to use PROJECT_ROOT

**Verification**: Run `frw doctor` and `frw check-artifacts` from a consumer project directory with frw on PATH.

---

## Wave 2: Parallel (after wave 1 commits)

### specialist-template-enforcement (harness-engineer, model: sonnet)

**Goal**: Add shell-level specialist validation, reconcile implement.md to warn+proceed.

**Changes**:
1. `bin/frw.d/scripts/generate-plan.sh`: After plan.json is written, add loop validating `specialists/{name}.md` exists for each assigned specialist. Warn on stderr if missing.
2. `skills/implement.md` lines 25-33: Change "STOP" / "blocking requirement" language to warn+proceed. Agent should warn on stderr and note the missing specialist in review evidence.

**Verification**: Create a plan.json with a non-existent specialist name, verify warning appears.

### config-move-and-source-todo (harness-engineer, model: sonnet)

**Goal**: Move furrow.yaml to .furrow/, update all refs, wire source_todo into handoff.

**Changes**:
1. Move `.claude/furrow.yaml` template to `.furrow/furrow.yaml` (or keep at root-level for template)
2. `bin/frw.d/init.sh`: Change target from `.claude/furrow.yaml` to `.furrow/furrow.yaml`
3. `bin/frw.d/install.sh`: Change target directory, update messages
4. `bin/frw.d/hooks/correction-limit.sh`: Add candidate loop
5. `bin/frw.d/scripts/run-ci-checks.sh`: Use PROJECT_ROOT + candidate loop (FURROW_ROOT already fixed in wave 1)
6. `tests/integration/helpers.sh`: Update test setup path
7. `commands/work.md`, `commands/init.md`, `commands/update.md`: Update text references
8. `commands/next.md`: Add instruction to read state.json source_todo and include in handoff prompt

**Verification**: Run `frw init` in a temp directory, verify `.furrow/furrow.yaml` is created. Run `frw install --check` in a consumer project with `.claude/furrow.yaml`, verify fallback works.

### cross-model-ideation-review (harness-engineer, model: sonnet)

**Goal**: Add ideation mode to cross-model review, fix codex invocation.

**Changes**:
1. `bin/frw.d/scripts/cross-model-review.sh`:
   - Add `--ideation` flag parsing
   - New `frw_cross_model_review_ideation()` function that builds framing review prompt from definition.yaml + summary.md
   - Fix codex exec: add `-c 'approval_policy="never"'` to both invocation paths (lines ~120, ~128)
   - FURROW_ROOT fixes already done in wave 1
2. `skills/ideate.md`: Update cross-model review reference to `frw cross-model-review <name> --ideation`
3. `bin/frw` usage text: Add `--ideation` to cross-model-review help

**Verification**: Run `frw cross-model-review infra-fixes --ideation` and verify structured output.
