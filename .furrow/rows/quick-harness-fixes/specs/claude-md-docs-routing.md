# Spec: claude-md-docs-routing

## Interface Contract

### `.claude/CLAUDE.md` (updated)

**Add a "Topic Routing" section** mapping sub-systems to their documentation files. The routing table helps agents find the right reference without ad-hoc exploration.

**Current CLAUDE.md:** 74 lines (budget: ≤100 lines).
**Strategy:** Add ~20-line routing section. May need to trim the duplicate Furrow command table (lines 51-74 are a `<!-- furrow:start -->` block that duplicates the earlier content). Removing the duplicate frees ~24 lines.

**Routing categories:**
| Category | Files |
|----------|-------|
| Row structure | `references/row-layout.md`, `references/definition-shape.md` |
| Gates & evals | `references/gate-protocol.md`, `references/eval-dimensions.md`, `evals/` |
| Review process | `references/review-methodology.md` |
| Specialists | `references/specialist-template.md`, `specialists/*.md` |
| CLI tools | `bin/frw` (harness), `bin/rws` (rows), `bin/alm` (almanac), `bin/sds` (seeds) |
| Architecture | `docs/architecture/`, `docs/skill-injection-order.md` |
| Research | `references/research-mode.md`, `docs/research/` |
| Knowledge base | `.furrow/almanac/` (rationale, roadmap, todos) |

## Acceptance Criteria (Refined)

- `.claude/CLAUDE.md` has a "Topic Routing" section with ≥6 category→file mappings
- Total `.claude/CLAUDE.md` line count ≤100 lines
- No content duplication between routing table and existing sections
- The `<!-- furrow:start -->` duplicate block is removed or consolidated
- Routing table covers: row structure, gates/evals, review, specialists, CLIs, architecture

## Implementation Notes

- The `<!-- furrow:start -->` / `<!-- furrow:end -->` block (lines 51-74) is managed by `install.sh` — it's the Furrow command reference injected during installation. Removing it means either: (a) updating install.sh to not inject it, or (b) keeping it but trimming the earlier manual duplicate. Check which section is the "real" one.
- If both command tables must stay, the routing table needs to be very compact (~12 lines).
- Format as a simple markdown table for scannability.

## Dependencies

- None — independent of other deliverables.
