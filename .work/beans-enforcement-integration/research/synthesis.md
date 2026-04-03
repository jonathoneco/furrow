# Research Synthesis: Seeds Integration

## Summary

Five parallel research tracks completed. All deliverables have clear implementation paths with no blocking unknowns.

## Key Findings by Deliverable

### D1: .furrow/ Restructure
- 127+ files reference `.work/`; mechanical find-and-replace with exhaustive grep verification
- Migration script must handle: mid-transition rows, missing .beans/, symlinks, .focused pointer
- Sequence: move files first, update references second, verify with grep third

### D2: sds CLI
- Fork from `bn` is straightforward — 2 path variables, 1 case statement, help text
- Core mechanics (dedup-on-read, flock, merge=union) unchanged
- Extended statuses: 10 values replacing 3
- Default status on create stays `open`; `rws` sets `claimed` immediately after
- Remove `in_progress` (replaced by step-specific statuses)
- Remove `migrate-from-beads`; add `migrate-from-beans` for data migration

### D3: rws CLI
- Monolithic ~1000-1200 line POSIX shell script with case dispatch
- step-transition.sh is the orchestrator; its internal calls (record-gate, advance-step, etc.) become internal functions
- All state mutations via update-state.sh (preserved as internal)
- New exit code 7 for seed mismatch (hard block)
- Focus management (.furrow/.focused) as first-class subcommand

### D4: Seeds-Row Integration
- Dual-layer gate check: Phase A (seed exists, not closed) + Phase B (status matches step)
- Step→status mapping codified (ideate→ideating, etc.)
- seed-sync dimension added to all 7 gate YAML files
- Recovery path requires human input: user must investigate mismatch, manually run `sds update` to correct, then re-trigger gate
- No auto-recovery, no automated resync — mismatches are procedural signal

### D5: alm CLI
- Monolithic ~600-800 line POSIX shell script
- 3 scripts absorbed, 4 new subcommands added (add, list, show, next)
- roadmap.yaml schema designed with DAG nodes/edges, phases, conflict zones
- Dual output deferred — YAML only for now, human-readable via `alm` subcommands
- todos.yaml schema: add `seed_id` field and `legacy` source type

## Architectural Decisions

| Decision | Rationale |
|---|---|
| Monolithic scripts over lib/ directories | bn works at 450 lines; rws at ~1200 and alm at ~800 are manageable |
| sds default status = `open` | Keep sds generic; rws sets `claimed` after creation |
| Phase A + Phase B for seed checks | Phase A fails fast (hard block); Phase B provides evidence |
| Exit code 7 for seed mismatch | Distinguishes seed errors from other gate failures |
| roadmap.yaml only (no .md render) | YAML is canonical; human output via `alm` CLI on demand |
| Recovery requires human input | Mismatches signal procedural errors; auto-correct hides problems |

## Open Questions Resolved

1. **Scripts NOT absorbed by rws**: run-gate.sh, evaluate-gate.sh, check-artifacts.sh, update-state.sh, etc. stay as standalone utilities called by rws internally. They don't need CLI exposure.

2. **Duplicate schemas**: schemas/ vs adapters/shared/schemas/ — defer consolidation. Both get updated in this work unit; cleanup is separate TODO.

3. **Project prefix for sds**: Set during `sds init --prefix <name>`, called by migration script or `rws` on first init. Deferred to implementation.

4. **Existing .work/ data during migration**: Preserve as-is in .furrow/rows/. state.json files get `seed_id` field added (null initially until row is used with seeds).

## Risk Assessment

| Risk | Severity | Mitigation |
|---|---|---|
| Stale .work/ references after rename | HIGH | Exhaustive grep verification after D1 |
| Missed status validation in sds | MEDIUM | Test all 10 statuses in create/update/list |
| rws transition breaks supervised flow | HIGH | Integration tests for two-phase flow |
| Migration script fails on edge cases | MEDIUM | Idempotent design, test on current data |
| Gate evaluation latency from sds calls | LOW | sds show is fast (~10ms, local file) |

## Implementation Sequence

```
D1 (restructure) ──→ checkpoint: grep clean
  ↓
D2 (sds) ──┐
D5 (alm) ──┤── parallel after D1
D3 (rws) ──┘
  ↓
D4 (integration) ── depends on D2+D3+D5
  ↓
Final: end-to-end test, migration script test
```
