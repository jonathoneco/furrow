# Spec: merge-specialist

## File
`specialists/merge-specialist.md`

## Format
YAML frontmatter (name: merge-specialist, description, type: specialist) followed by 5 sections per `references/specialist-template.md`.

## Content Outline

### Domain Expertise (1-2 paragraphs)
- Merge decisions in a structured workflow with parallel execution (waves), file ownership, and gate enforcement
- Covers wave-level merges (worktree branches) and row-to-main merges (archived work → main)

### How This Specialist Reasons (8 patterns)
1. **Pre-merge readiness** — Verify archived state, branch existence, clean working tree before any merge
2. **Rebase-before-merge discipline** — When to rebase work branch onto main (during implementation), when it's dangerous (post-push, shared branches)
3. **Conflict detection as ownership audit** — Use file_ownership globs from plan.json to predict mergeability; unplanned changes are warnings
4. **No-ff merge as traceability** — Individual commits preserved for bisect/blame; never squash, never fast-forward
5. **Wave-aware merging** — Validate inter-wave consistency; single-branch + ownership is default, worktrees are optional
6. **Post-merge verification** — CI/tests pass, working tree clean, summary updated, no orphaned branches
7. **Escalation paths** — Lead agent (shared imports/config) → specialist (domain-specific) → user (ambiguous ownership)
8. **Bootstrap acknowledgment** — This specialist cannot guide its own inaugural merge; first merge uses scripts/merge-to-main.sh directly

### Quality Criteria (prose)
- Every merge has a pre-check (archived?, branch exists?, tests pass?)
- Merge commit messages include deliverables and gate evidence
- No force-pushes to main/master
- Conflict resolution commits use type `fix`

### Anti-Patterns Table
| Pattern | Why It's Wrong | Do This Instead |
|---------|---------------|-----------------|
| Fast-forward merge | Loses merge boundary, breaks bisect | Always --no-ff |
| Squash merge | Destroys individual commit traceability | Preserve all commits |
| Merge before archive | Bypasses gate enforcement | Archive first, then merge |
| Force-push to resolve conflicts | Rewrites shared history | Rebase locally, merge cleanly |
| Skip CI after merge | Merge can introduce subtle issues | Run full test suite post-merge |

### Context Requirements
- Required: `scripts/merge-to-main.sh`, `docs/git-conventions.md`, `state.json` schema
- Required: `bin/rws` check_wave_conflicts function (line ~803)
- Helpful: `plan.json` wave/assignment structure
- Helpful: `specialists/migration-strategist.md` for rebase reasoning patterns

## Registration
Add entry to `specialists/_meta.yaml`:
```yaml
merge-specialist:
  file: merge-specialist.md
  description: "Merge strategy, conflict detection, and post-merge validation for Furrow workflows"
```
