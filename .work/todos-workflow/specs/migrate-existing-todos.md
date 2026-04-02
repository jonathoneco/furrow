# Spec: migrate-existing-todos

Deliverable from `.work/todos-workflow/definition.yaml`.

## Component

One-time migration of `TODOS.md` (10 manually-written entries from the `harness-v2-status-eval` work unit) into a `todos.yaml` file at the project root. The migration produces structured YAML that validates against `adapters/shared/schemas/todos.schema.yaml`.

## Files

| File | Action | Purpose |
|------|--------|---------|
| `TODOS.md` | Delete | Source file — replaced by `todos.yaml` |
| `todos.yaml` | Create | Structured TODO entries (migration output) |
| `ROADMAP.md` | Update | Remove references to `TODOS.md` if any point to it as a live file |

## Migration Mapping

Each `## N. Title` section in `TODOS.md` maps to a YAML object:

| TODOS.md Section | YAML Field | Notes |
|------------------|------------|-------|
| `## N. Title` | `id` | Kebab-case slug derived from title (see ID Generation Rules below) |
| `## N. Title` | `title` | Title text only, without the number prefix |
| `**Context**:` body | `context` | Multi-line block scalar (`\|`) |
| `**Work needed**:` / `**What to build**:` / `**Test plan**:` body | `work_needed` | Fold in sub-sections (**Scripts to review**, **Integration points**, **Process for a roadmap session**, etc.) |
| `**What could fail**:` / `**What to check**:` body | `risks` | Multi-line block scalar (`\|`) |
| `**References**:` list items | `references` | Extract file paths only; strip prose annotations |
| (constant) | `source_work_unit` | `"harness-v2-status-eval"` for all entries |
| (constant) | `source_type` | `"manual"` for all entries |
| (constant) | `created_at` | `"2026-04-02T00:00:00Z"` |
| (constant) | `updated_at` | `"2026-04-02T00:00:00Z"` |

### Section header variants

The TODOS.md entries do not use consistent section headers. The parser must recognize these variants:

| Canonical field | Headers found in TODOS.md |
|-----------------|--------------------------|
| `work_needed` | `**Work needed**:`, `**What to build**:`, `**Test plan**:`, `**What to check**:` (TODO 1 uses "Scripts to review" + "What to check" instead of "Work needed") |
| `risks` | `**What could fail**:`, `**What to check**:` (TODO 1 "What to check" is more risk-like than work) |
| `context` | `**Context**:` (consistent across all entries) |
| `references` | `**References**:` (consistent across all entries) |

**Decision for ambiguous headers**: When a section like "What to check" could be either `work_needed` or `risks`, treat it as `risks` if the entry also has a distinct work section (Scripts to review, Test plan, etc.), otherwise fold it into `work_needed`.

## ID Generation Rules

### Algorithm

1. Take the title text (e.g., "End-to-End Test with a Real Task")
2. Lowercase all characters
3. Replace spaces and non-alphanumeric characters with hyphens
4. Collapse consecutive hyphens into one
5. Strip leading/trailing hyphens
6. Validate against the schema pattern: `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`

### Expected ID mapping

| # | Title | Generated ID |
|---|-------|-------------|
| 1 | Review Implementation | **EXCLUDED** (completed) |
| 2 | End-to-End Test with a Real Task | `end-to-end-test-with-a-real-task` |
| 3 | Research Mode End-to-End Test | `research-mode-end-to-end-test` |
| 4 | Specialist Template Rewrite | `specialist-template-rewrite` |
| 5 | Auto-Advance Enforcement | `auto-advance-enforcement` |
| 6 | Formalize TODOS.md as a Harness Workflow | `formalize-todos-as-a-harness-workflow` |
| 7 | Roadmap Process from TODOS | `roadmap-process-from-todos` |
| 8 | Parallel Workflow Support | `parallel-workflow-support` |
| 9 | Triage-TODOs Harness Skill | `triage-todos-harness-skill` |
| 10 | Summary.md Agent-Written Sections Not Populated at Step Boundaries | `summary-agent-written-sections-not-populated-at-step-boundaries` |

Note: TODO 6 title contains "TODOS.md" -- the `.md` extension is stripped during slug generation (periods become hyphens, then collapsed). The resulting slug drops "md" as a standalone segment if it becomes one, but since `formalize-todos-md-as-a-harness-workflow` is also a valid slug, either form is acceptable. **Preferred**: drop the file extension from the slug for readability (`formalize-todos-as-a-harness-workflow`).

## Special Cases

### TODO 1 — Completed, exclude from migration

TODO 1 ("Review Implementation") was completed in the `review-impl-scripts` work unit (commit `7808ec2`). Per the task description: **exclude completed TODOs from migration**. The ROADMAP.md already marks T1 as "DONE" in Phase 0.

### Sub-sections fold into `work_needed`

Several entries have sub-sections that are not top-level fields:

| Entry | Sub-section | Action |
|-------|-------------|--------|
| TODO 1 | **Scripts to review**, **What to check** | N/A (excluded) |
| TODO 5 | **Open question**, **Examples of unenforced criteria**, **Decision needed** | Fold all into `work_needed` as prose |
| TODO 6 | **Integration points** | Fold into `work_needed` |
| TODO 7 | **Process for a roadmap session**, **Design considerations** | Fold into `work_needed` |
| TODO 8 | **What's blocking today**, **Design considerations** | "What's blocking today" becomes `context` supplement; "Design considerations" folds into `work_needed` |
| TODO 9 | **Design considerations**, **Integration points** | Fold both into `work_needed` |

