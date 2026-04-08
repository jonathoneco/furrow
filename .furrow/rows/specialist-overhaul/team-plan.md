# Team Plan: specialist-overhaul

## Wave Structure

4 waves, max parallelism of 2. Constrained by file ownership overlaps
on `skills/*.md` (3 deliverables touch these) and `specialists/_meta.yaml`
(2 deliverables touch this).

### Wave 1 — Foundation (parallel)

| Deliverable | Specialist | Files | Notes |
|---|---|---|---|
| gate-check-hook-fix | harness-engineer | `bin/frw.d/hooks/gate-check.sh` | Already partially done during research. Finalize and test. |
| specialist-reasoning-upgrade | complexity-skeptic | `specialists/*.md`, `references/specialist-template.md` | Update template standard first, then upgrade 15 specialists. WEAK first, then ADEQUATE grounding pass. |

No file overlap — safe to parallelize.

### Wave 2 — Content expansion (parallel)

| Deliverable | Specialist | Files | Notes |
|---|---|---|---|
| review-consent-isolation | harness-engineer | `skills/review.md` | Small: add consent isolation guidance to supervised transition protocol. |
| specialist-expansion | systems-architect | New specialist files, `_meta.yaml`, `rationale.yaml`, `harness-engineer.md` | Write 5 new specialists from research designs. Register in _meta.yaml and rationale.yaml. |

No file overlap — safe to parallelize.
specialist-expansion touches `_meta.yaml` which wave 1's specialist-reasoning-upgrade
also touched — wave ordering prevents conflict.

### Wave 3 — Enforcement (sequential)

| Deliverable | Specialist | Files | Notes |
|---|---|---|---|
| enforcement-wiring | harness-engineer | `skills/implement.md`, `skills/spec.md`, `skills/review.md` | Hard requirement for specialist loading + step-level modifiers. Must come after review-consent-isolation (wave 2) since both touch skills/review.md. |

### Wave 4 — Simplification (sequential)

| Deliverable | Specialist | Files | Notes |
|---|---|---|---|
| transition-simplification | harness-engineer | `bin/rws`, all `skills/*.md` | Largest refactor. Collapse --request/--confirm into single command. Update all 7 step skill transition protocols. Must come last — touches files modified by waves 2 and 3. Also clean up gate-check hook's --request/--confirm logic. |

## Architecture Decisions

1. **Template standard update before specialist upgrades** (wave 1):
   specialist-reasoning-upgrade must update `references/specialist-template.md`
   BEFORE upgrading individual specialists. Research identified 6 template
   standard gaps (no project-specific grounding requirement, no distinction
   between restated best practice and reasoning pattern, etc.).
   Source: `research/specialist-reasoning-upgrade.md` § "Template Standard Gaps Found"

2. **Gate-check hook cleanup in wave 4, not wave 1**: Wave 1 fixes the hook's
   two bugs (regex capturing `--request` instead of row name, wrong check
   function). Wave 4 revisits the hook when collapsing --request/--confirm
   into a single command — the hook's `--request`/`--confirm` branching
   becomes obsolete and needs redesign or removal.
   Source: `research/gate-check-hook-fix.md` § "Fix",
   `research/transition-simplification.md` § "Interaction with gate-check-hook-fix"

3. **specialist-expansion uses research designs directly**: Domain research
   produced detailed reasoning patterns for all 5 new specialists (6-8
   patterns each with quality criteria and anti-pattern tables). Implementation
   adapts these to stay within the 80-line template budget.
   Source: `research/specialist-expansion.md` § "New Specialist Designs"

4. **Shell-specialist differentiation**: Research audit found shell-specialist
   overlaps heavily with harness-engineer (shell-101 content vs. project-specific
   shell conventions already in harness-engineer). During wave 1, decide whether
   to differentiate (scope to non-harness shell work) or merge.
   Source: `research/specialist-reasoning-upgrade.md` § "Detailed Notes: WEAK Specialists: shell-specialist"
