# Specialist Delegation Protocol

When a step involves domain-specific reasoning, select and delegate to specialists:

1. **Scan** — read `specialists/_meta.yaml` scenarios index. Match `When` descriptions
   against the current task context (definition.yaml objective, deliverable names, file patterns).
2. **Select** — choose specialists whose scenarios are relevant. Prefer fewer specialists
   (1-2) over broad coverage. When no scenario matches, proceed without specialist delegation.
3. **Delegate** — dispatch selected specialists as **sub-agents** (never load into the
   orchestration session). Include the specialist template (`specialists/{name}.md`) in
   the sub-agent's context alongside the task-specific artifacts.
4. **Record** — note specialist selections in `summary.md` key-findings with rationale
   (e.g., "Selected go-specialist — scenario: error chain design for new CLI commands").

The Step-Level Specialist Modifier in each step skill defines the emphasis shift
when working with a specialist at that step. Delegation is advisory at early steps
(ideate, research) and authoritative at later steps (decompose, implement).
