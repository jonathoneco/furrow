# Spec: merge-process-skill

Deliverable in row `install-and-merge`, wave 3. Ships `/furrow:merge` as a
five-phase command (audit → classify → resolve-plan → execute → verify) that
operates on a worktree branch with a human-approved resolution plan and a
repo-tracked policy file (`schemas/merge-policy.yaml`). Also fixes a
long-standing script-guard heredoc false positive (AC 8).

The deliverable depends on waves 1 (install-architecture-overhaul) and 2
(config-cleanup, worktree-reintegration-summary). It consumes XDG state,
`frw rescue`, and `rws get-reintegration-json` as foundations.

---

## Interface Contract

### 1. `commands/merge.md` — `/furrow:merge` command

Markdown command, no YAML frontmatter (matches existing pattern of
`commands/review.md`, `commands/doctor.md`).

**Invocation**

```
/furrow:merge <worktree-name-or-branch> [--dry-run] [--skip-verify] [--policy <path>] [--resume <merge-id>]
```

**Arguments**

| Argument | Required | Default | Purpose |
|---|---|---|---|
| `<worktree-name-or-branch>` | yes (unless `--resume`) | — | Either a row name (resolves to `work/{name}`) or an explicit branch name. |
| `--dry-run` | no | off | Runs audit + classify + resolve-plan; does NOT execute or verify. |
| `--skip-verify` | no | off | Runs through execute but skips verify. Forbidden in CI. |
| `--policy <path>` | no | `schemas/merge-policy.yaml` | Override policy file path (test-fixture support). |
| `--resume <merge-id>` | no | — | Re-enter a previously-started merge after exit-8 rescue recovery; reuses the merge-state directory and skips audit/classify if `plan.json` already exists. Used after running `rescue.sh --apply`. |

**Exit codes**

| Code | Meaning |
|---|---|
| 0 | All five phases completed; main is clean. |
| 1 | Usage error. |
| 2 | Preflight failed (not archived, branch missing, policy invalid). |
| 3 | Audit surfaced blockers that require human intervention. |
| 4 | Classify found destructive commits; human must edit plan. |
| 5 | Resolve-plan artifact missing or stale (hash mismatch). |
| 6 | Execute aborted on plan deviation. |
| 7 | Verify caught a regression (hook syntax, sort invariant, bin/ deletion, rescue broken). |
| 8 | common.sh broken mid-merge; `frw rescue` invocation recommended. |

**Body (five phases)**

The command body in `commands/merge.md` dispatches to five independent scripts
under `bin/frw.d/scripts/`:

1. **Audit** — `frw_merge_audit <branch> <policy>` → writes
   `merge-state/{merge-id}/audit.json`.
2. **Classify** — `frw_merge_classify <merge-id>` → writes
   `classify.json` + `classify.md`.
3. **Resolve-plan** — `frw_merge_resolve_plan <merge-id>` → writes
   `plan.json` + `plan.md`. Prompts human to edit `plan.md`; re-run to
   regenerate (replacing both).
4. **Execute** — `frw_merge_execute <merge-id>` → verifies plan hash,
   performs `git merge` with planned resolutions, writes `execute.json`.
5. **Verify** — `frw_merge_verify <merge-id>` → runs post-merge checks,
   writes `verify.json`.

Each phase reads prior outputs from the merge-state directory; the command
orchestrates ordering and prompts the human at phase boundaries.

### 2. `schemas/merge-policy.yaml`

Repo-tracked file declaring globs and their merge disposition. Literal
contents (finalized from R5 Part A, glob syntax = `fnmatch(3)` with `**`
glob-star supported):

