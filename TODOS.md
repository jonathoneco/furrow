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

---

## 6. Formalize TODOS.md as a Harness Workflow

**Context**: This TODOS.md was created ad-hoc at the end of a work unit to capture follow-up work. The pattern proved useful — structured items with context, references, and test plans allow future sessions to pick up work accurately. This should be a first-class harness workflow, not a one-off.

**What to build**:
- A `/work-todos` or checkpoint-integrated command that generates TODOS.md at session end
- Template for TODO items: title, context (why this matters), work needed (concrete steps), what could fail (risks), references (artifacts with paths)
- Auto-populate from: open questions in summary.md, learnings.jsonl pitfalls that suggest follow-up, deferred items from recommendations, findings from review step that weren't addressed
- TODOS.md should live at project root (not in `.work/`) since it spans work units
- Each TODO should be convertible to a `/work` description — enough context to start a new work unit without re-reading the original session

**Integration points**:
- `commands/checkpoint.md` — offer to update TODOS.md at checkpoint time
- `commands/archive.md` — generate/update TODOS.md when archiving a work unit
- `skills/review.md` — review findings that aren't fixed should become TODOs
- `learnings.jsonl` — pitfalls with `promoted: false` may indicate unresolved follow-up

**References**:
- This file itself — the pattern to formalize
- `commands/lib/promote-learnings.sh` — similar "extract durable insights" pattern

---

## 7. Roadmap Process from TODOS

**Context**: TODOS.md captures what needs doing. A roadmap process would periodically triage these into prioritized work units with dependencies, grouping, and sequencing. This bridges the gap between "list of things to do" and "what to work on next."

**What to build**:
- A `/work-roadmap` command (or skill) that reads TODOS.md and produces a prioritized plan
- The roadmap process should:
  1. **Triage**: For each TODO, assess: urgency (blocking other work?), impact (how many other items does this unblock?), effort (session count estimate), dependencies (what must be done first?)
  2. **Group**: Cluster related TODOs into candidate work units (e.g., "specialist rewrites" groups items 4a-4c; "research mode validation" groups items 3 + parts of 2)
  3. **Sequence**: Order work units by dependency graph and impact — items that unblock the most other items go first
  4. **Output**: A ROADMAP.md with ordered work units, each with enough context to start via `/work`
