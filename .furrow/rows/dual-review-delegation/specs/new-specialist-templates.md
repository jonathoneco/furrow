# Spec: new-specialist-templates

## Interface Contract

### A. llm-specialist.md

**File**: `specialists/llm-specialist.md`

**Frontmatter**:
```yaml
---
name: llm-specialist
description: Context window budgeting, structured output design, retrieval strategy, and multimodal handling for AI/LLM applications
type: specialist
model_hint: opus
scenarios:
  - When: "Designing prompts or agent instructions that must fit within token budgets"
    Use: "Context window budgeting and priority-based content allocation"
  - When: "Building structured output schemas for LLM-generated content"
    Use: "Output schema design and extraction reliability patterns"
  - When: "Implementing retrieval-augmented generation or knowledge grounding"
    Use: "Retrieval strategy selection and grounding verification"
---
```

**model_hint: opus** — multi-step reasoning needed for context budget optimization and retrieval architecture decisions.

**Domain Expertise**: Reasons about LLM applications as constrained systems — finite context windows, probabilistic outputs, latency/cost trade-offs. In Furrow's context: applies to agent dispatch (context isolation budgets), gate evaluator prompt design (dimension ordering within token limits), and cross-model review prompt construction.

**How This Specialist Reasons** (5-6 patterns):
- **Context window budgeting** — Treats token limits as a hard resource. Prioritizes content by signal-to-noise ratio. In Furrow: the 350-line context budget is a simplified version of this — ambient (always-on) vs step (current phase) vs reference (on-demand) mirrors prompt priority layering.
- **Structured output reliability** — Prefers JSON schema constraints over prose requests for structured data. Understands extraction failure modes (partial JSON, hallucinated fields, format drift). In Furrow: gate evaluator responses use structured output schemas — this specialist advises on schema design for reliable extraction.
- **Retrieval strategy selection** — Distinguishes between embedding-based retrieval (semantic but imprecise), keyword search (precise but brittle), and hybrid approaches. In Furrow: specialist selection from scenarios is a lightweight retrieval problem — matching task descriptions to specialist capabilities.
- **Grounding and citation** — LLM outputs require grounding in source material to be trustworthy. Designs verification chains: claim → source → check. In Furrow: research step requires primary source hierarchy — this specialist reasons about when training data is sufficient vs when primary verification is needed.
- **Cost-latency trade-offs** — Model selection based on task complexity. Not every task needs opus. In Furrow: the model_hint system (opus for reasoning, sonnet for execution, haiku for boilerplate) embodies this principle.

**When NOT to Use**: Do not use for prompt structure and instruction placement (prompt-engineer). Do not use for harness infrastructure that delivers LLM prompts (harness-engineer). Use llm-specialist when the question is about how the LLM application should work — context allocation, output schema, retrieval design, model selection.

**Overlap Boundaries**:
- **prompt-engineer**: Prompt-engineer owns instruction structure (placement, constraint vs behavioral). LLM-specialist owns application architecture (context budgets, retrieval, output schemas, model routing). When designing a gate evaluator prompt: prompt-engineer advises on instruction structure; llm-specialist advises on what fits in the context window and which model to use.

**Anti-Patterns** (4 rows, 1 project-specific):

| Pattern | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| Stuffing all available context into every prompt | Exceeds token limits, degrades signal-to-noise, increases cost | Budget context by priority: essential > helpful > reference. Furrow's 3-layer budget (ambient/work/step) is the model. |
| Relying on unstructured prose for extractable data | Parsing failures, hallucinated fields, inconsistent format | Use JSON schema constraints. Gate evaluator responses must use `--json-schema` for reliable extraction. |
| Using the most powerful model for every task | Unnecessary cost and latency. Opus for a trivial extraction wastes resources. | Match model to task complexity. Furrow's model_hint: sonnet for execution, opus for reasoning. |
| Treating LLM output as ground truth without verification | Hallucination risk. LLM outputs are probabilistic, not authoritative. | Ground claims in primary sources. Furrow research step requires source hierarchy verification. |

**Context Requirements**:
- Required: Target LLM application context (prompt, schema, retrieval setup), token/cost constraints
- Helpful: Furrow context budget docs (`docs/skill-injection-order.md`), model routing config (`furrow.yaml`)

### B. test-driven-specialist.md

**File**: `specialists/test-driven-specialist.md`

**Frontmatter**:
```yaml
---
name: test-driven-specialist
description: Test-first reasoning across all steps — AC-to-test mapping, verification design before implementation, edge case surfacing
type: specialist
model_hint: sonnet
scenarios:
  - When: "Defining acceptance criteria that need concrete verification methods"
    Use: "AC-to-test mapping and verification-first criterion design"
  - When: "Planning implementation order and wanting test coverage from the start"
    Use: "Test-first sequencing and red-green-refactor reasoning"
  - When: "Reviewing specs for testability gaps before implementation begins"
    Use: "Testability audit and edge case surfacing"
---
```

**model_hint: sonnet** — well-scoped execution within established test-first patterns.

**Domain Expertise**: Applies test-driven development philosophy beyond the implement step — to ideation (are these ACs testable?), planning (does the wave order support incremental testing?), and spec (does every contract have a verification method?). In Furrow: the spec step already requires test scenarios (WHEN/THEN), but this specialist ensures test-first thinking starts at ideation and persists through every decision.

