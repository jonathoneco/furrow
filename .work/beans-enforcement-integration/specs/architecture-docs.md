# Spec: architecture-docs

## Overview

Document the three-CLI architecture, hook disposition, abstraction principle, and migration path.

## File: docs/architecture/cli-architecture.md

### Sections

#### 1. Directory Structure
```
.furrow/                          # Harness root
  .focused                        # Active row pointer
  _meta.yaml                      # Project metadata
  seeds/                          # sds data store
    seeds.jsonl                   # Seed records (JSONL, merge=union)
    config                        # Project prefix
    .lock                         # flock concurrency lock
  rows/                           # rws data store
    {row-name}/                   # Per-row state
      state.json                  # Lifecycle state (Furrow-exclusive write)
      definition.yaml             # Work contract
      summary.md                  # Regenerated at boundaries
      learnings.jsonl             # Per-row learnings
      reviews/                    # Review artifacts
      gate-prompts/               # Evaluation prompts
      gate-verdicts/              # Evaluator decisions
  almanac/                        # alm data store
    todos.yaml                    # TODO registry
    roadmap.yaml                  # Structured roadmap (YAML)
    rationale.yaml                # Component rationale
    learnings/                    # (future) Promoted learnings
```

#### 2. Three-CLI Model

| CLI | Domain | Binary | Data |
|---|---|---|---|
| `sds` | Seed tracking | bin/sds | .furrow/seeds/ |
| `rws` | Row lifecycle | bin/rws | .furrow/rows/ |
| `alm` | Planning & knowledge | bin/alm | .furrow/almanac/ |

**Principle**: All harness enforcement and interaction goes through these CLIs. Claude Code commands are thin wrappers. Hooks either fold into CLIs (domain hooks) or call CLIs for functionality (policy hooks).

#### 3. Data Flow

```
User → Claude Code command → CLI → .furrow/ data → CLI → output

/furrow:work      → rws init / rws transition / rws load-step
/furrow:status    → rws status
/furrow:archive   → rws archive
/work-todos       → alm extract / alm add
/furrow:triage    → alm triage
/furrow:next      → alm next
```

#### 4. Seed Lifecycle

```
rws init ──→ sds create ──→ seed (open → claimed)
rws transition ──→ sds update ──→ seed (ideating → researching → ...)
rws archive ──→ sds close ──→ seed (closed)

Gate evaluation ──→ sds show ──→ verify seed-sync
  Phase A: seed exists, not closed (deterministic)
  Phase B: seed status matches row step (evaluator)
```

#### 5. Hook Disposition

**Domain hooks (folded into rws):**
- gate-check → rws transition validates gates internally
- summary-regen → rws regenerate-summary
- timestamp-update → automatic in rws state updates
- transition-guard → removed (guarded scripts deleted)

**Policy hooks (remain separate, call CLIs):**
- correction-limit.sh — enforces correction count limits
- ownership-warn.sh — warns on file_ownership violations
- stop-ideation.sh — enforces section-by-section interaction
- state-guard.sh — blocks direct state.json writes
- verdict-guard.sh — blocks direct verdict file writes
- validate-definition.sh — validates definition.yaml on write
- validate-summary.sh — validates summary structure (calls rws validate-summary)
- post-compact.sh — context recovery after message compaction
- row-check.sh — session-end row state verification

**Principle**: Domain hooks answer "how does a row work?" Policy hooks answer "how should agents behave?" Domain logic belongs in CLIs; behavioral policies stay in hooks.

#### 6. Extended Seed Statuses

| Status | Set by | When |
|---|---|---|
| open | sds create | Default on creation |
| claimed | rws init | Immediately after seed creation |
| ideating | rws transition | Enter ideate step |
| researching | rws transition | Enter research step |
| planning | rws transition | Enter plan step |
| speccing | rws transition | Enter spec step |
| decomposing | rws transition | Enter decompose step |
| implementing | rws transition | Enter implement step |
| reviewing | rws transition | Enter review step |
| closed | rws archive / sds close | Row archived or manual close |

## File: references/row-layout.md (updated)

Rewrite to document .furrow/ structure instead of .work/. Include seeds/ and almanac/ alongside rows/.

## File: references/gate-protocol.md (updated)

Add section on seed-consistency dimension:
- Phase A check in check-artifacts.sh
- Phase B seed-sync dimension in all 7 gates
- Recovery path (requires human input)

## Migration Guide (section in cli-architecture.md)

### For existing .work/ projects:
```sh
# 1. Run migration
scripts/migrate-to-furrow.sh

# 2. Initialize seeds (if not already)
sds init --prefix my-project

# 3. Verify
grep -r '\.work/' --include='*.sh'  # should return nothing
rws list --active                    # should show migrated rows
alm validate                         # should pass
```

## Acceptance Criteria

| AC | Test |
|---|---|
| cli-architecture.md exists | File present with all 6 sections |
| Documents three-CLI model | grep for sds, rws, alm in doc |
| Documents hook disposition | Section 5 covers domain vs policy |
| Documents abstraction principle | "All harness enforcement goes through CLIs" |
| row-layout.md updated | References .furrow/ not .work/ |
| gate-protocol.md updated | Includes seed-consistency section |
| Migration guide included | Step-by-step instructions for .work/ → .furrow/ |