```yaml
# schemas/merge-policy.yaml
#
# Policy governing how /furrow:merge resolves file conflicts when landing a
# worktree branch into main. Globs use fnmatch(3) semantics with the
# following extensions:
#   - "**" matches any path segments (including zero).
#   - "*" does NOT cross "/" boundaries.
#   - "?" matches a single non-"/" character.
#   - Trailing "/*" matches direct children only.
# Paths are matched relative to the repo root. First matching category wins,
# evaluated in this order: protected -> machine_mergeable -> prefer_ours ->
# always_delete_from_worktree_only.
schema_version: "1.0"

# NEVER auto-merged. On any conflict here, the merge plan records
# "human-decides" and execute refuses to proceed without an edited plan.
protected:
  - path: "bin/alm"
    reason: "Top-level CLI; worktree install flow turns it into a symlink."
  - path: "bin/rws"
    reason: "Top-level CLI; same risk as bin/alm."
  - path: "bin/sds"
    reason: "Top-level CLI; same risk as bin/alm."
  - path: ".claude/rules/*"
    reason: "Rules shouldn't be install-produced symlinks."
  - path: "bin/frw.d/lib/common.sh"
    reason: "Hook cascade — a bad merge here blocks every tool call until rescue."
  - path: "bin/frw.d/lib/common-minimal.sh"
    reason: "Hook-safe subset. Same concern."
  - path: "schemas/*.json"
    reason: "Breaking schema changes should go through a conscious review."
  - path: "schemas/*.yaml"
    reason: "Same."

# Conflicts here are machine-resolved via the named strategy.
machine_mergeable:
  - path: ".furrow/seeds/seeds.jsonl"
    strategy: "sort-by-id-union"
    key: "id"
    sort_tuple: ["created_at", "id"]
  - path: ".furrow/almanac/todos.yaml"
    strategy: "sort-by-id-union"
    key: "id"
    sort_tuple: ["created_at", "id"]

# Default "prefer ours" (main wins) on conflict.
prefer_ours:
  - path: "bin/*.bak"
    reason: "Install backups should never be in main."
  - path: ".claude/rules/*.bak"
    reason: "Same."
  - path: ".gitignore"
    condition: "diff is entirely under the '# furrow:managed' block"
    reason: "Consumer-project gitignore additions don't belong in source repo."

# Deleted on the merge-produced commit if they appear only on the worktree side.
always_delete_from_worktree_only:
  - "bin/*.bak"
  - ".claude/rules/*.bak"
  - "**/.bak"

# Per-deliverable overrides (v1: unused; reserved for future).
overrides: {}
```

### 3. `schemas/merge-policy.schema.json`

JSON Schema (draft-07) validating `merge-policy.yaml`. Key rules:
- `schema_version` required, must equal `"1.0"`.
- `protected`, `machine_mergeable`, `prefer_ours`,
  `always_delete_from_worktree_only` all required.
- Each `protected` entry has required `path` (string) and `reason` (string).
- Each `machine_mergeable` entry has required `path`, `strategy`, `key`;
  `strategy` is enum `["sort-by-id-union"]`. Future strategies extend.
- `prefer_ours` entries have required `path`, `reason`; optional `condition`.
- `always_delete_from_worktree_only` is an array of glob strings.
- `additionalProperties: false` at every level.
- Consumed by `frw doctor` (lints the policy) and all five merge subphase
  scripts (they refuse to start on a malformed policy).

### 4. `bin/frw.d/scripts/merge-audit.sh`

```
frw_merge_audit <branch> <policy_path>

Exits:
  0 — audit produced; see merge-state/{merge-id}/audit.json
  1 — usage
  2 — branch missing / policy invalid / not archived
  3 — audit found blockers (proceed with caution)
Stdout: single line "merge_id=<uuid>" on success.
Stderr: human-readable summary.
```

Detects (per AC 2): symlink-ification of protected files, overlapping commits
between main and the branch, install-artifact additions, stale row/TODO
references (todos.yaml ids not in roadmap.yaml), common.sh syntax validity on
both sides (`sh -n` on ours + theirs tree-blob).

Produces `audit.json`:
```json
{
  "schema_version": "1.0",
  "merge_id": "<uuid>",
  "branch": "work/<name>",
  "base_sha": "<sha>",
  "head_sha": "<sha>",
  "policy_path": "schemas/merge-policy.yaml",
  "policy_sha256": "<hex>",
  "symlink_typechanges": [{"path": "...", "from": "file", "to": "symlink"}],
  "protected_touches": [{"path": "...", "side": "worktree"|"main"|"both"}],
  "install_artifact_additions": ["bin/alm.bak", "..."],
  "overlap_commits": [{"sha": "...", "subject": "...", "side": "main"}],
  "stale_references": {"todos": ["id1"], "rows": []},
  "commonsh_parse": {"ours": true, "theirs": true},
  "blockers": ["..."],
  "reintegration_json": {"...": "verbatim from rws get-reintegration-json"}
}
```

### 5. `bin/frw.d/scripts/merge-classify.sh`

