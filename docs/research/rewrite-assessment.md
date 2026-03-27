# V1 Harness Assessment — Key Findings

Source: work-harness `.work/harness-rewrite-assessment/research/deliverable.md`

## What v1 Was

115 files, ~18K LOC. 24 commands, 5 skills (with 14 sub-docs), 10 hooks, 4 agents. Primarily markdown prose that configures AI behavior, plus shell scripts for enforcement and YAML/JSON for state.

## What Worked (Validated Concepts)

- **Depth-based task routing**: Different tasks need different amounts of structure. A one-line fix shouldn't go through the same process as a multi-week initiative.
- **Session continuity via handoff prompts**: Explicit bridges between agent sessions. Without them, multi-session work collapses.
- **Review gates at step boundaries**: Quality checkpoints that catch regressions before they compound.
- **Step-aware knowledge injection**: Each workflow step gets exactly the skills/context it needs — not everything.
- **Centralized agent coordination**: Outperforms independent agents (4.4x error containment vs. 17.2x).

## What Failed

- **1.43:1 feature-to-fix ratio**: For every 10 features, 7 fix commits followed.
- **5 degradation mechanisms**: Version tracking decay, sync point staleness, content duplication, missing frontmatter contracts, cross-reference integrity failures. All rooted in implicit contracts enforced by documentation discipline rather than structural enforcement.
- **849 lines of config injected per agent session** before any project code. Context tax on every interaction.
- **Prompts embedded as 594-line prose in command files**: Untestable, drifting, path-dependent.
- **Shell hooks for enforcement**: High barrier to add new checks, no data-driven configuration.
- **Platform reimplementation**: ~70% of functionality duplicated what Claude Code provides natively.

## Path Dependency Finding

LLM anchoring bias empirically confirmed — 56.4% of LLM-related developer actions exhibit bias, with lower reversal rates than human coding. V1's own history: 4 consecutive improvement initiatives never questioned core abstractions. Agents are pattern-extenders, not architectural innovators.
