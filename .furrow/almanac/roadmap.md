# Roadmap

> Last updated: 2026-04-23 · 8 phases · 47 active TODOs in plan

## Dependency DAG (active items only)

```
Phase 1 — Post-install hygiene — test isolation, review pipeline, install asymmetry
  work/post-install-hygiene                (8 TODOs)
     ··· audit-test-install-sh-and-test-upgrade-sh-for-live
     ··· codex-cross-model-reviewer-flags-other-deliverable
     ··· audit-xdg-config-fields-for-runtime-consumers-pref
     ··· generate-reintegration-sh-should-use-canonical-sch
     ··· bin-frw-d-scripts-rescue-sh-committed-as-100644-di
     ··· commands-lib-promote-learnings-sh-reads-null-for-e
     ··· unify-tracked-14-vs-gitignored-8-specialist-symlin
     ··· ac-10-e2e-fixture-split-across-contaminated-stop-a

Phase 2 — CLI Go rewrite — foundational language migration
  work/cli-go-rewrite                      (1 TODO)
     ··· cli-architecture-overhaul

Phase 3 — Dispatch + ambient contract — foundational for downstream skills
  work/sub-agent-normalization             (4 TODOs)
     ··· sub-agent-normalization
     ── parallel-agent-orchestration-adoption
     ··· specialist-quality-validation
     ··· specialist-template-warning-escalation
  work/ambient-context                     (1 TODO)
     ··· ambient-context-promotion
  work/effort-and-model-routing            (1 TODO)
     ··· effort-selection-alongside-model

Phase 4 — Worktree + merge pipeline — /furrow:work and /furrow:next overhaul
  work/worktree-integration                (2 TODOs)
     ··· furrow-work-worktree-integration
     ··· install-user-bin-worktree-pinning
  work/next-merge-pipeline                 (3 TODOs)
     ··· furrow-next-semantic-merge
     ··· furrow-next-phase-lifecycle
     ··· merge-process-skill

Phase 5 — Seeds primitive — deterministic work graph replacing LLM-reasoned dependencies
  work/seeds                               (1 TODO)
     ── seeds-concept

Phase 6 — Artifacts, reviews, row variants — UX patterns for collaboration
  work/artifacts-and-row-variants          (4 TODOs)
     ··· artifact-writing-defaults
     ··· patch-row-concept
     ··· spike-row-mode
     ── low-finding-disposition-policy
  work/review-surfaces                     (2 TODOs)
     ··· collaborative-surfaces
     ··· unified-isolated-review
  work/triage-ux                           (2 TODOs)
     ── brain-dump-triage-command
     ── tmux-sessionizer-integration

Phase 7 — Post-seeds re-triage + dashboards + lifecycle
  work/post-seeds-retriage                 (6 TODOs)
     ··· sprint-inspired-planning
     ··· post-merge-watch-list
     ··· support-sharded-todos-d-directory-to-reduce-merge
     ··· gate-dimension-deduplication
     ··· todo-context-references
     ··· user-action-integration
  work/dashboards-and-lifecycle            (4 TODOs)
     ··· furrow-tui-dashboard
     ── harness-lifecycle-ux
     ··· adapters-audit
     ··· furrow-self-update-hook

Phase 8 — Research, long-tail, workflow cleanup
  work/research-mining                     (6 TODOs)
     ··· mine-claude-code
     ··· mine-v1-harness
     ··· apply-nate-jones-skill
     ··· research-documentation-detection
     ··· research-methodology-design
     ··· design-pattern-context-construction
  work/memetic-research                    (1 TODO)
     ··· memetic-algorithms-research
  work/work-folder-cleanup                 (1 TODO)
     ── work-folder-structure-and-cleanup

```

Legend: `──` has dependencies · `···` independent

## File Conflict Zones

| Phase | File | Rows | Severity |
|-------|------|------|----------|
| 3 | `specialists/` | effort-and-model-routing, sub-agent-normalization | medium |
| 3 | `bin/frw.d/scripts/` | effort-and-model-routing, sub-agent-normalization | medium |
| 3 | `references/specialist-template.md` | effort-and-model-routing, sub-agent-normalization | medium |
| 4 | `bin/rws` | next-merge-pipeline, worktree-integration | medium |
| 6 | `skills/` | artifacts-and-row-variants, review-surfaces | medium |
| 6 | `.furrow/almanac/rationale.yaml` | artifacts-and-row-variants, triage-ux | medium |
| 6 | `skills/review.md` | artifacts-and-row-variants, review-surfaces | medium |
| 7 | `skills/` | dashboards-and-lifecycle, post-seeds-retriage | medium |