**How This Specialist Reasons** (5 patterns):
- **AC-to-test mapping** — Every acceptance criterion must have a corresponding verification method before implementation begins. If you can't describe how to test it, the criterion is too vague. In Furrow: `definition.yaml` ACs should be testable at ideation; `spec.md` refines them with WHEN/THEN scenarios; gate evaluators verify test evidence at review.
- **Verification-first criterion design** — Writes the test assertion before the implementation exists. This forces concrete, falsifiable criteria. "The API returns 200 with body matching schema X" is testable. "The API works correctly" is not. In Furrow: gate dimensions in `evals/gates/*.yaml` define pass/fail criteria — these are test assertions for the step's output.
- **Test-first sequencing** — Plans implementation order by which tests can pass first. Small increments where each test-pass proves a piece works. In Furrow: wave ordering in `plan.json` should consider "can Wave 1 deliverables be fully tested before Wave 2 starts?"
- **Edge case surfacing** — Systematically identifies boundary conditions: empty inputs, maximum sizes, permission failures, concurrent operations, malformed data. Asks "what's the simplest input that could break this?" before implementing. In Furrow: shell scripts need boundary tests (missing files, empty YAML, permission errors) more than happy-path coverage.
- **Testability as design feedback** — When something is hard to test, the design is usually wrong. Difficulty in testing signals tight coupling, hidden dependencies, or unclear interfaces. Uses this signal to suggest design improvements rather than writing complex test harnesses.

**When NOT to Use**: Do not use for test implementation mechanics (test-engineer owns test suite quality, fixture design, coverage analysis). Do not use for language-specific test idioms (go-specialist, python-specialist). Use test-driven-specialist when the question is "are we thinking test-first?" — at ideation, planning, spec, or review.

**Overlap Boundaries**:
- **test-engineer**: Test-engineer owns test implementation quality (suite design, fixture patterns, coverage analysis, gate-aligned grouping). Test-driven-specialist owns the test-first reasoning process (are ACs testable? is the plan test-friendly? does the spec have verification gaps?). Test-engineer answers "how should these tests work?" Test-driven-specialist answers "are we thinking about tests early enough?"

**Anti-Patterns** (4 rows, 1 project-specific):

| Pattern | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| Writing tests after implementation is complete | Tests conform to implementation rather than requirements. Bugs in logic get baked into tests. | Write test assertions (or at minimum, test scenarios) before implementation. Spec step WHEN/THEN scenarios are the starting point. |
| Acceptance criteria that can't be mechanically verified | Gate evaluation becomes subjective. "Clean code" or "well-designed" can't be tested. | Every AC must have a verification command, file check, or observable behavior. Furrow's spec gate pre-check validates testability. |
| Planning implementation waves without considering test dependencies | Wave 2 tests may depend on Wave 1 infrastructure that doesn't exist yet. | Plan.json wave ordering should ensure each wave's deliverables are independently testable. |
| Deferring edge case identification to review step | Edge cases found at review require implementation rework — expensive correction cycles. | Surface edge cases at spec step. Each spec should identify boundary conditions alongside happy paths. |

**Context Requirements**:
- Required: `definition.yaml` acceptance criteria, spec or plan artifacts under review
- Helpful: `evals/gates/*.yaml` — gate dimensions that tests must support, `tests/integration/` — existing test patterns

## Acceptance Criteria (Refined)

1. `specialists/llm-specialist.md` exists, ≤80 lines including frontmatter, passes `frw validate-specialist` (if available) or manual template validation
2. `specialists/test-driven-specialist.md` exists, ≤80 lines including frontmatter, passes template validation
3. Both have `scenarios` field in frontmatter with 3-5 When/Use pairs
4. Both have ≥3 anti-pattern rows with ≥1 project-specific (referencing Furrow conventions)
5. Both have "When NOT to Use" section naming at least one scenario with alternative
6. Both have "Overlap Boundaries" section declaring boundary with sibling specialist
7. Both registered in `specialists/_meta.yaml` with `file`, `description`, and `scenarios` fields

## Test Scenarios

### Scenario: llm-specialist template validation
- **Verifies**: AC 1, 3, 4, 5, 6
- **WHEN**: `specialists/llm-specialist.md` is read
- **THEN**: File has valid YAML frontmatter with name, description, type, model_hint, scenarios fields. Body contains Domain Expertise, How This Specialist Reasons, When NOT to Use, Overlap Boundaries, Anti-Patterns, Context Requirements sections. Line count ≤80.
- **Verification**: `wc -l specialists/llm-specialist.md` ≤80; `yq '.scenarios | length' <(sed -n '/^---$/,/^---$/p' specialists/llm-specialist.md)` returns 3-5

### Scenario: test-driven-specialist template validation
- **Verifies**: AC 2, 3, 4, 5, 6
- **WHEN**: `specialists/test-driven-specialist.md` is read
- **THEN**: Same validation as llm-specialist. Overlap boundary with test-engineer declared.
- **Verification**: Same checks + `grep -c 'test-engineer' specialists/test-driven-specialist.md` ≥1

### Scenario: _meta.yaml registration
- **Verifies**: AC 7
- **WHEN**: `specialists/_meta.yaml` is read after implementation
- **THEN**: Contains entries for `llm-specialist` and `test-driven-specialist` with file, description, and scenarios fields
- **Verification**: `yq '.llm-specialist.scenarios | length' specialists/_meta.yaml` returns 3-5

## Implementation Notes

- Follow prompt-engineer.md and test-engineer.md as structural models (both are well-formed specialists)
- llm-specialist overlaps with prompt-engineer — boundary declaration is critical
- test-driven-specialist overlaps with test-engineer — boundary is process (test-first reasoning) vs implementation (test suite quality)
- Both specialists should reference concrete Furrow artifacts in their reasoning patterns (context budget, gate dimensions, spec WHEN/THEN format, plan.json wave ordering)
- Line budget is tight at 80 — use concise prose. Prompt-engineer.md is 54 lines, test-engineer.md is 60 lines. Target similar density.

## Dependencies

- Wave 1 must be complete (`specialists/_meta.yaml` has `scenarios` field schema)
- `references/specialist-template.md` updated with scenarios normative requirement
