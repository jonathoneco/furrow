# Plan Step — Phase 4: Plan artifacts

**Row**: `agent-host-portability-research`
**Step**: plan
**Phase**: 4 of 4
**Purpose**: Produce `plan.json` (wave ordering + specialist + file_ownership per deliverable) and `team-plan.md`. Then dual-reviewer dispatch, then plan → spec transition.

Answer inline. One-liners or "agree with lean" fine.

---

## P4-1 — Deliverable restructure: add `harness-schema-upgrades`?

The schema-level R10 adopts (typed JSON Schema blocks, typed `produces:`, specialist YAML contract) are currently sub-items under `pi-ecosystem-integration`. But they're CORE changes (touching `bin/alm`, `schemas/`, `specialists/`, `bin/rws`), not ecosystem compositions. Naming feels wrong.

- **(a) Keep as-is** — sub-items under `pi-ecosystem-integration`.
  - Pro: no restructure churn.
  - Con: misnamed grouping; harness-schema work happens under "ecosystem integration" label.

- **(b) Add new deliverable `harness-schema-upgrades`** between `pi-adapter-interface` and `pi-adapter`. Move the 3 schema ACs from `pi-ecosystem-integration` into it.
  - Pro: clean naming; dependency is explicit (`pi-adapter` depends on schema upgrades).
  - Con: 6-deliverable row; one more review cycle.

- **(c) Fold schema upgrades into `pi-adapter-interface`** — interface deliverable gains "and the harness-schema upgrades that support it" scope.
  - Pro: no new deliverable.
  - Con: interface deliverable balloons; conflates "design the interface" with "refactor the harness to support it."

**My lean: (b) add harness-schema-upgrades as a separate deliverable.** Schema work is cross-cutting (almanac + definition.yaml + specialists). Its own deliverable lets us scope it properly, assign the right specialist, and validate the migration path independently.

> YOUR ANSWER: Agreed

---

## P4-2 — Wave ordering

Given dependency DAG:

- `pi-migration-gap-analysis` (foundational, no deps)
- `pi-adapter-interface` (needs gap-analysis)
- `harness-schema-upgrades` (IF P4-1 adopts b — needs interface for alignment)
- `pi-adapter` (needs interface + harness-schema-upgrades if created)
- `pi-ecosystem-integration` (needs pi-adapter)
- `dual-host-migration-validation` (needs pi-adapter + pi-ecosystem-integration)

Wave options:

- **(a) Linear — 5 or 6 waves, one deliverable each.** No parallelism.
  - Pro: safest; each wave validates cleanly before next starts.
  - Con: no time savings.

- **(b) Parallel where possible** — after interface, run `harness-schema-upgrades` + `pi-adapter` in parallel if the schema migration doesn't block adapter code.
  - Pro: saves session time.
  - Con: adapter references schemas; parallel work risks churn if schemas shift.

- **(c) Pipeline with staging** — start next wave when prior wave's deliverable reaches 80% completion.
  - Pro: overlap without full parallelism.
  - Con: soft boundaries; hard to enforce.

**My lean: (a) linear 6 waves** (assuming P4-1 = b). No parallel-wave savings worth the risk of schema drift. Furrow's `pi-subagents`-driven parallelism can speed individual-deliverable work, but wave boundaries stay sequential.

> YOUR ANSWER: Agreed

---

## P4-3 — Specialist assignments

Current assignments (from definition.yaml):

| Deliverable                           | Specialist        | Rationale                                    |
| ------------------------------------- | ----------------- | -------------------------------------------- |
| `pi-migration-gap-analysis`           | systems-architect | Cross-cutting synthesis + trade-off analysis |
| `pi-adapter-interface`                | systems-architect | Interface spec = architecture work           |
| `harness-schema-upgrades` (if P4-1=b) | ??                | Schema design + migration scripts            |
| `pi-adapter`                          | harness-engineer  | Hook infrastructure + shell+TS integration   |
| `pi-ecosystem-integration`            | harness-engineer  | Plugin composition + install recipes         |
| `dual-host-migration-validation`      | harness-engineer  | Validation + per-host smoke tests            |

**Q for `harness-schema-upgrades` specialist** (if P4-1=b):

