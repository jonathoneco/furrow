# Post-Audit Planning Collapse Reconciliation

Date: 2026-04-28

Scope: item-level ledger for active roadmap Phase 5-15 rows and TODOs removed,
demoted, or folded by `work/post-audit-planning-collapse`.

## Rules Applied

- `roadmap.yaml` owns active phase/row execution state and completed row truth.
- `todos.yaml` remains canonical backlog input until an approved
  source-of-truth cutover row replaces it.
- `post_collapse_backlog` is a parking lot for deferred row candidates, folded
  rows, and blocked/provisional rows. It is not an execution queue.
- No roadmap/TODO UX, Pi UX, seed cutover, or code implementation is introduced
  by this row.
- No seed migration is approved by this row.

## Current Planning Ownership Contract

| Surface | Owns | Does not own |
| --- | --- | --- |
| `.furrow/almanac/roadmap.yaml` | Active phase/row execution state, row dependencies, key file surfaces, and completed row truth. | Canonical backlog intake or a new planning product UI. |
| `.furrow/almanac/todos.yaml` | Canonical backlog input until an explicitly approved source-of-truth cutover. | Active row execution state once a row is scheduled and tracked in the roadmap. |
| `post_collapse_backlog` | Deferred row candidates, folded rows, and blockers/provisional status for old roadmap groupings. | The next-row queue or approval to start blocked product work. |
| Seeds | Nothing new in this row. | TODO retirement, roadmap generation, Pi planning surfaces, or source-of-truth cutover. |

## Roadmap Row Ledger

| Prior row | Classification | Destination / reason |
| --- | --- | --- |
| `work/state-and-correction-guards` | `superseded` | The bundled row no longer matches the post-audit architecture. Layer rejection protection is split into `work/layer-guard-rejection-hardening`; Pi UX/schema/state expansion is backlog. |
| `work/artifact-validation-and-continuation` | `preserved-backlog` | Deferred behind collapse rows; still discoverable through `todos.yaml`. |
| `work/seeds-foundation` | `blocked-backlog` | Seed/TODO cutover work is deferred; `todos.yaml` stays canonical until an approved cutover row. |
| `work/seeds-graph-cutover-and-pi-surfaces` | `blocked-backlog` | Cutover and Pi planning surfaces are deferred until an approved cutover row. |
| `work/review-and-evaluator-orchestration` | `preserved-backlog` | Review execution remains optional by risk and is not part of immediate collapse. |
| `work/specialist-skills-and-engine-briefs` | `preserved-backlog` | Specialist/runtime output work waits until command and planning surfaces are smaller. |
| `work/row-variants-and-planning-ux` | `blocked-backlog` | Explicitly blocked until an approved planning UX/source-of-truth row; no new roadmap/TODO UX in this row. |
| `work/cli-introspection-and-history` | `folded-closed` | The immediate advertised-stub cleanup closed in `work/hide-vaporware-command-surface`; broader introspection/history must come from `todos.yaml` as a new explicit row. |
| `work/meta-and-archive-flow-improvements` | `preserved-backlog` | Archive/meta flow remains useful but is not in the collapse row. |
| `work/worktree-and-merge-pipeline` | `preserved-backlog` | Worktree/merge pipeline remains discoverable through `todos.yaml`. |
| `work/install-and-symlink-hygiene` | `preserved-backlog` | Install hygiene remains discoverable through `todos.yaml`. |
| `work/dual-runtime-parity-validation` | `provisional-backlog` | Parity work must be re-evaluated against live loaded-path evidence before execution. |
| `work/docs-and-research` | `preserved-backlog` | Docs/research must land or kill concrete implementation decisions before close. |
| `work/pi-native-leverage-and-tui` | `blocked-backlog` | Pi-native UX is deferred until backend truth is stable and a row explicitly approves Pi UX. |
| `work/legacy-shell-cutoff-and-removal` | `preserved-backlog` | Shell cutoff remains relevant but depends on parity and command replacement evidence. |

## TODO Ledger

