# Follow-Up Work

Generated from the `harness-v2-status-eval` work unit (2026-04-02).
Branch: `work/harness-v2-status-eval`. Commit: `5abffad`.

---

## 1. Review Implementation (immediate)

**Context**: All three implementation phases were completed in a single session. Six new scripts were written by subagents and need thorough review for edge cases, error handling, and adherence to harness conventions.

**Scripts to review** (by complexity):
- `scripts/run-eval.sh` (370 lines) — most complex, Phase A/B evaluation logic
- `scripts/validate-step-artifacts.sh` (180 lines) — 6 boundary checks, sources validate.sh
- `scripts/generate-plan.sh` (143 lines) — Python topological sort, jq plan assembly
- `scripts/cross-model-review.sh` (175 lines) — CLI invocation, JSON response parsing
- `hooks/correction-limit.sh` (60 lines) — glob matching, stdin JSON parsing
- `scripts/select-dimensions.sh` (30 lines) — simple routing
- `scripts/evaluate-gate.sh` (50 lines) — trust gradient routing

**What to check**:
- `set -eu` interaction with command substitution (the pattern that caused 3 of the 6 bugs this session)
- yq expressions: no `// empty` (jq-ism that broke validate-definition.sh)
- stdin JSON parsing in hooks (the pattern that caused PreToolUse errors)
- Atomic writes (temp + mv) are used consistently
- Exit code contracts match the spec in `specs/phase-*.md`

**References**:
- `.work/harness-v2-status-eval/specs/` — acceptance criteria per deliverable
- `.work/harness-v2-status-eval/learnings.jsonl` — pitfalls discovered this session
- `hooks/lib/validate.sh` — the file with 3 bugs fixed (from_entries, wave contiguity, yq syntax)

---

## 2. End-to-End Test with a Real Task

**Context**: The harness was built and tested in isolation. The bugs found this session (6 total) were all discovered through actual use, not static review. A real task would exercise the full pipeline including the new artifact validation gates.

**Test plan**:
- Start a new work unit with `/work <real task description>`
- Go through all 7 steps: ideate, research, plan, spec, decompose, implement, review
- At each step boundary, verify `validate-step-artifacts.sh` correctly gates advancement
- During plan step, test `generate-plan.sh` with a multi-deliverable definition
- During implement step, verify `correction-limit.sh` doesn't produce false positives
- During review step, test `run-eval.sh` on actual deliverables

**What could fail**:
- `validate-step-artifacts.sh` may be too strict for simple single-deliverable work (e.g., requiring plan.json when it's not needed)
- `init-work-unit.sh` flag parsing with edge cases (empty strings, special characters in titles)
- `step-transition.sh` artifact validation blocking when it shouldn't (e.g., research deliverables that existed before the spec step)

**References**:
- `commands/lib/step-transition.sh` — artifact validation integration point (line 85-91)
- `commands/lib/init-work-unit.sh` — new flag interface
- `skills/work-context.md` — CC plan mode guidance (ensure it's followed)

---

## 3. Research Mode End-to-End Test

**Context**: The mode flag plumbing was fixed (init-work-unit.sh now accepts `--mode research`) but the full research workflow was never tested end-to-end. Research mode has different artifact expectations, dimension files, and output locations.

**Test plan**:
- `/work "research topic" --mode research`
- Verify `state.json.mode` is `"research"`
- At research step: produce research.md, verify artifact validation accepts it
- At implement step: verify output goes to `.work/{name}/deliverables/` not git
- At review step: verify `select-dimensions.sh` returns `research-implement.yaml`
- Verify `run-eval.sh` checks deliverables/ instead of git diff

**What could fail**:
- `validate-step-artifacts.sh` implement→review check: does it correctly read mode and check deliverables/ vs git diff?
- `run-eval.sh` Phase A: does it handle research mode file existence checks?
- Dimension selection: does `select-dimensions.sh` handle the research+spec case?

**References**:
- `references/research-mode.md` — research workflow conventions
- `evals/dimensions/research-implement.yaml`, `evals/dimensions/research-spec.yaml` — research-specific dimensions
- `scripts/select-dimensions.sh` — routing logic

---

## 4. Specialist Template Rewrite

**Context**: The `harness-engineer` specialist was rewritten with reasoning-focused framing (8 thinking patterns: enforcement spectrum, platform boundary awareness, contract thinking, etc.). The other three specialists still use the old format (responsibilities list, not reasoning patterns).

**Work needed**:
- Rewrite `specialists/api-designer.md` — how does an API designer reason about resource design, contract evolution, error handling?
- Rewrite `specialists/database-architect.md` — how does a DB architect reason about schema normalization, index strategy, migration safety?
- Rewrite `specialists/test-engineer.md` — how does a test engineer reason about coverage, edge case discovery, flakiness prevention?
- Each should follow the `harness-engineer.md` pattern: Domain Expertise, How This Specialist Reasons (5-8 patterns), Quality Criteria, Anti-Patterns, Context Requirements

**References**:
- `specialists/harness-engineer.md` — the template to follow
- `references/specialist-template.md` — documents the two-path consumption model (skill invocation + agent prompt)
- The gstack research at `docs/research/findings-user-voices-2026-03.md` describes how gstack encodes "Voice" and "Cognitive Patterns" in specialist skills

---

## 5. Auto-Advance Enforcement

**Context**: Currently, auto-advance eligibility is checked by the gate evaluator reading skill instructions (prose). The `commands/lib/auto-advance.sh` script checks some criteria (deliverable count, dependencies, gate_policy) but doesn't enforce all the conditions described in each step skill.

**Open question** (from plan step Q&A): should auto-advance criteria be harness-enforced (shell checks that block/allow auto-advance) or remain evaluator-judged (prose in skills)?

**Examples of unenforced criteria**:
- spec step: auto-advance when single deliverable with >=2 testable ACs. But nothing checks AC testability (verbs, thresholds, file paths).
- research step: auto-advance when single deliverable + code mode + has path-like ACs. But "path-like" is a fuzzy check.

**Decision needed**: Is it worth adding deterministic testability checks to auto-advance, or is the current approach (evaluator judges) sufficient?

**References**:
- `commands/lib/auto-advance.sh` — current detection logic
- `scripts/auto-advance.sh` — current execution logic
- `skills/spec.md` line 28 — auto-advance criteria description
- `.work/harness-v2-status-eval/recommendations.md` — "What to Drop or Simplify" section discusses simplifying the step sequence

---

## Additional Deferred Items (from evaluation)

These were explicitly deferred in the recommendations. Listed for completeness:

| Item | Phase | Why Deferred |
|------|-------|-------------|
| Agent SDK adapter completion | Phase 2 | Claude Code is the only active runtime |
| Autonomous triggering | Phase 4 | No use case until supervised/delegated are battle-tested |
| Observability dashboard | Phase 4 | Need operational data first |
| Concurrent work streams | Phase 4 | Single-task flow needs to be solid |
| Self-improvement automation | Phase 5 | Requires eval infrastructure (now built, but untested) |
| Deletion testing automation | Phase 5 | Requires eval infrastructure |
| Phase 6 consistency review | Phase 6 | Wait until implementation stabilizes |

**References**:
- `.work/harness-v2-status-eval/recommendations.md` — full defer rationale
- `.work/harness-v2-status-eval/gap-matrix.md` — phase-by-phase coverage assessment
- `docs/architecture/PLAN.md` — original 6-phase plan with 19 specs
