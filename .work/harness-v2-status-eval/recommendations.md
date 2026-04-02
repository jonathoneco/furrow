# Recommendations: Prioritized Next Steps

Two categories: **Architectural** (missing functionality, unwired connections, structural gaps) and **Enforcement** (corrective/punitive measures). Both are needed — a harness that can't orchestrate work is as incomplete as one that can't catch misbehavior.

---

## Architectural Priorities

### A1: Wire Step-Artifact Validation into Transitions (high impact, moderate effort)

**The problem**: `step-transition.sh` advances steps without checking that the step's output exists. An agent can advance from research to plan having produced nothing. Only ideate has artifact validation (definition.yaml schema check).

**What to build**:
- Add artifact existence checks to `step-transition.sh` per step:
  - `research→plan`: require `research.md` OR `research/synthesis.md`
  - `plan→spec`: require `plan.json` if >1 deliverable (call existing `validate_plan_json()` from `hooks/lib/validate.sh` — it exists but is never invoked)
  - `spec→decompose`: require `spec.md` OR `specs/` with entries for all deliverables
  - `decompose→implement`: require `plan.json` valid + work branch created
  - `implement→review`: require git diff non-empty (code mode) OR `.work/{name}/deliverables/` non-empty (research mode)
  - `review→archive`: require `reviews/` has results for all deliverables
- This is ~80 lines of shell added to `step-transition.sh` or a new `validate-step-artifacts.sh` script
- Existing validators (`validate_plan_json`, `validate_definition_yaml`) just need to be *called*

**Why first**: Without this, the harness is a state machine that tracks progress but doesn't verify it. The gate system records "pass" but never checks what passed.

### A2: Create Missing Schemas and Templates (moderate impact, low effort)

**The problem**: `plan.json` is a core workflow artifact with no schema in `schemas/` and no template in `templates/`. Same for spec output and review results. `adapters/shared/schemas/` has `plan.schema.json` and `review-result.schema.json` but they're disconnected from the main validation pipeline.

**What to build**:
- Move or symlink `adapters/shared/schemas/plan.schema.json` → `schemas/plan.schema.json`
- Move or symlink `adapters/shared/schemas/review-result.schema.json` → `schemas/review-result.schema.json`
- Create `templates/plan.json` — example with 2 waves, dependencies, file ownership
- Create `templates/spec.md` — single-deliverable spec structure
- Create `schemas/learnings.schema.json` — formalize the learnings.jsonl format
- Wire these schemas into `validate-definition.sh` or a new `validate-artifacts.sh`
- Fix `init-work-unit.sh` to create `reviews/` directory (docs say it should, code doesn't)

### A3: Wire Mode and Trust Gradient into Runtime (high impact, moderate effort)

**The problem**: The `--mode research` flag from `/work` is never passed to `init-work-unit.sh`, so mode is always "code". The `gate_policy` field only affects auto-advance blocking (~20 lines). Everything else (gate decision routing, output directory selection, eval dimension selection, specialist type) is prose-only.

**What to build**:
- **Mode plumbing**: Fix `init-work-unit.sh` to accept `--mode` flag and write it to state.json
- **Mode-aware dimension loading**: Add a `scripts/select-dimensions.sh` that reads `state.json.mode` + current step and returns the correct eval dimension file path. This replaces the hardcoded path in `reviewer.py` and the prose instructions in review skills.
- **Gate policy routing**: Add a `scripts/evaluate-gate.sh` that reads `gate_policy` and:
  - `supervised`: always outputs "WAIT_FOR_HUMAN"
  - `delegated`: outputs evaluator verdict for non-critical steps, "WAIT_FOR_HUMAN" for implement→review
  - `autonomous`: outputs evaluator verdict for all steps
  - This makes the trust gradient executable, not advisory
- **Research mode output validation**: Add checks in step-transition that validate `.work/{name}/deliverables/` for research mode instead of git diff

### A4: Plan.json Generation and Wave Support (high impact, high effort)

**The problem**: Multi-deliverable work — the use case the research identifies as most valuable — has no operational support. The harness can validate a plan.json that a human writes, but nothing generates it from definition.yaml, and nothing executes waves from it.

**What to build (minimum viable)**:
- `scripts/generate-plan.sh` — reads definition.yaml, builds dependency graph, assigns waves, generates plan.json. This is the missing link between "what to build" (definition) and "how to build it" (plan). ~150 lines.
- `scripts/dispatch-wave.sh` — reads plan.json, constructs specialist prompts from specialist templates + context isolation rules + file ownership, outputs one prompt file per specialist per wave. Doesn't execute agents (that's platform-specific), but produces the prompt artifacts. ~100 lines.
- Update `skills/decompose.md` to reference these scripts instead of relying entirely on prose instructions
- Wire `check-wave-conflicts.sh` to run automatically between waves

**What NOT to build**: A full coordinator that spawns and manages agents. That's Agent SDK territory. For Claude Code, producing the prompt artifacts and letting the human dispatch is sufficient. The scripts make the harness *useful* for multi-deliverable work without building an agent framework.

### A5: Specialist Context Seeding (moderate impact, moderate effort)

**The problem**: The context seeding contract is documented in `references/specialist-template.md` and `skills/shared/context-isolation.md` but nothing constructs agent prompts from these. A human must manually read the specialist template, extract file ownership globs, build skill injection lists, and compose the prompt.

**What to build**:
- `scripts/build-specialist-prompt.sh` — given a work unit name, deliverable name, and specialist type, assembles:
  1. Specialist template from `specialists/{type}.md`
  2. File ownership globs from plan.json
  3. Acceptance criteria from definition.yaml
  4. Skill injection list per `docs/skill-injection-order.md`
  5. Context pointers from definition.yaml
  6. Output: a complete prompt file at `.work/{name}/prompts/{deliverable}.md`
