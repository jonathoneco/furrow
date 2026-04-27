---
layer: shared
---
# Merge Protocol

Reference for the `/furrow:merge` five-phase flow. Loaded by the merge-specialist
during merge-step sessions.

---

## Overview

Every merge of a worktree branch into main follows five sequential phases:

```
audit → classify → resolve-plan → execute → verify
```

Each phase writes machine-readable JSON artifacts to the merge-state directory.
Markdown is a rendered view; JSON is the source of truth. No phase parses
`summary.md` prose.

---

## Merge-state directory

```
$XDG_STATE_HOME/furrow/{repo-slug}/merge-state/{merge-id}/
├── audit.json         # Phase 1 output
├── classify.json      # Phase 2 output
├── classify.md        # Phase 2 rendered table
├── plan.json          # Phase 3 output (requires human approval)
├── plan.md            # Phase 3 human-readable plan
├── execute.json       # Phase 4 output
├── verify.json        # Phase 5 output
└── awaiting/          # Sentinel files for human-decides paths
```

---

## Phase 1: Audit (`merge-audit.sh`)

**Input**: branch name, policy path  
**Output**: `audit.json` with `merge_id`  
**Primary source**: `rws get-reintegration-json <row>` — embedded verbatim as `audit.json.reintegration_json`

Detects:
- Symlink typechanges on protected paths
- Install-artifact additions (`bin/*.bak`, `.claude/rules/*.bak`)
- Overlapping commits (cherry-pick duplicates from main)
- Stale `source_todos`/roadmap references
- `common.sh` syntax validity on both sides (`sh -n`)

**Exit 3**: blockers found. Human must resolve before proceeding.

---

## Phase 2: Classify (`merge-classify.sh`)

**Input**: `merge_id`  
**Output**: `classify.json`, `classify.md`  
**Primary signal**: `audit.json.reintegration_json.commits[].install_artifact_risk`

Labels each worktree commit:
| Label | Meaning |
|---|---|
| `safe` | Pure source change; no contamination signals |
| `redundant-with-main` | Already in main (cherry-pick) |
| `destructive` | Install artifacts or protected-path symlink |
| `mixed` | Source changes + destructive content |

**Exit 4**: any destructive or mixed commit.

---

## Phase 3: Resolve-plan (`merge-resolve-plan.sh`)

**Input**: `merge_id`  
**Output**: `plan.json` (approved: false, inputs_hash), `plan.md`  
**Policy**: `schemas/merge-policy.yaml` (repo-tracked)

Category precedence (first match wins):
1. `protected` → `human-decides` / `human-edit` (NEVER auto-resolved)
2. `machine_mergeable` → `sort-by-id-union`
3. `prefer_ours` → `ours` (main wins on conflict)
4. `always_delete_from_worktree_only` → `delete`
5. Unmatched → `auto` (git three-way merge)

**Approval gate**: operator sets `"approved": true` in `plan.json` after reviewing `plan.md`.  
**Re-running** resolve-plan replaces both artifacts and resets approval.

---

## Phase 4: Execute (`merge-execute.sh`)

**Input**: `merge_id`  
**Pre-flight**:
1. Re-hash inputs (audit.json + classify.json + policy). Mismatch → exit 5.
2. Confirm `plan.json.approved == true`. Not approved → exit 5.
3. Check `awaiting/` sentinels. Any present → exit 5 (human has not resolved).

**Execute loop**: applies each resolution via git. Then `git merge --no-commit --no-ff <branch>`.  
**Deviation check**: unplanned conflict → exit 6 with `deviations[]`.  
**Post-merge**: `sh -n common.sh`. Failure → exit 8.

**Exit 8 recovery**:
```
./bin/frw.d/scripts/rescue.sh --apply
/furrow:merge <branch> --resume <merge-id>
```
Rescue is operator-invoked (never automatic). Do not abort merge-in-progress.

---

## Phase 5: Verify (`merge-verify.sh`)

**Input**: `merge_id`  
**Output**: `verify.json` with per-check `pass/fail + evidence`

Six checks:
1. `frw doctor` exits 0
2. No `bin/*` deletion in merge diff
3. All hook/script `.sh` files pass `sh -n`
4. `rws validate-sort-invariant` (seeds + todos sorted)
5. `rescue.sh` callable (diagnose-only exits 0 or 1)
6. `rescue.sh --baseline-check` (drift → exit 3 = verify failure)

**Exit 7**: any check fails.

---

## Merge policy

`schemas/merge-policy.yaml` is repo-tracked and schema-validated by
`schemas/merge-policy.schema.json`. All five scripts refuse to start on
an invalid policy (exit 2).

**Protected-file rule is absolute**: any protected-path conflict → `human-decides`.
Never propose a machine resolution for a protected path.

---

## Resume semantics

After an exit-8 or exit-6 abort:

```
/furrow:merge <branch> --resume <merge-id>
```

- If `plan.json` exists and `approved == true`: skip audit/classify/resolve-plan; re-run execute + verify.
- If `plan.json` missing or not approved: restart from audit.

---

## Key invariants

1. **JSON is source of truth**. Never parse `summary.md` prose.
2. **Protected paths are human-decides**. No exceptions.
3. **Rescue is out-of-band**. Execute exits 8; operator runs rescue; operator resumes.
4. **Re-running resolve-plan resets approval**. Always review after regenerating.
5. **inputs_hash guards the plan**. If audit/classify/policy changes, re-plan.
