# Team Plan: team-demo-prep

## Scope Analysis

2 deliverables, sequential dependency (wave 2 depends on wave 1).
Single specialist type (docs-writer). No parallel coordination needed.

## Team Composition

Single agent executes both waves sequentially. No specialist dispatch needed —
this is content creation, not code.

## Task Assignment

### Wave 1: demo-script
- **Deliverable**: `demo-script`
- **File ownership**: `DEMO.md`
- **Spec**: `specs/demo-script.md`
- **Action**: Create DEMO.md at project root with prep checklist, tmux section, furrow section

### Wave 2: pre-staged-outputs
- **Deliverable**: `pre-staged-outputs`
- **File ownership**: `.furrow/demo/**`
- **Spec**: `specs/pre-staged-outputs.md`
- **Action**: Run `alm next`, capture output to `.furrow/demo/next-prompt.txt`, verify roadmap.md exists

## Coordination

None needed — sequential single-agent execution.

## Skills

No specialist templates required.
