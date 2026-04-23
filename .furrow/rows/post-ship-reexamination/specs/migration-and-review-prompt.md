# Spec: migration-and-review-prompt

## Interface Contract

**Files modified**:
- `.furrow/almanac/todos.yaml` — remove entry `re-evaluate-dispatch-enforcement`.
- `.furrow/almanac/observations.yaml` — add migrated entry as a `kind: decision-review` observation.
- `adapters/shared/schemas/todos.schema.yaml` — remove `decision-review` from `source_type` enum.
- `skills/review.md` — add one-line observation-capture prompt inside the existing Supervised Transition Protocol step 1.
- `skills/shared/summary-protocol.md` — add one bullet disambiguating Open Questions from Observations.

**Atomic-commit contract**: all 5 file changes land in ONE commit. `alm validate` must pass after each of the three schema/data sub-steps during preparation.

**Backward compatibility**: removal of `decision-review` from the TODO `source_type` enum is a non-additive schema change, but safe because `re-evaluate-dispatch-enforcement` is the only live user (verified via grep during research).

## Acceptance Criteria (Refined)

### Data migration: re-evaluate-dispatch-enforcement

Source (current state in `todos.yaml` at line ~1956):

```yaml
- id: re-evaluate-dispatch-enforcement
  title: "Re-evaluate whether structural enforcement is needed for multi-agent dispatch"
  context: |
    Decision during parallel-agent-wiring ideation: we chose instruction-only
    (concrete decision tree + examples in implement.md) over file-ownership hooks
    for enforcing multi-agent dispatch. ...
  work_needed: |
    - Run the next 3 multi-deliverable rows (2+ deliverables) with the new implement.md instructions
    - For each: check whether Agent tool calls appear during the implement step ...
    - Threshold: if <2 of 3 rows dispatch sub-agents for multi-deliverable waves, escalate to structural enforcement
    - If >=2 of 3 dispatch correctly: close this TODO
    - Enforcement options to revisit: file-ownership hooks, pre-edit hook checking agent identity, mandatory dispatch step
  source_type: "decision-review"
  created_at: "2026-04-09T00:00:00Z"
  updated_at: "2026-04-09T00:00:00Z"
  urgency: "low"
  impact: "medium"
  effort: "small"
  depends_on:
    - parallel-agent-orchestration-adoption
  status: active
```

Target (entry added to `observations.yaml`):

```yaml
- id: re-evaluate-dispatch-enforcement
  kind: decision-review
  title: "Re-evaluate whether structural enforcement is needed for multi-agent dispatch"
  triggered_by:
    type: rows_since
    since_row: parallel-agent-wiring
    count: 3
  lifecycle: open
  question: >-
    Given the instruction-only approach to multi-agent dispatch in
    implement.md, do step agents actually dispatch sub-agents for
    multi-deliverable waves in practice?
  options:
    - id: instruction-sufficient
      label: "Instruction-only is working (>=2 of 3 rows dispatch correctly); close as validated."
    - id: escalate-to-enforcement
      label: "Dispatch is not happening (<2 of 3); escalate to structural enforcement (file-ownership hooks, pre-edit hook, or mandatory dispatch step)."
  acceptance_criteria: >-
    Threshold: after 3 subsequent multi-deliverable rows archive, check whether
    Agent tool calls appeared during implement step in each. If >=2 of 3, choose
    instruction-sufficient. If <2 of 3, choose escalate-to-enforcement.
  evidence_needed:
    - "Session histories or row learnings for 3 post-parallel-agent-wiring multi-deliverable rows"
    - "Per-row count of Agent tool calls during implement step"
  source_work_unit: parallel-agent-wiring
  created_at: "2026-04-09T00:00:00Z"
  updated_at: "<migration-commit timestamp>"
```

Notes on the transformation:
- `source_type: decision-review` → `kind: decision-review` (now a proper first-class field).
- `work_needed` prose → structured `question` + `options` + `acceptance_criteria` + `evidence_needed`.
- `depends_on: [parallel-agent-orchestration-adoption]` drops out — observations have no `depends_on`; the trigger (`rows_since parallel-agent-wiring + 3`) encodes the "wait for shipping" relationship directly.
- `urgency`, `impact`, `effort`, `status` drop out — observations have `lifecycle` only; no prioritization fields (not part of the observation schema).
- `context` prose drops out — the question + acceptance_criteria capture what context was conveying.
- `created_at` preserved verbatim at `"2026-04-09T00:00:00Z"` (intentional — auditable record of when the decision was first deferred). `updated_at` bumped to migration commit timestamp. `created_at <= updated_at` invariant satisfied.

### Schema change: remove decision-review from todos source_type enum

Edit `adapters/shared/schemas/todos.schema.yaml`: remove the `- decision-review` line from the `source_type` enum (currently around line 57).

Before (abbreviated):
```yaml
source_type:
  type: string
  enum:
    - open-question
    - unpromoted-learning
    - review-finding
    - brain-dump
    - manual
    - legacy
    - decision-review
```

After:
```yaml
source_type:
  type: string
  enum:
    - open-question
    - unpromoted-learning
    - review-finding
    - brain-dump
    - manual
    - legacy
```

### Migration ordering (single commit)

Execute in this EXACT order. Validate between each step.

1. **Add to observations.yaml**: append the migrated entry. Run `alm validate`. Must pass (observations pass; todos still valid, including the to-be-migrated entry — enum still has `decision-review`).
2. **Remove from todos.yaml**: delete the `re-evaluate-dispatch-enforcement` entry. Run `alm validate`. Must pass (observations still valid; todos valid — no orphaned enum reference because we removed the only user).
3. **Remove enum value**: delete `- decision-review` from the source_type enum. Run `alm validate`. Must pass (observations still valid; todos valid — enum tightened, no entries use the removed value).