```
frw_merge_classify <merge_id>

Exits:
  0 — classification produced; all commits safe or redundant
  4 — one or more destructive/mixed commits found
Stdout: merge-state path to classify.json
```

Classifies each worktree-side commit into one of four labels
(AC 3): `safe`, `redundant-with-main`, `destructive`, `mixed`. Uses
`audit.json.reintegration_json.commits[].install_artifact_risk` as the primary
signal, cross-checked against git-diff against main.

Produces `classify.json` (machine) + `classify.md` (rendered table).

### 6. `bin/frw.d/scripts/merge-resolve-plan.sh`

```
frw_merge_resolve_plan <merge_id> [--regenerate]

Exits:
  0 — plan artifact written to merge-state/{merge-id}/plan.{json,md}
  5 — required human approval marker missing (first run writes plan; operator edits; re-run confirms)
Stdout: path to plan.md for human to review.
```

Reads `audit.json` + `classify.json`, applies `merge-policy.yaml` category
rules, and emits a **resolve plan artifact**:

- `plan.json` — machine-readable list of per-path resolutions. Fields:
  ```json
  {
    "schema_version": "1.0",
    "merge_id": "...",
    "inputs_hash": "sha256 of audit.json + classify.json + policy content",
    "approved": false,
    "approved_at": null,
    "approved_by": null,
    "resolutions": [
      {"path": "...", "category": "protected|machine_mergeable|prefer_ours|auto|human-decides",
       "strategy": "ours|theirs|sort-by-id-union|delete|human-edit",
       "rationale": "...", "conflict": true}
    ]
  }
  ```
- `plan.md` — human-readable rendering with a `<!-- approved:yes -->` marker
  that the human toggles after editing. Approval is explicit.

Re-running resolve-plan **replaces** both artifacts (AC 5 / Implementation
Notes). `execute` refuses to proceed unless `plan.json.approved == true` AND
`plan.json.inputs_hash` matches a fresh recomputation (protects against stale
audit.json being used with an edited plan).

**Protected-file rule**: any `path` matched by `policy.protected` that has a
conflict is written with `category: "human-decides"`, `strategy:
"human-edit"`. The script NEVER writes a machine resolution for a protected
conflict — even if only one side changed it, the plan asks the human.

### 7. `bin/frw.d/scripts/merge-execute.sh`

```
frw_merge_execute <merge_id>

Exits:
  0 — merge committed on main; merge_sha recorded in execute.json
  5 — plan missing / not approved / hash mismatch
  6 — plan deviation mid-merge (an unplanned conflict appeared)
  8 — common.sh broken after merge; rescue recommended
```

Pre-flight:
1. Re-parse policy, re-hash inputs, compare to `plan.json.inputs_hash`. On
   mismatch, abort with exit 5 (tells the human to re-run resolve-plan).
2. Confirm `plan.json.approved == true`.

Execute loop (per path in resolutions, deterministic order):
- `ours`: `git checkout --ours <path>` then `git add <path>`.
- `theirs`: `git checkout --theirs <path>` then `git add <path>`.
- `delete`: `git rm <path>`.
- `sort-by-id-union`: invoke
  `bin/frw.d/scripts/merge-sort-union.sh <path> <key> <sort_tuple>` then
  `git add`. The script unions records from both sides, de-dups by `key`,
  sorts by tuple with `LC_ALL=C` (matches AD-4).
- `human-edit`: writes a sentinel file
  `merge-state/{merge-id}/awaiting/{path}`; aborts with exit 5 if that file
  wasn't manually removed (signaling the human resolved it in-tree).

After all resolutions applied, runs `git merge --no-ff --no-commit`
equivalent then produces the merge commit.

Deviation check: if a conflict appears for a path NOT in `plan.json`, or a
planned path is no longer in conflict, abort with exit 6, leaving the
working tree on the merge-in-progress state and writing
`execute.json.deviations[]`.

Post-execute `sh -n bin/frw.d/lib/common.sh`: if it fails, write
`execute.json.commonsh_broken = true` and exit 8. `commands/merge.md` catches
exit 8 and recommends `frw rescue --apply` to the operator. Rescue is NOT
invoked automatically mid-merge (out-of-band per AD-2).

### 8. `bin/frw.d/scripts/merge-verify.sh`

```
frw_merge_verify <merge_id>

Exits:
  0 — all post-merge checks pass
  7 — one or more post-merge regressions
```

