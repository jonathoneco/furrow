# Team Plan — install-and-merge

## Lead specialists

| Deliverable | Specialist | Wave | Why |
|---|---|---|---|
| install-architecture-overhaul | harness-engineer | 1 | Owns shell script hygiene, hook cascade, install flow. Primary author. |
| config-cleanup | harness-engineer | 2 | Same surface — schemas, dispatcher, resolver. Handoff from wave 1. |
| worktree-reintegration-summary | harness-engineer | 2 | Surface is `rws` + skills + schema — continuation of harness work. |
| merge-process-skill | merge-specialist | 3 | New subagent surface (`/furrow:merge`); git merge reasoning beyond harness work. |

## Consultants (read-only advisers)

| Consultant | Engages on | How |
|---|---|---|
| shell-specialist | POSIX portability review of install.sh, frw.d scripts, rescue.sh, merge scripts | Spot-review diffs before commit; flag bash-isms and GNU-only flags. Formal pass at end of each wave. |
| complexity-skeptic | XDG config tier scope; argue against `promotion-targets.yaml` creep; challenge the rescue bundled-baseline maintenance cost | Single skeptical pass at the end of wave 1 and beginning of wave 2 (before config-cleanup scope ossifies). |
| test-engineer | Integration-test ACs across all four deliverables — testability, flake risk, fixture-repo design | Review test plans before fixtures are written; re-review after first green run. |

## Engagement protocol

- Lead specialist owns code changes (writes).
- Consultants get read-only drafts via delegated subagent runs; return structured findings.
- Leads must address or explicitly reject each finding in the deliverable's review record before the deliverable can be marked complete.
- Consultants don't gate the step transition — they gate the deliverable completion inside the step.

## Wave-level parallelism

- Waves 1 → 2 → 3: strict dependency order (wave 2 needs wave 1 infrastructure; wave 3 needs both).
- Within wave 2: `config-cleanup` and `worktree-reintegration-summary` run in parallel. File_ownership is disjoint (see plan.json `parallel_safety` field). No shared writes.
- Within wave 1: deliverable is internally sequenced into Foundation → Enforcement passes (see plan.json `internal_sequencing`). Foundation is additive-only and ships first so `frw rescue` exists before `common.sh` is touched.

## Decisions carried in from plan step

| Question | Resolution | Applied where |
|---|---|---|
| OQ-1: sort ordering | Tuple `(created_at, id)` with `LC_ALL=C` stabilization | wave 1, sub-step 1k |
| OQ-2: `--no-verify` escape hatch | Accept; warn in hook stderr; CI belt-and-suspenders | wave 1, sub-step 1g + docs |
| OQ-3: install-state.json scope | Per-repo under `$XDG_STATE_HOME/furrow/{repo-slug}/`; slug from `remote.origin.url` basename with path-hash fallback | wave 1, sub-step 1j |
| OQ-4: rescue when common.sh missing | Bundled baseline heredoc; write + warn `--not-from-HEAD` | wave 1, sub-step 1d |

## Handoff contracts

- **Wave 1 → Wave 2**:
  - `bin/frw.d/lib/common-minimal.sh` exists and is sourced by all hooks.
  - `bin/frw.d/scripts/rescue.sh` exists and passes its smoke test.
  - `.furrow/SOURCE_REPO` sentinel is committed.
  - `schemas/definition.schema.json` has `source_todos` (already done this session).
  - Pre-commit hooks are live so wave-2 work can't regress wave-1 state.
- **Wave 2 → Wave 3**:
  - `bin/frw upgrade` dispatcher case exists and passes migration test.
  - `schemas/reintegration.schema.json` is in place; `rws generate-reintegration` works.
  - `templates/reintegration.md.tmpl` is available.
  - Resolution chain respects `$XDG_CONFIG_HOME`.

## Gate signatures

For each deliverable:
- All acceptance criteria from definition.yaml satisfied.
- Integration test(s) green on a clean checkout.
- Specialist review record in `.furrow/rows/install-and-merge/reviews/`.
- Consultant findings resolved or explicitly rejected with rationale.

## Decompose-step additions

### Task enumeration (26 tasks total across 3 waves)

Derived from plan.json `internal_sequencing` fields.

- **Wave 1** (install-architecture-overhaul) — 14 tasks: 1a–1n.
  - **Foundation block** (1a–1e): sentinel + 24-symlink repair + common-minimal.sh + rescue.sh + foundation tests. All additive; can land before any common.sh change.
  - **Enforcement block** (1f–1n): common.sh reduction + pre-commit hooks + gitignore + SOURCE_REPO branching + XDG quarantine + sort-by-id + integration tests + CI drift check + no-verify bypass test.
- **Wave 2** (parallel) — 13 tasks total:
  - `config-cleanup` 2a–2g (7 tasks).
  - `worktree-reintegration-summary` 2h–2m (6 tasks).
  - File ownership verified disjoint per plan.json `parallel_safety`.
- **Wave 3** (merge-process-skill) — 10 tasks: 3a–3j. Policy schema → command file → five subphase scripts → script-guard fix → audit-reintegration wire → end-to-end test.

### Task sizing rubric

Each lettered sub-step is sized to a single specialist-sub-agent dispatch (target: 1 PR's worth of change, 200–600 LOC of code + test, with its own atomic commit). Tasks with explicit dependencies on prior sub-steps within the same wave run sequentially; otherwise, within the two parallel deliverables of wave 2, the implement step can fan out two sub-agents simultaneously.

### Implementation-step dispatch plan

- Wave 1: single harness-engineer sub-agent processes 1a–1e Foundation; verify tests green; then same agent processes 1f–1n Enforcement. Consultant engagements at end of Foundation (shell-specialist + test-engineer) and end of Enforcement (shell-specialist + complexity-skeptic).
- Wave 2: two harness-engineer sub-agents run in parallel (config-cleanup and worktree-reintegration-summary). Consultant engagements as assigned in team-plan.
- Wave 3: single merge-specialist sub-agent; consultant engagements at end.

### Vertical slicing note

Each deliverable is independently testable after its wave completes — wave 1 ships a working install + rescue + minimal lib without requiring wave 2's config tier. Wave 2's config-cleanup ships a working `frw upgrade` without requiring reintegration-summary. Wave 2's reintegration-summary ships working reintegration generation without requiring merge-skill. Wave 3's merge-skill consumes all prior but the merge fixture test exercises end-to-end.