## Phase 1 — Post-install hygiene — test isolation, review pipeline, install asymmetry — PLANNED

Post-merge cleanup from install-and-merge (shipped 2026-04-22). Test-isolation fix leads — tests corrupted live-repo symlinks, a safety issue. Bundled so 8 small fixes amortize one branch instead of 8 tiny ones.

### `work/post-install-hygiene` (8 TODOs)

- `audit-test-install-sh-and-test-upgrade-sh-for-live` — Audit test-install-*.sh and test-upgrade-*.sh for live-worktree mutation *[high/medium/small]*
- `codex-cross-model-reviewer-flags-other-deliverable` — Codex cross-model reviewer flags other deliverables' commits as unplanned *[medium/high/small]*
- `audit-xdg-config-fields-for-runtime-consumers-pref` — Audit XDG config fields for runtime consumers (preferred_specialists, cross_model.provider) *[medium/medium/small]*
- `generate-reintegration-sh-should-use-canonical-sch` — generate-reintegration.sh should use canonical schema, not inline jq-subset *[medium/medium/small]*
- `bin-frw-d-scripts-rescue-sh-committed-as-100644-di` — bin/frw.d/scripts/rescue.sh committed as 100644; dispatcher exec fails *[medium/low/small]*
- `commands-lib-promote-learnings-sh-reads-null-for-e` — commands/lib/promote-learnings.sh reads null for every learning *[low/low/small]*
- `unify-tracked-14-vs-gitignored-8-specialist-symlin` — Unify tracked (14) vs .gitignored (8) specialist symlinks *[low/low/small]*
- `ac-10-e2e-fixture-split-across-contaminated-stop-a` — AC-10 e2e fixture split across contaminated-stop and safe-happy-path *[low/low/small]*

- **Conflict risk**: low
- **Why together**: Same source review; same subsystem (install/test/review pipeline); bundling avoids 8 tiny branches.

## Phase 2 — CLI Go rewrite — foundational language migration — PLANNED

Go rewrite of frw/rws/alm/sds. Decision 2026-04-23: Go (over TypeScript), all-in (no bash quick-wins phase). Rewrites the exact infrastructure Phase 3+ builds on, so it must land first. Absorbs cli-ergonomics-pass, cli-breakup-script-guard, register-deliverable-command, and log-disposition-discipline — their implementations live in the new Go CLI rather than transitional bash.

### `work/cli-go-rewrite` (1 TODO)

- `cli-architecture-overhaul` — CLI architecture overhaul — Go rewrite of frw/rws/alm/sds with modularization, structured logging, introspection *[high/high/large]*

- **Key files**: `.furrow/almanac/rationale.yaml`, `bin/`, `cmd/`, `install.sh`, `internal/`, `schemas/`, `tests/integration/`
- **Conflict risk**: low
- **Why together**: Single large migration — every downstream row builds on the new binaries.

## Phase 3 — Dispatch + ambient contract — foundational for downstream skills — PLANNED

Sub-agent dispatch shape, ambient-layer contract, and specialist quality signal. These reshape contracts that Phase 4-6 skills/commands write against. Landing them after the Go rewrite means generators and ambient-layer tooling are built in Go from the start.

### `work/sub-agent-normalization` (4 TODOs)

- `sub-agent-normalization` — Sub-agent normalization — register specialists as Claude Code agent types with single-source generation *[medium/high/medium]*
- `parallel-agent-orchestration-adoption` — Built-in team orchestration isn't being used — diagnose and fix *[high/high/medium]*
- `specialist-quality-validation` — Establish a validation mechanism for specialist template quality *[low/high/medium]*
- `specialist-template-warning-escalation` — Escalate specialist template warnings to structured observability *[low/medium/small]*

- **Key files**: `.claude/agents/`, `.claude/commands/specialist:*.md`, `.furrow/almanac/rationale.yaml`, `bin/frw.d/scripts/`, `evals/`, `install.sh`, `references/specialist-template.md`, `skills/implement.md` (+more)
- **Conflict risk**: medium
- **Why together**: All four touch specialist dispatch shape, registration, and quality gating — same module.
- **Depends on**: per-step-model-routing, specialist-expansion

