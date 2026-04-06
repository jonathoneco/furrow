# Spec: cli-mediated-interaction

## Interface Contract

### `rws update-summary [name] <section> [--replace]`

**Arguments:**
- `name` (optional): Row name. Falls back to focused row via `resolve_name`.
- `section` (required): One of `key-findings`, `open-questions`, `recommendations` (kebab-case).
- `--replace` (optional flag): Overwrite section entirely. Default: append to existing content.

**stdin:** Content to write (one or more lines). Required — exits with usage error if stdin is empty/TTY.

**stdout:** `"Updated <Section Name> in summary.md"` on success.

**stderr:** Error messages on failure.

**Exit codes:**
- 0: Success
- 1: Usage/argument error (bad section name, missing stdin, etc.)
- 2: State file not found
- 3: Validation failed (section empty after update)

**Contract guarantees:**
- Atomic write: writes to temp file, then `mv` to summary.md
- Validates ≥1 non-empty line in updated section after write
- Preserves all other sections unchanged (uses awk extraction pattern from `regenerate_summary`, lines 923-937 of `bin/rws`)
- Section name mapping: `key-findings` → `Key Findings`, `open-questions` → `Open Questions`, `recommendations` → `Recommendations`

**Callers:** Agents via Bash tool, step skills, summary-protocol guidance.

### `.claude/rules/cli-mediation.md`

**Format:** Markdown rule file (~30 lines). Survives context compaction.

**Content sections:**
1. What is CLI-mediated (table: operation → command)
2. What is forbidden (direct Edit/Write of state.json, summary.md)
3. Why (atomicity, validation, audit trail)
4. Escape hatch (if no CLI command exists, suggest adding one)

**Also:** Fix broken `.claude/rules/workflow-detect.md` symlink (remove it or create actual file).

## Acceptance Criteria (Refined)

- `rws update-summary quick-harness-fixes key-findings` reads from stdin and appends content to Key Findings section of summary.md
- `rws update-summary quick-harness-fixes open-questions --replace` replaces Open Questions section content entirely
- `rws update-summary` with no stdin exits with code 1 and usage message
- `rws update-summary` with invalid section name exits with code 1
- `rws update-summary` with nonexistent row exits with code 2
- After update, section has ≥1 non-empty line (validated; exits code 3 if not)
- All other summary.md sections preserved unchanged after update
- `.claude/rules/cli-mediation.md` exists with operation→command mapping
- `.claude/rules/workflow-detect.md` broken symlink removed or fixed
- `rws help` output includes `update-summary` command with usage line

## Implementation Notes

- Follow `rws_validate_summary` pattern (lines 2012-2043): wrapper calls resolve_name, require_state, delegates to helper
- Awk extraction pattern from lines 923-937: `/^## SectionName/{found=1; next} /^## /{if(found) exit} found{print}`
- Atomic write: extract full summary.md, replace target section, write to `.tmp`, `mv` to summary.md
- Section name normalization: `key-findings` → `Key Findings` via case statement
- Register in help text and dispatch case statement (lines 2104-2121)
- stdin detection: `[ -t 0 ]` to check if stdin is a TTY (reject interactive use)

## Dependencies

- `bin/rws` existing infrastructure: `resolve_name`, `require_state`, `resolve_row_dir`
- `jq` for state.json reads
- `awk` for section extraction
- No external dependencies beyond what rws already uses
