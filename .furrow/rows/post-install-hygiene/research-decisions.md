# Research Decisions — post-install-hygiene

Decisions taken at the research → plan handoff. Plan step applies these to definition.yaml.

## R1 — Script-mode scope

**Decision: Fix all 19 non-executable scripts** (not just rescue.sh).

- All 19 files under `bin/frw.d/scripts/` that are currently 100644 get `git update-index --chmod=+x`.
- Single pre-commit hook `bin/frw.d/hooks/pre-commit-script-modes.sh` asserts all `bin/frw.d/scripts/*.sh` are 100755 going forward.
- Rename deliverable from `rescue-sh-exec-fix` to `script-modes-fix` to reflect scope. Rescue still gets called out in an AC as the known-broken one that originally surfaced the issue.

**Rationale**: same hook catches all; same specialist; same PR. Leaves 18 latent bugs fixed as a side effect.

## R2 — Learnings schema resolution

**Decision: A — Migrate the 4 old-format rows to the new schema + canonicalize.**

- One-time migration script (tracked in the deliverable) rewrites `learnings.jsonl` for the 4 old-format rows, mapping old fields to new: `timestamp → ts`, `source_step → step`, `category → kind` (document the mapping), `content → summary`, `context → detail`. Drop fields not in new schema; log any unmappable records for manual review.
- Update `skills/shared/learnings-protocol.md` to document only the new schema as canonical.
- Add `bin/frw.d/hooks/append-learning.sh` (or an existing hook) that validates every append against `schemas/learning.schema.json`.
- `commands/lib/promote-learnings.sh` reads the new schema only.

**Rationale**: cleanest end state; no permanent dual-schema code; one-time data transform runs against archived rows.

## R3 — preferred_specialists wiring

**Decision: In-row — create the first consumer.**

- `skills/shared/specialist-delegation.md` gains a "preferred specialist lookup" step that consults `resolve_config_value "preferred_specialists.<role>"` (e.g., `preferred_specialists.test-engineer`) when choosing a specialist at decompose time. Fallback to the current selection logic if unset.
- Add a regression test under `tests/integration/test-config-resolution.sh` that verifies: project override > XDG fallback > no-override-default-selection.
- XDG config schema in `config.yaml` documents `preferred_specialists` as a map from role-name to specialist-name.

**Rationale** (user override of my lean to defer): preferred_specialists should do something rather than be a write-only field. Wiring is small — one helper call in one file plus a test.

## R4 — Install architecture docs target

**Decision: Extend `docs/architecture/self-hosting.md` — do not create a new file.**

- The "Specialist symlinks are install-time artifacts" section lands as a new subsection of the existing 110-line self-hosting.md.
- Update definition.yaml AC to reference `docs/architecture/self-hosting.md` instead of the non-existent `install-architecture.md`.
- context_pointers updated to match.

**Rationale**: self-hosting.md already frames source-vs-consumer install and is owned by install-and-merge's prior work; this is a natural extension.

## Mechanical AC revisions (no user decision — apply at plan step)

M1. `cross-model-per-deliverable-diff`: replace `git diff <first>^..<last>` with `git log -p --no-merges <base>..HEAD -- <globs>` in the AC text. Document that `--follow` is single-path so rename tracking is not supported.

M2. `xdg-config-consumer-wiring`: replace references to a new `get_config_field` helper with the existing `resolve_config_value` in `bin/frw.d/lib/common.sh:121-144`. Either rename it, wrap it with a defaulting shim, or call it directly with caller-side fallback — plan step decides.

M3. `reintegration-schema-consolidation`: downgrade the archived-row migration AC from "walk and validate every file" to "migration script exists; regression test creates a synthetic pre-migration archived file and verifies the migration produces a schema-valid output." Since no archived reintegration.json files exist today, this is forward-looking insurance, not hot-path migration.

## Impact on existing definition.yaml at plan step

- **Rename**: `rescue-sh-exec-fix` → `script-modes-fix` (R1).
- **Expand ACs**: `script-modes-fix` gains "all 19 scripts chmod+x" + clarifying note about rescue as the originally-broken one.
- **Expand ACs**: `promote-learnings-schema-fix` gains migration-of-4-old-rows AC (R2).
- **Expand ACs**: `xdg-config-consumer-wiring` keeps preferred_specialists wiring + new consumer in specialist-delegation.md (R3).
- **Edit ACs**: point to `self-hosting.md` (R4).
- **Edit ACs**: M1, M2, M3 mechanical fixes.
- **No new deliverables; no removed deliverables; dependency graph unchanged.**
