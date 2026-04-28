# Roadmap Truth Hardening Audit

Date: 2026-04-28

Scope: planned Phases 5-15, plus completed Phase 1-4 wording that future rows
depend on.

## Findings

### CUTOVER-MISSING: Pi parity wording implied full enforcement

Fixed in roadmap.

Phase 3 is now titled `Pi enforcement foundations (loaded-path corrected)` and
states that only loaded-path main-thread Pi layer enforcement is complete.
Subprocess subagent hook blindness remains a known limitation, not a completed
parity claim.

### DEPENDENCY-GAP: Backend contract rows lacked normalized hook inputs

Fixed in correction scope.

The roadmap now references the Session 2 correction: `ToolEvent` and
`PresentationEvent` are backend-owned normalized inputs; Claude/Pi runtime
payloads are adapter shims.

### VAPORWARE-IN-PLANNING: Blocker parity counted absent Pi handlers

Fixed in tests and roadmap wording.

Absent Pi handlers are fixture inventory, not parity passes. Future parity rows
must add live adapter handlers or downgrade the claim.

### DUAL-SOURCE: seeds.jsonl versus todos.yaml

Fixed in roadmap wording.

Phase 7 now introduces seeds as the future source while `todos.yaml` remains
canonical. Phase 8 performs the cutover: `seeds.jsonl` becomes authoritative,
roadmap/todos views become derived, and `todos.yaml` freezes until Phase 15
removal.

### OPTIONALITY-DRIFT: Specialist rows described registered agent types

Fixed in roadmap wording.

Phase 9 row 2 is now `work/specialist-skills-and-engine-briefs`. Specialists
are described as skills loaded into general agents; runtime-specific agent files
are adapter-rendered outputs.

### COLLISION-RISK: Remaining high-overlap phases

Reviewed and accepted.

The roadmap already sequences high-overlap work into single-row phases for
artifact validation, seeds foundation, seeds cutover, row variants, CLI
introspection, and archive flow. Phase 13 and Phase 15 remain parallel waves
because their rows touch related but separable surfaces and have explicit
dependency gates.

### CUTOVER-MISSING: Legacy shell hybrid

Already represented.

Phase 15 names the hard cutoff row and exact removal surfaces:
`bin/rws`, `bin/alm`, `bin/sds`, `bin/frw.d/hooks/`, `bin/frw.d/scripts/`,
`.furrow/almanac/todos.yaml`, and obsolete Claude shell wrappers.

## Manual Hardening Notes

- Replacement rows now either include cutover semantics or depend on a cutoff
  row.
- Transitional research streams in Phase 14 must land or kill outputs before
  row close.
- Adapter/backend ownership is explicit: backend rows own normalized contracts;
  adapter rows own runtime discovery, translation, templates, and UI.

## Verification Notes

Run after edits:

- `furrow almanac validate`
- `frw doctor`

Manual limitation:

- The parallel-batch invariant cannot reason about semantic collision in
  `skills/`, `commands/`, or `internal/cli/`; those risks are captured in
  phase rationales and `conflict_risk` fields.
