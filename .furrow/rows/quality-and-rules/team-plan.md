# Team Plan: quality-and-rules

## Scope Analysis

6 deliverables across 3 waves. All changes are to Furrow's own infrastructure:
shell scripts (hooks, CLI), rules files, templates, skills, and documentation.
No external dependencies. No code generation — all edits to existing patterns.

## Team Composition

**Wave 1: shell-specialist** (1 agent, 2 deliverables)
- stop-hook-exit-codes: 3 hook files — exit code changes + stop-ideation implementation
- cli-post-actions: bin/rws — 2 insertion points

Both deliverables touch shell scripts with established patterns. Same specialist
handles both sequentially (no file overlap, but same domain expertise).

**Wave 2: harness-engineer** (1 agent, 2 deliverables — sequential)
- harness-rules: .claude/rules/, CLAUDE.md, install.sh, references/furrow-commands.md
- rules-strategy-doc: references/rules-strategy.md (depends on harness-rules for examples)

Sequential within wave: strategy doc references the rules created by harness-rules.

**Wave 3: harness-engineer** (1 agent, 2 deliverables)
- spec-test-scenarios: templates/spec.md, skills/spec.md, evals/dimensions/spec.yaml
- row-naming-guidance: skills/ideate.md

Independent deliverables, no file overlap. Can run in parallel or sequentially.

## Task Assignment

| Wave | Deliverable | Specialist | Files | Model |
|------|-------------|------------|-------|-------|
| 1 | stop-hook-exit-codes | shell-specialist | bin/frw.d/hooks/{validate-summary,stop-ideation,work-check}.sh | sonnet |
| 1 | cli-post-actions | shell-specialist | bin/rws | sonnet |
| 2 | harness-rules | harness-engineer | .claude/rules/*, .claude/CLAUDE.md, install.sh, references/furrow-commands.md | sonnet |
| 2 | rules-strategy-doc | harness-engineer | references/rules-strategy.md | sonnet |
| 3 | spec-test-scenarios | harness-engineer | templates/spec.md, skills/spec.md, evals/dimensions/spec.yaml | sonnet |
| 3 | row-naming-guidance | harness-engineer | skills/ideate.md | sonnet |

## Coordination

- Waves execute sequentially (1 → 2 → 3)
- Within Wave 1: sequential (same specialist, different files)
- Within Wave 2: sequential (rules-strategy-doc depends on harness-rules)
- Within Wave 3: parallel possible (independent files)
- No cross-wave file conflicts
- Commit after each deliverable completion

## Skills

No additional skills beyond specialist defaults. All work follows existing
patterns in the codebase (hook structure, CLI subcommand structure, template
structure, rule file structure).
