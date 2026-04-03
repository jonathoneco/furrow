# File Structure

> Component rationale is tracked in .furrow/almanac/rationale.yaml.

## Overview

Two trees: **Furrow** (this repo, reusable across projects) and the
**project** (any project using Furrow, instance artifacts).

Furrow is grouped by concern. Each top-level directory maps to a distinct
architectural role. Content files (specialist definitions, review methodologies)
are distinguished from infrastructure files (schemas, hooks, runner code).

## Harness Layout

```
furrow/
│
├── conventions/                    # Schemas and format definitions
│   ├── work-definition.schema.json
│   ├── progress.schema.json
│   └── execution-plan.schema.json
│
├── enforcement/                    # Hooks and callbacks (Python throughout)
│   ├── on_session_start.py         # Hard gate: load work context, validate schema
│   ├── on_completion_gate.py       # Hard gate: validate claim, trigger review
│   └── on_session_end.py           # Backstop: auto-generate work summary
│
├── adapters/                       # Runtime-specific adapters
│   ├── claude-code/
│   │   ├── load-work.md            # Skill: load work def, set up session
│   │   └── hooks.json              # Hook configuration template
│   └── agent-sdk/
│       ├── coordinator.py          # Coordinator agent template
│       └── specialist.py           # Specialist agent template
│
├── review/                         # Review infrastructure
│   ├── runner.py                   # Review execution: discover criteria,
│   │                               # run deterministic checks, spawn
│   │                               # LLM-judge, store results
│   └── methodologies/              # Domain review approaches (content)
│       ├── code-security.md
│       ├── database.md
│       ├── documentation.md
│       └── general.md
│
├── specialists/                    # Specialist agent definitions (content)
│   ├── security-specialist.md
│   ├── database-architect.md
│   ├── frontend-specialist.md
│   ├── technical-writer.md
│   └── test-engineer.md
│
├── evals/                          # Harness behavioral evals
│   ├── test_work_entry.py          # Behavior 1: work def loaded at start
│   ├── dimensions/                 # Quality dimension rubrics per artifact type
│   │   ├── research.yaml
│   │   ├── plan.yaml
│   │   ├── spec.yaml
│   │   ├── decompose.yaml
│   │   └── implement.yaml
│   ├── gates/                      # Gate evaluation rubrics per step
│   │   ├── ideation.yaml           # Post-step only
│   │   ├── research.yaml           # Pre-step + post-step
│   │   ├── plan.yaml               # Pre-step + post-step
│   │   ├── spec.yaml               # Pre-step + post-step
│   │   ├── decompose.yaml          # Pre-step + post-step
│   │   ├── implement.yaml          # Post-step only
│   │   └── review.yaml             # Post-step only
│   ├── test_dependency_order.py    # Behavior 2: dependency order respected
│   ├── test_completion_claims.py   # Behavior 3: claims before next deliverable
│   ├── test_review_at_boundary.py  # Behavior 4: review runs at boundaries
│   ├── test_correction_limit.py    # Behavior 5: stops after N failures
│   └── test_progress_integrity.py  # Behavior 6: progress matches artifacts
│
└── docs/
    ├── architecture/               # Architectural specs (this phase)
    └── research/                   # Research seed material
```

## File Inventory

### conventions/ — Schemas and format definitions

| File | Purpose | Research finding |
|------|---------|-----------------|
| `work-definition.schema.json` | JSON Schema for work definition YAML files. Level A enforcement — validated before work begins. | Insight #1: convention layer needs structural enforcement |
| `progress.schema.json` | JSON Schema for progress state. Enforces single active deliverable, valid status transitions. | Gap review: progress file integrity is a procedural backstop |
| `execution-plan.schema.json` | JSON Schema for coordinator's execution plan. Validates wave structure, specialist assignments. | Design decision: coordinator produces explicit plan |

### enforcement/ — Hooks and callbacks

Three enforcement points, implemented for both runtimes:

**on_session_start.py** (Hard gate)
- Load active work definition into session context
- Validate work definition against schema
- Load progress state and work summary
- If no active row, skip (ad-hoc work is fine)

**on_completion_gate.py** (Hard gate)
- Triggered by progress.json mutation (completion claim)
- Validate claim structure against schema
- Check correction count — if above limit, pause for human input
- Trigger review runner
- Block next deliverable until review passes

