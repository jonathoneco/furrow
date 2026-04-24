# Furrow

Status: Active
Authority: Canonical
Time horizon: Enduring

A workflow harness for AI coding agents. Furrow structures work into tracked
units called *rows* that move through a fixed sequence of steps — from ideation
through implementation to review — with quality gates at each boundary. It
keeps agents focused, prevents drift, and makes multi-session work resumable.

## Guiding principles

Furrow is not just a set of commands. It is a view of how AI-assisted work
should be structured: staged, observable, reviewable, and durable. These
principles explain the shape of the harness and the tradeoffs it makes.

- **Workflow over vibes** — AI work should move through explicit stages, not
  drift through one long chat.
- **Human pilot, AI engine** — Furrow is designed to amplify human judgment,
  not replace it. The human remains responsible for direction, tradeoffs, and
  approval; the AI supplies speed, synthesis, and execution inside a structured
  workflow.
- **Enforcement over aspiration** — if something matters, it should be
  enforced, not merely suggested in a prompt.
- **Observability as a feature** — row state, artifacts, gates, reviews, and
  decisions should be inspectable, resumable, and auditable.
- **Artifacts are first-class** — files are not exhaust from the chat; they are
  durable workflow inputs and outputs, and later stages should consume them as
  workflow inputs rather than merely documenting work after the fact.
- **Thoughtful ideation and planning pay off** — strong early clarification,
  research, and planning reduce downstream drift and rework.
- **Orchestration matters** — the active session should do more than generate
  outputs. It should coordinate stages, load the right context, route work to
  the right specialist or review path, and stop at the right decision points.
- **Offload repetitive structure** — Furrow carries workflow state, context,
  and ceremony so humans can spend attention on judgment instead of repeated
  bookkeeping.
- **Canonical state matters** — workflow truth should live in durable,
  auditable state and artifacts, not only in session memory.
- **Gated progression over silent advancement** — work should advance because
  it passed an explicit gate, not because the model informally decided it was
  done.
- **Review is a real gate, not a formality** — Furrow separates structural
  validation from substantive evaluation. **Phase A** checks readiness,
  required artifacts, protocol compliance, and preconditions. **Phase B**
  evaluates correctness, quality, risk, and readiness to proceed. Advancement
  should be earned through evidence, not implied by model confidence.
- **Shared semantics, host-native ergonomics** — Furrow should preserve the
  same backend and artifact semantics across hosts, while allowing each runtime
  to expose those semantics in the way it is best suited to.

## What does it feel like

Furrow is currently in a dual-host migration. Claude Code remains an important
host shape, and the repo now also contains a Pi adapter with a primary `/work`
loop over the same backend-canonical `.furrow/` state. A typical Claude-form
session still looks like this:

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
| `adapters/` | Runtime-specific bindings for Claude Code, Pi, and Agent SDK |
| `.furrow/almanac/rationale.yaml` | Component inventory with deletion criteria |

Furrow supports Claude Code, Pi, and the Anthropic Agent SDK through thin
runtime adapters over the shared backend. The current Furrow Pi adapter lives
in `adapters/pi/` and should be extended there rather than replaced with a
parallel adapter. It is aimed at making Pi the stronger primary host without
moving canonical workflow semantics out of the backend. See `adapters/` for
runtime-specific bindings.
