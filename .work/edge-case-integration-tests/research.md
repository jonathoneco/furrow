## Research: Edge-Case Integration Tests

### Overview

All 5 scripts under test have been fully analyzed. Each has clear exit codes, file I/O contracts, and branching logic. No existing test framework exists — we build from scratch.

### Key Findings Per Test Area

#### 1. generate-plan.sh — Wave Generation & Cycle Detection

- Uses embedded Python (Kahn's algorithm) for topological sort
- Cycle detection: if `len(topo_order) != len(names)`, prints cycle members to stderr, exits 3
- Wave assignment: `max(wave of deps) + 1`; roots get wave 1
- Missing specialist: caught before Python runs, exits 3
- Calls `validate_plan_json()` from `hooks/lib/validate.sh` post-generation
- Writes `plan.json` atomically (temp + mv)
- **Prereqs:** `yq`, `jq`, `python3` must be on PATH

**Test scenarios:** linear chain, diamond, cycle, multi-root, missing specialist

#### 2. correction-limit.sh — Glob Matching & Blocking

- PreToolUse hook; reads JSON from stdin: `{"tool_name":"Write","tool_input":{"file_path":"..."}}`
- Only enforces during `step = "implement"`
- Default correction limit: 3 (from `.claude/harness.yaml` or hardcoded)
- Glob matching uses shell `case` statement: `case "${file_path}" in ${glob})`
- Two path extraction strategies: `extract_unit_from_path()` then fallback to `find_focused_work_unit()`
- Exit 0 = allowed, Exit 2 = blocked with stderr message

**Test scenarios:** at-limit blocked, under-limit allowed, unowned file, non-implement step, both field names

#### 3. check-artifacts.sh — Mixed Verdicts & Artifact Presence

- Takes `<name> <deliverable>` args
- Two modes: research (checks `deliverables/` for non-empty files) and code (uses git diff + globs)
- Writes `reviews/phase-a-results.json` with `verdict: "pass"|"fail"`
- ACs all get `met: {artifacts_present}` — binary, based on artifact detection
- **Git dependency:** code mode requires real git repo with base_commit
- Missing base_commit → artifacts_present = false → fail

**Test scenarios:** code mode pass/fail, research mode pass/fail, missing base_commit

#### 4. step-transition.sh — Correction Increment on Failure

- On fail during implement/review: increments `.deliverables[*].corrections` BUT only where `.status == "in_progress"`
- Exact jq: `.deliverables |= with_entries(if .value.status == "in_progress" then .value.corrections = ((.value.corrections // 0) + 1) else . end)`
- On pass: calls record-gate → validate-step-artifacts → regenerate-summary → advance-step
- Pass at final step (review) with no next step → exit 3
- Fail at final step → stays at step, resets step_status to in_progress

**Test scenarios:** fail increments only in_progress, completed untouched, final step pass/fail

#### 5. load-step.sh — Conditional Pass Carry-Forward

- Reads `.gates | last` from state.json
- If `outcome == "conditional"` AND `conditions != null`: emits bulleted list on stdout
- Format: `"CONDITIONAL PASS: The following conditions must be addressed this step:\n- cond1\n- cond2"`
- jq expression: `.conditions | join("\n- ")`
- Skill file must exist at `skills/${step}.md`; missing → exit 3

**Test scenarios:** conditional with conditions, conditional with null, pass (no conditions), missing skill

### Architecture Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Git repos | Only for check-artifacts.sh tests | Only script that uses git diff |
| Test files | 5 separate files + helpers.sh + runner | Independent execution, maintainability |
| Location | tests/integration/ | Clean namespace |
| Assertions | 4 functions in helpers.sh | Lightweight, no deps |
| Fixtures | mktemp dirs with trap cleanup | Self-contained, no state leakage |

### Dependencies

All scripts require `jq` and `yq` on PATH. `generate-plan.sh` also requires `python3`. Tests should check for these at the top and skip gracefully if missing.

### Open Risks

- **check-artifacts.sh git tests:** Need a real git repo. Tests must `git init` in temp dir, create commits. This is slower but necessary — no way to mock git diff.
- **step-transition.sh subcalls:** It calls record-gate.sh, validate-step-artifacts.sh, regenerate-summary.sh, advance-step.sh. For testing the fail path (correction increment), these subcalls still execute. Need to either stub them or set up enough fixtures for them to succeed/fail predictably.
- **correction-limit.sh harness.yaml:** Tests need to either create a `.claude/harness.yaml` in the fixture or accept the default (3).
