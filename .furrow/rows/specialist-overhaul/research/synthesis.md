# Research Synthesis: specialist-overhaul

## Deliverable Readiness

All 7 deliverables have been researched. Summary of readiness:

### 1. gate-check-hook-fix — READY
Two bugs identified: regex captures `--request` instead of row name, and
hook delegates to wrong function (`rws gate-check` instead of `has_passing_gate`).
Fix implemented inline during research. Needs review.

### 2. transition-simplification — READY
Two-phase ceremony analyzed. `pending_approval` state provides no functional
value — user approval happens before both phases, no interaction between them.
Single atomic command design clear. Interaction with gate-check hook understood.

### 3. review-consent-isolation — READY
Consent borrowing bug documented. Fix is skill instruction additions to
`skills/review.md`. Small scope.

### 4. enforcement-wiring — READY
Current advisory language in `skills/implement.md` identified. Three changes
needed: hard requirement language, plan.json validation, step-level modifiers
in spec/implement/review skills.

### 5. specialist-reasoning-upgrade — READY
Full audit of all 15 specialists complete:
- 4 STRONG (minor polish): harness-engineer, merge-specialist, cli-designer, complexity-skeptic
- 7 ADEQUATE (project grounding needed): api-designer, document-db-architect, go-specialist, migration-strategist, relational-db-architect, systems-architect, test-engineer
- 4 WEAK (significant rework): security-engineer, shell-specialist, python-specialist, typescript-specialist
- Template standard has 6 gaps to address first

### 6. specialist-expansion — READY
All 5 new specialist designs researched with detailed reasoning patterns:
- frontend-designer (8 patterns, sonnet)
- css-specialist (7 patterns, sonnet)
- accessibility-auditor (8 patterns, opus)
- prompt-engineer (8 patterns, opus)
- technical-writer (7 patterns, sonnet)

## Open Questions Resolved

| Question | Resolution |
|----------|-----------|
| How many specialists genuinely need rework? | 4 WEAK need rework, 7 ADEQUATE need grounding pass, 4 STRONG need minor polish |
| Should harness-engineer rationale grounding extend to others? | Yes — merge-specialist and systems-architect should also reference rationale.yaml |
| What step-modifier language works? | Research defers to implementation — will be empirical |

## Execution Order Recommendation

1. **gate-check-hook-fix** — unblocks all transitions (already partially done)
2. **review-consent-isolation** — small, independent
3. **enforcement-wiring** — enables specialist loading for all subsequent work
4. **specialist-reasoning-upgrade: template standard first** — update standard before upgrading specialists
5. **specialist-reasoning-upgrade: WEAK specialists** — security, shell, python, typescript
6. **specialist-reasoning-upgrade: ADEQUATE specialists** — project grounding pass
7. **specialist-expansion** — write 5 new specialists
8. **transition-simplification** — largest refactor, touches most files, ship last

## Risk Assessment

- **Transition simplification** touches `bin/rws` (core CLI) and all 7 step
  skills. Highest risk deliverable. Consider whether the hook fix alone is
  sufficient and defer transition simplification to a separate row.
- **80-line constraint** may be tight for specialists with 8 patterns + full
  anti-pattern tables. Need to check during implementation.
- **Shell-specialist overlap** with harness-engineer needs a clear
  differentiation decision during implementation.