### `work/ambient-context` (1 TODO)

- `ambient-context-promotion` — Ambient context promotion system — row→project→global knowledge graduation *[medium/high/large]*

- **Key files**: `.furrow/almanac/`, `bin/alm`, `commands/lib/`
- **Conflict risk**: low
- **Why together**: Standalone — reshapes ambient contract before Phase 4 writes against it.

### `work/effort-and-model-routing` (1 TODO)

- `effort-selection-alongside-model` — Add effort_hint to specialists and step skills — decouple reasoning depth from model identity *[low/high/medium]*

- **Key files**: `bin/frw.d/scripts/`, `references/specialist-template.md`, `skills/`, `specialists/`
- **Conflict risk**: medium
- **Why together**: Touches specialists/ frontmatter — sequence with sub-agent-normalization (same files).

## Phase 4 — Worktree + merge pipeline — /furrow:work and /furrow:next overhaul — PLANNED

Row-to-branch coupling (worktree) and branch-to-main coupling (semantic merge). Every future row uses these. Depends on Phase 2 CLI stabilization since merge logic lives in bin/frw.d/scripts/ (now Go).

### `work/worktree-integration` (2 TODOs)

- `furrow-work-worktree-integration` — furrow:work auto-creates a git worktree when not already on one *[medium/high/medium]*
- `install-user-bin-worktree-pinning` — frw install writes ~/.local/bin symlinks pointing at the invocation path, not the canonical source repo *[high/high/small]*

- **Key files**: `.claude/commands/furrow:archive.md`, `.claude/commands/furrow:work.md`, `.furrow/almanac/rationale.yaml`, `bin/frw.d/hooks/auto-install.sh`, `bin/frw.d/install.sh`, `bin/frw.d/scripts/rescue.sh`, `bin/rws`, `skills/ideate.md` (+more)
- **Conflict risk**: medium
- **Why together**: Worktree lifecycle owned by one branch.

### `work/next-merge-pipeline` (3 TODOs)

- `furrow-next-semantic-merge` — furrow:next semantic merge — read row artifacts for intelligent merge + per-deliverable squash *[medium/high/large]*
- `furrow-next-phase-lifecycle` — furrow:next as full phase lifecycle — merge, update roadmap, handoff, launch *[medium/high/medium]*
- `merge-process-skill` — Design a /furrow:merge skill — reconcile worktree branches back into main *[medium/high/medium]*

- **Key files**: `.claude/commands/furrow:next.md`, `.furrow/furrow.yaml`, `bin/frw.d/hooks/`, `bin/frw.d/scripts/`, `bin/frw.d/scripts/launch-phase.sh`, `bin/frw.d/scripts/merge-to-main.sh`, `bin/rws`, `commands/` (+more)
- **Conflict risk**: medium
- **Why together**: All modify /furrow:next flow; shared commit-msg and squash code path.

## Phase 5 — Seeds primitive — deterministic work graph replacing LLM-reasoned dependencies — PLANNED

Foundational task-management primitive. Cross-row work graph + in-row task tracking in one unified graph, owned by sds. alm delegates to sds for triage/roadmap queries. Absorbs almanac-graph-primitives. Must land after Go rewrite (graph engine belongs in Go).

### `work/seeds` (1 TODO)

- `seeds-concept` — Seeds as the task management primitive — unified work graph, in-row tracking, gating, and alm delegation *[medium/high/large]*

- **Key files**: `.furrow/almanac/`, `bin/alm`, `bin/rws`, `bin/sds`, `references/`, `skills/`, `templates/`
- **Conflict risk**: low
- **Why together**: Single large primitive — alm-side wiring and sds core ship together.
- **Depends on**: cli-architecture-overhaul

## Phase 6 — Artifacts, reviews, row variants — UX patterns for collaboration — PLANNED

Artifact-first content discipline, patch/spike row variants, review surfaces, and the triage/brain-dump commands that drive them. All depend on seeds for task tracking and on Phase 3 ambient contract.

### `work/artifacts-and-row-variants` (4 TODOs)

