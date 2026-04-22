# Spec: orchestration-instructions

## Interface Contract

**Files modified**: skills/implement.md, skills/shared/context-isolation.md
**Consumers**: The agent executing the implement step
**Contract**: After reading implement.md, the agent has an unambiguous decision
tree for solo vs multi-agent dispatch, a copy-pasteable Agent() call template,
a pre-wave dispatch checklist, and a wave inspection protocol.

## Acceptance Criteria (Refined)

1. implement.md contains a decision tree with explicit thresholds:
   - 1 deliverable in plan.json → solo execution
   - >1 deliverable with same specialist, same wave → solo with specialist skill loaded
   - >1 deliverable with different specialists OR >1 wave → dispatch sub-agents
2. implement.md contains a complete Agent() tool call example showing:
   specialist template content injected in prompt, file_ownership scope,
   definition.yaml deliverable reference, and model selection from specialist model_hint
3. implement.md contains a dispatch checklist: read plan.json → validate wave
   ordering → for each wave → for each deliverable in wave → spawn agent with
   specialist + curated context → wait for completion → inspect outputs
4. implement.md contains a wave inspection protocol: verify deliverable files
   exist in expected paths, check for file_ownership violations, summarize
   changes for next wave's context curation
5. context-isolation.md updated with explicit between-wave curation protocol:
   what outputs to include, what to summarize vs pass verbatim, size guidance

## Test Scenarios

### Scenario: Decision tree leads to dispatch
- **Verifies**: AC 1
- **WHEN**: plan.json has 2 waves with different specialists assigned
- **THEN**: Agent reading implement.md can determine dispatch is required without ambiguity
- **Verification**: Manual review — read the decision tree and confirm the 2-wave case maps unambiguously to "dispatch sub-agents"

### Scenario: Agent tool call is copy-pasteable
- **Verifies**: AC 2
- **WHEN**: Agent needs to dispatch a cli-designer specialist for a deliverable
- **THEN**: The example in implement.md can be adapted by substituting deliverable name, specialist template path, and file_ownership globs
- **Verification**: Manual review — confirm the example includes all required fields (prompt with specialist content, description, file_ownership scope)

## Implementation Notes

- Decision tree replaces the current vague "two-path loading" description
- The Agent() example must use real specialist template format (YAML frontmatter + markdown body)
- Context budget: implement.md may exceed 50 lines after rewrite; this is acceptable per plan decision
- Pattern reference: current implement.md lines 32-39 describe the two paths abstractly

## Dependencies

- specialists/*.md (template format to reference in example)
- templates/plan.json (schema to reference in dispatch checklist)
- No deliverable dependencies (wave 1)
