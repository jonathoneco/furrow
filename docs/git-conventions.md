# Git Conventions Reference

Detailed git workflow conventions for Furrow.

## 1. Branch Lifecycle

### Creation
- Branch name: `work/{row-name}` (kebab-case, matches `.furrow/rows/` directory)
- Created at the `decompose->implement` gate boundary by `scripts/create-work-branch.sh`
- Branch starts from current HEAD at creation time
- Recorded in `state.json.branch`

### During Implementation
- Parallel specialists within a wave share the same branch
- File ownership prevents conflicts — no per-specialist branches needed
- Rebase onto main periodically to stay current: `git rebase main`

### After Review
- Branch is merged to main with `scripts/merge-to-main.sh`
- Merge uses `--no-ff` to preserve individual commit history
- Branch deletion is manual (not automated by Furrow)

### Idempotent Checkout
- If the branch already exists (e.g., correction cycle), `create-work-branch.sh`
  checks it out without recreating

## 2. Commit Message Format

### Standard Commits
```
{type}({row-name}): {description}

Deliverable: {deliverable-name}
Step: {step}
```

**Types**: `feat`, `fix`, `chore`, `docs`, `refactor`, `test`

### Gate Commits
```
chore({row-name}): gate pass {from}->{to}

Step: {to}
```

### Merge Commits
```
merge: complete {row-name}

Deliverables: {comma-separated list}
Gate: review pass
```

## 3. Commit Timing

Commits happen at these points:
- After each deliverable is completed within the implement step
- After each gate record is written (state transitions)
- After `summary.md` regeneration at step boundaries
- After `definition.yaml` is finalized (end of ideate)
- After `plan.json` is written (end of decompose)

Pre-branch commits (ideate through decompose) go to the current branch (typically main).
On-branch commits (implement through review) go to `work/{name}`.

## 4. Merge Policy

### Within a Work Branch
- Specialists commit to the shared branch directly
- Commit order is first-complete (no dependency ordering within a wave)
- File ownership prevents overlapping edits

### Back to Main
- Always `--no-ff` merge (never fast-forward, never squash)
- Squash is explicitly disallowed — individual commits provide traceability
- Merge commit preserves the full commit history
- Merge requires the row to be archived (review passed)

## 5. Conflict Resolution

### Prevention
File ownership enforcement (at decompose time and via write hooks) is the
primary conflict prevention mechanism.

### Detection
`scripts/check-wave-conflicts.sh` runs at wave boundaries to detect files
modified outside a specialist's ownership that overlap with another specialist.

### Resolution Escalation
1. Lead agent resolves (shared imports, config)
2. Specialist rework (domain-specific conflicts)
3. User escalation (ambiguous ownership, architectural disagreement)

Conflict resolution commits use type `fix`.

## 6. CI Integration

### Pre-Merge Checks
`scripts/run-ci-checks.sh` runs the project's test suite (configured in
`.claude/furrow.yaml` under `ci`) and produces structured gate evidence
at `gates/implement-to-review-ci.json`.

### Gate Evidence Format
```json
{
  "boundary": "implement->review",
  "ci_run": {
    "tests_total": 142,
    "tests_passed": 142,
    "tests_failed": 0,
    "tests_skipped": 0,
    "duration_seconds": 34,
    "command": "go test ./..."
  },
  "overall": "pass",
  "timestamp": "2026-04-01T10:00:00Z"
}
```

## 7. Row Diff

`scripts/row-diff.sh` produces a `git diff --stat` from `state.json.base_commit`
to HEAD. Used by the review step (Phase A) for plan completion audit — cross-referencing
changed files against deliverable file_ownership globs.