- This turns the context seeding contract from documentation into a tool

---

## Enforcement Priorities

### E1: Correction Limit (safety)

**Why**: Two absent gap-review behaviors (#5, #13). Agent can spiral indefinitely.

**What**: Hook tracking consecutive failures per deliverable, configurable limit (default: 3), pause + surface on limit. ~1 script + hook entry.

### E2: Eval Runner (minimum viable)

**Why**: Three research insights blocked (eval-first, generator-evaluator separation, deletion testing).

**What**: Shell script for deterministic checks (schema, existence, naming) + prompt template for LLM-judge using existing dimension YAMLs + results in `reviews/{deliverable}.json`. Wire into `step-transition.sh`. Not yet: calibration, traces, cross-model.

### E3: Cross-Model Enforcement

**Why**: `harness.yaml` has `cross_model.provider` — configured, never read. 3-5x bug detection improvement per research.

**What**: Script reads provider config, constructs review invocation with different model, wires into review skill Phase B. ~1 script + skill update.

---

## What to Explicitly Defer

| Feature | Why Defer |
|---------|----------|
| **Agent SDK adapter completion** | Defer unless you're actively using Agent SDK. Claude Code is the working runtime. Architecture supports adding later. |
| **Autonomous triggering** | No use case until supervised/delegated modes are battle-tested |
| **Observability dashboard** | Premature — need operational data first |
| **Concurrent work streams** | Single-task flow needs to be solid first |
| **Self-improvement automation** | Requires eval infrastructure (E2) as prerequisite |
| **Deletion testing automation** | Requires eval infrastructure (E2) |
| **CI/CD integration** | Dev-time tool; CI adds complexity without current need |
| **Phase 6 consistency review** | Wait until A1-A4 + E1-E2 are done |
| **Full coordinator agent** | `dispatch-wave.sh` producing prompts is sufficient for Claude Code |

---

## What to Drop or Simplify

| Item | Rationale |
|------|-----------|
| **Fixed 7-step sequence for all work** | Research advocated complexity emergence. Consider: T1 (fix) skips to implement; T2 starts at plan; only T3 uses full sequence. `auto-advance.sh` partially addresses this but the assumption deserves challenge. |
| **6-part ideation ceremony for delegated/autonomous** | In delegated mode, agent self-answers — ceremony becomes theater. Collapse to: write definition → validate → gate. Full ceremony for supervised only. |
| **Scope change protocol** | `redirect.md` covers pivots. Mid-execution amendment is rare — YAGNI. |
| **Per-deliverable gate override** | Schema field exists, nothing reads it, no evidence it's needed. Remove from schema or wire it — don't leave dead fields. |

---

## What's Working Well (Preserve)

1. **Context budget enforcement** — 300-line ceiling with measurement. The #1 v1 lesson. Protect it.
2. **File-based state** — state.json + definition.yaml + summary.md. Simple, debuggable, git-tracked.
3. **`_rationale.yaml`** — deletion-first thinking. Continue annotating. Prevents v2 from becoming v1.
4. **Progressive loading** — step-aware skill injection. Each step sees only what it needs.
5. **State guard hook** — structural enforcement pattern. Build more at this level.
6. **Shell script lifecycle** — atomic operations that compose well. Better than v1's prose-encoded procedures.
7. **Learnings capture** — knowledge accumulation loop v1 lacked entirely.
8. **Schema validation pipeline** — definition.yaml and state.json validation is solid. Extend this pattern to plan.json and review results.

---

## Suggested Build Order

If tackling these as a single initiative:

```
Phase I (wiring what exists):
  A1: Step-artifact validation  ──┐
  A2: Missing schemas/templates ──┤── can be done in parallel
  A3: Mode + trust gradient     ──┘

Phase II (new capabilities):
  A4: Plan generation + wave support ─── depends on A2 (plan.json schema)
  A5: Specialist context seeding     ─── depends on A4 (plan.json exists)
  E1: Correction limit               ─── independent

Phase III (quality infrastructure):
  E2: Eval runner           ─── depends on A1 (knows what to validate)
  E3: Cross-model review    ─── depends on E2 (eval runner dispatches review)
```

**Phase I alone** would close the majority of architectural gaps. It's ~200 lines of shell across 3-4 scripts, and mostly wires together components that already exist.

---

## Revised Summary Scorecard

| Dimension | Score | Notes |
|-----------|-------|-------|
| Architecture & abstractions | 9/10 | Clean separation, correct abstractions, avoids all v1 failure modes |
| Foundation schemas & state | 8/10 | definition + state solid; plan + spec + review schemas disconnected |
| Step workflow completeness | 5/10 | Steps exist but artifacts aren't validated; advancement is unchecked |
| Multi-agent orchestration | 3/10 | Schemas + templates exist; no generation, dispatch, or coordination |
| Trust gradient runtime | 2/10 | Only auto-advance blocking is wired; gate routing is prose |
| Mode differentiation | 2/10 | Mode flag not even persisted; all mode behavior is prose advisory |
| Enforcement & safety | 4/10 | State guard great; correction limit and eval gates absent |
| Context management | 9/10 | Standout feature: budgets, measurement, progressive loading, recovery |
| Knowledge & learnings | 7/10 | Learnings capture works; promotion and reuse need work |
| **Overall** | **5.5/10** | Strong architecture, significant wiring and functionality gaps |

Previous assessment (6.5) was inflated by focusing on enforcement gaps while overlooking the architectural ones. The harness has excellent design documents, solid schemas for its core artifacts, and strong context management — but the workflow machinery between steps is largely advisory prose, the trust gradient isn't runtime-enforced, and multi-agent orchestration is unimplemented.
