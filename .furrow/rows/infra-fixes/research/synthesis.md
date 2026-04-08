# Research Synthesis: infra-fixes

## Summary

Research across all 4 deliverables is complete. Key finding: the scope of each
deliverable is clearer and more precise than ideation assumed.

## Deliverable 1: project-root-resolution

**Scope is well-defined.** 11 project-relative bugs in 8 files, all following the
same pattern (`$FURROW_ROOT/.furrow/rows/...`). Fix is mechanical: introduce
`PROJECT_ROOT` variable in `bin/frw`, change 11 references. 98 install-relative
references are correct and untouched.

**Design decision**: `PROJECT_ROOT` defaults to `$(pwd)` — no directory walk needed.
The harness already assumes you run from the project root. Exported alongside
FURROW_ROOT by the frw dispatcher.

**Risk**: Low for the 11 fixes. Medium for the 4 ambiguous references in
measure-context.sh and doctor.sh (they accept parameters but default to FURROW_ROOT).

## Deliverable 2: specialist-template-enforcement

**Scope is narrower than expected.** `skills/implement.md` already has blocking
specialist loading instructions (lines 25-33). The original TODO may predate these
instructions. The actual gaps are:

1. **Shell-level**: `generate-plan.sh` doesn't validate specialist files exist
2. **Skill-level**: implement.md says "STOP" but user decision is warn+proceed
3. **Observability**: No way to verify agents actually loaded specialists

Fix: Add file validation in generate-plan.sh (warn), reconcile implement.md
language to warn+proceed, defer observability to separate TODO.

## Deliverable 3: config-move-and-source-todo

**Blast radius is manageable.** 9 source files need furrow.yaml path updates.
2 files already handle both locations (auto-install.sh, launch-phase.sh) — use
their candidate loop pattern. Text references in 4 command files also need updates.

**Migration**: Candidate loop (`.furrow/furrow.yaml` → `.claude/furrow.yaml`)
provides backward compatibility. No forced migration.

**source_todo wiring**: The field exists in state.json schema, `rws init` accepts
`--source-todo`. Gap is in `/furrow:next` (commands/next.md) which never reads
state.json. Fix is a skill-level change to the next command instructions.

## Deliverable 4: cross-model-ideation-review

**Design is straightforward.** Add `--ideation` flag to `frw cross-model-review`.
When present, build prompt from definition.yaml + summary.md instead of deliverable
acceptance criteria. Fix codex invocation with `approval_policy="never"`. Fix
FURROW_ROOT usage (covered by deliverable 1).

## Open Questions Resolved

| Question | Answer |
|----------|--------|
| PROJECT_ROOT behavior when no .furrow/ exists? | Default to PWD. Commands that need rows fail naturally with file-not-found. |
| Physical vs logical path resolution? | `readlink -f` for FURROW_ROOT (physical). PWD for PROJECT_ROOT (logical). |
| Backward compatibility for .claude/furrow.yaml? | Candidate loop pattern — check .furrow/ first, fall back to .claude/. |

## Revised Effort Estimates

| Deliverable | Ideation Estimate | Research Estimate | Reason |
|-------------|-------------------|-------------------|--------|
| project-root-resolution | Medium | Small-Medium | Mechanical: 11 line changes + 2 variable additions |
| specialist-template-enforcement | Small | Small | Narrower than expected: skill already has instructions |
| config-move-and-source-todo | Medium | Medium | 9 files + 4 text refs + source_todo wiring |
| cross-model-ideation-review | Small | Small | New function + codex fix + flag handling |

## Dependencies Confirmed

- Deliverable 3 depends on deliverable 1 (config paths use PROJECT_ROOT)
- Deliverable 4 depends on deliverable 1 (cross-model-review.sh uses PROJECT_ROOT)
- Deliverable 2 is independent
