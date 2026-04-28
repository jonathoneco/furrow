# /furrow:merge

Reserved command design. This slash command and `furrow merge` are not
implemented in the Go CLI; this document is retained as historical planning
material, not live operator procedure.

Five-phase worktree merge command. Brings a completed worktree branch into main
with a human-approved resolution plan, machine-readable artifacts, and
post-merge invariant verification.

## Invocation

```
/furrow:merge <worktree-name-or-branch> [--dry-run] [--skip-verify] [--policy <path>] [--resume <merge-id>]
```

## Arguments

| Argument | Required | Default | Purpose |
|---|---|---|---|
| `<worktree-name-or-branch>` | yes (unless `--resume`) | — | Row name (resolves to `work/<name>`) or explicit branch. |
| `--dry-run` | no | off | Runs audit + classify + resolve-plan only. Does NOT execute or verify. |
| `--skip-verify` | no | off | Runs through execute but skips verify. Forbidden in CI. |
| `--policy <path>` | no | `schemas/merge-policy.yaml` | Override policy file (test-fixture support). |
| `--resume <merge-id>` | no | — | Re-enter a prior merge after exit-8 rescue recovery. Reuses the merge-state directory; skips audit/classify if `plan.json` exists. Used after `./bin/frw.d/scripts/rescue.sh --apply`. |

## Exit Codes

| Code | Meaning |
|---|---|
| 0 | All five phases completed; main is clean. |
| 1 | Usage error. |
| 2 | Preflight failed (row not archived, branch missing, policy invalid). |
| 3 | Audit surfaced blockers requiring human intervention. |
| 4 | Classify found destructive commits; human must edit plan. |
| 5 | Resolve-plan artifact missing, not approved, or stale (hash mismatch). |
| 6 | Execute aborted on plan deviation. |
| 7 | Verify caught a regression (hook syntax, sort invariant, bin/ deletion, rescue broken). |
| 8 | common.sh broken mid-merge; `frw rescue` invocation recommended. |

---

## Phase 1: Audit

**Script**: `bin/frw.d/scripts/merge-audit.sh`
**Invocation**: `frw_merge_audit <branch> <policy_path>`
**Output**: `merge-state/{merge-id}/audit.json`
**Stdout**: `merge_id=<uuid>` on success.

The audit phase calls the legacy `rws get-reintegration-json <row>`
compatibility wrapper and embeds the result
verbatim in `audit.json.reintegration_json`. All downstream scripts read commit
classifications from `audit.json.reintegration_json.commits[].install_artifact_risk`
— they never parse `summary.md` prose.

Detects:
- Symlink-ification of protected paths (regular → symlink typechange).
- Install-artifact additions (`bin/*.bak`, `.claude/rules/*.bak`).
- Overlapping commits between main and the branch (cherry-pick duplicates).
- Stale `source_todos` / roadmap references (todos.yaml ids not in roadmap.yaml).
- `common.sh` syntax validity on both sides (`sh -n` on ours + theirs blob).

If the audit finds blockers, it exits 3. The merge command surfaces the
`audit.json.blockers[]` list and stops. The operator must resolve blockers
before re-running.

---

## Phase 2: Classify

**Script**: `bin/frw.d/scripts/merge-classify.sh`
**Invocation**: `frw_merge_classify <merge_id>`
**Output**: `merge-state/{merge-id}/classify.json` + `classify.md`

Reads `audit.json.reintegration_json` and classifies each worktree commit:

| Label | Meaning |
|---|---|
| `safe` | Pure source change; no install-artifact risk. |
| `redundant-with-main` | Commit (or equivalent) already in main. |
| `destructive` | Adds install artifacts or turns protected file into symlink. |
| `mixed` | Combines safe changes with destructive ones. |

Exits 4 if any commit is `destructive` or `mixed`. The operator reviews
`classify.md` before proceeding to resolve-plan.

---

## Phase 3: Resolve-plan

**Script**: `bin/frw.d/scripts/merge-resolve-plan.sh`
**Invocation**: `frw_merge_resolve_plan <merge_id> [--regenerate]`
**Output**: `merge-state/{merge-id}/plan.json` + `plan.md`

Reads `audit.json` + `classify.json`, applies `merge-policy.yaml` category
rules, and emits the resolution plan:

- **Protected paths**: any conflict → `category: "human-decides"`, `strategy: "human-edit"`. Never auto-resolved.
- **machine_mergeable**: resolved via `sort-by-id-union`.
- **prefer_ours**: main wins on conflict.
- **Unmatched**: left as `auto` for git's default three-way merge.