| Prior TODO | Classification | Destination / reason |
| --- | --- | --- |
| `layer-guard-silent-rejection-on-top-layer-integrat` | `folded-into` | `work/layer-guard-rejection-hardening`. |
| `layer-guard-verdict-reason-should-also-write-to-st` | `folded-into` | Added to `work/layer-guard-rejection-hardening` to preserve verdict reason work. |
| `hook-chain-must-allow-edit-on-recovery-paths-when` | `folded-into` | Added to `work/layer-guard-rejection-hardening` to preserve narrow recovery work. |
| `state-guard-rm-coverage` | `preserved-backlog` | State guard expansion remains in `todos.yaml`; not immediate post-audit work. |
| `pi-correction-limit-visibility` | `preserved-backlog` | Pi footer/widget UX is explicitly deferred. |
| `pi-session-resume-reground` | `preserved-backlog` | Pi session reground UX is explicitly deferred. |
| `pi-tool-call-canonical-schema-and-surface-audit` | `preserved-backlog` | Canonical Pi handler schema waits until handler scope is reduced. |
| `artifact-validation-per-step-schema` | `preserved-backlog` | Deferred under artifact validation and continuation. |
| `artifact-continuation-model` | `preserved-backlog` | Deferred under artifact validation and continuation. |
| `stage-aware-ceremony-enforcement` | `preserved-backlog` | Deferred under artifact validation and continuation. |
| `artifact-writing-defaults` | `preserved-backlog` | Deferred under artifact validation and continuation. |
| `artifact-informed-handoffs-and-gate-prompts` | `preserved-backlog` | Deferred under artifact validation and continuation. |
| `seeds-typed-graph-nodes` | `preserved-backlog` | Deferred; no seed cutover in Phase 5. |
| `seeds-backend-surface-layer` | `preserved-backlog` | Deferred; no seed command work in Phase 5. |
| `seed-row-binding-contract` | `preserved-backlog` | Deferred until source-of-truth simplification. |
| `seeds-concept` | `preserved-backlog` | Deferred; `todos.yaml` remains canonical. |
| `pi-almanac-operating-model` | `preserved-backlog` | Deferred; no Pi planning UI in Phase 5. |
| `seeds-graph-queries` | `preserved-backlog` | Deferred; no seed graph cutover in Phase 5. |
| `seeds-follow-up-promotion` | `preserved-backlog` | Deferred; no seed follow-up promotion in Phase 5. |
| `roadmap-generation-from-seeds` | `preserved-backlog` | Deferred; no derived roadmap/TODO UX before simplification. |
| `todo-to-seed-cutover-migration` | `preserved-backlog` | Deferred; explicit approved cutover row still required. |
| `pi-seed-surfaces-in-work-loop` | `preserved-backlog` | Deferred; no Pi planning surfaces in Phase 5. |
| `almanac-scope-after-todo-retirement` | `preserved-backlog` | Deferred; `todos.yaml` remains canonical. |
| `todo-context-references` | `preserved-backlog` | Deferred as TODO backlog support. |
| `review-evaluator-isolation-spec` | `preserved-backlog` | Deferred under review/evaluator orchestration. |
| `unified-isolated-review` | `preserved-backlog` | Deferred under review/evaluator orchestration. |
| `gate-dimension-deduplication` | `preserved-backlog` | Deferred under review/evaluator orchestration. |
| `collaborative-surfaces` | `preserved-backlog` | Deferred under review/evaluator orchestration. |
| `sub-agent-normalization` | `preserved-backlog` | Deferred under specialist skills and engine briefs. |
| `specialist-quality-validation` | `preserved-backlog` | Deferred under specialist skills and engine briefs. |
| `specialist-template-warning-escalation` | `preserved-backlog` | Deferred under specialist skills and engine briefs. |
| `effort-selection-alongside-model` | `preserved-backlog` | Deferred under specialist skills and engine briefs. |
| `engine-fan-out-budget-depth-and-token-limits-for-a` | `preserved-backlog` | Deferred under specialist skills and engine briefs. |
| `patch-row-concept` | `preserved-backlog` | Deferred; row variants/planning UX blocked by `work/post-audit-planning-collapse`. |
| `spike-row-mode` | `preserved-backlog` | Deferred; row variants/planning UX blocked by `work/post-audit-planning-collapse`. |
| `brain-dump-triage-command` | `preserved-backlog` | Deferred; roadmap/TODO UX blocked by `work/post-audit-planning-collapse`. |
| `sprint-inspired-planning` | `preserved-backlog` | Deferred; roadmap/TODO UX blocked by `work/post-audit-planning-collapse`. |
| `support-todos-sharding` | `preserved-backlog` | Deferred; TODO storage changes blocked by source-of-truth simplification. |
| `user-action-integration` | `preserved-backlog` | Deferred; planning UX blocked by `work/post-audit-planning-collapse`. |
| `post-merge-watch-list` | `preserved-backlog` | Deferred; planning UX blocked by `work/post-audit-planning-collapse`. |
| `ambient-context-promotion` | `preserved-backlog` | Deferred; planning/context promotion UX blocked by `work/post-audit-planning-collapse`. |
| `cli-introspection-suite` | `preserved-backlog` | Broader introspection remains backlog; stub hiding is immediate. |
| `cli-architecture-overhaul-slice-2` | `preserved-backlog` | Broader CLI port remains backlog; advertised-stub cleanup folds into `work/hide-vaporware-command-surface`. |
| `harness-parallel-dispatch-race` | `preserved-backlog` | Deferred under CLI introspection/history. |
| `close-re-evaluate-dispatch-enforcement-observation` | `preserved-backlog` | Deferred under CLI introspection/history. |
| `supervised-decision-surface-spec` | `preserved-backlog` | Deferred under meta/archive flow. |
| `archive-implications-propagation` | `preserved-backlog` | Deferred under meta/archive flow. |
| `furrow-meta-folds-into-roadmap` | `preserved-backlog` | Deferred under meta/archive flow. |
| `furrow-work-worktree-integration` | `preserved-backlog` | Deferred under worktree/merge pipeline. |
| `furrow-next-semantic-merge` | `preserved-backlog` | Deferred under worktree/merge pipeline. |
| `furrow-next-phase-lifecycle` | `preserved-backlog` | Deferred under worktree/merge pipeline. |
| `merge-process-skill` | `preserved-backlog` | Deferred under worktree/merge pipeline. |
| `formalize-team-orchestrated-phase-integration-as-a` | `preserved-backlog` | Deferred under worktree/merge pipeline. |
| `install-user-bin-worktree-pinning` | `preserved-backlog` | Deferred under install/symlink hygiene. |
| `consumer-install-symlink-validation` | `preserved-backlog` | Deferred under install/symlink hygiene. |
| `xdg-state-isolation-audit-and-doc` | `preserved-backlog` | Deferred under install/symlink hygiene. |
| `post-install-hygiene-followup` | `preserved-backlog` | Deferred under install/symlink hygiene. |
| `harness-lifecycle-ux` | `preserved-backlog` | Deferred under install/symlink hygiene. |
| `adapters-audit` | `preserved-backlog` | Deferred under dual-runtime parity; live loaded-path evidence required. |
| `define-adapters-audit-pass-fail-rubric` | `preserved-backlog` | Deferred under dual-runtime parity. |
| `claude-wrapper-compatibility` | `preserved-backlog` | Deferred under dual-runtime parity. |
| `pi-adapter-package` | `preserved-backlog` | Deferred under dual-runtime parity. |
| `dual-runtime-parity-validation` | `preserved-backlog` | Deferred under dual-runtime parity. |
| `workflow-power-preservation` | `preserved-backlog` | Deferred under dual-runtime parity. |
| `docs-cleanup-pass` | `preserved-backlog` | Deferred under docs/research. |
| `doc-authority-class-enforcement` | `preserved-backlog` | Deferred under docs/research. |
| `migration-residue-archival` | `preserved-backlog` | Deferred under docs/research. |
| `mine-claude-code` | `preserved-backlog` | Deferred under docs/research; must land or kill concrete decisions. |
| `mine-v1-harness` | `preserved-backlog` | Deferred under docs/research; must land or kill concrete decisions. |
| `memetic-algorithms-research` | `preserved-backlog` | Deferred under docs/research; must land or kill concrete decisions. |
| `research-documentation-detection` | `preserved-backlog` | Deferred under docs/research. |
| `research-methodology-design` | `preserved-backlog` | Deferred under docs/research; must land or kill concrete decisions. |
| `apply-nate-jones-skill` | `preserved-backlog` | Deferred under docs/research; must land or kill concrete decisions. |
| `land-or-kill-decision-for-phase-8-research-streams` | `preserved-backlog` | Deferred under docs/research. |
| `finalize-transitional-architecture-docs-authority` | `preserved-backlog` | Deferred under docs/research. |
| `furrow-tui-dashboard` | `preserved-backlog` | Deferred under Pi-native leverage; no Pi UX before simplification. |
| `furrow-self-update-hook` | `preserved-backlog` | Deferred under Pi-native leverage. |
| `pi-native-capability-leverage` | `preserved-backlog` | Deferred under Pi-native leverage; no Pi UX before simplification. |
| `remove-bin-rws-shell-entrypoint` | `preserved-backlog` | Deferred under legacy shell cutoff. |
| `remove-bin-alm-shell-entrypoint` | `preserved-backlog` | Deferred under legacy shell cutoff. |
| `remove-bin-sds-shell-entrypoint` | `preserved-backlog` | Deferred under legacy shell cutoff. |
| `retire-todos-yaml-as-canonical-planning-primitive` | `preserved-backlog` | Deferred under legacy shell cutoff; `todos.yaml` remains canonical until approved cutover. |
| `remove-legacy-shell-hooks-under-bin-frw-d-hooks` | `preserved-backlog` | Deferred under legacy shell cutoff. |
| `archive-legacy-shell-scripts-tree` | `preserved-backlog` | Deferred under legacy shell cutoff. |
| `remove-claude-shell-wrappers-after-dual-runtime-pa` | `preserved-backlog` | Deferred under legacy shell cutoff. |

## Required Topic Reconciliation

- Current Phase 5 state/correction guard items: layer rejection work folded into
  `work/layer-guard-rejection-hardening`; Pi UX/schema/state expansion is
  preserved backlog.
- Seed/TODO cutover rows: preserved backlog; `todos.yaml` remains canonical.
- Row variants/planning UX: preserved backlog and explicitly blocked by
  `work/post-audit-planning-collapse`.
- Review/specialist rows: preserved backlog, no new default ceremony.
- CLI introspection/history: advertised-stub cleanup folded into
  `work/hide-vaporware-command-surface`; broad command expansion is backlog.
- Meta/archive flow: preserved backlog.
- Worktree/install pipeline: preserved backlog.
- Dual-runtime parity: preserved backlog with loaded-path evidence requirement.
- Docs/research: preserved backlog; research must land or kill decisions.
- Pi-native leverage: preserved backlog; no Pi UX before simplification.
- Legacy shell cutoff: preserved backlog; hard cutoff still requires parity and
  replacement evidence.