Runs the post-merge checklist (AC 7):

1. `frw doctor` — must exit 0.
2. No `bin/*` path was deleted by the merge (git-diff against `base_sha`).
3. All shell files under `bin/frw.d/` parse (`sh -n`).
4. `.furrow/seeds/seeds.jsonl` and `.furrow/almanac/todos.yaml` satisfy the
   sort invariant (`rws validate-sort-invariant`, added in wave 1 —
   see `spec-install-architecture-overhaul.md` §"`rws validate-sort-invariant`").
5. `bin/frw.d/scripts/rescue.sh` is callable: `sh -n` passes AND invoking
   `rescue.sh` WITHOUT `--apply` (diagnose-only default) returns exit 0 or 1
   (anything else is a rescue tooling regression). This is the existence check,
   not a repair invocation — rescue is out-of-band per AD-2.
6. `bin/frw.d/lib/common-minimal.sh` matches bundled heredoc in `rescue.sh`
   (AD-2 drift check) — invoke `rescue.sh --baseline-check` and treat exit 3
   as a verify failure.

Writes `verify.json` with per-check pass/fail and evidence paths.

### 9. Merge-state directory

All five scripts read/write under:

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

`merge-id` is a short UUID generated by audit. Directory survives aborts and
is cleaned by `frw merge-cleanup {merge-id}` (not in scope for this
deliverable; leave stale directories for post-mortem).

### 10. `bin/frw.d/hooks/script-guard.sh` — heredoc fix

Replace the current substring-match body with a token-aware guard:

1. Shell-tokenize `command_str` (POSIX-style, respecting `'...'`, `"..."`,
   and `<<EOF ... EOF` heredocs). Implement with a small state-machine
   helper `shell_tokenize()` in `skills/shared/merge-protocol.md` or inline.
   No bash-isms (POSIX sh only).
2. For each token, test:
   - If the token is a **command token** (position 0 of the command, or
     follows a pipe/semicolon/`&&`/`||`), retain current allowlist logic.
   - If the token is a **data token inside a quoted string or heredoc**,
     never block.
3. Specifically, the string `bin/frw.d/scripts/merge-execute.sh` appearing
   inside a `git commit -m "..."` argument or a `<<EOF` heredoc passes the
   guard.

Behavior when `jq` is unavailable or `.tool_input.command` is null: fail-open
(return 0) as today; the guard is advisory belt-and-suspenders.

### 11. Rescue integration

`commands/merge.md` catches exit 8 from execute and prompts:

> common.sh no longer parses after merge. Run `./bin/frw.d/scripts/rescue.sh
> --apply` and then `/furrow:merge <branch> --resume` (resume flag reuses
> the same merge-id). Do NOT abort the merge-in-progress until rescue
> completes.

`merge-verify.sh` check 5 confirms rescue is callable. Rescue is invoked
by the operator, not by any merge script, preserving AD-2's out-of-band
constraint.

---

## Acceptance Criteria (Refined)

### AC 1 — Command file exists with five-phase body
`commands/merge.md` exists; its body references the five script names
(`merge-audit.sh`, `merge-classify.sh`, `merge-resolve-plan.sh`,
`merge-execute.sh`, `merge-verify.sh`) in that order; `--dry-run`,
`--skip-verify`, and `--policy <path>` are documented.
**Verification**: `grep -c 'merge-audit\|merge-classify\|merge-resolve-plan\|merge-execute\|merge-verify' commands/merge.md` >= 5.

### AC 2 — Audit phase detects all contamination classes
`merge-audit.sh`, given a branch with any of: (a) regular→symlink
typechange on a protected path, (b) install-artifact addition
(`bin/*.bak`, `.claude/rules/*.bak`), (c) overlap commit with main,
(d) stale `source_todos` / roadmap reference, (e) a `common.sh` that
fails `sh -n` on either side — populates the corresponding
`audit.json` field with a non-empty list AND includes a short English
blocker message in `audit.json.blockers[]` when severity warrants.
**Verification**: fixture test (see Scenario 1).

### AC 3 — Classify produces machine + human artifacts
`merge-classify.sh` writes `classify.json` (every worktree commit
appears with label in `{"safe", "redundant-with-main", "destructive",
"mixed"}`) and `classify.md` (markdown table with columns: sha,
subject, label, rationale). Exits 4 if any commit is `destructive` or
`mixed`.
**Verification**: JSON-schema validation on output; markdown table
column count; exit code.

