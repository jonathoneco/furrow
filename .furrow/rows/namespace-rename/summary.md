# Consolidate harness source/install duplication, rename project to furrow, and verify cross-platform compatibility — Summary

## Task
Rename project namespace from "harness" to "furrow", consolidate any denormalized content, and audit shell scripts for macOS/WSL portability.

## Current State
Step: implement | Status: in_progress
Deliverables: 2/2
Mode: code

## Artifact Paths
- definition.yaml: .work/namespace-rename/definition.yaml
- state.json: .work/namespace-rename/state.json
- plan.json: .work/namespace-rename/plan.json
- research.md: .work/namespace-rename/research.md
- specs/: .work/namespace-rename/specs/
- team-plan.md: .work/namespace-rename/team-plan.md

## Settled Decisions
- **ideate->research**: pass — Definition validated against schema. 2 deliverables: rename-to-furrow (with denormalization audit pre-step) and cross-platform-compatibility. Cross-model review surfaced 10 findings, all resolved.
- **ideate->research**: pass — Definition validated. Gate recorded.
- **research->plan**: pass — Research complete. Categorized rename map (A/B/C/D) with ~250 mechanical + ~40 prose changes. 5 denormalization areas found (2 actionable). Portability audit found only 2 real issues (readlink -f, expr comparison) — far fewer than ideation estimated. research.md written.
- **research->plan**: pass — Research complete. Categorized rename map with ~250 mechanical + ~40 prose changes. 5 denormalization areas found (2 actionable). Portability audit: only 2 real issues. research.md written. Summary populated.
- **plan->spec**: pass — Plan complete. Sequential execution, single specialist (shell-specialist). 3 architecture decisions recorded. plan.json written. No parallel execution needed.
- **plan->spec**: pass — Plan complete. 2 waves: wave 1 (rename-to-furrow), wave 2 (cross-platform-compatibility). Sequential execution, shell-specialist for both. plan.json written in wave schema format.
- **plan->spec**: pass — Plan complete. 2 waves: wave 1 rename-to-furrow, wave 2 cross-platform-compatibility. plan.json validated.
- **spec->decompose**: pass — Specs written for both deliverables. rename-to-furrow: 6 phases (denorm audit, mechanical sed, project names, file renames, migration, verification). cross-platform-compatibility: 2 fixes (readlink -f, expr), shellcheck validation, residual risk docs.
- **decompose->implement**: pass — Decompose complete. 2 waves, single agent, sequential execution. team-plan.md written. Work branch created: work/namespace-rename.
- **implement->review**: pass — Both deliverables implemented. Wave 1: renamed harness→furrow across 100 files (commit e2e268e). Wave 2: fixed readlink -f portability, expr comparison, shellcheck clean (commit 9d37dc6). install.sh --check passes.

## Context Budget
Measurement unavailable

## Key Findings
- Rename map: ~250 mechanical identifier replacements (Category A), ~20 project-name changes (B), ~40 prose reviews (C), 3 file renames
- Denormalization: command table maintained in both CLAUDE.md and install.sh template; HARNESS_ROOT init copy-pasted in 20+ files
- Portability: only 2 real issues — `readlink -f` (install.sh) and `expr` comparison (common.sh). Zero shebang/feature mismatches found (correcting ideation estimate)
- Codebase is already 95% portable to macOS/WSL

## Open Questions
- None remaining — all architecture decisions resolved in plan step
- Future consideration: centralize FURROW_ROOT init post-rename to reduce maintenance burden

## Recommendations
- Execute rename in 3 phases: denormalization audit/fix, mechanical sed replacements, prose review
- Do NOT centralize HARNESS_ROOT init before rename — mechanical sed is simpler and lower risk
- commands/harness.md → commands/furrow.md (simple rename, no restructure)
- Keep cross-platform as separate deliverable for clean commit history despite small scope
