# CLI Architecture

## 1. Directory Structure

All harness state lives under `.furrow/` at the project root. Three CLIs own
disjoint subtrees; no tool writes outside its own directory.

```
.furrow/                          # Harness root
  .focused                        # Active row pointer (row name)
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
        phase-a-results.json      # Deterministic check output
        {deliverable}.json        # Per-deliverable review result
      gate-prompts/               # Evaluation prompts for subagent
      gate-verdicts/              # Evaluator decisions
  almanac/                        # alm data store
    todos.yaml                    # TODO registry
    roadmap.yaml                  # Structured roadmap (YAML)
    rationale.yaml                # Component rationale
    learnings/                    # (future) Promoted learnings
```

## 2. Three-CLI Model

| CLI | Domain | Binary | Data Store |
|-----|--------|--------|------------|
| `sds` | Seed tracking | `bin/sds` | `.furrow/seeds/` |
| `rws` | Row lifecycle | `bin/rws` | `.furrow/rows/` |
| `alm` | Planning and knowledge | `bin/alm` | `.furrow/almanac/` |

**Abstraction principle**: All harness enforcement and interaction goes through
these three CLIs. Claude Code commands are thin wrappers that translate user
intent into CLI calls. Hooks either fold into CLIs (domain hooks) or call CLIs
for their functionality (policy hooks). No script, hook, or command writes
directly to `.furrow/` state files.

## 3. Data Flow

User actions flow through Claude Code commands into CLI invocations, which read
and write `.furrow/` data and return structured output.

```
User --> Claude Code command --> CLI --> .furrow/ data --> CLI --> output

/furrow:work      --> rws init / rws transition / rws load-step
/furrow:status    --> rws status
/furrow:checkpoint --> rws checkpoint
/furrow:archive   --> rws archive
/furrow:review    --> rws review (triggers run-gate.sh + evaluate-gate.sh)
/work-todos       --> alm extract / alm add
/furrow:triage    --> alm triage
/furrow:next      --> alm next
```

Gate evaluation follows a shell-then-subagent pattern:

```
rws transition
  |
  +--> frw run-gate (Phase A: check-artifacts, deterministic)
  |      exit 0  --> gate resolved, no subagent needed
  |      exit 1  --> Phase A failed deterministically
  |      exit 10 --> needs subagent evaluation (prompt path on stdout)
  |
  +--> Agent tool spawns isolated subagent (Phase B: judgment)
  |
  +--> frw evaluate-gate (applies gate_policy trust gradient)
         stdout: PASS | FAIL | CONDITIONAL | WAIT_FOR_HUMAN
```

## 4. Seed Lifecycle

Seeds track work items from creation through completion. Every row is backed
by exactly one seed; seeds are mandatory.

```
rws init ------> sds create ------> seed (open --> claimed)
rws transition -> sds update ------> seed (ideating --> researching --> ...)
rws archive ----> sds close -------> seed (closed)

Gate evaluation -> sds show -------> verify seed-sync
  Phase A: seed exists, not closed (deterministic, in check-artifacts.sh)
  Phase B: seed status matches row step (evaluator dimension)
```

### Step-to-Status Mapping

| Row Step | Seed Status |
|----------|-------------|
| (created) | open |
| (initialized) | claimed |
| ideate | ideating |
| research | researching |
| plan | planning |
| spec | speccing |
| decompose | decomposing |
| implement | implementing |
| review | reviewing |
| (archived) | closed |

## 5. Hook Disposition

Hooks split into two categories based on the question they answer.

**Domain hooks** answer "how does a row work?" Their logic belongs inside the
CLIs, not in standalone scripts.

| Former Hook | Disposition |
|-------------|-------------|
| gate-check | Folded into `rws transition` -- validates gates internally |
| summary-regen | Folded into `rws regenerate-summary` |
| timestamp-update | Automatic in `rws` state updates |
| transition-guard | Removed -- guarded scripts deleted |

**Policy hooks** answer "how should agents behave?" They remain as standalone
hook scripts and call CLIs when they need harness data.

| Hook | Calls CLI? | Purpose |
|------|-----------|---------|
| `correction-limit.sh` | No | Enforces correction count limits |
| `ownership-warn.sh` | No | Warns on file_ownership violations |
| `stop-ideation.sh` | No | Enforces section-by-section interaction |
| `state-guard.sh` | No | Blocks direct state.json writes |
| `verdict-guard.sh` | No | Blocks direct verdict file writes |
| `validate-definition.sh` | No | Validates definition.yaml on write |
| `validate-summary.sh` | Yes (`rws validate-summary`) | Validates summary structure |
| `post-compact.sh` | No | Context recovery after message compaction |
| `work-check.sh` | No | Session-end row state verification |
| `gate-check.sh` | Yes (`rws gate-check`) | Delegates gate validation to rws |

**Principle**: Domain logic belongs in CLIs; behavioral policies stay in hooks.

## 6. Extended Seed Statuses

| Status | Set By | When |
|--------|--------|------|
| `open` | `sds create` | Default on creation |
| `claimed` | `rws init` | Immediately after seed creation |
| `ideating` | `rws transition` | Enter ideate step |
| `researching` | `rws transition` | Enter research step |
| `planning` | `rws transition` | Enter plan step |
| `speccing` | `rws transition` | Enter spec step |
| `decomposing` | `rws transition` | Enter decompose step |
| `implementing` | `rws transition` | Enter implement step |
| `reviewing` | `rws transition` | Enter review step |
| `closed` | `rws archive` / `sds close` | Row archived or manual close |

All 10 statuses form a linear progression. The `rws` CLI is responsible for
calling `sds update` at each transition so seed status stays synchronized with
row step. Drift between the two is caught by the seed-consistency gate
dimension (see gate-protocol.md).

## 7. Migration Guide

For existing `.work/` projects migrating to the `.furrow/` structure:

```sh
# 1. Run the migration script (supports --dry-run for preview)
frw migrate-to-furrow --dry-run   # preview changes
frw migrate-to-furrow             # execute migration

# 2. Initialize seeds (if the project did not already use beans/seeds)
sds init --prefix my-project

# 3. Verify the migration
grep -r '\.work/' --include='*.sh'    # should return nothing
rws list --active                     # should show migrated rows
alm validate                          # should pass
```

### What the Migration Script Does

1. Creates `.furrow/rows/`, `.furrow/seeds/`, `.furrow/almanac/`
2. Moves `.work/{name}/` directories to `.furrow/rows/{name}/`
3. Moves `.work/.focused` and `.work/_meta.yaml` to `.furrow/`
4. Moves `.beans/` contents to `.furrow/seeds/` (renames `issues.jsonl` to `seeds.jsonl`)
5. Moves `todos.yaml`, `ROADMAP.md`, `_rationale.yaml` into `.furrow/almanac/`
6. Renames state.json fields: `issue_id` to `seed_id`, `epic_id` to `epic_seed_id`
7. Updates `.gitattributes` paths from `.beans/` to `.furrow/seeds/`
8. Removes empty `.work/` and `.beans/` directories

The script is idempotent -- running it multiple times is safe. Already-migrated
rows and files are skipped.

### Post-Migration Checklist

- [ ] Confirm `.furrow/rows/` contains all expected row directories
- [ ] Confirm `state.json` files use `seed_id` (not `issue_id`)
- [ ] Confirm `.furrow/seeds/seeds.jsonl` exists if project used beans
- [ ] Confirm `.furrow/almanac/todos.yaml` exists if project had TODOs
- [ ] Update any CI scripts that reference `.work/` paths
- [ ] Update `.gitignore` if it references `.work/` or `.beans/`