### AC 4 — Policy is tracked, schema-validated, and loaded
`schemas/merge-policy.yaml` is committed. `schemas/merge-policy.schema.json`
validates it. All five merge scripts refuse to start when the policy
fails schema validation, with exit 2 and a stderr message naming the
invalid field path.
**Verification**: `ajv validate -s schemas/merge-policy.schema.json -d schemas/merge-policy.yaml` exits 0; intentional corruption produces exit 2.

### AC 5 — Resolve-plan produces approved-gate artifact
`merge-resolve-plan.sh` writes `plan.json` + `plan.md` from policy
application. `plan.json.approved` defaults false; an explicit
`<!-- approved:yes -->` marker in `plan.md` or `plan.json.approved =
true` is required before execute proceeds. Re-running resolve-plan
replaces both artifacts and resets approval to false.
**Verification**: run once, confirm `approved == false`; edit marker,
re-run resolve-plan, confirm `approved == false` again.

### AC 6 — Execute applies approved plan and aborts on deviation
`merge-execute.sh` exits 5 when `plan.json.approved != true` OR
`plan.json.inputs_hash` no longer matches a fresh recomputation. Given
an approved plan, applies each resolution in order; if an unplanned
conflict appears, exits 6 leaving the merge-in-progress state intact
and recording `execute.json.deviations[]` with path + reason.
**Verification**: Scenario 4.

### AC 7 — Post-merge verify catches six regression classes
`merge-verify.sh` exits 7 when any of: (a) `frw doctor` fails, (b) any
`bin/*` file deletion present in merge diff, (c) any `bin/frw.d/**/*.sh`
fails `sh -n`, (d) seeds.jsonl or todos.yaml violate sort invariant
(via `rws validate-sort-invariant` exit 3), (e) `rescue.sh` is not
callable (invoked without `--apply` as a diagnose-only probe — exit 0 or
exit 1 is fine; any other code fails), (f) `common-minimal.sh` has
drifted from `rescue.sh`'s bundled baseline (via `rescue.sh --baseline-check`
exit 3). `verify.json` records per-check evidence.
**Verification**: six per-check fixtures (Scenario 5).

### AC 8 — Script-guard heredoc false positive fixed
`bin/frw.d/hooks/script-guard.sh`, invoked with
`{"tool_input":{"command": "git commit -m 'refactor: tweak bin/frw.d/scripts/merge-execute.sh'"}}`,
returns 0. Same invocation with the path OUTSIDE a quoted string (e.g.,
`./bin/frw.d/scripts/merge-execute.sh foo`) still returns 2.
**Verification**: Scenario 6 (regression test).

### AC 9 — Reintegration JSON is the primary input
`merge-audit.sh` calls `rws get-reintegration-json <row>` at start
and embeds the returned object verbatim under
`audit.json.reintegration_json`. If the call fails (row not archived,
no reintegration section), audit exits 2 with a message pointing at
`/furrow:status`. Downstream scripts read commit classifications from
`audit.json.reintegration_json.commits[].install_artifact_risk` rather
than reparsing `summary.md` prose.
**Verification**: grep the merge scripts for any `grep`/`sed`/`awk`
against `summary.md` — must return zero matches.

### AC 10 — End-to-end fixture produces clean main
`tests/integration/test-merge-e2e.sh` drives a fixture repo through
all five phases. The fixture (see Implementation Notes — contaminated
worktree) exercises: install-artifact additions, one protected-file
conflict (`bin/alm` typechange), machine-mergeable conflict
(`todos.yaml`), and two feature commits. After human-edit of the plan
to resolve the `bin/alm` conflict with `ours`, execute succeeds,
verify exits 0, `frw doctor` reports green, and `git log --oneline
main` shows the merge commit with no `bin/alm` deletion.
**Verification**: Scenario 7.

---

## Test Scenarios

### Scenario 0: Command file structure + resume path
- **Verifies**: AC 1.
- **WHEN**: (a) `commands/merge.md` is parsed for frontmatter and body structure; (b) `/furrow:merge --resume <merge-id>` is invoked against a merge-state directory whose `plan.json` exists and whose `execute.json` recorded exit 8.
- **THEN**: (a) file exists, YAML frontmatter present, body contains the literal heading `## Phase 1: Audit` (and similarly 2–5 for Classify/Resolve-plan/Execute/Verify), in that order; `--dry-run`, `--skip-verify`, `--policy`, and `--resume` are each documented at least once in the body. (b) The resume invocation re-runs execute and verify against the existing `plan.json` WITHOUT re-running audit/classify/resolve-plan; new `execute.json` overwrites the exit-8 prior record.
- **Verification**: `tests/integration/test-merge-command-file.sh` — grep-based structural check + a fixture `merge-state/{id}/` directory exercising `--resume`.

