# Team Plan — model-routing-and-specialists

## Wave Structure

### Wave 1: orchestrator-architecture
- **Specialist**: systems-architect (model_hint: opus)
- **Deliverable**: orchestrator-architecture
- **File ownership**: skills/orchestrator.md, skills/shared/context-isolation.md, references/model-routing.md, skills/*.md (all 7 step skills)

### Wave 2: specialist-step-modes
- **Specialist**: harness-engineer (model_hint: sonnet)
- **Deliverable**: specialist-step-modes
- **File ownership**: specialists/harness-engineer.md, references/specialist-template.md, specialists/_meta.yaml, skills/plan.md, skills/decompose.md, skills/research.md (mode overlay additions)
- **Depends on**: Wave 1 (mode overlays reference dispatch metadata structure from orchestrator-architecture)

## Architecture Decisions

### Why 2 sequential waves (not parallel)
Deliverable 2 (specialist-step-modes) adds mode overlays to step skills. These overlays reference the Agent Dispatch Metadata sections added by deliverable 1 (orchestrator-architecture). Wave 2 must read wave 1 outputs to ensure consistency.

### Why systems-architect for wave 1
The orchestrator skill is cross-cutting infrastructure — it defines component boundaries (orchestrator vs agent), dependency direction (what flows where), and architectural decisions (dispatch tables, curation rules). This is systems-architect's core domain.

### Why harness-engineer for wave 2
Specialist templates, mode overlays, and rationale grounding are harness infrastructure — they define how the workflow harness primes agents. harness-engineer owns this domain.

### Model routing for wave agents
- Wave 1 agent: **opus** (systems-architect model_hint is opus; this is cross-component architectural work requiring novel design)
- Wave 2 agent: **sonnet** (harness-engineer model_hint is sonnet; this is well-scoped execution within established patterns — adding sections to existing files)

## Coordination Strategy

### Wave 1 → Wave 2 handoff
Wave 1 produces:
- skills/orchestrator.md (new file)
- skills/shared/context-isolation.md (updated)
- references/model-routing.md (new file)
- skills/*.md (7 files refactored — dispatch metadata added, collaboration extracted)

Wave 2 reads wave 1 outputs to:
- Verify mode overlay sections align with dispatch metadata structure
- Ensure specialist-template.md documents the overlay convention consistently
- Audit _meta.yaml model_hint values against the model routing documented in references/model-routing.md

### Inspection gate between waves
After wave 1 completes:
1. Verify orchestrator.md exists and is ≤100 lines
2. Verify all 7 step skills have Agent Dispatch Metadata sections
3. Verify context-isolation.md has orchestrator/agent boundary rules
4. Verify references/model-routing.md has per-step model rationale
5. Spot-check: step skills still read as standalone agent instructions
