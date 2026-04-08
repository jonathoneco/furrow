# Rules Strategy: Enforcement Layer Taxonomy

## Overview

Furrow uses four enforcement layers with different persistence and authority.
This document defines what belongs where and when to extract invariants into rules.

## Layer Taxonomy

| Layer | Purpose | Persistence | Subagents | Enforcement |
|-------|---------|-------------|-----------|-------------|
| **Hooks** (settings.json) | Automatic validation on tool use | Universal — runs on every tool call | Yes | Mechanical — blocks or allows |
| **Rules** (.claude/rules/) | Invariants the agent must follow | Re-read from disk after compaction | Unclear — may not load | Behavioral — agent guidance |
| **CLAUDE.md** | Project config, routing, conventions | Re-read from disk after compaction | Not auto-loaded | Behavioral — agent guidance |
| **Skills** (skills/) | Step-scoped procedural guidance | Transient — replaced at step boundaries | Not inherited | Procedural — how to do work |

## Key Finding: Persistence Parity

Rules and CLAUDE.md have equivalent persistence:
- Both re-read from disk after context compaction
- Both load in worktrees (from worktree directory)
- Neither reliably loads in subagents spawned via Agent tool
- Hooks (settings.json) are the only enforcement mechanism that's universal

## What Goes Where

### Rules (.claude/rules/*.md)
**Criteria**: Would violating this break the harness workflow?

Use for invariants where:
1. Violation causes state corruption or procedural breakdown
2. The invariant must persist after compaction (not step-scoped)
3. A hook backs the enforcement (rule documents what hook enforces)

**Current rules**:
- `cli-mediation.md` — state mutations through CLI only (backed by state-guard hook)
- `step-sequence.md` — 7-step sequence, no skipping (backed by gate-check hook)

### Hooks (settings.json)
Use for enforcement that must be mechanical and universal:
- PreToolUse: block forbidden actions (state-guard, correction-limit, verdict-guard)
- Stop: validate session-end state (validate-summary, stop-ideation)
- PostCompact: restore context after compaction

### CLAUDE.md
Use for:
- Active task detection and recovery instructions
- File naming conventions and schema field patterns
- Context budget constraints (advisory — verified by `frw measure-context`)
- Topic routing tables (where to find documentation)
- Commit conventions

### Skills (skills/*.md)
Use for step-scoped procedural guidance:
- How to run the ideation ceremony
- What research should produce
- How to write specs
- Transition protocols

## When to Extract a New Rule

1. An invariant keeps being violated despite being in CLAUDE.md
2. The violation causes actual harm (state corruption, broken workflow)
3. A hook exists or should exist to back the enforcement
4. The rule is <=20 lines (ambient budget is shared, <=150 lines)

Do NOT extract if:
- The invariant is advisory (context budgets, naming quality)
- It's step-scoped (belongs in the skill)
- It's already well-covered by an existing rule
- Extracting would push ambient context over 150 lines

## install.sh Management

Rules are managed by symlinks:
- `install.sh` globs `.claude/rules/*.md` from the Furrow source
- Each rule is symlinked to the target project's `.claude/rules/`
- Self-installs skip symlinks (source = target)
- No namespace separation — all rules are flat in `.claude/rules/`
- No conflict detection — if a project has a local rule with the same name, the symlink overwrites it

Revisit namespace separation when rule count exceeds 5.