`plan.json.approved` defaults to `false`. The operator edits `plan.md`,
changes the `<!-- approved:yes -->` marker, then re-runs resolve-plan to
confirm (re-running resets approval to false again — the approved state is
set by the operator editing `plan.json` directly, setting `"approved": true`).

**Re-running resolve-plan replaces both artifacts** and resets approval.
Execute refuses to proceed unless `plan.json.approved == true`.

---

## Phase 4: Execute

**Script**: `bin/frw.d/scripts/merge-execute.sh`
**Invocation**: `frw_merge_execute <merge_id>`
**Output**: `merge-state/{merge-id}/execute.json`

Pre-flight:
1. Re-hashes inputs (audit.json + classify.json + policy content). If
   `plan.json.inputs_hash` mismatches, exits 5 — re-run resolve-plan.
2. Confirms `plan.json.approved == true`. If not, exits 5.

Applies each resolution in order:
- `ours`: `git checkout --ours <path>` + `git add`.
- `theirs`: `git checkout --theirs <path>` + `git add`.
- `delete`: `git rm <path>`.
- `sort-by-id-union`: runs `bin/frw.d/scripts/merge-sort-union.sh` then `git add`.
- `human-edit`: checks `merge-state/{id}/awaiting/{path}` sentinel; if present,
  the human hasn't resolved it yet — exits 5.

If an unplanned conflict appears (a path not in `plan.json`), exits 6 leaving
the merge-in-progress state intact; records deviation in `execute.json.deviations[]`.

Post-merge: runs `sh -n bin/frw.d/lib/common.sh`. If it fails, records
`execute.json.commonsh_broken = true` and exits 8.

**Exit 8 recovery** — if execute exits 8:
```
common.sh no longer parses after merge.
Run: ./bin/frw.d/scripts/rescue.sh --apply
Then: /furrow:merge <branch> --resume <merge-id>
Do NOT abort the merge-in-progress until rescue completes.
```

---

## Phase 5: Verify

**Script**: `bin/frw.d/scripts/merge-verify.sh`
**Invocation**: `frw_merge_verify <merge_id>`
**Output**: `merge-state/{merge-id}/verify.json`

Post-merge checklist (exits 7 if any check fails):

1. `frw doctor` exits 0.
2. No `bin/*` path was deleted by the merge (git-diff against `base_sha`).
3. All shell files under `bin/frw.d/` parse cleanly (`sh -n`).
4. `seeds.jsonl` and `todos.yaml` satisfy sort invariant through the legacy
   `rws validate-sort-invariant` compatibility wrapper.
5. `rescue.sh` is callable: `sh -n` passes AND invoking `rescue.sh` without
   `--apply` returns exit 0 or 1 (existence check only — rescue is out-of-band).
6. `common-minimal.sh` matches `rescue.sh`'s bundled baseline (`rescue.sh --baseline-check`
   exits 0 or 1; exit 3 = drift = verify failure).

`verify.json` records per-check `pass/fail` and evidence.

---

## Resume semantics (`--resume`)

If execute exits 8 (common.sh broken) or 6 (plan deviation), the operator
may rescue and re-enter the merge:

```
/furrow:merge <branch> --resume <merge-id>
```

Resume behavior:
- If `plan.json` exists and is approved: skip audit, classify, resolve-plan.
  Jump directly to execute (re-running from clean state).
- If `plan.json` missing or unapproved: restart from audit.
- `execute.json` is overwritten by the resumed run.

---

## Merge-state directory

All phase artifacts live under:

```
$XDG_STATE_HOME/furrow/{repo-slug}/merge-state/{merge-id}/
├── audit.json
├── classify.json
├── classify.md
├── plan.json
├── plan.md
├── execute.json
├── verify.json
└── awaiting/           # sentinel files for human-decides paths
```

The `merge-id` is a short UUID generated by the audit phase. Directories
survive aborts for post-mortem inspection. Clean up with:
`frw merge-cleanup <merge-id>` (not in scope for v1 — leave stale directories).

---

## Dry-run

`--dry-run` short-circuits after resolve-plan. No `git merge` is invoked;
the working tree is untouched. Use this to preview the resolution plan before
committing to execute.

---

## Policy

The merge policy lives at `schemas/merge-policy.yaml` (repo-tracked). All five
scripts refuse to start if the policy fails schema validation
(`schemas/merge-policy.schema.json`), exiting 2 with a stderr message naming
the invalid field path.

Override the policy path (e.g., for test fixtures) with `--policy <path>`.
