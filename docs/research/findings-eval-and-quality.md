# Eval Architecture & Quality Gates

> How do you define "correct behavior" for an agentic workflow? What does a
> practical, bootstrappable eval pipeline look like? How should review and
> verification be structured? This document addresses research questions 3
> (eval architecture) and 4 (quality gates).

---

## Part 1: What Needs to Be Evaluated

Agentic work produces outcomes at multiple levels. Each needs different
evaluation approaches:

### Level 1: Output Correctness

**Question**: Does the produced artifact work?

- Code compiles and passes tests
- Generated files are syntactically valid
- APIs respond correctly
- UI renders as expected

**Approach**: Deterministic, automated. Existing tools (pytest, shell scripts,
linters, type checkers). Cheapest and most reliable. Should always run.

### Level 2: Specification Compliance

**Question**: Does the output satisfy the work definition's requirements?

- All deliverables are present
- Each deliverable meets its stated evaluation criteria
- Constraints in the work definition are respected
- No scope creep (features added that weren't requested)

**Approach**: Partially automated. Deliverable presence is checkable. Criteria
compliance may need LLM-as-judge for subjective requirements. Scope creep
detection is a diff analysis problem.

### Level 3: Process Quality

**Question**: Did the agent follow the expected process?

- Was work done one deliverable at a time?
- Was evaluation triggered at each boundary?
- Were correction limits respected?
- Was context loaded appropriately (not everything, not nothing)?

**Approach**: Trace analysis. Examine the sequence of actions, file mutations,
and tool calls. Mostly automatable via pattern matching on structured logs.

### Level 4: Outcome Quality

**Question**: Is the output *good*, beyond mere correctness?

- Code quality (maintainability, security, performance)
- Design quality (for UI/UX work)
- Architecture quality (for structural decisions)
- Documentation quality

**Approach**: LLM-as-judge with calibrated criteria, or human review. Most
expensive. Reserve for high-stakes work or periodic calibration checks.

### Mapping Levels to Cost and Reliability

| Level | Reliability | Automation | Default usage |
|---|---|---|---|
| Output correctness | High (deterministic) | Full | Always — all work |
| Spec compliance | Medium (partial LLM) | Mostly | Always for multi-deliverable work |
| Process quality | Medium (pattern matching) | Mostly | Always for 2+ deliverable work; harness development |
| Outcome quality | Variable (LLM/human) | Partial | Default for non-trivial work; cross-model |

---

## Part 2: Eval Approaches

### Deterministic Evals (Level 1)

Standard testing tools. Furrow doesn't need to build anything here — it
needs to *require* that evals exist and *run* them at the right time.

**Convention**: Evals for a work unit live in `evals/` relative to the work
definition. They can be:

- pytest files (`test_*.py`)
- Shell scripts (`check_*.sh`)
- Any executable that returns 0 for pass, non-zero for fail

**Furrow's job**: Discover and run these at evaluation boundaries. Not
build a test framework.

### LLM-as-Judge Evals (Levels 2, 4)

For criteria that can't be expressed as deterministic checks. The seed research
provides strong guidance here:

**Key findings from the Anthropic blog:**
- "Out of the box, Claude is a poor QA agent" — raw LLM judgment is uncalibrated
- Calibration requires iterative work: read logs, find divergences from human judgment, update prompt
- Criteria wording directly shapes output: "museum quality" pushed designs toward visual convergence
- Grade outcomes, not paths: checking step sequences is "too rigid"
- The "early victory problem": evaluators declare success after minimal testing

**Proposed LLM-as-judge convention:**

An LLM-judge eval spec is a file containing:

```yaml
name: "feature-review"
type: "llm-judge"
model: "cross-model"  # default: different model than generator
criteria:
  - name: "correctness"
    weight: 3
    prompt: |
      Does the implementation correctly handle all specified requirements?
      Look specifically for: [requirement list from work definition]
      Grade: PASS / FAIL with specific evidence.
  - name: "code-quality"
    weight: 2
    prompt: |
      Is the code maintainable, well-structured, and following project conventions?
      Grade: PASS / NEEDS_WORK / FAIL with specific examples.
calibration:
  examples:
    - input: "path/to/known-good-output"
      expected: "PASS"
    - input: "path/to/known-bad-output"
      expected: "FAIL"
```

Key design choices:
- **Weighted criteria** — not all criteria are equal; weights influence the aggregate judgment
- **Specific evidence required** — prevents the "early victory" problem by forcing the evaluator to cite specifics
- **Calibration examples** — known-good and known-bad examples anchor the evaluator's judgment
- **Cross-model default** — the evaluator uses a different model than the generator, eliminating correlated blind spots

### Behavioral Trace Evals (Level 3)

For evaluating whether the agent followed expected process patterns. These
operate on structured traces of agent behavior (tool calls, file mutations,
completion claims).

**Trace infrastructure is a Phase 0 requirement.** Behavioral evals are blocked
until traces exist in a normalized format. This is a fixed cost that enables all
downstream behavioral evaluation — build it first.

**Proposed approach**: Assertion-based, inspired by the Fireworks Eval Protocol.

```python
# evals/test_process.py
def test_one_at_a_time(trace):
    """Verify deliverables were worked on sequentially, not in parallel."""
    active = set()
    for event in trace.events:
        if event.type == "deliverable_started":
            assert len(active) == 0, f"Started {event.deliverable} while {active} in progress"
            active.add(event.deliverable)
        elif event.type == "deliverable_completed":
            active.discard(event.deliverable)

def test_evaluation_at_boundaries(trace):
    """Verify evaluation ran after each deliverable completion."""
    for i, event in enumerate(trace.events):
        if event.type == "deliverable_completed":
            next_events = trace.events[i+1:i+5]
            assert any(e.type == "evaluation_ran" for e in next_events), \
                f"No evaluation after completing {event.deliverable}"
```

**The trace normalization layer is essential infrastructure.** Claude Code and
Agent SDK produce different event formats. Furrow needs a common normalized
event format across both runtimes. This is not optional — without it, behavioral
evals are either runtime-specific (doubling maintenance) or impossible.

---

## Part 3: The Eval Pipeline

### Bootstrap Sequence

The eval pipeline deploys all eval levels early, with calibration tracking from
the start:

**Phase 0: Foundation (day 1)**
- Existence checks (work def has criteria, eval files exist, eval files executable)
- Trace infrastructure — normalized event format across both runtimes
- Schema validation for work definitions and progress files
- This is a shell script + a small trace normalization module

**Phase 1: Deterministic + behavioral evals (week 1)**
- Run pytest/shell evals at deliverable boundaries — gating
- Run behavioral trace evals (one-at-a-time discipline, eval-at-boundaries, completion claims) — gating
- Both eval types gate: work doesn't proceed until they pass

**Phase 2: LLM-judge gating + cross-model eval (week 1-2)**
- Deploy LLM-judge as GATING, not advisory, from first use
- Cross-model evaluation as default configuration
- Calibration tracking from day 1 — store all judge outputs with inputs and grades
- If judge is too unreliable to gate, fix calibration — don't downgrade to advisory
- Initial calibration corpus: human review of harness's own development artifacts

**Phase 3: Calibration refinement + self-evolving eval proposals (week 2-3)**
- Systematic comparison of LLM-judge output to human judgment
- Update judge prompts to close gaps
- System proposes new evals based on observed failure patterns (human-in-loop approval)
- Track calibration metrics over time

**Phase 4: Deletion testing (ongoing)**
- Periodically remove harness components and run full eval suite
- If evals still pass — component is no longer needed, delete permanently
- Remove process evals that models now handle natively
- Test whether cross-model adds value over single-model for each work type

### The Eval Runner

Furrow needs an eval runner that:

1. Discovers eval files for a work unit (by convention: `evals/` directory)
2. Executes them (shell out to pytest, bash, or a custom runner for LLM-judge specs)
3. Reports results in a structured format (JSON)
4. Stores results alongside the work unit (for history/calibration)

The eval runner handles discovery, execution, result storage, and calibration
tracking across two runtimes and multiple eval types (deterministic, behavioral
trace, LLM-judge). Its scope is determined by what's needed to make evals work
reliably, not by a line-count target.

### Dual-Runtime Eval Execution

| Eval type | Claude Code | Agent SDK |
|---|---|---|
| Deterministic | Hook triggers eval runner at deliverable boundary | Callback triggers eval runner after completion |
| LLM-as-judge | Hook triggers judge; human can review/override | Callback triggers judge; result is authoritative |
| Behavioral trace | Trace extracted from conversation/tool history | Trace extracted from agent loop events |
| Calibration | Human reviews sample of judge outputs | Deferred to human review queue |

The eval *specifications* are identical across runtimes. The eval *execution*
mechanism differs. The eval *results format* is identical.

---

## Part 4: Quality Gates

### The Generator-Evaluator Separation

The seed research is unambiguous: self-review fails. Furrow must
structurally separate generation from evaluation.

**Structural separation means:**
- The evaluator runs in a fresh context (not the generator's context)
- The evaluator has its own prompt (calibrated independently)
- The evaluator sees the output, not the reasoning process
- The evaluator's judgment is recorded and actionable

**Structural separation is the default for ALL non-trivial work**, not just
complex work. The depth scales — deterministic-only for simple work, full
cross-model for complex work — but the separation itself is always present.

**In Claude Code**: The evaluator is a subagent (fresh context) or a hook-
triggered separate evaluation step.

**In Agent SDK**: The evaluator is a separate agent invocation or a callback
that spawns a fresh evaluation agent.

### Quality Gate Depth

Not all work needs the same evaluation depth. Furrow should support
configurable gate depth:

| Gate | What it catches | Default usage |
|---|---|---|
| **Automated tests** | Functional regressions, syntax errors | Always — all work |
| **LLM-as-judge (cross-model)** | Spec violations, quality issues, correlated blind spots | Default for non-trivial work |
| **LLM-as-judge (single-model)** | Same, with correlated blind spots risk | Only for trivial work or when cross-model is verified unnecessary for work type |
| **Human review** | Subtle quality issues, preference alignment | Architectural decisions, trust level transitions, calibration |

The work definition specifies which gates apply:

```yaml
quality_gates:
  - type: automated_tests      # always
  - type: llm_judge            # for each deliverable
    model: cross-model
  - type: human_review         # for final deliverable only
    trigger: final_deliverable
```

### Evaluator Calibration

The Anthropic blog describes calibration as iterative work that takes "several
rounds." Calibration is ongoing work that improves over time. Deploy LLM-judge
as gating from the start, track calibration metrics, and improve continuously.

The calibration loop:

1. **Collect judge outputs**: Every LLM-judge evaluation is stored (input,
   criteria, output, grade).
2. **Sample for human review**: Periodically, present a sample of judge outputs
   to the human for agreement/disagreement.
3. **Identify divergences**: Where the judge and human disagree, understand why.
4. **Update judge prompts**: Refine criteria wording, add calibration examples,
   adjust weights.
5. **Re-evaluate**: Run the updated judge on the same inputs to verify improvement.

**Storage convention**: Judge outputs and calibration data live alongside the
work unit:

```
work/
  current-feature/
    evals/
      results/
        2024-03-27T14:30:00-test_output.json    # deterministic results
        2024-03-27T14:30:00-judge_review.json    # LLM-judge results
      calibration/
        human_overrides.json                      # where human disagreed with judge
```

### Cross-Model Review

Cross-model review is the **default evaluator configuration** for non-trivial
work. The evidence: Claude+Gemini pair reaches 91% of a five-model ceiling,
cross-model finds 3-5x more bugs. On a flat-rate plan, cost is not a constraint.

Single-model evaluation is used only when:
- The work is trivial and fully covered by deterministic tests
- Measurement shows cross-model adds no value for this specific work type (the eval framework tracks this)

The eval framework measures: what does cross-model catch that single-model
misses? If the answer is "nothing, on this work type," downgrade to single-model
for that type. Data-driven downgrade, not conservative default.

---

## Part 5: The Relationship Between Evals and Harness Evolution

Evals serve double duty:

1. **Validating work output** — the primary purpose
2. **Validating harness components** — the meta-purpose

Every harness component (a prompt, a convention, a structural guardrail) exists
because of an assumption about model limitations. Evals test whether that
assumption still holds.

**The deletion test** (from the platform boundary document) depends on evals:
- Remove a component → run evals → if evals still pass, the component was
  scaffolding a capability the model now has natively → delete permanently.

**The calibration loop** tests evaluator quality:
- If human agreement with the judge is consistently >95% → the judge is
  well-calibrated, consider reducing human review sampling rate.
- If human agreement drops → the judge needs recalibration (or the quality
  standards have shifted).

**Eval coverage as health metric**: Furrow is healthy when its evals cover
all behavioral expectations. A behavioral rule without an eval is documentation
that will drift — exactly the failure mode that sank v1.

---

## Open Questions for Architecture Phase

1. **Trace format**: What does a normalized trace look like? What events are
   captured? How granular? This needs prototyping with both runtimes to find
   the right abstraction. Trace infrastructure is Phase 0, so this must be
   resolved first.

2. **Calibration data volume**: How many human-reviewed samples are needed for
   meaningful calibration? The answer probably varies by domain. Need to
   establish practical minimums.

3. **Eval specification portability**: If the same eval spec runs in both
   runtimes, but trace formats differ, how much of the eval logic is truly
   shared vs. runtime-specific? Need to prototype to find out.

4. **Feedback loop latency**: Eval results must feed back within the same work
   unit. Between-session at minimum. Within-session for deterministic evals.
   The DSPy model (compile optimal prompts from metrics) is appealing but may
   be over-engineered for a thin harness.

5. **Self-evolving evals**: Phase 3 of the bootstrap. After a failure that
   existing evals didn't catch, the system proposes a new eval that would have
   caught it. Human-in-loop approval of proposed evals. Feasible and valuable —
   scheduled for week 2-3 of the bootstrap sequence.