### Cross-references between TODOs

Some entries reference other TODOs by number. These must be converted to slug-based ID references:

| Source | Reference | Converted |
|--------|-----------|-----------|
| TODO 9 | "TODO 7 (Roadmap Process)" | `roadmap-process-from-todos` |
| TODO 7 | references TODOS.md generally | No specific TODO cross-ref needed |
| TODO 8 | "Deferred items table (this file, item 'Concurrent work streams')" | Reference to the deferred items table is informational; retain as prose in `work_needed` |
| ROADMAP.md | References T1-T9 by number | Not migrated (ROADMAP.md uses its own notation) |

### "Additional Deferred Items" section (between TODO 5 and TODO 6)

The section titled "Additional Deferred Items (from evaluation)" is a table, not a numbered TODO. It should **not** become a `todos.yaml` entry. It is informational context already captured in the ROADMAP.md "Deferred" section. Skip it entirely.

### TODO 10 — Late addition

TODO 10 ("Summary.md Agent-Written Sections Not Populated at Step Boundaries") was added during the `todos-workflow` work unit, not the original `harness-v2-status-eval` session. Override its metadata:

- `source_work_unit`: `"todos-workflow"` (not `harness-v2-status-eval`)
- `created_at`: `"2026-04-02T00:00:00Z"` (same date, added same day)

## Validation

### Pre-write validation (mental model check)

Before writing `todos.yaml`:
- Confirm 9 entries (TODOs 2-10, excluding TODO 1)
- Confirm all IDs are unique
- Confirm all IDs match `^[a-z][a-z0-9]*(-[a-z0-9]+)*$`
- Confirm all required fields present (`id`, `title`, `context`, `work_needed`, `created_at`, `updated_at`)

### Post-write validation

```sh
# Schema + cross-field validation
scripts/validate-todos.sh todos.yaml

# Verify entry count
test "$(yq 'length' todos.yaml)" -eq 9

# Verify no duplicate IDs
test "$(yq '.[].id' todos.yaml | sort | uniq -d | wc -l)" -eq 0

# Verify all required fields present on every entry
yq -e '.[].id' todos.yaml > /dev/null
yq -e '.[].title' todos.yaml > /dev/null
yq -e '.[].context' todos.yaml > /dev/null
yq -e '.[].work_needed' todos.yaml > /dev/null
yq -e '.[].created_at' todos.yaml > /dev/null
yq -e '.[].updated_at' todos.yaml > /dev/null
```

### TODOS.md removal verification

After validation passes:
```sh
# Confirm todos.yaml exists and is valid
scripts/validate-todos.sh todos.yaml && rm TODOS.md
```

## Acceptance Criteria

From `definition.yaml`:

1. **Current TODOS.md content migrated to todos.yaml format** -- all 9 non-completed TODO entries (2-10) are present as YAML objects with correct field mapping.
2. **Each entry has a stable slug id** -- IDs are kebab-case, deterministically derived from titles, unique across all entries, and match the schema pattern.
3. **Validates against the new schema** -- `scripts/validate-todos.sh todos.yaml` exits 0 with no errors.
4. **TODOS.md replaced or removed** -- `TODOS.md` no longer exists at the project root; `todos.yaml` is the single source of truth.

## Edge Cases

### Multiline content preservation

`context`, `work_needed`, and `risks` fields contain multi-paragraph prose with bullet lists, code blocks, and tables. Use YAML block scalars (`|`) to preserve formatting. Verify that:
- Bullet lists render correctly when the YAML is read back
- Indented code blocks (from markdown fenced blocks) are preserved
- Tables (from TODO 5 "Examples of unenforced criteria" and the deferred items table) are preserved as plain text

### References with annotations

TODOS.md references include prose annotations after file paths:
```
- `scripts/run-eval.sh` (370 lines) — most complex, Phase A/B evaluation logic
```
Extract only the file path (`scripts/run-eval.sh`). Strip the line count, dash, and description. If a reference line has no backtick-delimited path, extract the first path-like string (contains `/` or starts with `.`).

### References to non-existent paths

Some references may point to files that only exist on other branches or were removed. Include them as-is -- the `references` field is informational, not validated for file existence.

### Empty `risks` field

If a TODO entry has no "What could fail" section (e.g., TODO 4 "Specialist Template Rewrite" has no explicit risks section), omit the `risks` field entirely rather than setting it to an empty string. The schema marks `risks` as optional.

### Long IDs

TODO 10 produces a long slug (`summary-agent-written-sections-not-populated-at-step-boundaries`). This is acceptable -- the schema has no `maxLength` constraint on `id`. The slug is still human-readable and matches the pattern.

### ROADMAP.md consistency

After removing `TODOS.md`, verify that `ROADMAP.md` does not contain instructions directing users to read `TODOS.md` as a live document. The header "Generated from `TODOS.md` on 2026-04-02" is historical and acceptable, but any language like "see TODOS.md for current items" should be updated to reference `todos.yaml`.
