# Research: worktree-summary

## Current State

**update-summary pattern** (the model to replicate):
- Kebab-case section names map to display names via case statement
- Reads stdin (blocks TTY input)
- Awk state-machine finds `^## SectionName` markers, replaces content until next `^## `
- Atomic write: temp file + move
- Updates state.json timestamp

**Accepted sections**: key-findings, open-questions, recommendations (hardcoded)

**regenerate-summary**: Rebuilds skeleton from state.json + definition.yaml while preserving
agent-written sections (Key Findings, Open Questions, Recommendations) via awk extraction.

**validate-summary**: Checks all required sections present, agent-written sections have >=1
non-empty line. Skips validation for prechecked gates.

**Existing worktree infra**: launch-phase.sh creates git worktrees and tmux sessions per
phase row, writes prompt files to /tmp. No reintegration path exists — worktrees are created
but never summarized back.

## Implementation Plan

Replicate update-summary pattern with worktree-specific sections:

1. `rws update-worktree-summary [name] <section>` — same stdin + awk pattern
2. Sections: files-changed, decisions, open-items, test-results
3. Template: `rws regenerate-worktree-summary [name]` generates skeleton
4. Validation: each section >=1 non-empty line
5. Storage: `.furrow/rows/{name}/worktree-summary.md`
6. State timestamp update on write

The awk section-replacement pattern is ~30 lines and can be extracted into a shared
function if it doesn't already exist in common.sh.

## Sources Consulted

| Source | Tier | Contribution |
|--------|------|-------------|
| bin/rws.bak (lines 993-1067) | Primary | update-summary implementation |
| bin/rws.bak (lines 852-987) | Primary | regenerate-summary implementation |
| bin/rws.bak (lines 1073-1126) | Primary | validate-summary implementation |
| bin/frw.d/scripts/launch-phase.sh (lines 1-123) | Primary | Existing worktree lifecycle |
| .furrow/rows/quick-harness-fixes/summary.md | Primary | Real summary example |
