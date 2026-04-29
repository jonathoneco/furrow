# /work-todos [--extract [name]] [--new]

Manage TODO entries in `.furrow/almanac/todos.yaml`. Two modes: extract candidates from row artifacts, or create a new TODO interactively.

## Syntax

```
/work-todos              → Extract mode (active task)
/work-todos --extract    → Extract mode (active task)
/work-todos --extract N  → Extract mode (named row)
/work-todos --new        → New mode (interactive creation)
```

Flags are mutually exclusive. Error if both provided.

---

## Extract Mode

### 1. Resolve Row

- If `name` provided: verify `.furrow/rows/{name}/` exists. Error if not.
- If no `name`: run `furrow row status`. Error if no active task.

### 2. Run Extraction

```sh
alm extract "{name}"
```

This is a temporary compatibility holdout; no Go-backed TODO extraction command
is canonical yet. `furrow almanac validate` remains the canonical validation
surface. Outputs JSON array of candidates with `source`, `title`,
`context`, `raw_content`, `source_file`.

If empty array: "No TODO candidates found in {name}." — exit.

### 3. Load Existing Entries

Read `.furrow/almanac/todos.yaml`. If absent, treat as empty array `[]`.

### 4. Dedup Reasoning

For each candidate, compare against existing entries using these rules:

**Match criteria** — an existing entry is a potential match if any hold:
1. Title describes the same concern (even with different wording)
2. Context describes the same root cause, component, or desired outcome
3. References overlap and describe the same concern about those files

**Action assignment** given a match:
- **SKIP**: Candidate is entirely subsumed — same concern, context, no new info
- **MERGE**: Candidate adds new information to existing concern — additional context, references, different angle
- **ADD**: Related but distinct concern — same component different problem, or same problem different component

**No match found** → ADD.

**Bias when uncertain**: ADD > MERGE > SKIP. Better to have a slightly redundant entry than lose information.

### 5. Present Batch

```
Found {N} TODO candidates from {name}:

[1/{N}] "{title}"
  Source: {source} ({source_file})
  Proposed: ADD as new TODO

[2/{N}] "{title}"
  Source: {source} ({source_file})
  Proposed: MERGE with existing "{id}" — adds context about {what}

[3/{N}] "{title}"
  Source: {source} ({source_file})
  Proposed: SKIP — covered by existing "{id}"
```

Prompt: "Review the proposals. Adjust any action (e.g., '2: add', '3: merge with foo-bar'), or 'ok' to proceed, 'cancel' to abort."

### 6. User Confirmation

- `ok` / `confirm`: accept all proposals
- `{number}: {action}`: override specific item
- `cancel`: abort, no writes

Re-display changed proposals before writing.

### 7. Write Changes

**ADD**:
- Generate slug `id` from title: lowercase → non-alphanum to hyphens → collapse → trim → max 60 chars. If collision, append `-2`, `-3`, etc.
- Refine `context` and `work_needed` from raw candidate into clear prose (don't copy `raw_content` verbatim)
- Set `source_work_unit` to row name
- Map candidate `source` to `source_type` enum: `summary-open-questions` → `open-question`, `learnings-pitfall` → `unpromoted-learning`, `review-finding` → `review-finding`
- Set `created_at` and `updated_at` to current ISO 8601

**MERGE**:
- Extend target entry's `context` with new information (add paragraph or bullet)
- Update `work_needed` if candidate suggests additional steps
- Add `source_file` to `references` if not present
- Bump `updated_at`
- Do not change `id`, `title`, `source_work_unit`, `source_type`, `created_at`

**SKIP**: No action.

### 8. Validate

Run `furrow almanac validate`. If fails, report error, do not commit, ask user to review.

### 9. Commit

Stage and commit:

```sh
git add .furrow/almanac/todos.yaml
git commit -m "chore: extract TODOs from {name} into .furrow/almanac/todos.yaml"
```

Where `{name}` is the source row name.

### 10. Report

```
Updated .furrow/almanac/todos.yaml:
  Added: {count} new entries ({ids})
  Merged: {count} entries ({ids})
  Skipped: {count} candidates
```

---

## New Mode

### 1. Prompt

Ask: "Describe the TODO idea. It can be vague — we'll refine it together."

### 2. Refine

Ask targeted clarifying questions to populate fields. Skip questions whose answers are apparent from the description. Propose answers the agent can infer — user confirms or corrects.

Fields to populate: title, context, work_needed, risks, references.

### 3. Check Overlap

Read `.furrow/almanac/todos.yaml`. If semantic overlap found:

```
This seems related to existing TODO "{id}":
  Title: {title}
  Context: {snippet}

Options:
  1. Create as new TODO (distinct concern)
  2. Merge into "{id}"
  3. Cancel (already covered)
```

### 4. Write

- Generate slug `id` from title (same rules as extract mode)
- Set `source_type: "manual"`
- Set `source_work_unit` to active row name if one exists, otherwise omit
- If user chose merge: apply merge rules instead

### 5. Validate

Run `furrow almanac validate`.

### 6. Commit

Stage and commit:

```sh
git add .furrow/almanac/todos.yaml
git commit -m "chore: add TODO {id} to .furrow/almanac/todos.yaml"
```

Where `{id}` is the generated TODO slug.

### 7. Report

```
Added TODO "{id}" to .furrow/almanac/todos.yaml.
  Title: {title}
  Source: manual
```