**on_session_end.py** (Procedural backstop)
- Auto-generate work summary from progress state + recent file changes
- Update progress.json with session metadata

All enforcement is Python — same modules used by both runtimes. Claude Code
hooks call `python3 enforcement/on_*.py`. Agent SDK callbacks import and
call the same functions. No shell dependencies (jq, yq, etc.).

| File | Claude Code | Agent SDK |
|------|-------------|-----------|
| `on_session_start.py` | Hook calls via `python3` | Callback imports directly |
| `on_completion_gate.py` | Hook calls via `python3` | Callback imports directly |
| `on_session_end.py` | Hook calls via `python3` | Callback imports directly |

### adapters/ — Runtime-specific adapters

| File | Purpose |
|------|---------|
| `claude-code/load-work.md` | Skill that reads a work definition, displays status, and sets up the session. Uses YAML frontmatter + markdown body (Skills format). |
| `claude-code/hooks.json` | Template for the hooks configuration to add to the project's `.claude/settings.json`. Documents which hook scripts to wire to which lifecycle events. |
| `agent-sdk/coordinator.py` | Program template for the coordinator agent. Reads work definition, produces execution plan, spawns specialists, manages progress. |
| `agent-sdk/specialist.py` | Program template for specialist agents. Receives deliverable assignment, context pointers, acceptance criteria. Writes output to row directory. |

### review/ — Review infrastructure

| File | Purpose |
|------|---------|
| `runner.py` | Review execution: discovers acceptance criteria from work definition, runs deterministic checks, spawns LLM-judge (cross-model by default), composes review approach from signals (file ownership, criteria, specialist domain), stores results as JSON in row directory. |
| `methodologies/*.md` | Domain review approach prompts (frontmatter+MD). Private to reviewer — executor never loads these. Selected by review runner based on deliverable signals. |

### specialists/ — Specialist agent definitions

Frontmatter+markdown files that define domain specialist agents. The
frontmatter carries metadata (name, domain). The body carries the system
prompt that primes the agent's domain reasoning.

These are **content, not infrastructure**. Furrow ships with common
specialist types. Projects can add project-specific specialists by placing
additional definition files in Furrow's specialists directory (or a
project-level override location, TBD in Phase 2).

### evals/ — Harness behavioral evals

Behavioral evals for Furrow itself — distinct from acceptance criteria
review of work output. These test whether Furrow's conventions are being
followed and whether its enforcement mechanisms are working.

Maps to the behavior catalog from the gap review (behaviors 1-6 prioritized
for Phase 0-1 bootstrap).

### evals/gates/ — Gate evaluation rubrics

Gate YAML files define the dimensions used for pre-step and post-step evaluation
at each step boundary. Pre-step dimensions determine whether a step can be skipped
(applies to research, plan, spec, decompose). Post-step dimensions evaluate the
quality of step output. Post-step sections reference `evals/dimensions/` via
`dimensions_from` to avoid duplication.

| File | Pre-step | Post-step |
|------|----------|-----------|
| `ideation.yaml` | No | Yes (completeness, alignment, feasibility, cross-model) |
| `research.yaml` | Yes (path-relevance) | Yes (dimensions_from research.yaml) |
| `plan.yaml` | Yes (complexity-assessment) | Yes (dimensions_from plan.yaml) |
| `spec.yaml` | Yes (testability) | Yes (dimensions_from spec.yaml) |
| `decompose.yaml` | Yes (wave-triviality) | Yes (dimensions_from decompose.yaml) |
| `implement.yaml` | No | Yes (dimensions_from implement.yaml) |
| `review.yaml` | No | Yes (Phase A + B aggregate) |

## Project Layout

When a project uses Furrow, instance artifacts live in `.furrow/rows/` at the
project root (configurable).

```
project-root/
├── .furrow/rows/                          # Row instances (default location)
│   ├── auth-token-rotation/        # One directory per row
│   │   ├── definition.yaml         # Work definition (YAML, human-authored)
│   │   ├── execution-plan.json     # Coordinator's plan (JSON, machine-authored)
│   │   ├── progress.json           # Progress state (JSON, machine-authored)
│   │   ├── summary.md              # Work summary (MD, auto-generated)
│   │   └── results/                # Review results per deliverable
│   │       ├── token-rotation-logic.json
│   │       └── session-schema-update.json
│   └── previous-row/
│       └── ...
├── .claude/
│   ├── CLAUDE.md                   # Includes Furrow ambient context
│   └── settings.json               # Includes Furrow hook configuration
└── (project files)
```