- The roadmap should be regenerated when TODOS.md changes significantly (new items added, items completed)
- Completed TODOs move to an "## Archive" section (not deleted — they're audit trail)

**Process for a roadmap session**:
```
1. Read TODOS.md
2. For each item: is it still relevant? (check if conditions changed)
3. Triage: urgency / impact / effort / dependencies
4. Group into candidate work units (1-3 TODOs per unit)
5. Sequence by dependency + impact
6. Write ROADMAP.md
7. Start top-priority work unit via /work
```

**Design considerations**:
- TODOS.md is append-friendly (new items added at end); ROADMAP.md is rewrite-friendly (regenerated from current state)
- TODOs are granular (one concern per item); roadmap entries are scoped work units (may combine multiple TODOs)
- The roadmap process itself should be a research-mode work unit the first time, then become a lightweight command

**References**:
- `docs/architecture/PLAN.md` — the original 6-phase roadmap (a manual version of this process)
- `.work/harness-v2-status-eval/recommendations.md` — "Suggested Build Order" section shows the dependency-driven sequencing pattern
- `scripts/generate-plan.sh` — the topological sort logic could be reused for roadmap dependency ordering

---

## 8. Parallel Workflow Support

**Context**: The harness currently supports only one active work unit at a time. `detect-context.sh` warns when multiple active tasks exist and asks the user to pick one. Hooks like `state-guard.sh`, `ownership-warn.sh`, and `timestamp-update.sh` assume a single active `.work/` directory. Real-world usage often requires concurrent streams — e.g., a bug fix while a feature is in the plan step, or two independent deliverables that could progress simultaneously.

**What's blocking today**:
- `detect-context.sh` treats multiple active tasks as an error condition (asks "which to continue?" instead of allowing both)
- Hooks scan all `.work/*/state.json` files but don't scope operations to a specific work unit — a write to one unit could trigger validation on another
- `work-context.md` skill loads context for a single active task; no mechanism to switch or scope
- `post-compact.sh` re-injects context for one task; a second active task loses context
- Step skills assume one step sequence in flight; no namespacing of step state

**What to build**:
- Work unit scoping: commands and hooks must accept/infer which work unit they're operating on (e.g., `--unit <name>` flag or CWD-based detection)
- Context multiplexing: `work-context.md` should support loading context for a specific unit, not just "the active one"
- Hook scoping: each hook must operate on the triggering work unit only, not scan all active units
- Session affinity: a mechanism to "focus" a session on one work unit while others remain active but dormant
- `detect-context.sh` should list all active units and allow continuing any one without treating multiplicity as an error

**Design considerations**:
- Start with "focused + dormant" model: one unit is focused (receives context injection, hook enforcement), others are dormant (state preserved but not actively loaded). This avoids the complexity of true concurrent execution.
- The `/work` command could accept a `--switch <name>` flag to change focus without archiving the current unit.
- Consider whether step hooks should be fully isolated per unit or share the hook pipeline with unit-scoped filtering.

**References**:
- `commands/lib/detect-context.sh` — current single-task assumption
- `hooks/state-guard.sh`, `hooks/ownership-warn.sh` — hooks that need scoping
- `skills/work-context.md` — context loading that assumes one active unit
- `hooks/post-compact.sh` — context re-injection after compaction
- Deferred items table (this file, item "Concurrent work streams") — originally Phase 4

---

## 9. Triage-TODOs Harness Skill

**Context**: The process of turning TODOS.md into a dependency-aware, parallelizable roadmap was done manually this session. It required: reading all TODOs, analyzing file-level conflicts between them, building a dependency DAG, grouping into phases that respect both logical dependencies and worktree-safe file isolation, and producing a ROADMAP.md with branch/merge strategy. This should be a repeatable harness skill, not a one-off exercise.

**What to build**:
- A `/harness:triage` (or `triage-todos`) skill that reads TODOS.md and produces/updates ROADMAP.md
- The skill should perform:
  1. **Dependency extraction**: Parse each TODO for explicit dependencies ("depends on TODO N", "after X is done") and implicit ones (file overlap analysis via grep of "files touched" sections)
  2. **File conflict analysis**: For each TODO, identify files it would modify. Cross-reference to find TODOs that touch the same files — these cannot safely parallelize in worktrees
  3. **DAG construction**: Build a directed acyclic graph from dependencies + file conflicts. Identify the critical path and maximum parallelism width
  4. **Phase grouping**: Cluster TODOs into phases where all items in a phase can run in parallel worktrees. Each phase has a merge point back to main before the next phase starts
  5. **Branch strategy**: Generate branch names, merge order, and conflict-risk annotations per phase
  6. **ROADMAP.md generation**: Write the roadmap with DAG visualization, phase breakdown, and per-track work descriptions

**Design considerations**:
- The skill should be idempotent — re-running after adding/completing TODOs regenerates the roadmap from current state
- Completed TODOs (marked with `[x]` or moved to archive section) should be shown as done in the DAG but excluded from active phases
- The file conflict analysis could reuse `scripts/check-wave-conflicts.sh` patterns (already does file overlap detection for implementation waves)
- The DAG could reuse `scripts/generate-plan.sh` topological sort logic
- Output format should match what `/work` expects so each phase track can be started directly

**Integration points**:
- `TODOS.md` — input (structured TODO items with references)
- `ROADMAP.md` — output (phased, parallelizable plan)
- `scripts/generate-plan.sh` — reusable topological sort
- `scripts/check-wave-conflicts.sh` — reusable file conflict detection
- `/work` command — each roadmap track should be startable as a work unit

**References**:
- This session's manual triage process — the pattern to automate
- `ROADMAP.md` — the output format to replicate
- `scripts/generate-plan.sh` — topological sort for dependency ordering
- `scripts/check-wave-conflicts.sh` — file overlap detection for worktree safety
- TODO 7 (Roadmap Process) — the broader roadmap lifecycle this skill plugs into