- `artifact-writing-defaults` — Artifact-writing defaults — long-form outputs go to files as first-class citizens *[medium/high/medium]*
- `patch-row-concept` — patch-row variant — lightweight harness mode for small fixes, bug fixes, accessibility issues *[medium/high/medium]*
- `spike-row-mode` — Spike row mode — implementation-flavored research with throwaway prototypes *[low/high/medium]*
- `low-finding-disposition-policy` — LOW finding disposition policy — auto-TODO with audit trail *[medium/medium/small]*

- **Key files**: `.claude/rules/step-sequence.md`, `.furrow/almanac/rationale.yaml`, `bin/alm`, `bin/rws`, `evals/dimensions/`, `references/definition-shape.md`, `references/review-methodology.md`, `references/row-layout.md` (+more)
- **Conflict risk**: high
- **Why together**: Artifact conventions + lightweight row shapes are the same design conversation.
- **Depends on**: patch-row-concept

### `work/review-surfaces` (2 TODOs)

- `collaborative-surfaces` — Document-based collaboration — markdown + comment threading, Notion integration *[low/medium/large]*
- `unified-isolated-review` — Unify Phase B and cross-model review into a single isolated-review script *[medium/high/medium]*

- **Key files**: `adapters/`, `bin/frw.d/scripts/cross-model-review.sh`, `commands/review.md`, `skills/`, `skills/ideate.md`, `skills/review.md`, `skills/shared/eval-protocol.md`
- **Conflict risk**: medium
- **Why together**: Review/ambient-context loop; same skill files.

### `work/triage-ux` (2 TODOs)

- `brain-dump-triage-command` — Brain dump + triage command — collaborative ideation, TODO extraction, roadmap bootstrap fields *[medium/high/medium]*
- `tmux-sessionizer-integration` — tmux sessionizer integration — ship a Furrow-aware layout tied to the focused row *[low/medium/small]*

- **Key files**: `.furrow/almanac/rationale.yaml`, `.tmux-sessionizer`, `bin/frw.d/scripts/`, `commands/`, `commands/next.md`, `commands/triage.md`, `commands/work-todos.md`, `templates/roadmap.md.tmpl`
- **Conflict risk**: medium
- **Why together**: Triage/brain-dump UX and the panes that watch those artifacts in real time.
- **Depends on**: artifact-writing-defaults, furrow-work-worktree-integration, parallel-agent-orchestration-adoption

## Phase 7 — Post-seeds re-triage + dashboards + lifecycle — PLANNED

Several TODOs may be subsumed, simplified, or re-shaped once seeds lands — re-triage them here rather than designing against pre-seeds assumptions. Plus dashboards, self-update, and harness lifecycle UX which build on stable foundations.

### `work/post-seeds-retriage` (6 TODOs)

- `sprint-inspired-planning` — Sprint-inspired work planning — retros, velocity, multi-row coordination, observability *[low/high/large]*
- `post-merge-watch-list` — Post-merge watch-list — track behavioral signals to validate after rows merge *[low/high/medium]*
- `support-sharded-todos-d-directory-to-reduce-merge` — Support sharded todos.d/ directory to reduce merge-conflict surface *[low/medium/large]*
- `gate-dimension-deduplication` — Extract shared gate dimensions (seed-sync, dual-review) into reusable definitions *[low/medium/small]*
- `todo-context-references` — TODOs with context references from dump and active sessions *[low/medium/medium]*
- `user-action-integration` — Integration points for actions the user must take *[low/medium/medium]*

- **Key files**: `.furrow/almanac/`, `bin/alm`, `bin/rws`, `commands/triage.md`, `commands/work-todos.md`, `evals/dimensions/`, `evals/gates/`, `skills/` (+more)
- **Conflict risk**: medium
- **Why together**: Each one has an overlap with seeds semantics. Re-triage instead of pre-planning.

### `work/dashboards-and-lifecycle` (4 TODOs)

- `furrow-tui-dashboard` — Furrow TUI / agent-dashboard integration *[low/medium/large]*
- `harness-lifecycle-ux` — Harness UX — sow/reap verbs, status line, installation/exploration skill *[low/medium/large]*
- `adapters-audit` — Adapters pass — check for atrophy, modularization decay, internal consistency *[low/medium/medium]*
- `furrow-self-update-hook` — furrow-self-update-hook — session-start check for upstream Furrow changes *[low/medium/small]*