- **(a) systems-architect** — schema design is architectural
- **(b) harness-engineer** — touches bin/alm, bin/rws, schemas/ — harness surface
- **(c) Split**: systems-architect for schema design, harness-engineer for migration/validation — sequential sub-tasks within the deliverable

**My lean: (b) harness-engineer**. The schema design work was done in Phase 3 (by us/user). What remains is implementation — schema files, `alm` validation wiring, migration scripts. That's harness engineering.

> YOUR ANSWER: I lean Option C

---

## P4-4 — File ownership boundaries per deliverable

Per P3-4, `file_ownership:` is the write scope per specialist. Proposed boundaries:

| Deliverable                           | file_ownership                                                                                                                      |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `pi-migration-gap-analysis`           | `docs/research/pi-migration-gap-analysis.md`                                                                                        |
| `pi-adapter-interface`                | `docs/architecture/pi-adapter-interface.md`, `schemas/host-adapter-interface.schema.json`                                           |
| `harness-schema-upgrades` (if P4-1=b) | `schemas/*.schema.json`, `bin/alm`, `bin/rws`, `.furrow/almanac/*.yaml` (migration only), `specialists/**` (frontmatter-only edits) |
| `pi-adapter`                          | `adapters/pi/**`, `bin/frw.d/hooks/pi-*.sh`                                                                                         |
| `pi-ecosystem-integration`            | `adapters/pi/ecosystem/**`, `docs/architecture/pi-ecosystem-integration.md`                                                         |
| `dual-host-migration-validation`      | `docs/architecture/dual-host-validation.md`, `bin/frw.d/scripts/host-switch.sh`                                                     |

Concerns to flag:

- `harness-schema-upgrades` touches a LOT of surface. Worth sub-decomposing?
- `specialists/**` frontmatter edits overlap with any later specialist-template changes — conflict risk with specialist-quality work in roadmap Phase 3.

**My lean: accept the boundaries; add explicit constraint that harness-schema-upgrades touches specialists/ only for frontmatter, not body content.**

> YOUR ANSWER: Agreed

---

## P4-5 — Dual-reviewer scope

Plan skill requires dual-reviewer: fresh Claude + cross-model (codex). What artifacts go to reviewers?

- **(a) plan.json + team-plan.md + summary.md** — plan artifacts only.
- **(b) + definition.yaml** — include the contract being planned against.
- **(c) + definition.yaml + phase-1/2/3/4 files** — include the architectural reasoning trail.

**My lean: (b)**. Plan reviewers need the contract (definition.yaml) to verify plan matches. Phase files are my work, not review input — reviewers should reach independent conclusions.

> YOUR ANSWER: Agreed

---

## P4-6 — Post-plan-review behavior

If reviewers return concerns, what's the threshold for "revise and re-review" vs "revise and proceed"?

- **(a) Any concern → re-review** — conservative, high-quality.
- **(b) Blocker-level → re-review; concerns → note and proceed** — balanced.
- **(c) Always proceed, address in spec step** — fast but risky.

**My lean: (b)**. Blocker = plan structure or missing deliverable coverage. Concern = stylistic, sequencing preference, etc. — can be addressed in spec without another review cycle.

> YOUR ANSWER: Agreed

---

## P4-7 — Plan summary update

After plan.json + team-plan.md are written, `summary.md` needs Key Findings / Open Questions / Recommendations updated for plan step.

- **(a) I write them based on Phase 1-4 decisions** — standard pattern.
- **(b) You draft, I refine** — slower but matches your plan-step ownership.

**My lean: (a)**. Phase decisions are already recorded in the phase files; summary.md just extracts highlights.

> YOUR ANSWER: Agreed

---

## What happens after Phase 4 is locked

1. If P4-1 = b: edit `definition.yaml` to add `harness-schema-upgrades` deliverable; re-validate.
2. Write `plan.json` with wave ordering + assignments.
3. Write `team-plan.md` with specialist briefings per deliverable.
4. Update `summary.md` (Key Findings / Open Questions / Recommendations for plan step).
5. Dispatch dual reviewers (fresh Claude + codex cross-model).
6. Synthesize review findings; revise as needed.
7. Ask you: "**Ready to advance to spec?**"
8. On yes: `rws transition agent-host-portability-research pass manual "<evidence>"`.
9. Load `skills/spec.md` and begin spec step.
