# Research: quality-and-rules

## 1. Stop Hook Exit Codes

### Findings

**validate-summary.sh** — Returns 1 on validation failure (line 73). Should return 2 (blocking).
- Validates: 7 required sections, >=1 non-empty line in Key Findings/Open Questions/Recommendations
- Skip logic (exit 0): no active row, no summary, prechecked gate, ideate step (only requires Open Questions)
- Single change: `return 1` → `return 2` on line 73; update comment on line 11

**stop-ideation.sh** — Implementation incomplete. Always returns 0.
- Documents `return 1` for missing section markers but never actually returns 1
- Currently just checks if definition.yaml exists; marker validation is advisory
- Needs: complete the implementation, then use return 2 for failures

**work-check.sh** — Intentionally informational. Always returns 0.
- Documented as "Non-blocking — informational only" (line 4)
- Validates ALL active rows at session end, updates timestamps
- Should remain exit 0 — changing to blocking would cascade failures across all rows

### Open Question Resolved
> Should work-check.sh use blocking exit codes or stay informational?

**Answer: Stay informational.** It's a cross-row health check that logs warnings. Making it blocking would require ALL rows to pass before ANY session can end.

## Sources Consulted
- Primary: bin/frw.d/hooks/validate-summary.sh (source code)
- Primary: bin/frw.d/hooks/stop-ideation.sh (source code)
- Primary: bin/frw.d/hooks/work-check.sh (source code)
- Primary: .claude/settings.json (hook registration)
- Primary: Claude Code documentation (exit code semantics via subagent research)

---

## 2. CLI Post-Actions

### Findings

**`update_state()` already auto-updates `updated_at`** (line 212 in bin/rws). Every call to `update_state()` appends `.updated_at = $now` to the jq expression. All state-mutating subcommands use `update_state()`, so timestamps are already correct for:
- rws init, transition (--request and --confirm), complete-step, archive, rewind

**Gap 1: `rws complete-deliverable` doesn't regenerate summary.**
- Line 1730: calls `update_state()` (timestamp OK) but no `regenerate_summary()` call
- Insert after line 1730: `regenerate_summary "$_cd_name"`
- Why: deliverable completion changes the summary's deliverable count and status

**Gap 2: `rws update-summary` doesn't update state.json timestamp.**
- Line 1061: writes summary.md via `mv` but doesn't touch state.json
- Insert after line 1061: `update_state "$_usm_name" "."` (no-op mutation to trigger timestamp)
- Why: summary changes should make the row appear as "recently updated" in `rws list`

**No other gaps found.** The `updated_at` pattern is well-established via `update_state()`.

### Open Question Resolved
> No timestamp drift — updated_at reflects the last meaningful state change

**Confirmed.** The existing `update_state()` pattern handles this. Only 2 insertion points needed.

## Sources Consulted
- Primary: bin/rws (source code, lines 212, 1361-1596, 1682-1733, 2126-2166)
- Primary: bin/frw.d/hooks/ (hook interaction with CLI commands)

---

## 3. Spec Test Scenarios

### Findings

**Current template structure** (templates/spec.md):
1. Interface Contract
2. Acceptance Criteria (Refined)
3. Implementation Notes
4. Dependencies

**Insertion point:** After Acceptance Criteria, before Implementation Notes. ACs define what must work; test scenarios demonstrate how to verify it.

**Format:**
```markdown
## Test Scenarios

### Scenario: [descriptive name]
- **Verifies**: [AC reference]
- **WHEN**: [setup + action]
- **THEN**: [observable outcome]
- **Verification**: [command or check procedure]
```

**Relationship to ACs:** Supplementary. 1 AC can have 0-N scenarios. Simple ACs ("exit code 0") need no scenario. Complex ACs get 1-3 scenarios covering main path + edge cases.

**Decompose interaction:** Decompose does NOT derive test work from ACs or scenarios. It maps deliverables to specialists and waves. Test scenarios flow downstream to implement (specialists reference them) and review (evaluators check against them). No decompose changes needed.

**New eval dimension:**
```yaml
- name: "test-scenario-coverage"
  definition: "Whether test scenarios adequately exemplify the acceptance criteria"
  pass_criteria: "Every non-trivial AC has at least one scenario with WHEN/THEN/verification. Trivially testable ACs may omit scenarios."
  fail_criteria: "Non-trivial AC has no scenario, or scenario is vague (no observable outcome)"
```

### Open Question Resolved
> How should spec test scenarios interact with the decompose step?