- **Key files**: `.claude/settings.json`, `.furrow/_meta.yaml`, `.furrow/almanac/rationale.yaml`, `adapters/`, `bin/frw.d/hooks/`, `bin/frw.d/scripts/`, `commands/`, `install.sh` (+more)
- **Conflict risk**: medium
- **Why together**: User-facing polish on stabilized foundations; independent internally but shares rationale/install surface.
- **Depends on**: cli-architecture-overhaul

## Phase 8 — Research, long-tail, workflow cleanup — PLANNED

Lowest-urgency work: research spikes (mining prior harnesses, methodology), speculative research, and .furrow/rows/ structure cleanup. Run as capacity allows.

### `work/research-mining` (6 TODOs)

- `mine-claude-code` — Mine Claude Code for reusable patterns and capabilities *[low/medium/small]*
- `mine-v1-harness` — Mine v1 harness for learnings, insights, and research *[low/medium/small]*
- `apply-nate-jones-skill` — Apply Nate Jones harness skill patterns to Furrow *[low/medium/small]*
- `research-documentation-detection` — Detect when research output should be documentation instead *[low/medium/small]*
- `research-methodology-design` — Research methodology for systems design — beyond naive web search *[low/medium/small]*
- `design-pattern-context-construction` — Context construction driven by design pattern thinking *[low/medium/medium]*

- **Key files**: `commands/lib/promote-components.sh`, `docs/`, `references/`, `skills/research.md`, `skills/review.md`
- **Conflict risk**: low
- **Why together**: Research spikes informing future harness design; same research artifact pattern.

### `work/memetic-research` (1 TODO)

- `memetic-algorithms-research` — Research memetic algorithms for LLM orchestration *[low/low/large]*

- **Conflict risk**: low
- **Why together**: Standalone research spike; large effort but low urgency.

### `work/work-folder-cleanup` (1 TODO)

- `work-folder-structure-and-cleanup` — Structure .furrow/rows/ to prevent unbounded growth *[medium/medium/medium]*

- **Key files**: `bin/rws`, `commands/archive.md`, `references/row-layout.md`
- **Conflict risk**: low
- **Why together**: Standalone housekeeping; depends on brain-dump-triage-command landing first.
- **Depends on**: brain-dump-triage-command

## Worktree Quick Reference

### Phase 1 — Post-install hygiene — test isolation, review pipeline, install asymmetry
```sh
git worktree add ../furrow-post-install-hygiene -b work/post-install-hygiene
```

### Phase 2 — CLI Go rewrite — foundational language migration
```sh
git worktree add ../furrow-cli-go-rewrite -b work/cli-go-rewrite
```

### Phase 3 — Dispatch + ambient contract — foundational for downstream skills
```sh
git worktree add ../furrow-sub-agent-normalization -b work/sub-agent-normalization
git worktree add ../furrow-ambient-context -b work/ambient-context
git worktree add ../furrow-effort-and-model-routing -b work/effort-and-model-routing
```

### Phase 4 — Worktree + merge pipeline — /furrow:work and /furrow:next overhaul
```sh
git worktree add ../furrow-worktree-integration -b work/worktree-integration
git worktree add ../furrow-next-merge-pipeline -b work/next-merge-pipeline
```

### Phase 5 — Seeds primitive — deterministic work graph replacing LLM-reasoned dependencies
```sh
git worktree add ../furrow-seeds -b work/seeds
```

### Phase 6 — Artifacts, reviews, row variants — UX patterns for collaboration
```sh
git worktree add ../furrow-artifacts-and-row-variants -b work/artifacts-and-row-variants
git worktree add ../furrow-review-surfaces -b work/review-surfaces
git worktree add ../furrow-triage-ux -b work/triage-ux
```

### Phase 7 — Post-seeds re-triage + dashboards + lifecycle
```sh
git worktree add ../furrow-post-seeds-retriage -b work/post-seeds-retriage
git worktree add ../furrow-dashboards-and-lifecycle -b work/dashboards-and-lifecycle
```

### Phase 8 — Research, long-tail, workflow cleanup
```sh
git worktree add ../furrow-research-mining -b work/research-mining
git worktree add ../furrow-memetic-research -b work/memetic-research
git worktree add ../furrow-work-folder-cleanup -b work/work-folder-cleanup
```
