# Spec: specialist-reasoning-upgrade

## Interface Contract

Files owned:
- `references/specialist-template.md` — template standard (update first)
- `specialists/*.md` — all 15 specialist definitions (upgrade per triage tier)
- `specialists/_meta.yaml` — registry (update if specialists are merged/removed)

Consumers: agents loading specialists during implement/spec/review steps via
`plan.json` assignments. The template standard is also consumed by anyone
creating new specialists.

Exemplars (do not degrade): `specialists/harness-engineer.md`,
`specialists/merge-specialist.md` — these define the target quality bar.

## Acceptance Criteria (Refined)

### Phase 1: Template Standard Update

1. `references/specialist-template.md` adds a "Project Grounding" requirement:
   every specialist MUST contain at least one reasoning pattern or anti-pattern
   that references a concrete project convention, file path, tool, or workflow.
   Generic domain knowledge alone is insufficient.

2. Template adds an "Encoded Reasoning vs. Restated Best Practice" section with
   the distinction defined in Implementation Notes below. This is a normative
   test — any reasoning bullet that fails the test must be rewritten or removed.

3. Template adds a "When NOT to Use" section requirement: each specialist must
   declare at least one scenario where the specialist is the wrong choice, naming
   the better alternative (another specialist or no specialist).

4. Template adds overlap guidance: when two specialists share domain surface,
   each must declare its boundary. The overlap section names the sibling and
   states what belongs where.

5. Template adds anti-pattern minimum: at least 3 rows in the anti-pattern table,
   at least 1 must be project-specific (referencing a Furrow convention, tool, or
   file path).

6. Template adds `model_hint` rationale guidance: `opus` for work requiring
   multi-step reasoning across large contexts or novel problem-solving; `sonnet`
   for well-scoped execution within established patterns; `haiku` reserved for
   trivial boilerplate tasks (currently no specialists qualify).

### Phase 2: WEAK Specialist Rework (4 specialists)

7. `security-engineer.md` rewritten with project-specific content: Furrow's trust
   boundaries (CLI mediation, state.json write ownership, hook enforcement),
   secrets lifecycle in `.furrow/` context, and the specific threat model for a
   workflow harness (state corruption, unauthorized step transitions, hook bypass).
   Generic OWASP content removed; reasoning patterns must reference Furrow
   components.

8. `shell-specialist.md` scoped to non-harness shell work. Boundary declared:
   harness-engineer owns `bin/frw.d/`, hook scripts, and validation pipelines;
   shell-specialist owns general-purpose POSIX scripts outside the harness
   (install scripts, user-facing utilities, CI glue). Both specialists reference
   this boundary. If the remaining non-harness scope is too thin to justify a
   standalone specialist, merge into harness-engineer and remove shell-specialist
   (updating `_meta.yaml` and all plan.json references).

9. `python-specialist.md` evaluated for project relevance. If the project has no
   Python code paths, remove the specialist and document the removal rationale in
   `_meta.yaml`. If Python is used (e.g., tooling, scripts), rewrite with
   project-specific conventions replacing language-reference content.

10. `typescript-specialist.md` evaluated for project relevance using the same
    criteria as python-specialist. Remove or rewrite accordingly.

### Phase 3: ADEQUATE Specialist Grounding (7 specialists)

11. Each ADEQUATE specialist (`api-designer`, `document-db-architect`,
    `go-specialist`, `migration-strategist`, `relational-db-architect`,
    `systems-architect`, `test-engineer`) receives a project-grounding pass:
    - At least 1 reasoning pattern rewritten to reference a specific Furrow
      convention, file path, or design decision
    - At least 1 anti-pattern row made project-specific
    - "When NOT to Use" section added
    - Overlap boundaries declared where applicable

12. `test-engineer.md` specifically grounds its "gate-aligned testing" concept
    with references to `evals/gates/*.yaml` dimension files and the review
    step's evaluation protocol.

### Phase 4: STRONG Specialist Polish (4 specialists)

13. `harness-engineer.md`, `merge-specialist.md`, `cli-designer.md`, and
    `complexity-skeptic.md` receive template compliance pass only: add "When NOT
    to Use" section if missing, verify anti-pattern minimum met, declare overlap
    boundaries if applicable. No reasoning pattern changes unless template
    compliance requires it.

### Cross-Cutting

14. No specialist exceeds 80 lines (including frontmatter).

15. Every specialist passes the "encoded reasoning" test: for each reasoning
    bullet, removing it must change how the agent behaves on a Furrow task. If
    the agent would behave identically without the bullet, the bullet is restated
    best practice and must be rewritten or removed.

16. `specialists/_meta.yaml` updated to reflect any additions, removals, or
    merges performed during the upgrade.

## Implementation Notes

### Encoded Reasoning vs. Restated Best Practice

A reasoning pattern is **encoded reasoning** if it meets ALL of:
- It encodes a decision the model would not make by default (the model's naive
  approach would differ)
- It references a specific tradeoff, threshold, or heuristic ("prefer X over Y
  when Z", not "consider X")
- Removing it from the specialist would change the agent's output on a realistic
  Furrow task

A reasoning pattern is **restated best practice** if ANY of:
- It restates general domain knowledge the model already has (e.g., "quote shell
  variables", "use parameterized queries", "prefer composition over inheritance")
- It uses vague language without actionable specifics ("consider security",
  "think about performance")
- The model would follow the same advice without the specialist loaded

**Litmus test**: Read the bullet, then ask "would Claude follow this advice
anyway if I just said 'write a shell script' / 'design an API' / 'review
security'?" If yes, it is restated best practice.

### Shell-Specialist / Harness-Engineer Overlap Resolution

The decision tree:
1. List all shell scripts in the project outside `bin/frw.d/` and `bin/rws.d/`
   and `bin/alm.d/` and `bin/sds.d/`
2. If the remaining corpus is >= 5 scripts with meaningful conventions beyond
   what harness-engineer covers: keep shell-specialist, scoped to that corpus
3. If < 5 scripts or conventions fully subsumed by harness-engineer: merge
   shell-specialist content into harness-engineer's context requirements and
   remove shell-specialist
4. Document the decision in `_meta.yaml` either way

### Upgrade Process Per Specialist

For each specialist file:
1. Read the current file and the two exemplars side-by-side
2. Apply the encoded reasoning litmus test to each bullet
3. Check anti-pattern table against the minimum and project-specificity requirement
4. Add "When NOT to Use" section
5. Add overlap boundary declarations if applicable
6. Verify line count <= 80
7. Run a "removal test" thought experiment: if this specialist were deleted, would
   agents behave worse on Furrow tasks? If the answer is unclear, the specialist
   needs more project grounding or should be removed.

### Relevance Evaluation for Python/TypeScript

To determine project relevance:
1. Search codebase for `.py` / `.ts` / `.tsx` / `.js` files
2. Check `mise` config for Python/Node tool versions
3. If no code and no tooling: remove specialist, add removal note to `_meta.yaml`
4. If tooling-only (e.g., Python used for a build script): evaluate whether a
   specialist is justified or if go-specialist/harness-engineer covers the need

## Dependencies

- No blocking dependencies (wave 1 deliverable)
- Template standard update (Phase 1) must complete before specialist upgrades
  (Phases 2-4) begin, enforced by sequencing within this deliverable
- Produces: updated specialist files consumed by enforcement-wiring (wave 3)
  and specialist-expansion (wave 2 — new specialists reference the updated
  template standard)
