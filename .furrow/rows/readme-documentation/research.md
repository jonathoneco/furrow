# Research: README Documentation

## Open Questions Resolved

### Q1: Walkthrough format — transcript-style vs. annotated command sequence?

**Decision: Annotated command sequence.** A transcript would be too long and model-dependent (responses vary). An annotated command sequence shows the *user's* side of the interaction — what they type and what happens — without needing to reproduce AI output. This is more durable and scannable.

Example shape:
```
/furrow:work "add rate limiting to API"   # starts ideation ceremony
/furrow:status                             # check progress anytime
/furrow:checkpoint --step-end              # advance to next step
/furrow:review                             # trigger structured review
/furrow:archive                            # complete and archive
```

### Q2: Mention Agent SDK adapter or Claude Code only?

**Decision: Mention briefly, don't feature.** Agent SDK is a first-class adapter with dedicated config, callbacks, and templates. But the primary audience (friends trying it out) will be using Claude Code. One sentence acknowledging dual-runtime support with a pointer to `adapters/` is sufficient.

## Source Material Summary

### Install
- `install.sh` creates symlinks for 4 CLIs (frw, sds, rws, alm) in `~/.local/bin` or `~/bin`
- Delegates to `frw install --project <path>` for per-project setup
- `frw install --check` verifies installation
- Prerequisites: PATH must include `~/.local/bin` or `~/bin`

### Commands (14)
Full list gathered. Key user-facing commands: work, status, checkpoint, review, archive, reground, redirect, next, triage, work-todos. Infrastructure: doctor, update, init, meta.

### Step Sequence (7)
ideate → research → plan → spec → decompose → implement → review

### Core Concepts
- **Row**: unit of work with definition, state, deliverables
- **Step**: stage in the 7-step sequence
- **Gate**: evaluation boundary between steps (supervised/delegated/autonomous)
- **Seed**: task tracking entry synced with row state
- **Specialist**: domain expert agent template
- **Adapter**: runtime binding (Claude Code / Agent SDK)

### Existing Docs to Reference
- `docs/KICKOFF.md` — vision and design philosophy
- `references/` — 9 deep-dive documents
- `commands/` — 14 command specifications
- `specialists/` — 16 specialist templates