Land all five files (observations.yaml, todos.yaml, todos.schema.yaml, skills/review.md, skills/shared/summary-protocol.md) in **one git commit** with conventional-commits message like `refactor: migrate decision-review TODO to observation; remove source_type workaround`.

If any validate step fails: abort, reset working tree, investigate. Do not attempt partial commits.

### skills/review.md addition

Add ONE line to the existing Supervised Transition Protocol. Current step 1:

```markdown
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
```

Change to:

```markdown
1. Update `summary.md` — write Key Findings, Open Questions, and Recommendations sections.
   Before updating: check whether any decisions in this row are conditional on
   post-ship evidence. If yes, record each via `alm observe add --kind decision-review ...`.
```

Do not restructure or renumber other sections. Do not add new top-level sections.

### skills/shared/summary-protocol.md addition

Locate the "When to Update" list (or equivalent list indicating what goes where in the summary). Add ONE bullet that disambiguates Open Questions (unresolved-now) from Observations (deferred-to-trigger):

```markdown
- Observations — if a decision needs re-examination post-ship (after a row merges or after N rows archive), record it via `alm observe add` instead of parking it in Open Questions. Open Questions are for unresolved blockers in THIS row; Observations are for deferred re-examinations triggered by future archive events.
```

Placement: at the end of the "When to Update" list (or wherever Open Questions is currently defined/used). One bullet only; do not expand into a new section.

## Test Scenarios

### Scenario: migration-dry-run-validates-between-each-step
- **Verifies**: atomic-commit ordering with validation at each sub-step
- **WHEN**: A dry-run applies each of the three edits sequentially.
- **THEN**: After step 1, `alm validate` exits 0 (observations.yaml and todos.yaml both valid). After step 2, `alm validate` exits 0. After step 3, `alm validate` exits 0.
- **Verification**: Manually execute dry-run with `git stash` between steps; run validate each time.

### Scenario: reversed-order-fails
- **Verifies**: ordering really matters
- **WHEN**: Attempt step 3 (remove enum) before step 2 (remove from todos).
- **THEN**: `alm validate` FAILS because `re-evaluate-dispatch-enforcement` still has `source_type: decision-review` which is no longer a valid enum value.
- **Verification**: Document this as a sanity check, not a required automated test.

### Scenario: migrated-observation-validates
- **Verifies**: the new observation passes the observations schema
- **WHEN**: observations.yaml has the migrated entry in the exact shape specified above.
- **THEN**: `alm validate` exits 0; `alm observe show re-evaluate-dispatch-enforcement` prints all fields correctly.
- **Verification**: `alm validate && alm observe show re-evaluate-dispatch-enforcement`

### Scenario: activation-computed-for-migrated-entry
- **Verifies**: the pull-model activation works on the migrated entry
- **WHEN**: `parallel-agent-wiring` row is archived AND >=3 additional rows have archived since.
- **THEN**: `alm observe list --active` includes `re-evaluate-dispatch-enforcement`.
- **Verification**: Inspect `.furrow/rows/parallel-agent-wiring/state.json:archived_at`; count rows archived after that timestamp; if >=3, observation must appear in `--active` listing.

### Scenario: no-orphan-references-after-migration
- **Verifies**: nothing else references the old TODO id
- **WHEN**: After migration lands.
- **THEN**: `grep -r "re-evaluate-dispatch-enforcement" .furrow/almanac/ adapters/ schemas/` only finds the observation entry in observations.yaml, not any TODO file or schema.
- **Verification**: `grep -rn re-evaluate-dispatch-enforcement .furrow/almanac/ adapters/ schemas/` output

### Scenario: review-prompt-addition-fits-skill-budget
- **Verifies**: skills/review.md addition is minimal
- **WHEN**: Counting the diff on skills/review.md.
- **THEN**: Added lines ≤ 3; no removed lines from the existing step structure.
- **Verification**: `git diff --stat skills/review.md` — additions column ≤ 3.

### Scenario: summary-protocol-addition-fits-shared-budget
- **Verifies**: skills/shared/summary-protocol.md addition is minimal
- **WHEN**: Counting the diff.
- **THEN**: Added lines ≤ 5 (one bullet, potentially multi-line).
- **Verification**: `git diff --stat skills/shared/summary-protocol.md`

## Implementation Notes

**Reference AD-7** (team-plan.md). Specialist: `migration-strategist` — their specialty is ordered atomic migrations with rollback discipline.

**Single-commit discipline**: the implementer must stage all five files together, validate, and only then commit. If validation fails partway, reset and retry. Use `git stash` / `git reset` as needed — do NOT commit-then-fix.

**Options.id pattern**: the new schema uses `{id: string, label: string}` for option entries. Use short kebab-case ids (`instruction-sufficient`, `escalate-to-enforcement`) for future reference by `alm observe resolve <id> --option <option-id>`.

**No changes to `alm` code in this deliverable**. All CLI capability comes from D2. If D4 wants to add the entry via `alm observe add`, fine; if it edits observations.yaml directly via YAML surgery, also fine — both paths pass through `alm validate` as the correctness gate.

**skills/review.md budget drift**: the file is already ~102 lines vs the project's ≤50-line-per-step budget. We are NOT fixing that drift in this row (out of scope). Our addition is 2 lines inside an existing step; it does not worsen the situation meaningfully.

## Dependencies

- **Blocks on**: D2 (alm-observe-cli) — we need `alm validate` to cover observations.yaml before we can claim "validation passes at each sub-step".
- **Unblocks**: nothing internal to this row.
- External reference: the migrated observation's behavior will be validated in practice over the next 3 multi-deliverable rows. That's a meta-feedback loop, captured by the observation itself.