### Row directory

Each row is a directory containing a standard set of files:

| File | Format | Author | Purpose |
|------|--------|--------|---------|
| `definition.yaml` | YAML | Human or planner agent | The work definition (schema: `conventions/work-definition.schema.json`) |
| `execution-plan.json` | JSON | Coordinator agent | Parallel waves, specialist assignments (schema: `conventions/execution-plan.schema.json`) |
| `progress.json` | JSON | Coordinator agent, hooks | Progress state per deliverable (schema: `conventions/progress.schema.json`) |
| `summary.md` | Frontmatter+MD | Auto-generated by hook | ~200-500 token work summary for session recovery |
| `results/*.json` | JSON | Review runner | Review results per deliverable, stored for calibration |

### Row lifecycle

1. **Created**: `definition.yaml` is written (by human or planner agent)
2. **Planned**: coordinator produces `execution-plan.json`
3. **Active**: specialists execute, `progress.json` tracks state
4. **Reviewed**: review results accumulate in `results/`
5. **Complete**: all deliverables pass review, `progress.json` reflects completion
6. **Archived**: row directory remains for history (git tracks it)

No separate archive mechanism needed — `progress.json` status distinguishes
active from complete work. `git log` provides the audit trail.

### .gitignore considerations

Row directories SHOULD be committed — they're the audit trail for what
was built, what was reviewed, and what passed. The only exception: calibration
data in the Furrow repo may contain large volumes of LLM-judge outputs that
don't belong in the project's git history.

## File Count Budget

| Category | Infrastructure files | Content files | Total |
|----------|---------------------|---------------|-------|
| conventions/ | 3 schemas | — | 3 |
| enforcement/ | 3 (shared Python modules) | — | 3 |
| adapters/ | 4 (2 Claude Code + 2 Agent SDK) | — | 4 |
| review/ | 1 runner | 3-5 methodologies | 4-6 |
| specialists/ | — | 4-6 definitions | 4-6 |
| evals/ | — | 5-8 behavioral evals | 5-8 |
| **Total** | **11** | **12-19** | **23-30** |

Infrastructure core: **11 files** (well within 20-30 budget).
Content files grow with usage — specialist definitions, review methodologies,
and behavioral evals are added/removed based on need.

## Relationship to Architecture Specs

| Concern | Spec | Key files |
|---------|------|-----------|
| Work definition format | `work-definition-schema.md` | `conventions/work-definition.schema.json`, project `definition.yaml` |
| Prompt format | `prompt-format.md` | All `.yaml`, `.json`, and `.md` files follow the three-format rule |
| Context model | `context-model.md` | `enforcement/hooks/on-session-start.sh`, project `summary.md` |
| Review infrastructure | (Phase 2) | `review/runner.py`, `review/methodologies/*.md` |
| Enforcement skeleton | (Phase 2) | `enforcement/hooks/*`, `enforcement/callbacks/*` |
| Dual-runtime adapters | (Phase 2) | `adapters/claude-code/*`, `adapters/agent-sdk/*` |

## Design Decisions Log

| Decision | Resolution | Rationale |
|----------|-----------|-----------|
| Flat vs grouped | Grouped by concern | Extensibility; each concern can grow independently |
| Row location | `.furrow/rows/` at project root, configurable | Hidden directory keeps project root clean; configurable for non-standard layouts |
| Reusable vs instance | Harness repo = reusable; project `.furrow/rows/` = instance | Natural repo boundary; no naming conventions needed |
| Infrastructure vs content budget | 14 infrastructure files; content grows with usage | Infrastructure core is well within 20-30 target; content is configuration, not code |
| Archive mechanism | None — git + progress.json status | No custom archival; git is the audit trail |
| Hook consolidation | 3 enforcement points (start, completion-gate, end) | Consolidated from 5; completion-gate handles claim validation + correction limit + review trigger + gate |
