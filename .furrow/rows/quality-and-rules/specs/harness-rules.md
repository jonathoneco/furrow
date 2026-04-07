# Spec: harness-rules

## Interface Contract

Create/modify these files:

**`.claude/rules/step-sequence.md`** (new, ~12 lines)
- Documents the 7-step sequence and gate enforcement
- No `paths` frontmatter (loads unconditionally)

**`.claude/rules/cli-mediation.md`** (expand, +8 lines)
- Append correction limit documentation section
- Document: default limit (3), implement-step-only enforcement, file ownership scoping

**`.claude/CLAUDE.md`** (shrink, -23 lines)
- Move Furrow command reference table to `references/furrow-commands.md`
- Keep the "Run `/furrow:doctor` to check health" line

**`references/furrow-commands.md`** (new)
- Contains the command reference table moved from CLAUDE.md

**`install.sh`** (verify)
- Confirm new rules are symlinked correctly by existing rules management logic

## Acceptance Criteria (Refined)

1. `.claude/rules/step-sequence.md` exists, documents the 7-step sequence (ideate→research→plan→spec→decompose→implement→review)
2. `step-sequence.md` documents: no skipping, prechecked auto-advance, gate enforcement
3. `step-sequence.md` has no `paths` frontmatter (loads unconditionally in all contexts)
4. `.claude/rules/cli-mediation.md` includes correction limit section documenting: default 3, implement-step-only, file ownership scoping, escalation path
5. CLAUDE.md Furrow command table moved to `references/furrow-commands.md`
6. Total ambient context (CLAUDE.md + all rules/) stays <=120 lines
7. `install.sh` rules symlink logic handles new rule files without modification
8. All rules follow the pattern: invariant statement, enforcement mechanism, consequence of violation

## Test Scenarios

### Scenario: step-sequence rule loads unconditionally
- **Verifies**: AC 3
- **WHEN**: New Claude Code session starts in a Furrow-installed project
- **THEN**: step-sequence.md content appears in ambient context
- **Verification**: File has no `---` frontmatter block with `paths:` field

### Scenario: ambient budget compliance
- **Verifies**: AC 6
- **WHEN**: All rules and CLAUDE.md are present
- **THEN**: Combined line count <= 120
- **Verification**: `wc -l .claude/CLAUDE.md .claude/rules/*.md | tail -1` shows total <= 120

### Scenario: install.sh handles new rules
- **Verifies**: AC 7
- **WHEN**: `install.sh` runs against a target project
- **THEN**: step-sequence.md is symlinked to target .claude/rules/
- **Verification**: `ls -la target/.claude/rules/step-sequence.md` shows symlink

## Implementation Notes

- step-sequence.md pattern: follow cli-mediation.md structure (invariant → enforcement → forbidden actions → rationale)
- Correction limit section in cli-mediation.md: 3-4 line description + behavior + override path
- CLAUDE.md budget math: 76 current - 23 (command table) + 0 (keep doctor line) = ~53 lines
- Rules: 31 (cli-mediation + 8 expansion) + 12 (step-sequence) = ~51 lines
- Total: ~104 lines (16 under budget)
- install.sh already globs `.claude/rules/*.md` — no code change needed, just verify

## Dependencies

- `references/furrow-commands.md` must be created before CLAUDE.md can be trimmed
- `install.sh` must be verified (not modified) after new rules are in place
