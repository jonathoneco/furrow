# Pi-native capability leverage

Status: Proposed
Owner: Furrow migration
Related:
- `docs/architecture/host-strategy-matrix.md`
- `docs/architecture/dual-runtime-migration-plan.md`
- `docs/architecture/workflow-power-preservation.md`
- `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
- `docs/architecture/pi-parity-ladder.md`

## Purpose

Document the Pi-native extensibility surfaces Furrow should intentionally
exploit **after semantic parity and workflow-power preservation are stable**.

This is a fast-follow planning document, not a reason to dilute the current
parity-restoration work. The immediate goal remains restoring Furrow's staged,
backend-canonical operating loop in Pi. Once that is trustworthy, Furrow should
use Pi's deep extensibility to become better than a Claude-shaped port.

## Why this needs to be explicit now

Pi offers materially richer host-level extensibility than Claude Code in areas
that can strengthen Furrow once parity is stable:

- extensions with lifecycle hooks, tool interception, UI, commands, and state
- system prompt access and per-turn prompt shaping
- project-local and package-distributed skills
- prompt templates as reusable slash commands
- presets for repeatable operating modes
- packages for bundling and sharing the full Furrow Pi surface
- dynamic resource loading and custom TUI surfaces

If this is not documented, Furrow risks freezing at "minimum parity" instead of
using Pi as a true workflow host.

## Strategic rule

The strategic rule remains:

- **shared semantics and artifacts stay backend-canonical**
- **Pi-native leverage is encouraged for host UX, orchestration ergonomics, and runtime shaping**
- **Pi-native features must not become the hidden source of canonical domain semantics**

That means Furrow should use Pi to become more capable, but not by moving row,
gate, review, or seed semantics out of the backend.

## Capability areas to exploit

## 1. Extensions

Pi extensions are the main host-power surface.

Relevant capabilities:
- custom commands
- event hooks (`before_agent_start`, `tool_call`, `tool_result`, etc.)
- user interaction (`confirm`, `select`, `input`, notifications)
- custom UI widgets, footer/header, custom editor components
- session state persistence
- custom tools
- message/session manipulation
- dynamic resource discovery

### Furrow use cases

Extensions are the right place for:
- the primary `/work` entrypoint UX
- supervised confirmation dialogs
- blocker presentation and guided recovery UX
- row selection UI when multiple active rows exist
- protected-path and direct-state-mutation guardrails
- status/footer widgets showing row, step, seed, and validation state
- launch/coordination surfaces for tmux/worktrees later
- session handoff helpers and multi-session choreography
- custom compaction or summarization that respects Furrow artifacts

### Guardrail

Extensions may **operate** workflow semantics, but must not become the
canonical source of those semantics.

If a feature changes:
- row lifecycle rules
- gate meaning
- review meaning
- seed semantics
- `.furrow/` state invariants

then it belongs in the backend, not only in an extension.

## 2. System prompt access

Pi exposes multiple system-prompt shaping surfaces:
- project `.pi/SYSTEM.md`
- `APPEND_SYSTEM.md`
- extension-time `before_agent_start`
- extension access to structured `systemPromptOptions`
- tool-specific prompt snippets and guidelines

### Furrow use cases

System-prompt access is valuable for:
- reinforcing the active Furrow operating mode
- injecting stage-aware guidance derived from current row state
- loading or highlighting the current step contract
- surfacing project conventions and current host rules
- selectively biasing the session toward review / planning / implementation
  posture when combined with presets or commands

### Guardrail

Do not let critical Furrow semantics live **only** in prompt text.

System-prompt shaping should reinforce and operationalize backend/state-driven
behavior, not replace it.

Bad pattern:
- "the prompt says don't skip steps" while backend and adapter permit it

Good pattern:
- backend blocks invalid progression, adapter surfaces it, prompt explains the
  operator contract

## 3. Skills

Pi skills are strong progressive-disclosure assets.

### Furrow use cases

Skills are a good fit for:
- step-specific work protocols
- specialized research/review/playbooks
- integration guides for external systems
- teammate-friendly, host-local procedural aids
- Pi-specific orchestration helpers that should be loaded on demand rather than
  always live in the extension

They can also help separate:
- canonical backend semantics
- on-demand operator guidance and procedures

### Guardrail

Skills should not be the only place a hard invariant exists. If violating a
rule would corrupt Furrow semantics, it still needs backend/adapter enforcement.

## 4. Prompt templates

Prompt templates are low-cost reusable command surfaces.

### Furrow use cases

Prompt templates are useful for:
- review kickoff prompts
- archive/disposition prompts
- handoff prompts
- merge/reintegration prompts
- row-init or row-recovery bootstrap prompts
- targeted planning/research helpers

These are especially attractive when the workflow benefit is mostly in
repeatable framing, not in canonical semantics.

### Guardrail

Templates are accelerators, not authorities. They should not be required for a
supported Furrow flow to remain semantically correct.

## 5. Presets

Presets are a practical way to bundle:
- model choice
- thinking level
- active tools
- appended instructions
- extension-mode toggles

### Furrow use cases

Furrow should likely keep or expand presets for:
- ideation / research
- planning / specification
- implementation
- review
- merge / archive
- read-only planning mode

This is a good way to make the stageful workflow ergonomic without hardcoding
model posture into the core semantics.

### Guardrail

Presets should shape ergonomics and model posture, not redefine the workflow.
A supervised checkpoint should still be required even if a preset changes model
or thinking settings.

## 6. Packages

Pi packages are the distribution mechanism that can make Furrow feel like a
real Pi product rather than only a project-local extension.

### Furrow use cases

A Furrow Pi package can eventually bundle:
- extensions
- skills
- prompts
- themes if useful
- package dependencies

This is likely the right distribution vehicle once:
- the staged `/work` loop is stable
- backend contracts are stable enough
- team install/upgrade ergonomics matter

### Guardrail

Packaging should happen after behavioral stability, not before. The package
should bundle a mature surface, not become the forcing function for design.

## 7. Dynamic resources and custom UI

Pi supports dynamic resource discovery and richer TUI surfaces.

### Furrow use cases

This opens later opportunities for:
- row-aware dynamic prompts/skills
- context-sensitive loading of specialist or step assets
- richer dashboard widgets
- modal workflows for row selection, review disposition, or launch planning
- structured questionnaires for ideation/research clarification

### Guardrail

These are high-leverage, but they are fast follow after the primary `/work`
operating loop is trustworthy. They should not compete with the current parity
restoration work.

## Recommended fast-follow sequence

After the current parity/preservation work is stable, recommended order is:

1. **Stabilize semantic parity and staged `/work` loop**
   - backend-canonical workflow
   - supervised checkpoints
   - create-on-use artifacts
   - seed-visible flow

2. **Validate shared-backend behavior across Pi and Claude-compatible paths**
   - confirm semantic compatibility and artifact compatibility

3. **Exploit Pi-native host leverage intentionally**
   - strengthen extension UX
   - add prompt/system shaping where useful
   - grow skills/templates/presets
   - evaluate packaging shape

4. **Promote the repo-owned Pi package surface**
   - only after the behavior is worth packaging

## Candidate fast-follow work items

Good follow-on candidates once the parity slice lands:

- richer `/work` UI with row selection and guided checkpoint dialogs
- stage-aware status/footer widgets
- dedicated review/disposition dialogs
- dynamic loading of step-specific prompts/skills/resources
- Furrow package bundling for extensions + skills + prompts
- stronger project-local system prompt layering for Furrow mode selection
- more opinionated presets per Furrow stage
- custom compaction or handoff flows that preserve Furrow artifact context
- session choreography helpers for multi-row or multi-stage work

## Anti-patterns to avoid

Do not use Pi's extensibility to:
- hide critical semantics only in prompt text
- move canonical row/gate/review logic into TS
- create Pi-only artifact formats
- make supported workflow correctness depend on optional templates or presets
- bypass backend validation because the extension can "guide the model"

## Bottom line

Once Furrow restores parity and workflow power in Pi, it should not stop at
"equivalent enough." Pi's extensibility is one of the main reasons to prefer it
as the primary host.

The right target is:
- **shared backend semantics**
- **shared artifact semantics**
- **Pi-native leverage on top**

That gives Furrow a path to be both:
- compatible for teammates in Claude Code
- meaningfully stronger in Pi for primary usage