**Answer: They don't.** Decompose maps deliverables to specialists. Test scenarios are consumed during implement and review, not decompose.

## Sources Consulted
- Primary: templates/spec.md (current template)
- Primary: skills/spec.md (step instructions)
- Primary: evals/dimensions/spec.yaml (evaluation dimensions)
- Primary: skills/decompose.md (decompose consumption of spec)
- Primary: evals/gates/spec.yaml (gate dimensions)

---

## 4. Harness Rules & Invariant Extraction

### Findings

**CLAUDE.md audit** — 76 lines, contains these invariants:

| Invariant | Lines | Already in rules? | Extract? |
|---|---|---|---|
| state.json CLI-only | 12 | cli-mediation.md | No (covered) |
| Step sequence (7 steps) | 13 | No | **Yes** |
| Summary CLI-only | 12, 19 | cli-mediation.md | No (covered) |
| Ambient budget <=120 | 19 | No | **Yes** |
| Total injected <=320 | 24 | No | **Yes** (same file) |
| Correction limit (3) | Not in CLAUDE.md | No | **Yes** |

**Rule candidates:**

1. **step-sequence.md** (~12 lines) — Fixed 7-step sequence, no skipping, gate enforcement, prechecked auto-advance. Currently split across CLAUDE.md line 13 and work-context.md.

2. **context-budget.md** (~14 lines) — Per-layer budgets (120/150/50/600), total <=320, one-instruction-per-layer rule, `frw measure-context` verification.

3. **Correction limit** (~8 lines) — Default 3 corrections per deliverable during implement, blocks writes, no CLI override. Currently undocumented in ambient context; users discover via failure. Append to cli-mediation.md or standalone.

**Budget impact:**
- Current: 107 lines (CLAUDE.md 76 + cli-mediation 31)
- Adding 3 rules: +34 lines = 141 lines (21 over budget)
- **Solution:** Move Furrow command table (23 lines) from CLAUDE.md to references/. Net: ~118 lines (within budget)

### Open Question Resolved
> Context budget impact: how many lines will new rules add?

**Answer: ~34 lines net new, offset by moving 23 lines of command table to references/. Final: ~118 lines, within 120-line budget.**

## Sources Consulted
- Primary: .claude/CLAUDE.md (invariant audit)
- Primary: .claude/rules/cli-mediation.md (existing rule pattern)
- Primary: skills/shared/summary-protocol.md (summary ownership)
- Primary: install.sh (rules symlink management)
- Primary: bin/frw.d/hooks/correction-limit.sh (correction limit behavior)

---

## 5. Row Naming Examples

### Findings

**27 row names surveyed** across active, archived, and branch history.

**Good patterns (outcome-oriented):**
- `isolated-gate-evaluation` — architectural change clearly stated
- `namespace-rename` — exact action + scope
- `default-supervised-gating` — feature + property being changed
- `auto-advance-enforcement` — mechanism + enforcement

**Bad patterns (vague/generic):**
- `research-e2e` — "e2e" of what?
- `todos-workflow` — "workflow" is structural, not outcome
- `roadmap-process` — "process" says nothing about result
- `specialist-rewrite` — which specialists? rewrite how?
- `quick-harness-fixes` — "quick" is temporal, "fixes" is generic

**Naming principles derived:**
1. **Outcome over area** — name what changes, not where
2. **Action + component** for single-focus rows
3. **Concrete nouns** — avoid: workflow, process, support, eval, integration
4. **Scope specifiers** when work affects a subset

## Sources Consulted
- Primary: .furrow/rows/ directory listing
- Primary: git log (archived row names from commits)
- Primary: git branch (work/ prefix branches)

---

## Research Synthesis

All 3 open questions from ideation are resolved. Key findings per deliverable:

| Deliverable | Key Finding | Implementation Complexity |
|---|---|---|
| stop-hook-exit-codes | 1 line change in validate-summary.sh; stop-ideation.sh needs implementation; work-check.sh stays informational | Low |
| cli-post-actions | 2 insertion points in bin/rws; update_state() pattern already handles timestamps | Low |
| spec-test-scenarios | Insert after ACs in template; new eval dimension; no decompose changes | Medium |
| harness-rules | 3 rule files (~34 lines); move command table to stay within budget | Medium |
| rules-strategy-doc | Research complete; enforcement taxonomy clear from this analysis | Low |
| row-naming-guidance | 27 examples surveyed; patterns identified; 5-minute inline edit | Low |
