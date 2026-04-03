# Team Plan: specialist-rewrite

## Scope Analysis

13 specialist files + 1 reference doc update + 1 validation pass = 15 work items across 3 waves.
All files are independent markdown authoring — no cross-file dependencies within a wave.
Wave 2 has 10 parallel files across 4 deliverables.

## Team Composition

All work items use the same specialist type (`harness-engineer`) since every task is authoring
a specialist template in a defined format. The differentiation comes from the agent prompt, not
the specialist assignment — each agent receives domain-specific context from the specs.

**Wave 1** (4 agents parallel):
- Agent per file: api-designer, test-engineer, relational-db-architect, document-db-architect
- Each receives: exemplar (harness-engineer.md), existing file content, spec from `specs/existing-rewrites.md`

**Wave 2** (up to 10 agents parallel, batched by deliverable):
- Language batch (4 agents): go, shell, typescript, python
- Architecture batch (2 agents): systems-architect, security-engineer
- Process batch (3 agents): migration-strategist, complexity-skeptic, cli-designer
- Reference doc (1 agent): specialist-template.md update
- Each receives: exemplar, completed Wave 1 files as additional exemplars, spec from relevant spec file

**Wave 3** (1 agent):
- Catalog validation: reads all 13 files, runs conformance checks, documents overlap boundaries

## Task Assignment

| Wave | Deliverable | Files | Agent Count |
|------|------------|-------|-------------|
| 1 | existing-rewrites | api-designer, test-engineer, relational-db-architect, document-db-architect | 4 |
| 2 | language-specialists | go, shell, typescript, python | 4 |
| 2 | architecture-specialists | systems-architect, security-engineer | 2 |
| 2 | process-specialists | migration-strategist, complexity-skeptic, cli-designer | 3 |
| 2 | reference-doc-update | specialist-template.md | 1 |
| 3 | catalog-validation | (read-only) | 1 |

## Coordination

- **No cross-agent coordination needed within waves** — each agent writes one file with no shared state.
- **Wave boundary is the sync point** — all Wave 1 agents must complete before Wave 2 starts.
- **Agent prompt template**: Each agent gets:
  1. The full exemplar (harness-engineer.md)
  2. The spec section for their specific file (pattern names, descriptions, QC, anti-patterns, context requirements)
  3. For rewrites: the existing file content
  4. For Wave 2: completed Wave 1 files as additional format reference
  5. Instruction: "Write the complete specialist file. Follow the exemplar format exactly. Use the spec's reasoning pattern names and descriptions as the starting point — expand each into 2-4 sentences of actionable reasoning."

## Skills

No additional skills needed beyond the default work context. Specialist templates are
in the reference layer (not counted against context budget).

## Deletion

After Wave 1, `specialists/database-architect.md` should be deleted (replaced by relational + document variants).
