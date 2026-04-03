# Spec: README.md

## Deliverable: `readme`

Target: `README.md` at project root. ~150 lines.

---

### Section 1: Header (~10 lines)

```
# Furrow

One-line tagline: what Furrow is in a sentence.

One paragraph (~3-4 sentences) expanding: what problem it solves, how it works
at a high level (structured steps with gates), who it's for (developers using
AI coding agents).
```

### Section 2: What Does It Feel Like (~25 lines)

Heading: `## What does it feel like`

Annotated command sequence showing a full row lifecycle. Each line is a command
with a `#` comment explaining what happens. Cover: starting work, checking
status, advancing steps, reviewing, archiving.

```
/furrow:work "add rate limiting"    # define the task through guided ideation
/furrow:status                      # see current step and progress
/furrow:checkpoint --step-end       # complete step, evaluate gate, advance
/furrow:review                      # trigger structured multi-phase review
/furrow:archive                     # archive row, promote learnings
```

Follow with 2-3 sentences explaining that Furrow handles the ceremony between
these commands: breaking work into steps, evaluating quality at each gate,
dispatching specialist agents, and maintaining context across sessions.

### Section 3: Prerequisites (~8 lines)

Heading: `## Prerequisites`

Bullet list:
- Claude Code (link to anthropic docs)
- `~/.local/bin` or `~/bin` on PATH
- Git (for branching/commit workflow)

### Section 4: Install (~15 lines)

Heading: `## Install`

Three steps:
1. Clone the repo
2. Run `./install.sh` (creates CLI symlinks)
3. In your project: `frw install --project .`

Mention `frw install --check` for verification.

### Section 5: Commands (~45 lines)

Heading: `## Commands`

Two sub-tables:

**Working** (daily use):
| Command | Purpose |
| /furrow:work | Start or continue a task |
| /furrow:status | Show progress and next action |
| /furrow:checkpoint | Save progress, optionally advance step |
| /furrow:review | Trigger structured review |
| /furrow:archive | Complete and archive a row |

**Managing** (infrastructure/planning):
| Command | Purpose |
| /furrow:reground | Recover context after a break |
| /furrow:redirect | Record dead end, reset step |
| /furrow:next | Generate handoff prompts from roadmap |
| /furrow:triage | Triage TODOs into roadmap |
| /furrow:work-todos | Extract or create TODOs |
| /furrow:init | Initialize Furrow in a project |
| /furrow:doctor | Check installation health |
| /furrow:update | Check for configuration drift |
| /furrow:meta | Enter self-modification mode |

### Section 6: Core Concepts (~25 lines)

Heading: `## Core concepts`

Brief definitions, 2-3 lines each:

- **Row**: A unit of work. Has a definition (objective, deliverables, constraints), state (current step, gate history), and artifacts (research, specs, code).
- **Step**: Rows traverse 7 steps: ideate → research → plan → spec → decompose → implement → review. Each step has a skill that guides the agent's behavior.
- **Gate**: Quality checkpoint between steps. Evaluates readiness to advance. Can be supervised (human approves), delegated (evaluator decides), or autonomous (auto-approved).
- **Seed**: Task tracking entry. Seeds sync with row state and enable roadmap planning via `/furrow:triage`.

### Section 7: Going Deeper (~15 lines)

Heading: `## Going deeper`

Pointer list to in-tree documentation:
- `references/` — gate protocol, review methodology, row layout, eval dimensions
- `docs/KICKOFF.md` — design philosophy and constraints
- `specialists/` — domain expert agent templates (16 available)
- `.furrow/almanac/rationale.yaml` — component inventory with deletion criteria
- `adapters/` — runtime adapters for Claude Code and Agent SDK

One sentence noting dual-runtime support: Furrow works with both Claude Code
(slash commands) and the Anthropic Agent SDK (Python callbacks). The adapters/
directory has the runtime-specific bindings.

---

## Acceptance Criteria Mapping

| Criterion | Section |
|-----------|---------|
| One-liner + paragraph explanation | 1: Header |
| Session walkthrough | 2: What does it feel like |
| Prerequisites and install | 3 + 4 |
| Command overview table | 5: Commands |
| Core concepts (~30 lines) | 6: Core concepts |
| Going deeper pointers | 7: Going deeper |
| Under ~200 lines | Sum: ~143 lines |
| No frequently-changing content duplication | Commands use purpose summaries, not flags/args |
