# Spec: work-todos-command

## Component

`commands/work-todos.md` — a standalone harness command that manages TODO entries in `todos.yaml`. Two modes: **extract** (harvest candidates from a work unit's artifacts and dedup against existing entries) and **new** (interactively refine a user-provided idea into a well-formed TODO entry).

## Files

| File | Action | Purpose |
|------|--------|---------|
| `commands/work-todos.md` | Create | Command definition (the deliverable) |

### Dependencies (must exist before this deliverable)

| File | Deliverable | Purpose |
|------|-------------|---------|
| `adapters/shared/schemas/todos.schema.yaml` | todos-yaml-schema | Schema for validation |
| `scripts/validate-todos.sh` | todos-yaml-schema | Post-write validation |
| `scripts/extract-todo-candidates.sh` | extract-candidates-script | Candidate extraction |
| `todos.yaml` | migrate-existing-todos | Existing entries for dedup |

### Runtime dependencies (used by the command)

| File | Purpose |
|------|---------|
| `commands/lib/detect-context.sh` | Active task detection |
| `todos.yaml` | Read existing entries, write new/updated entries |

## Command Syntax

```
/work-todos [--extract [name]] [--new]
```

| Invocation | Mode | Behavior |
|------------|------|----------|
| `/work-todos` | Extract (default) | Extract from active task |
| `/work-todos --extract` | Extract | Extract from active task |
| `/work-todos --extract my-task` | Extract | Extract from named work unit |
| `/work-todos --new` | New | Interactive creation |

Flags are mutually exclusive. If both provided, error: "Specify either --extract or --new, not both."

## Extract Mode Flow

### 1. Resolve Work Unit

- If `name` argument provided: use `.work/{name}/`. Verify directory exists; error if not: "Work unit '{name}' not found."
- If no `name`: run `commands/lib/detect-context.sh`. If zero active tasks: error "No active task. Specify a work unit name: /work-todos --extract <name>". If multiple active: list them and ask user to specify.

### 2. Run Extraction Script

```sh
scripts/extract-todo-candidates.sh "{name}"
```

Receives a JSON array on stdout:

```json
[
  {
    "source": "summary-open-questions",
    "title": "Short description from source",
    "context": "Surrounding context or the full question",
    "raw_content": "Original text verbatim",
    "source_file": ".work/{name}/summary.md"
  }
]
```

Source types: `summary-open-questions`, `learnings-pitfall`, `review-finding`.

If the array is empty, inform user: "No TODO candidates found in {name}." and exit.

### 3. Load Existing Entries

Read `todos.yaml` at project root. If the file does not exist, treat as an empty array. Parse into a list of existing TODO entries with their `id`, `title`, `context`, `work_needed`, and `source_work_unit` fields available for comparison.

### 4. Dedup Reasoning (per candidate)

For each candidate, the agent reasons about semantic overlap with existing entries. The agent applies the dedup reasoning rules (see section below) and assigns one of three proposed actions:

- **ADD**: No semantic overlap found. This is a genuinely new concern.
- **MERGE**: Overlaps with an existing entry but adds new information (different angle, additional context, new references). Identify the target entry by `id`.
- **SKIP**: Already fully covered by an existing entry. Identify the covering entry by `id`.

### 5. Present Batch

Display all candidates as a numbered batch with proposed actions:

```
Found {N} TODO candidates from {name}:

[1/{N}] "{title}"
  Source: {source} ({source_file})
  Proposed: ADD as new TODO

[2/{N}] "{title}"
  Source: {source} ({source_file})
  Proposed: MERGE with existing "{existing_id}" — adds context about {what_is_new}

[3/{N}] "{title}"
  Source: {source} ({source_file})
  Proposed: SKIP — covered by existing "{existing_id}"
```

After the list, prompt: "Review the proposals above. You can adjust any action (e.g., '2: change to ADD', '3: change to MERGE with foo-bar'). Confirm with 'ok' to proceed."

### 6. User Confirmation

User can:
- Type `ok` or `confirm` to accept all proposals as-is.
- Override specific items: `{number}: {action}` (e.g., `2: skip`, `3: add`, `1: merge with existing-id`).
- Type `cancel` to abort without writing.

Agent re-displays any changed proposals for confirmation before writing.

### 7. Write Changes

For each confirmed action:

**ADD**:
- Generate `id` as a slug from the title (lowercase, hyphens, max 60 chars, no trailing hyphens). If the slug collides with an existing `id`, append `-2` (or `-3`, etc.).
- Populate entry:
  ```yaml
  - id: generated-slug
    title: "{title}"
    context: "{agent-refined context from candidate}"
    work_needed: "{agent-inferred concrete steps}"
    risks: "{agent-inferred risks, or 'TBD' if unclear}"
    references:
      - "{source_file}"
    source_work_unit: "{name}"
    source_type: "{source}"
    created_at: "{ISO 8601 now}"
    updated_at: "{ISO 8601 now}"
  ```
- The agent should refine `context` and `work_needed` from the raw candidate into clear prose — not just copy `raw_content` verbatim.

**MERGE**:
- Locate the target entry by `id` in `todos.yaml`.
- Append new information to `context` (add a paragraph or bullet noting the additional finding).
- Update `work_needed` if the candidate suggests additional steps.
- Add `source_file` to `references` if not already present.
- Set `updated_at` to current ISO 8601 timestamp.
- Do not change `id`, `title`, `source_work_unit`, `source_type`, or `created_at`.

**SKIP**: No write action.

### 8. Validate

Run `scripts/validate-todos.sh` after writing. If validation fails, report the error and do not commit — ask user to review.

### 9. Report

```
Updated todos.yaml:
  Added: {count} new entries ({list of ids})
  Merged: {count} entries ({list of ids})
  Skipped: {count} candidates

Run `scripts/validate-todos.sh` to re-verify.
```

## New Mode Flow

### 1. Prompt for Idea

Ask: "Describe the TODO idea. It can be vague — we'll refine it together."

User provides free-form description.

### 2. Interactive Refinement

The agent asks targeted clarifying questions to populate the TODO fields. The agent should ask only the questions whose answers are not already apparent from the user's description. Questions to consider:

- **Title**: "Can you summarize this in one sentence?" (Skip if the description is already concise.)
- **Context**: "Why does this matter? What breaks or degrades without it?" (Skip if the description explains motivation.)
- **Work needed**: "What concrete steps would address this?" (Skip if the description is already actionable.)
- **Risks**: "What could go wrong or make this harder than expected?"
- **References**: "Are there specific files, scripts, or docs related to this?"

The agent should propose answers for any fields it can infer and ask the user to confirm or correct, rather than asking the user to write everything from scratch.

### 3. Check for Overlap

Read `todos.yaml` and check for semantic overlap using the dedup reasoning rules.

If overlap found, present the existing entry and ask:
```
This seems related to existing TODO "{existing_id}":
  Title: {existing_title}
  Context: {existing_context snippet}

Options:
  1. Create as new TODO (distinct concern)
  2. Merge into "{existing_id}" (adds your new context)
  3. Cancel (already covered)
```

### 4. Write Entry

Write the entry to `todos.yaml`:
- Generate slug `id` from title (same rules as extract mode).
- Set `source_type: "manual"`.
- Set `source_work_unit` to active task name if one exists, otherwise omit.
- Set `created_at` and `updated_at` to current ISO 8601 timestamp.

If user chose merge in step 3, apply merge rules from extract mode instead.

### 5. Validate

Run `scripts/validate-todos.sh`. Report result.

### 6. Report

```
Added TODO "{id}" to todos.yaml.
  Title: {title}
  Source: manual
```

## Dedup Reasoning Rules

The agent applies these rules when comparing a candidate against existing `todos.yaml` entries. The comparison is semantic, not string-matching.

### Match Criteria

An existing entry is a **potential match** if any of the following hold:

1. **Title similarity**: The candidate title and existing title describe the same concern, even with different wording (e.g., "Fix summary validation hook" matches "Summary sections not populated at step boundaries").
2. **Context overlap**: The candidate's context describes the same root cause, affected component, or desired outcome as an existing entry's `context` or `work_needed`.
3. **Reference overlap**: The candidate and existing entry reference the same files and describe the same concern about those files.

### Action Assignment

Given a potential match:

- **SKIP** if the candidate's information is entirely subsumed by the existing entry — same concern, same context, no new references or angles.
- **MERGE** if the candidate adds new information to an existing concern — additional context from a different source, new references, a different angle on the same problem, or more specific work steps.
- **ADD** if the candidate describes a related but distinct concern — e.g., the same component but a different problem, or the same problem in a different component.

When no potential match is found, assign **ADD**.

### Ties and Ambiguity

- When the agent is uncertain between MERGE and ADD, prefer ADD. It is better to have a slightly redundant entry than to lose information by merging unrelated concerns.
- When the agent is uncertain between MERGE and SKIP, prefer MERGE. It is better to add a note than to silently discard a finding.
- Always explain the reasoning in the proposal line (the "— adds context about {what}" or "— covered by existing {id}" suffix).

## Output Format

### todos.yaml Entry Schema

Each entry in `todos.yaml` is a YAML list item conforming to `adapters/shared/schemas/todos.schema.yaml`:

```yaml
- id: slug-style-identifier
  title: "Short description"
  context: "Why this matters — multi-line prose ok"
  work_needed: "Concrete steps to address this"
  risks: "What could go wrong"
  references:
    - path/to/relevant/file
    - .work/unit-name/artifact.md
  source_work_unit: unit-name        # optional
  source_type: summary-open-questions # or learnings-pitfall, review-finding, manual
  created_at: "2026-04-02T19:00:00Z"
  updated_at: "2026-04-02T19:00:00Z"
```

### Slug ID Generation

1. Lowercase the title.
2. Replace non-alphanumeric characters with hyphens.
3. Collapse consecutive hyphens.
4. Trim leading/trailing hyphens.
5. Truncate to 60 characters (at a word boundary if possible).
6. If the slug collides with an existing `id`, append `-2` (incrementing as needed).

## Acceptance Criteria

1. `commands/work-todos.md` defines a standalone command with two modes: extract and new.
2. Extract mode runs `scripts/extract-todo-candidates.sh`, agent reasons about dedup against existing `todos.yaml`, presents candidates with proposed action (add/merge/skip).
3. New mode (`--new`): interactive refinement where agent works with user to clarify an abstract idea into a well-formed TODO entry.
4. Both modes write to `todos.yaml` at project root.
5. Dedup reasoning rules are explicit: title similarity, context overlap, reference overlap, with bias toward ADD over MERGE over SKIP when uncertain.
6. User has full control: can override any proposed action before write.
7. Post-write validation via `scripts/validate-todos.sh`.
8. Merge operations preserve existing entry identity (`id`, `created_at`, `source_work_unit`, `source_type`) and only extend content fields.
9. Slug IDs are deterministic from title and handle collisions.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| `todos.yaml` does not exist | Create it as an empty list, then proceed normally. After writing, the file will contain only the new entries. |
| `todos.yaml` exists but is empty | Treat as empty list. All candidates become ADD proposals. |
| Extraction script returns empty array | Inform user: "No TODO candidates found in {name}." Exit cleanly. |
| Extraction script fails (non-zero exit) | Report error with stderr output. Do not proceed to dedup. |
| Named work unit does not exist | Error: "Work unit '{name}' not found." |
| No active task and no name given (extract mode) | Error: "No active task. Specify a work unit name: /work-todos --extract <name>" |
| All candidates are SKIP | Present the batch showing all SKIPs, confirm with user, write nothing. Report: "All candidates already covered by existing TODOs." |
| Slug collision | Append `-2`, `-3`, etc. until unique. |
| Validation fails after write | Report validation error. Do not commit. Ask user to review `todos.yaml` manually. |
| User cancels during confirmation | Abort without writing. Inform: "Cancelled. No changes made to todos.yaml." |
| `--new` mode with active task | Set `source_work_unit` to active task name automatically. |
| `--new` mode with no active task | Omit `source_work_unit` field from entry. |
| `--new` overlap detected, user picks merge | Apply merge rules: extend existing entry, do not create new. |
| Candidate has very long title | Slug truncation handles it; the full title is preserved in the `title` field. |
| Multiple candidates match the same existing entry | Each is independently assessed. Multiple MERGEs into the same entry are fine — they accumulate context. |
