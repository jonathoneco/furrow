# Research: specialist-template-enforcement

## Key Finding: The Gap Is Narrower Than Expected

`skills/implement.md` (lines 25-33) already has **blocking** specialist loading instructions:

> Before starting implementation, validate that every deliverable's `specialist`
> field in `plan.json` references an existing file in `specialists/`. Surface
> any missing specialists as errors and STOP — do not proceed with unresolved
> specialist assignments.
>
> Before dispatching any agent for a deliverable, you MUST read and load the
> specialist template from `specialists/{specialist}.md` as assigned in plan.json.

The TODO ("specialist templates from team-plan not enforced during implementation") was likely
written before implement.md was updated with this language. The current instructions are clear
and use blocking terminology ("MUST", "STOP", "blocking requirement").

## Actual Gaps

### Gap 1: No shell-level specialist file validation
`generate-plan.sh` validates that every deliverable HAS a specialist field (not null/empty),
but does NOT validate that `specialists/{specialist}.md` exists. This means invalid assignments
pass plan generation silently and only surface when an agent tries to load the file.

**Fix**: Add file existence check in generate-plan.sh after plan generation:
```sh
for specialist in $(jq -r '.waves[].assignments[].specialist' "$plan_file" | sort -u); do
  if [ ! -f "$FURROW_ROOT/specialists/${specialist}.md" ]; then
    echo "Warning: specialist not found: specialists/${specialist}.md" >&2
  fi
done
```

### Gap 2: Agent compliance is unverifiable
The instructions tell agents to load specialists, but there's no mechanism to verify they
actually did. An agent CAN dispatch a sub-agent without including the specialist template.

**Fix**: This is an observability problem, not an enforcement problem. Per the ideation
decision (warn + proceed), the right approach is:
- Keep implement.md instructions as-is (they're already strong)
- Add a pre-implement check (shell or hook) that validates specialist files exist
- Log warnings for missing specialists rather than hard blocking
- Defer structured observability to the specialist-template-warning-escalation TODO

### Gap 3: implement.md says STOP but user wants warn+proceed
The current implement.md uses "STOP" and "blocking requirement" language. The ideation
decision was warn + proceed for missing templates. These need to be reconciled.

**Fix**: Change implement.md from "STOP" to "warn and proceed":
```
If the file does not exist, warn on stderr and proceed without the specialist
template. This is a degraded mode — the agent should note the missing specialist
in the deliverable's review evidence.
```

## Specialist Templates Available (21 files)

1. accessibility-auditor
2. api-designer
3. cli-designer
4. complexity-skeptic
5. css-specialist
6. document-db-architect
7. frontend-designer
8. go-specialist
9. harness-engineer
10. merge-specialist
11. migration-strategist
12. prompt-engineer
13. python-specialist
14. relational-db-architect
15. security-engineer
16. shell-specialist
17. systems-architect
18. technical-writer
19. test-engineer
20. typescript-specialist

Registry: `specialists/_meta.yaml`

## Template Structure
YAML frontmatter (`model_hint`, `name`, `description`, `type`) followed by:
- Domain Expertise
- How This Specialist Reasons (5-8 patterns)
- When NOT to Use
- Overlap Boundaries
- Quality Criteria
- Anti-Patterns (table)
- Context Requirements (Required + Helpful lists)

## Agent Dispatch Flow

1. Lead agent reads `plan.json` → gets wave/deliverable/specialist assignments
2. Lead reads `skills/implement.md` → told to load specialist before dispatch
3. Lead reads `specialists/{name}.md` → gets domain framing + model hint
4. Lead dispatches sub-agent via Agent tool with:
   - Specialist template content in prompt
   - Model hint as model parameter
   - Curated context per `skills/shared/context-isolation.md`

Skill injection order: code-quality → specialist skills → implement → task.

## Sources Consulted

- skills/implement.md (primary — specialist loading instructions)
- skills/shared/context-isolation.md (primary — sub-agent dispatch rules)
- references/specialist-template.md (primary — template format spec)
- specialists/_meta.yaml (primary — registry)
- specialists/harness-engineer.md (primary — example template)
- bin/frw.d/scripts/generate-plan.sh (primary — plan generation + validation)
- bin/frw.d/lib/validate.sh (primary — validation functions)
- docs/skill-injection-order.md (primary — injection sequence)
- .furrow/rows/quick-harness-fixes/plan.json (primary — example plan)