### Scenario 1: Audit catches all four historical contamination classes
- **Verifies**: AC 2.
- **Fixture**: `tests/integration/fixtures/merge-contamination/` — bare git
  repo with four pre-cooked branches replaying the R3 commits:
  `b/f067df9` (destructive-merge revert), `b/a6eb8ff` (bin/ deletion +
  gitignore addition), `b/8b6a63a` (symlink revert), `b/c432926` (symlink
  escape). Each branched from a common ancestor.
- **WHEN**: `frw merge audit b/f067df9 schemas/merge-policy.yaml` is run for
  each of the four branches.
- **THEN**: `audit.json.blockers[]` is non-empty for each; the label set on
  `protected_touches[].path` matches the expected R3 evidence
  (bin/alm, bin/rws, bin/sds, .claude/rules/*).
- **Verification**: per-branch golden `audit.json.expected` committed to
  the fixture; test diffs generated against golden.

### Scenario 2: Classify labels map correctly
- **Verifies**: AC 3.
- **Fixture**: synthetic branch with four commits — one pure-source feature
  (`safe`), one cherry-picked from main (`redundant-with-main`), one
  `bin/*.bak` addition + regular→symlink on `bin/alm` (`destructive`), one
  feature + install-artifact combined (`mixed`).
- **WHEN**: `frw merge classify <merge_id>` runs after a successful audit.
- **THEN**: `classify.json[].label` values match the four expected labels
  in order; exit code is 4.
- **Verification**: jq assertions + exit code check.

### Scenario 3: Resolve-plan matches golden fixture
- **Verifies**: AC 5.
- **Fixture**: contaminated worktree from Scenario 2 plus a
  `todos.yaml` conflict (id-overlap on both sides).
- **WHEN**: resolve-plan runs with the canonical policy.
- **THEN**: `plan.json` diffs cleanly against
  `fixtures/merge-contamination/golden/plan.json` (ignoring `merge_id`
  and `inputs_hash` with `jq del(.merge_id, .inputs_hash)`).
- **Verification**: `diff <(jq 'del(.merge_id,.inputs_hash)' plan.json) golden/plan.json` returns empty.

### Scenario 4: Execute aborts when plan deviates
- **Verifies**: AC 6.
- **WHEN**: after a successful resolve-plan + manual approval, the operator
  edits a protected file in the working tree between approval and execute
  (simulating a race or deliberate tampering).
- **THEN**: execute detects hash mismatch (exit 5) OR plan deviation
  during merge (exit 6) depending on the path edited. `execute.json`
  records the deviation.
- **Verification**: two sub-cases scripted; each asserts its specific exit
  code and a non-empty `deviations[]` or `abort_reason` field.

### Scenario 5: Post-merge verify catches six regression classes
- **Verifies**: AC 7.
- **Six sub-fixtures**, each simulating one failure mode:
  1. `frw doctor` pre-broken (stale rationale entry).
  2. `bin/alm` deleted on the merge commit.
  3. A hook with a syntax error (`bin/frw.d/hooks/broken.sh`).
  4. `todos.yaml` written out-of-order by a bad merge.
  5. `rescue.sh` missing execute bit (sh -n still passes, but invocation
     fails).
  6. `common-minimal.sh` has a function `rescue.sh`'s heredoc doesn't
     include (drift).
- **WHEN**: verify runs post-execute on each fixture.
- **THEN**: exit 7; `verify.json.checks[].pass == false` for the expected
  check only; other checks pass.
- **Verification**: jq-based per-fixture assertion.

### Scenario 6: Script-guard heredoc regression
- **Verifies**: AC 8.
- **Inputs**: five `tool_input.command` strings:
  1. `git commit -m 'fix: bin/frw.d/scripts/merge-execute.sh typo'` → allow.
  2. `git commit -m "refactor: bin/frw.d/hooks/script-guard.sh"` → allow.
  3. heredoc: `cat <<EOF\nbin/frw.d/scripts/merge-execute.sh\nEOF` → allow.
  4. `./bin/frw.d/scripts/merge-execute.sh foo` → block (exit 2).
  5. `bin/frw.d/scripts/merge-execute.sh; echo hi` → block (exit 2).
- **THEN**: exit codes match expected per-case.
- **Verification**: `tests/integration/test-script-guard-heredoc.sh` runs
  all five cases.

### Scenario 7: End-to-end — contaminated worktree to clean main
- **Verifies**: AC 10.
- **Fixture**: a purpose-built bare repo
  `tests/integration/fixtures/merge-contamination/e2e/` with:
  - One `feat:` commit (pure source change).
  - One `chore:` commit adding `bin/alm.bak`.
  - One commit turning `bin/alm` from regular into a symlink.
  - One commit appending two ids to `todos.yaml` that collide with main.
- **WHEN**: operator runs `/furrow:merge work/e2e-row`, edits `plan.md` to
  set the `bin/alm` resolution to `ours`, marks approved, resumes execute,
  runs verify.
- **THEN**: merge commit lands on main, `bin/alm` remains a regular file,
  `bin/alm.bak` is absent, `todos.yaml` is sorted with the union of ids,
  `frw doctor` exits 0, `verify.json.overall == "pass"`.
- **Verification**: `git log --oneline main | head -1` shows the merge;
  `file bin/alm | grep -v symbolic` succeeds; `jq '.overall' verify.json`
  returns `"pass"`.

### Scenario 8: Policy schema validation
- **Verifies**: AC 4.
- **WHEN**: a corrupted `schemas/merge-policy.yaml` (missing
  `schema_version`, or `machine_mergeable[].strategy` = "invalid") is
  passed via `--policy`.
- **THEN**: all five scripts exit 2 with stderr naming the failing field
  (e.g., `merge-policy.yaml: missing required field .schema_version`).
- **Verification**: per-corruption golden stderr messages.

---

## Implementation Notes

- **Five subphases are independent scripts**, orchestrated by
  `commands/merge.md`. Each reads the prior's JSON artifact from
  `$XDG_STATE_HOME/furrow/{repo-slug}/merge-state/{merge-id}/`. This keeps
  each script small, testable in isolation, and resumable after operator
  edits.
- **Protected-file rule is absolute**: any conflict matching a
  `policy.protected[].path` glob writes `category: "human-decides"` in
  `plan.json`. Never propose a resolution. The human edits the plan or
  aborts. This is stricter than "prefer ours" on protected paths because
  worktree-side changes to (e.g.) `common.sh` may legitimately be the
  intended change — only the human can decide.
- **`sort-by-id-union` strategy** (AD-4):
  1. Parse both sides' records (JSONL for seeds.jsonl; YAML list for
     todos.yaml).
  2. Index by `key` (default `id`); union, last-writer-wins on duplicate
     keys with a warning in `execute.json.warnings[]`.
  3. Sort by `sort_tuple` (default `["created_at", "id"]`) with `LC_ALL=C`.
  4. Write back preserving jq-friendly one-object-per-line for JSONL;
     preserving anchor/alias if present for YAML (yq handles this).
- **Resolve-plan is the artifact humans edit**. Re-running resolve-plan
  overwrites both `plan.json` and `plan.md` and resets approval. Execute
  re-hashes inputs (audit.json + classify.json + policy content) and
  compares to `plan.json.inputs_hash`; a mismatch means the inputs
  changed after the plan was written, and the human must re-run
  resolve-plan before executing.
- **Script-guard heredoc fix — tokenization**:
  - Implement `shell_tokenize` as a POSIX-sh state machine with states
    `normal`, `single_quote`, `double_quote`, `heredoc`.
  - Track command-token position: after `|`, `;`, `&&`, `||`, newline,
    or at start-of-string.
  - Only test path matches against tokens in `normal` state AND at
    command-token position. Heredoc body and quoted string contents are
    skipped entirely for path matching.
  - A helper reference: the plan.md tokenizer behaves like
    `shlex` in quote-aware mode; write tests first (Scenario 6) and
    iterate until green.
- **End-to-end fixture location**:
  `tests/integration/fixtures/merge-contamination/` (bare git repo with
  four pre-cooked branches) and
  `tests/integration/fixtures/merge-contamination/e2e/` (a more elaborate
  contaminated worktree for Scenario 7). Fixtures are created by a
  one-shot setup script `tests/integration/fixtures/merge-contamination/setup.sh`
  that is idempotent and checked into the repo (but the resulting `.git`
  directory is `.gitignore`'d — re-run setup.sh to generate).
- **`frw rescue` integration is deliberately out-of-band**. `merge-execute.sh`
  can exit 8 ("common.sh broken") but never invokes rescue itself.
  `commands/merge.md` surfaces the exit-8 message to the operator with the
  exact rescue invocation to run. This preserves AD-2's "rescue sources
  nothing from the thing it repairs" principle even when rescue lives in the
  same process tree.
- **Portability**: POSIX sh only. `jq` and `yq` (go-yq, `kislyuk/yq`, or
  `mikefarah/yq` — the install script decides based on availability) are
  required dependencies; `merge-audit.sh` checks for both and exits 2 if
  missing.
- **Consumption of `rws get-reintegration-json`**: wave 2 adds this
  subcommand. It reads `summary.md`'s `<!-- reintegration:begin --> ...
  <!-- reintegration:end -->` region, validates against
  `schemas/reintegration.schema.json`, and emits JSON on stdout. Exit
  codes: 0 ok, 2 section missing, 3 schema-invalid. Merge-audit calls it
  and embeds the JSON verbatim.
- **No merge commit is produced on `--dry-run`**. The flag short-circuits
  after resolve-plan; no `git merge` is invoked, working tree is
  untouched.

---

## Dependencies

### Upstream deliverables (plan.json)
- **install-architecture-overhaul** (wave 1) — XDG state dir, `frw rescue`
  (AD-2), common-minimal.sh split (AD-1), sort-on-write for seeds.jsonl +
  todos.yaml (AD-4), CI contamination-check script (AD-9).
- **config-cleanup** (wave 2) — XDG config tier, `source_todos` array
  schema (already landed, AD-5).
- **worktree-reintegration-summary** (wave 2) —
  `schemas/reintegration.schema.json`, `rws generate-reintegration`, `rws
  get-reintegration-json`.

### External tools
- `git` (>= 2.30, for `git merge-tree` and `--no-commit` semantics).
- `jq` (>= 1.6).
- `yq` (either `mikefarah/yq` v4+ or `kislyuk/yq` — setup.sh picks; wave 1
  install-state records which).
- POSIX `sh` (not bash-specific).

### Schemas
- `schemas/merge-policy.yaml` (new; tracked).
- `schemas/merge-policy.schema.json` (new; tracked).
- `schemas/reintegration.schema.json` (wave 2) — read-only consumer.

### Scripts and libraries (this deliverable)
- `bin/frw.d/scripts/merge-audit.sh` — new.
- `bin/frw.d/scripts/merge-classify.sh` — new.
- `bin/frw.d/scripts/merge-resolve-plan.sh` — new.
- `bin/frw.d/scripts/merge-execute.sh` — new.
- `bin/frw.d/scripts/merge-verify.sh` — new.
- `bin/frw.d/scripts/merge-sort-union.sh` — new; helper for
  `sort-by-id-union` strategy.
- `bin/frw.d/hooks/script-guard.sh` — modified (heredoc fix).
- `bin/frw` — dispatcher gains `merge audit|classify|resolve-plan|execute|verify|sort-union`
  subcommands. Existing `merge-to-main` subcommand (see
  `bin/frw.d/scripts/merge-to-main.sh`) remains; `/furrow:merge` invokes
  the new five-phase flow instead.
- `skills/shared/merge-protocol.md` — new; protocol doc the merge
  specialist loads during merge-step sessions. Documents the
  five-phase ordering, the approval-gate semantics, and the rescue
  escape hatch.
- `commands/merge.md` — new.

### Tests
- `tests/integration/test-merge-audit.sh`
- `tests/integration/test-merge-classify.sh`
- `tests/integration/test-merge-resolve-plan.sh`
- `tests/integration/test-merge-execute.sh`
- `tests/integration/test-merge-verify.sh`
- `tests/integration/test-merge-e2e.sh`
- `tests/integration/test-script-guard-heredoc.sh`
- `tests/integration/test-merge-policy-schema.sh`
- `tests/integration/fixtures/merge-contamination/setup.sh`
- `tests/integration/fixtures/merge-contamination/golden/*.json`
