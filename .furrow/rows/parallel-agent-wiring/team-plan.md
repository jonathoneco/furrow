# Team Plan: parallel-agent-wiring

## Execution Strategy

3 sequential waves (file_ownership on bin/rws prevents wave 2+3 parallelism).

## Wave 1: orchestration-instructions

**Specialist**: prompt-engineer
**Files**: skills/implement.md, skills/shared/context-isolation.md
**Task**: Rewrite implement.md orchestration section with:
- Decision tree: >1 wave OR >1 deliverable with different specialists → dispatch
- Dispatch checklist (read plan.json → for each wave → for each deliverable → spawn agent)
- Concrete Agent() tool call example with specialist template injection (inline, not reference file)
- Wave inspection protocol (verify files, run tests, check conflicts)
- Update context-isolation.md with explicit curation protocol between waves

**Context to provide agent**:
- definition.yaml (deliverable: orchestration-instructions)
- research/orchestration-instructions.md (gaps and current state)
- Current skills/implement.md (what to rewrite)
- specialists/prompt-engineer.md (specialist template for self-reference)
- templates/plan.json (schema agent should reference in examples)

## Wave 2: worktree-summary

**Specialist**: cli-designer
**Files**: bin/rws, bin/frw.d/lib/common.sh
**Task**: Add worktree summary CLI commands:
- Extract shared awk section-replacement to `replace_md_section` in common.sh
- Refactor existing update-summary to use the shared function
- `rws update-worktree-summary [name] <section>` — stdin, shared awk function, atomic write
- `rws regenerate-worktree-summary [name]` — generates skeleton
- `rws validate-worktree-summary [name]` — checks sections non-empty
- Sections: files-changed, decisions, open-items, test-results

**Context to provide agent**:
- definition.yaml (deliverable: worktree-summary)
- research/worktree-summary.md (update-summary pattern details)
- bin/rws current update-summary implementation (pattern to replicate)
- bin/frw.d/lib/common.sh (for shared function extraction)

## Wave 3: user-action-lifecycle

**Specialist**: cli-designer
**Files**: bin/rws, schemas/state.schema.json, skills/shared/, .claude/rules/step-sequence.md, .claude/settings.json
**Task**: Add user action lifecycle and clean up vestigial hook:
- Schema: add pending_user_actions array to state.schema.json
- `rws add-user-action [name] <id> <instructions>` — appends to state
- `rws complete-user-action [name] <id>` — sets completed_at
- `rws list-user-actions [name]` — shows pending/completed
- Extend rws_transition() to block if pending actions lack completed_at
- Add gate evidence for action completion
- Remove vestigial bin/frw.d/hooks/gate-check.sh (no-op)
- Update .claude/rules/step-sequence.md to remove gate-check hook references
- Update .claude/settings.json to remove gate-check hook registration
- Add agent instructions in skills/shared/ for when/how to use add-user-action

**Context to provide agent**:
- definition.yaml (deliverable: user-action-lifecycle)
- research/user-action-lifecycle.md (state mutation patterns, gate enforcement)
- schemas/state.schema.json (current schema to extend)
- bin/rws current transition implementation (where to add enforcement)
- bin/frw.d/hooks/gate-check.sh (to remove)
- .claude/rules/step-sequence.md (to update)
