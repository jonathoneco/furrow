# Research: Quick Harness Fixes

## R1: Open Surgery Patterns (D1/D2)

### Findings from conversation/git mining

**State.json** — guard hook (`state-guard.sh`) now blocks direct Write/Edit. Historical
commits show direct mutations for archiving, gate recording, vocabulary migrations.
These are now covered by `rws` commands. Guard is effective.

**Summary.md** — no guard exists. No CLI command for incremental updates. Agents are
forced into direct Edit/Write because `regenerate-summary` overwrites system sections
and `validate-summary` is read-only. The gap is clear: agents need a write path
through CLI.

**Most common surgery patterns:**
1. Appending bullet points to Key Findings, Open Questions, Recommendations
2. Replacing section content wholesale during step transitions
3. Reading summary.md to check what's been written (less problematic — read-only)

### Design for `rws update-summary`

**Interface:** `rws update-summary [name] <section> [--replace]`
- Content from stdin (pipe-friendly, avoids shell quoting issues)
- Sections: `key-findings`, `open-questions`, `recommendations` (kebab-case)
- Default: append to existing content
- `--replace`: overwrite section entirely
- Validates ≥1 non-empty line after update

**Implementation pattern:** Follow existing rws commands:
- Resolve name via `resolve_name`
- Require state via `require_state`
- Extract section with awk (lines 928-937 of rws)
- Write atomically via temp file
- Exit codes: 0 success, 1 usage, 2 state not found, 3 validation failed

## R2: Rule vs Hook Enforcement (D1/D2)

### Findings

**Rules** (`.claude/rules/*.md`): Markdown files, ~30-40 lines. Document policy in
human-readable form. Survive context compaction. Enforced by agent discipline.
Currently only `workflow-detect.md` exists in this project (broken symlink).

**Hooks** (`settings.json`): Mechanical enforcement via shell scripts. Don't survive
compaction (settings do, but hook context doesn't). Already have `state-guard.sh`
for state.json.

### Recommendation

**Both.** Use a rule file (`.claude/rules/cli-mediation.md`) as the primary policy
document — it survives compaction and documents *why*. Optionally add a summary-guard
hook similar to state-guard.sh for mechanical enforcement, but the rule is primary.

**Rule content pattern:**
- What is CLI-mediated (allowed operations with commands)
- What is forbidden (direct file edits)
- Why (atomicity, validation, audit trail)
- Escape hatch (suggest new CLI command if gap found)

## R3: Summary Protocol Reconciliation (D2)

### Inconsistency found

- `validate-summary.sh`: requires ≥1 non-empty line per agent-written section
- `summary-protocol.md`: says ≥2 bullets per section

**Resolution:** Align to ≥1 non-empty line (hook's standard). The 2-bullet guidance
is aspirational, not a hard requirement. Update summary-protocol.md to match.

## R4: CLAUDE.md Routing Table (D3)

### Sub-systems surveyed

| Category | Files | Purpose |
|----------|-------|---------|
| Fundamentals | `references/row-layout.md`, `references/definition-shape.md` | Row structure, definition schema |
| Procedures | `references/gate-protocol.md`, `references/review-methodology.md`, `references/eval-dimensions.md` | Gate rules, review process, scoring |
| Specialists | `specialists/*.md`, `references/specialist-template.md` | 15 domain specialists, template format |
| CLIs | `bin/frw`, `bin/rws`, `bin/alm`, `bin/sds` | Harness, row, almanac, seeds tools |
| Architecture | `docs/architecture/`, `docs/skill-injection-order.md` | Design patterns, context loading |
| Knowledge | `.furrow/almanac/*.yaml`, `docs/research/` | Todos, roadmap, rationale, research |
| Evals | `evals/gates/`, `evals/dimensions/` | Step gate configs, quality dimensions |

### Proposed routing section (~20 lines)

Fits within 100-line budget (current CLAUDE.md is 74 lines; need to trim or restructure
to accommodate). May need to consolidate existing sections.

## Open Questions Resolved

| Question | Answer |
|----------|--------|
| CLI interface for update-summary? | `rws update-summary [name] <section> [--replace]`, stdin for content |
| Rule vs hook? | Both — rule primary (survives compaction), hook optional |
| What surgery patterns? | summary.md section appends/replaces; state.json covered by guard |
| What sub-systems for routing? | 7 categories: fundamentals, procedures, specialists, CLIs, architecture, knowledge, evals |
