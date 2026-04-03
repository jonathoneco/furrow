# Furrow

A workflow harness for AI coding agents. Furrow structures work into tracked
units called *rows* that move through a fixed sequence of steps — from ideation
through implementation to review — with quality gates at each boundary. It
keeps agents focused, prevents drift, and makes multi-session work resumable.

## What does it feel like

You interact with Furrow through slash commands in Claude Code. A typical
session looks like this:

```
/furrow:work "add rate limiting to API"   # starts guided ideation
                                          # — brainstorm, premise challenge,
                                          #   cross-model review, section-by-section
                                          #   definition approval

/furrow:status                            # check current step, deliverables, next action

/furrow:checkpoint --step-end             # complete current step, evaluate gate, advance

/furrow:review                            # trigger structured two-phase review
                                          # — artifact validation, then quality evaluation

/furrow:archive                           # archive row, promote learnings, extract TODOs
```

Between these commands, Furrow handles the ceremony: breaking work into steps,
loading step-specific skills, evaluating readiness at gates, dispatching
specialist agents for implementation, and maintaining context across sessions
and compaction events.

## Prerequisites

- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and configured
- `~/.local/bin` or `~/bin` on your PATH
- Git

## Install

```sh
# 1. Clone
git clone <repo-url> && cd furrow

# 2. Create CLI symlinks (frw, sds, rws, alm)
./install.sh

# 3. In your project directory, install Furrow
frw install --project /path/to/your/project
```

Verify with `frw install --check /path/to/your/project`.

## Commands

### Working

| Command | Purpose |
|---------|---------|
| `/furrow:work` | Start a new task or continue an existing one |
| `/furrow:status` | Show current step, deliverable progress, next action |
| `/furrow:checkpoint` | Save session progress; with `--step-end`, advance step |
| `/furrow:review` | Trigger structured multi-phase review |
| `/furrow:archive` | Complete and archive a finished row |

### Managing

| Command | Purpose |
|---------|---------|
| `/furrow:reground` | Recover context after a session break |
| `/furrow:redirect` | Record a dead end and reset the current step |
| `/furrow:next` | Generate handoff prompts from the roadmap |
| `/furrow:triage` | Triage TODOs into a phased roadmap |
| `/furrow:work-todos` | Extract or create TODO entries |
| `/furrow:init` | Initialize Furrow in a new project |
| `/furrow:doctor` | Check installation health |
| `/furrow:update` | Check for configuration drift |
| `/furrow:meta` | Enter self-modification mode |

## Core concepts

**Row** — A unit of work. Each row has a definition (objective, deliverables,
constraints), tracked state (current step, gate history), and artifacts
produced along the way (research notes, specs, code, reviews).

**Step** — Rows traverse seven steps in order:
ideate → research → plan → spec → decompose → implement → review.
Each step loads a skill that guides the agent's behavior for that phase.

**Gate** — A quality checkpoint between steps. Gates evaluate whether the
current step's work is sufficient to advance. Three policies control oversight:
*supervised* (human approves), *delegated* (evaluator decides most gates),
*autonomous* (all gates auto-evaluated).

**Seed** — A task tracking entry. Seeds sync with row lifecycle state and feed
into roadmap planning via `/furrow:triage`.

## Going deeper

| Resource | What's there |
|----------|-------------|
| `references/` | Gate protocol, review methodology, row layout, eval dimensions |
| `docs/` | Architecture references, git conventions, research findings |
| `specialists/` | Domain expert agent templates (15 available) |
| `evals/` | Gate and review evaluation rubrics |
| `.furrow/almanac/rationale.yaml` | Component inventory with deletion criteria |

Furrow supports both Claude Code (slash commands) and the Anthropic Agent SDK
(Python callbacks). See `adapters/` for runtime-specific bindings.
