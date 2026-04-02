# Replace /work-roadmap with /harness:triage command — Summary

## Task
Replace /work-roadmap with /harness:triage — a command that reads todos.yaml, runs dependency analysis via triage-todos.sh, applies AI reasoning to fill missing triage metadata (urgency/impact/effort/depends_on), groups TODOs into conflict-free phases, and generates a phased ROADMAP.md with worktree parallelism strategy. Idempotent — re-running regenerates from current state.

## Current State
Step: review | Status: completed
Deliverables: 0/4
Mode: code

## Artifact Paths
- definition.yaml: .work/triage-todos-harness-skill/definition.yaml
- state.json: .work/triage-todos-harness-skill/state.json
- plan.json: .work/triage-todos-harness-skill/plan.json
- research.md: .work/triage-todos-harness-skill/research.md
- specs/: .work/triage-todos-harness-skill/specs/
- team-plan.md: .work/triage-todos-harness-skill/team-plan.md

## Settled Decisions
- **ideate->research**: pass — definition.yaml validated; 4 deliverables defined with acceptance criteria; user approved objective, deliverables, constraints, and gate policy; cross-model review completed with findings incorporated
- **ideate->research**: pass — definition.yaml validated; 4 deliverables defined with acceptance criteria; user approved objective, deliverables, constraints, and gate policy; cross-model review completed with findings incorporated
- **research->plan**: pass — research.md covers all 4 deliverables: triage command spec (adapt existing 10-step pipeline), harness registration (8 files to repair, symlink mechanism documented), work-todos auto-commit (3 commit message variants), glob-regex bugfix (trailing slash conversion)
- **plan->spec**: pass — plan.json generated: 2 waves, wave 1 has 3 independent deliverables (glob-regex-bugfix, triage-command-spec, work-todos-auto-commit), wave 2 has harness-registration. Single specialist (harness-engineer), no file conflicts, sequential execution.
- **spec->decompose**: pass — User approved all 4 spec files: triage-command-spec (rename+adapt work-roadmap), harness-registration (symlink+4 file repairs), work-todos-auto-commit (commit step in both modes), glob-regex-bugfix (trailing slash normalization)
- **decompose->implement**: pass — User approved decompose: 2 waves, 4 deliverables, single implementer, sequential execution on existing work/triage-todos branch. plan.json and team-plan.md written.
- **implement->review**: pass — All 4 deliverables implemented: glob-regex-bugfix (triage-todos.sh), triage-command-spec (commands/triage.md), work-todos-auto-commit (commands/work-todos.md), harness-registration (symlink + 4 reference repairs + deletion). Bonus: validate-step-artifacts.sh ideate->research boundary.
- **implement->review**: pass — All 4 deliverables implemented across 5 commits: validate-step-artifacts fix, glob-regex bugfix, triage command + registration, reference repairs, work-todos auto-commit

## Context Budget
Measurement unavailable

## Key Findings
- The existing `/work-roadmap` command spec (219 lines) is already a complete 10-step pipeline — the new `/harness:triage` is a rename+adaptation, not a ground-up design
- `check-wave-conflicts.sh` is NOT reusable for this command — `triage-todos.sh` has its own file conflict detection (lines 175-214)
- `validate-step-artifacts.sh` was missing the `ideate->research` boundary case — fixed during ideation
- All 4 current todos in `todos.yaml` already have full triage metadata — no missing fields to assess currently
- Bare directory paths in `files_touched` (e.g., `skills/shared/`) silently break glob-to-regex conflict detection

## Open Questions
- How should `/harness:triage` be discovered by Claude Code? Currently `/work-roadmap` has no `.claude/commands/` symlink — need to verify the symlink at `.claude/commands/harness:triage.md` is sufficient for registration
- The duplicate gate record from the failed first transition (two `ideate->research` entries) — should this be cleaned up?

## Recommendations
- Proceed with Angle C (replace, no shim) — clean break from `/work-roadmap`
- Fix the glob-to-regex bug before implementing the command spec since it's a pre-existing issue in the triage script
- Add auto-commit to `/work-todos` as a parallel deliverable since it's an independent change with no dependencies
