# Spec: worktree-summary

## Interface Contract

**Files modified**: bin/rws, bin/frw.d/lib/common.sh
**New artifact**: .furrow/rows/{name}/worktree-summary.md
**Consumers**: Main session agent after worktree reintegration

**Commands added to bin/rws**:
- `rws update-worktree-summary [name] <section>` — reads stdin, replaces
  section in worktree-summary.md via shared awk function, updates state timestamp
  - Sections: files-changed, decisions, open-items, test-results
  - Exit codes: 0 success, 1 usage/TTY, 2 row not found
- `rws regenerate-worktree-summary [name]` — generates skeleton with
  4 empty sections, preserves existing content if present
  - Exit codes: 0 success, 2 row not found
- `rws validate-worktree-summary [name]` — checks all 4 sections present
  with >=1 non-empty line each
  - Exit codes: 0 valid, 1 invalid (lists missing/empty sections), 2 row not found

**Shared function added to common.sh**:
- `replace_md_section <file> <section_display_name> <new_content>` — awk
  state-machine replacing content between `^## Target` and next `^## `
- Existing update-summary refactored to call this function

## Acceptance Criteria (Refined)

1. `rws update-worktree-summary` accepts 4 kebab-case sections
   (files-changed, decisions, open-items, test-results) and writes
   to .furrow/rows/{name}/worktree-summary.md via stdin
2. `replace_md_section` function exists in common.sh and is used by
   both update-summary and update-worktree-summary
3. Existing update-summary behavior is unchanged after refactoring
   to use the shared function
4. `rws regenerate-worktree-summary` produces a skeleton with all 4
   section headers and preserves existing agent-written content
5. `rws validate-worktree-summary` returns exit 1 with error listing
   when any section is missing or empty

## Test Scenarios

### Scenario: Round-trip write and validate
- **Verifies**: AC 1, AC 5
- **WHEN**: `echo "changed file.md" | rws update-worktree-summary test-row files-changed`
  for all 4 sections, then `rws validate-worktree-summary test-row`
- **THEN**: Validate returns exit 0; worktree-summary.md contains all 4 sections with content
- **Verification**: `rws validate-worktree-summary test-row; echo $?` → 0

### Scenario: Shared function preserves update-summary
- **Verifies**: AC 2, AC 3
- **WHEN**: Run `rws update-summary` with each existing section (key-findings,
  open-questions, recommendations) after the refactor
- **THEN**: summary.md output is identical to pre-refactor behavior
- **Verification**: Diff summary.md before/after refactor with same inputs

### Scenario: Validation catches empty sections
- **Verifies**: AC 5
- **WHEN**: `rws regenerate-worktree-summary test-row` (creates skeleton
  with empty sections), then `rws validate-worktree-summary test-row`
- **THEN**: Exit code 1, stderr lists all 4 sections as empty
- **Verification**: `rws validate-worktree-summary test-row 2>&1; echo $?` → 1

## Implementation Notes

- Follow update-summary pattern exactly: case statement for section validation,
  stdin check (reject TTY), atomic write (temp + mv)
- Awk state-machine: match `^## SectionName`, print header, printf new content,
  skip old content until next `^## `
- Shared function signature: `replace_md_section <file> <display_name> <content_string>`
  (content passed as argument, not stdin, since the caller already read stdin)
- Refactoring update-summary must be tested before building worktree variant

## Dependencies

- bin/frw.d/lib/common.sh (shared function target)
- Existing update-summary implementation in bin/rws (pattern source + refactor target)
- orchestration-instructions deliverable (wave 1 must complete first)
