# Spec: worktree-reintegration-summary

Wave-2 deliverable (plan.json + AD-6). Specialist: harness-engineer. Formalizes
the machine handoff a completed worktree hands to `/furrow:merge`. JSON Schema
is the stable contract; markdown is a view rendered from the JSON.

## Interface Contract

### Files owned (plan.json wave 2)

- `schemas/reintegration.schema.json` — JSON Schema draft-07 contract (NEW).
- `bin/rws` — adds `generate-reintegration` + `get-reintegration-json` subcommands.
- `bin/frw.d/scripts/generate-reintegration.sh` — helper invoked by rws; builds the JSON from state + git + reviews.
- `bin/frw.d/scripts/launch-phase.sh` — one-line hook call on worktree-complete (sole wave-2 edit per AD-8).
- `templates/reintegration.md.tmpl` — markdown skeleton rendered from the JSON.
- `skills/implement.md` — document the worktree-complete hook point.
- `skills/shared/context-isolation.md` — note reintegration as the handoff artifact.
- `tests/integration/test-reintegration.sh` — scenario coverage (see below).

### 1. `schemas/reintegration.schema.json`

Full draft-07 schema, tightened from R5 Part B (stricter patterns, required
fields, descriptions, inline examples).

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "$id": "https://furrow.dev/schemas/reintegration.schema.json",
  "title": "Worktree Reintegration Summary",
  "description": "Structured handoff from a completed worktree to the main session. Produced by `rws generate-reintegration`; consumed by `/furrow:merge` as the sole interface contract. JSON is source of truth; markdown in summary.md is a rendered view.",
  "type": "object",
  "required": [
    "schema_version",
    "row_name",
    "branch",
    "base_sha",
    "head_sha",
    "generated_at",
    "commits",
    "files_changed",
    "decisions",
    "open_items",
    "test_results"
  ],
  "additionalProperties": false,
  "properties": {
    "schema_version": {
      "const": "1.0",
      "description": "Bump on breaking contract changes; `/furrow:merge` refuses unknown versions."
    },
    "row_name": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$",
      "maxLength": 64,
      "description": "Kebab-case row identifier, matching .furrow/rows/<name>/."
    },
    "branch": {
      "type": "string",
      "pattern": "^[A-Za-z0-9._/-]+$",
      "maxLength": 128,
      "description": "Git branch name (e.g., work/install-and-merge)."
    },
    "base_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{7,40}$",
      "description": "Commit sha where the branch diverged from main (git merge-base)."
    },
    "head_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{7,40}$",
      "description": "Tip of the worktree branch at generation time."
    },
    "generated_at": {
      "type": "string",
      "format": "date-time",
      "description": "ISO-8601 UTC timestamp of generation. Drives idempotency: re-generation overwrites if timestamp differs."
    },
    "commits": {
      "type": "array",
      "minItems": 1,
      "items": {
        "type": "object",
        "required": ["sha", "subject", "conventional_type"],
        "additionalProperties": false,
        "properties": {
          "sha": { "type": "string", "pattern": "^[0-9a-f]{7,40}$" },
          "subject": { "type": "string", "minLength": 1, "maxLength": 100 },
          "conventional_type": {
            "type": "string",
            "enum": ["feat", "fix", "chore", "docs", "refactor", "test", "infra", "merge", "revert"],
            "description": "First token before ':' in the commit subject. `merge`/`revert` are recognized variants."
          },
          "install_artifact_risk": {
            "type": "string",
            "enum": ["none", "low", "medium", "high"],
            "default": "none",
            "description": "Worktree's self-assessment of install-artifact contamination. Feeds /furrow:merge classify phase. Elevated to `high` automatically when any touched path matches an `install-artifact` glob (bin/*.bak, .claude/rules/*.bak) or a protected glob from merge-policy.yaml."
          }
        }
      }
    },
    "files_changed": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["path_glob", "count", "category"],
        "additionalProperties": false,
        "properties": {
          "path_glob": {
            "type": "string",
            "minLength": 1,
            "description": "Glob or exact path summarizing one category of touched files."
          },
          "count": {
            "type": "integer",
            "minimum": 1,
            "description": "Number of distinct files matching the glob."
          },
          "category": {
            "type": "string",
            "enum": ["source", "test", "doc", "config", "schema", "install-artifact"],
            "description": "Categorization per R3. `install-artifact` is a hard signal for /furrow:merge to propose prefer-ours."
          }
        }
      }
    },
    "decisions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["title", "resolution", "rationale"],
        "additionalProperties": false,
        "properties": {
          "title": { "type": "string", "minLength": 1, "maxLength": 120 },
          "resolution": { "type": "string", "minLength": 1 },
          "rationale": { "type": "string", "minLength": 1 },
          "ideation_section": {
            "type": "string",
            "pattern": "^ideation:section:[a-z0-9-]+$",
            "description": "Ties back to the <!-- ideation:section:<id> --> marker in summary.md so reviewers can trace resolution → debate."
          }
        }
      }
    },
    "open_items": {
      "type": "array",
      "description": "Items the main session must resolve after merge.",
      "items": {
        "type": "object",
        "required": ["title", "urgency"],
        "additionalProperties": false,
        "properties": {
          "title": { "type": "string", "minLength": 1 },
          "urgency": { "type": "string", "enum": ["low", "medium", "high"] },
          "suggested_todo_id": {
            "type": "string",
            "pattern": "^[a-z][a-z0-9-]*$",
            "description": "Optional: id to create in todos.yaml during /furrow:merge execute phase."
          }
        }
      }
    },
    "test_results": {
      "type": "object",
      "required": ["pass"],
      "additionalProperties": false,
      "properties": {
        "pass": { "type": "boolean" },
        "evidence_path": {
          "type": "string",
          "description": "Relative path under .furrow/rows/<name>/ to the review/test log."
        },
        "skipped": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "merge_hints": {
      "type": "object",
      "description": "Optional advisory flags for /furrow:merge. Always produced (may be empty object).",
      "additionalProperties": false,
      "properties": {
        "expected_conflicts": {
          "type": "array",
          "items": { "type": "string" }
        },
        "rescue_likely_needed": {
          "type": "boolean",
          "description": "True iff any commit touched bin/frw.d/lib/common.sh or bin/frw.d/lib/common-minimal.sh."
        }
      }
    }
  },
  "examples": [
    {
      "schema_version": "1.0",
      "row_name": "install-and-merge",
      "branch": "work/install-and-merge",
      "base_sha": "a284525",
      "head_sha": "deadbeefcafe",
      "generated_at": "2026-04-22T19:00:00Z",
      "commits": [
        { "sha": "deadbeef", "subject": "feat: add reintegration schema", "conventional_type": "feat", "install_artifact_risk": "none" }
      ],
      "files_changed": [
        { "path_glob": "schemas/reintegration.schema.json", "count": 1, "category": "schema" },
        { "path_glob": "bin/rws", "count": 1, "category": "source" }
      ],
      "decisions": [
        { "title": "JSON is source of truth", "resolution": "Render markdown from JSON", "rationale": "Machine consumers don't parse prose.", "ideation_section": "ideation:section:json-vs-markdown" }
      ],
      "open_items": [
        { "title": "Extend schema v1.1 for per-file diff stats", "urgency": "low" }
      ],
      "test_results": { "pass": true, "evidence_path": "reviews/2026-04-22T19-00.md" },
      "merge_hints": { "expected_conflicts": [], "rescue_likely_needed": false }
    }
  ]
}
```

### 2. CLI: `rws generate-reintegration [row-name]`

| Aspect | Contract |
|---|---|
| Arguments | Optional `row-name`. When omitted, falls back to `find_focused_row` / `find_active_rows` (same resolution as `update_summary`). |
| Stdin | Ignored. |
| Stdout | On success: `Generated reintegration section: <summary_path>` (one line). |
| Stderr | Validation errors (schema mismatch, missing git history, missing state). |
| Side effects | Writes JSON to `.furrow/rows/<name>/reintegration.json`; writes rendered markdown into the `## Reintegration` section of `summary.md` via the same atomic `replace_md_section` helper `update_summary` uses; updates `state.json` timestamp. |
| Exit codes | 0 success; 1 usage; 2 row not found; 3 schema validation failed; 4 subprocess (git/jq/yq) failure. Same codes as the rest of rws (`EXIT_*`). |
| Re-runs | Idempotent: re-generation overwrites both `reintegration.json` and the markdown section. `generated_at` is the only non-idempotent field. |

Internals: `rws generate-reintegration` delegates to
`bin/frw.d/scripts/generate-reintegration.sh`, passing the resolved row name.
The helper is a POSIX-sh script (no bash-isms) that:

1. Resolves `<row>/state.json` for `row_name` and `branch`.
2. Computes `base_sha = git merge-base <branch> main`; `head_sha = git rev-parse <branch>`.
3. Walks `git log --no-merges --pretty=format:'%H%x09%s' <base_sha>..<head_sha>` for `commits[]`.
4. Runs `git diff --name-only <base_sha>..<head_sha>` through a categorizer (see Implementation Notes) for `files_changed[]`.
5. Reads the most recent file under `.furrow/rows/<name>/reviews/` (by mtime) for `test_results`.
6. Extracts `decisions[]` from summary.md by matching `<!-- ideation:section:... -->` markers when present.
7. Classifies `install_artifact_risk` and `merge_hints.rescue_likely_needed` from the touched paths.
8. Validates the assembled JSON against `schemas/reintegration.schema.json` using the same validator the rest of rws uses (`jq -f` assertions or an optional `ajv-cli` when available — prefer pure jq for portability).
9. Writes `.furrow/rows/<name>/reintegration.json` atomically (tmp + mv).
10. Renders the markdown via `templates/reintegration.md.tmpl` + `jq` (pure substitution, no shell templating).
11. Calls the internal `replace_md_section` helper on summary.md between the begin/end markers.

### 3. CLI: `rws get-reintegration-json [row-name]`

| Aspect | Contract |
|---|---|
| Purpose | Primary read path for `/furrow:merge` (consumes JSON, never markdown). |
| Arguments | Optional `row-name` (same fallback as generate). |
| Stdout | The `.furrow/rows/<name>/reintegration.json` contents, streamed verbatim. |
| Stderr | Error if file missing, suggesting `rws generate-reintegration`. |
| Exit codes | 0 success; 2 missing reintegration.json; 3 reintegration.json fails schema validation (refuse to return stale/corrupt). |
| Side effects | None. Read-only. |

### 4. summary.md section markers

The `## Reintegration` section in `.furrow/rows/<name>/summary.md` is
delimited by HTML comment markers, not just a heading:

```
## Reintegration
<!-- reintegration:begin -->
{rendered markdown, pure function of reintegration.json + template}
<!-- reintegration:end -->
```

Behavior:

- `rws generate-reintegration` overwrites the range `[begin, end]` atomically.
- If markers are absent, the generator appends a new `## Reintegration` section with both markers at the end of summary.md.
- `rws validate-summary` is extended (minor change) to accept `## Reintegration` as a known section and to require that both markers exist when the section is present. Missing one marker is a validation error (exit 3).
- `rws update-summary <name> reintegration` is **NOT** an accepted section — reintegration is machine-generated only. Attempting it exits 1 with a message pointing to `rws generate-reintegration`.

### 5. `templates/reintegration.md.tmpl`

Template engine: **pure `jq` string-interpolation via `jq -r` templates**. No
`range` / `if` pseudo-syntax — rendering is done by a dedicated jq program
embedded in `bin/frw.d/scripts/generate-reintegration.sh` that walks the JSON
and emits markdown directly. The `.tmpl` file is a **skeleton / header
template**: static markdown that the rendering script concatenates with its
jq-produced sections.

Skeleton contents (literal, no placeholders):

```markdown
<!-- reintegration:begin -->
## Reintegration

_Generated by `rws generate-reintegration`. JSON source of truth at `.furrow/rows/{row}/reintegration.json`._

<!-- reintegration:end -->
```

Rendering algorithm (reference pseudocode for implementers):

```sh
# render_reintegration.sh (invoked by generate-reintegration.sh)
printf '<!-- reintegration:begin -->\n## Reintegration\n\n'
printf '**Branch**: %s  ·  **Range**: %s..%s  ·  Generated: %s\n\n' \
  "$branch" "$base_sha" "$head_sha" "$generated_at"

printf '### Commits (%s)\n' "$(jq '.commits | length' <<<"$json")"
jq -r '.commits[] | "- `\(.sha[0:7])` **\(.conventional_type)** — \(.subject)" +
  (if .install_artifact_risk != "none" then " _(install-artifact risk: \(.install_artifact_risk))_" else "" end)' <<<"$json"

printf '\n### Files Changed\n'
jq -r '.files_changed[] | "- `\(.path_glob)` (\(.count)) — _\(.category // "source")_"' <<<"$json"

printf '\n### Decisions\n'
jq -r '.decisions[] | "- **\(.title)** — \(.resolution) _(why: \(.rationale))_"' <<<"$json"

printf '\n### Open Items\n'
jq -r '.open_items[] | "- [\(.urgency)] \(.title)" +
  (if .suggested_todo_id then " → `\(.suggested_todo_id)`" else "" end)' <<<"$json"

printf '\n### Test Results\n- pass: **%s**' "$(jq '.test_results.pass' <<<"$json")"
evidence=$(jq -r '.test_results.evidence_path // empty' <<<"$json")
[ -n "$evidence" ] && printf ' · evidence: `%s`' "$evidence"
printf '\n'

if [ "$(jq '.merge_hints.rescue_likely_needed // false' <<<"$json")" = "true" ]; then
  printf '\n> **Merge hint**: `frw rescue` may be needed after merge — this worktree touched common.sh.\n'
fi
printf '<!-- reintegration:end -->\n'
```

**No new runtime dependency beyond `jq`** (already required by wave-1 common-minimal.sh). No mustache engine, no `mo` script, no Go templates. The rendering is entirely portable POSIX shell + jq.

### 6. launch-phase.sh hook point

The script currently has no worktree-complete lifecycle event; it only
spawns. Per AD-8, this deliverable is the first wave-2 edit. The minimal
edit adds a single `trap`-based completion hook so that when a tmux session
exits cleanly (worktree complete path), `rws generate-reintegration` runs
against that row before the script exits.

Exact addition (single block appended to the row-processing loop,
conditional on a `FURROW_AUTO_REINTEGRATE=${FURROW_AUTO_REINTEGRATE:-1}`
env var so the existing launch-only behavior can be preserved in CI):

```sh
  # Hook: generate reintegration summary when the worktree's primary session ends.
  # Runs out-of-band via tmux set-hook so the launcher itself remains non-blocking.
  if [ "${FURROW_AUTO_REINTEGRATE:-1}" = "1" ]; then
    tmux set-hook -t "$session_name" session-closed \
      "run-shell 'cd \"$(cd "$worktree_dir" && pwd)\" && rws generate-reintegration \"$row_name\" >/dev/null 2>&1 || true'"
  fi
```

Rationale:
- `tmux set-hook` is already an implicit dep (tmux is in the preflight).
- The `|| true` preserves the hands-off nature of launch-phase.sh; a failure
  to generate does not break the launcher.
- The hook runs `rws generate-reintegration` from the worktree's cwd, so
  `git`/`state.json` resolution is correct.

### 7. `/furrow:merge` consumption contract

`/furrow:merge` reads the JSON via `rws get-reintegration-json <name>`.
It does **not** parse the markdown. If `rws get-reintegration-json` exits
non-zero, `/furrow:merge` must refuse to proceed (there's no reintegration
handoff to act on). This is spec'd here (not in merge-process-skill) to
lock in the interface from the producer side.

## Acceptance Criteria (Refined)

- **AC-R1** (from def AC 1): `summary.md` contains `## Reintegration` delimited by
  `<!-- reintegration:begin -->` / `<!-- reintegration:end -->`. Generated by
  `rws generate-reintegration`; `rws update-summary <name> reintegration`
  rejects with exit 1 pointing at `generate-reintegration`.
  *Testable by*: generate then grep both markers; attempt update-summary → non-zero exit.

- **AC-R2** (from def AC 2): `schemas/reintegration.schema.json` exists,
  is draft-07, and every field enumerated in the "Interface Contract" section
  above is present with the declared pattern/enum. `jq`-based validation
  against a known-good example passes; against a fixture missing any required
  field fails with a message naming the missing field.
  *Testable by*: `tests/integration/test-reintegration.sh` scenario "schema round-trip".

- **AC-R3** (from def AC 3): `rws generate-reintegration <row>` invoked on
  a row with at least one commit, a state.json, and a review record produces
  (a) `.furrow/rows/<row>/reintegration.json` that validates against the
  schema, and (b) a rendered `## Reintegration` section in summary.md with
  both markers, in under 2 seconds on a 10-commit branch.
  *Testable by*: scenario "synthetic worktree".

- **AC-R4** (from def AC 4): `rws get-reintegration-json <row>` exits 0 and
  emits the canonical JSON verbatim; exits 2 if `reintegration.json` is
  missing; exits 3 if it fails schema validation. No markdown is ever emitted
  on this path.
  *Testable by*: three-shot scenario "merge-consumer contract".

- **AC-R5** (from def AC 5): `templates/reintegration.md.tmpl` exists and
  contains the literal skeleton markdown shown in §5 (static header + both
  markers, no placeholders — rendering is performed by the jq-driven
  `generate-reintegration.sh`). The generator must reference this template
  by path (`templates/reintegration.md.tmpl`) and concatenate it with
  jq-rendered sections — verified by (a) file existence + byte-for-byte
  match against the canonical skeleton in the test fixture, and (b)
  `grep -c '{{' templates/reintegration.md.tmpl` = 0 (asserts no
  placeholder drift).
  *Testable by*: scenario "template fallback".

- **AC-R6** (from def AC 6): Round-trip through `rws generate-reintegration`
  → read `reintegration.json` → re-generate → read again produces byte-
  identical JSON **except** for `generated_at`. No field is dropped; no
  field is reordered non-deterministically (jq `--sort-keys` is used).
  *Testable by*: scenario "idempotency + round-trip".

## Test Scenarios

All scenarios live in `tests/integration/test-reintegration.sh`, POSIX sh,
sourcing no common.sh (hook-safe), using a temp git repo fixture.

### Scenario: schema round-trip
- **Verifies**: AC-R2, AC-R6.
- **WHEN**: the fixture generates a known-good `reintegration.json`, the test validates it with jq against the schema, round-trips through `jq -S .` twice, and re-validates.
- **THEN**: exit 0; all fields preserved; key ordering stable.
- **Verification**: `diff <(jq -S . out1.json) <(jq -S . out2.json)` is empty after stripping `generated_at`.

### Scenario: synthetic worktree
- **Verifies**: AC-R3.
- **WHEN**: the fixture repo has 3 commits (`feat: x`, `fix: y`, `chore: z`), `state.json` with the row, and a `reviews/<ts>.md` with `pass: true`, then `rws generate-reintegration` runs.
- **THEN**: `reintegration.json` is written; `commits[]` has length 3 with the expected `conventional_type` values; `test_results.pass == true`; schema validation succeeds; summary.md contains both markers.
- **Verification**: `jq '.commits | length == 3 and (map(.conventional_type) == ["feat","fix","chore"])' reintegration.json` returns true.

### Scenario: install-artifact detection
- **Verifies**: AC-R3 (classifier behavior).
- **WHEN**: the fixture's last commit touches `bin/rws.bak`.
- **THEN**: that commit's `install_artifact_risk == "high"`; its `files_changed[]` entry has `category == "install-artifact"`; `merge_hints.rescue_likely_needed == false` (because common.sh untouched).
- **Verification**: `jq '.commits[-1].install_artifact_risk == "high"'`.

### Scenario: template fallback
- **Verifies**: AC-R5.
- **WHEN**: a fresh row has no prior `## Reintegration` section; `rws generate-reintegration` is invoked.
- **THEN**: the template file is read verbatim from `templates/reintegration.md.tmpl`; the rendered markdown is appended with both markers; schema-valid JSON is produced.
- **Verification**: byte-level compare of rendered output against a golden file; checksum of the template file matches the committed one.

### Scenario: rescue hint on common.sh touch
- **Verifies**: AC-R3 (hint logic).
- **WHEN**: the fixture includes one commit touching `bin/frw.d/lib/common.sh`.
- **THEN**: `merge_hints.rescue_likely_needed == true`; the rendered markdown contains the "frw rescue may be needed" blockquote.
- **Verification**: `jq '.merge_hints.rescue_likely_needed == true'` + grep for "frw rescue" in summary.md.

### Scenario: merge-consumer contract
- **Verifies**: AC-R4.
- **WHEN**: (a) reintegration.json missing → `rws get-reintegration-json` exits 2; (b) reintegration.json present and valid → exits 0 with JSON on stdout; (c) reintegration.json present but intentionally corrupted (drop `schema_version`) → exits 3.
- **THEN**: exit codes as stated; stdout is pure JSON in (b) (parseable by `jq .`).
- **Verification**: three assertions in the test script.

### Scenario: idempotency + round-trip
- **Verifies**: AC-R6.
- **WHEN**: generate twice back-to-back.
- **THEN**: both `reintegration.json` files are byte-identical modulo `generated_at`; both `summary.md` sections are byte-identical.
- **Verification**: `diff` after `jq 'del(.generated_at)'`.

### Scenario: update-summary rejects reintegration section
- **Verifies**: AC-R1 (guard).
- **WHEN**: `echo "stuff" | rws update-summary <row> reintegration`.
- **THEN**: exit 1; stderr points to `rws generate-reintegration`.
- **Verification**: captured stderr contains "generate-reintegration".

## Implementation Notes

- **JSON is source of truth**. Markdown rendering is a pure function of
  `reintegration.json + templates/reintegration.md.tmpl`. Never hand-write
  markdown for this section.
- **No bash-isms** (AD + project constraint): target POSIX sh on both GNU
  and BSD userlands; all array-like logic goes through `jq`.
- **Key stability**: `jq --sort-keys` on every write to guarantee byte-
  stable JSON under re-generation.
- **Input sources** (in priority order for each field):
  - `row_name`, `branch`: `.furrow/rows/<name>/state.json`.
  - `base_sha`: `git merge-base <branch> main` (fallback: first commit on the branch).
  - `head_sha`: `git rev-parse <branch>`.
  - `commits[]`: `git log --no-merges --pretty=format:'%H%x09%s' <base>..<head>`; conventional_type = first token before `:`; anything unparseable defaults to `chore`.
  - `files_changed[]`: `git diff --name-only <base>..<head>`, grouped by category. Category assignment (R3):
    - `install-artifact` — matches `*.bak`, `bin/*.bak`, `.claude/rules/*.bak`, `.gitignore` (when diff is within `# furrow:managed` block).
    - `schema` — matches `schemas/*.json`, `schemas/*.yaml`.
    - `test` — matches `tests/**`, `*_test.go`, `test-*.sh`.
    - `doc` — matches `docs/**`, `*.md`.
    - `config` — matches `.furrow/*.yaml`, `.furrow/furrow.yaml`, `*.yaml` outside schemas/.
    - `source` — everything else.
  - `decisions[]`: scan summary.md for `<!-- ideation:section:<id> -->` markers; extract title + resolution via local heuristics (the next `### ` heading + first paragraph). Absence → empty array, which is schema-valid.
  - `open_items[]`: from the most recent review record's "Open Items" section if present; else empty.
  - `test_results`: from the most recent file under `reviews/` (by mtime). Absence → `{ "pass": false, "evidence_path": null }` **after** schema allows it; to keep schema tight we require at least `{ "pass": false }`.
  - `merge_hints.rescue_likely_needed`: true iff `git diff --name-only <base>..<head>` matches `bin/frw.d/lib/common.sh` or `bin/frw.d/lib/common-minimal.sh`.
- **launch-phase.sh edit scope**: single `tmux set-hook` block, gated by
  `FURROW_AUTO_REINTEGRATE` env var. No other changes to the launcher.
  Per AD-8, wave-1 did not touch this file; wave-2 is the first editor.
- **Validation strategy**: ship a minimal jq program that walks the schema's
  `required` arrays and `pattern`/`enum` clauses. Avoid a hard dependency on
  `ajv-cli`; if present, prefer it (faster), else fall back to the jq
  validator. Record the chosen validator in `rationale.yaml`.
- **Atomic writes**: `.tmp.$$ + mv` pattern for both `reintegration.json`
  and summary.md, mirroring existing rws helpers.
- **No state.json writes** beyond the existing `update_state "$name" "."`
  timestamp bump already used by `update_summary`.

## Dependencies

### Upstream (wave 1 — must land first)

- `.furrow/SOURCE_REPO` sentinel (from install-architecture-overhaul).
  Whether reintegration *runs* does not depend on it — source-repo worktrees
  still generate. Consumers (`/furrow:merge`) may ignore the output based on
  the sentinel.
- `bin/frw.d/lib/common-minimal.sh` — this deliverable's helper sources it
  for `log_error` / `log_warning` only. Hook-safe subset per AD-1.
- Seeds/todos sort-by-id landed in wave 1 — no direct dep, but relevant
  because the reintegration may reference `suggested_todo_id`.

### Upstream (wave 2 sibling)

- `config-cleanup` runs in parallel. File ownership is disjoint (plan.json
  `parallel_safety`): reintegration owns `bin/rws` + `schemas/reintegration`
  + `launch-phase.sh`; config-cleanup owns `bin/frw` + `schemas/definition`
  + `schemas/state` + `upgrade.sh`. No coordination needed.

### Downstream (wave 3)

- `merge-process-skill` (wave 3) consumes via `rws get-reintegration-json`
  only. This spec locks the producer side of that interface; the consumer
  side is spec'd in merge-process-skill's spec.

### External tools

- `jq` (>= 1.6) — JSON parsing, schema validation, templating.
- `yq` — already used by launch-phase.sh; not newly introduced.
- `git` (>= 2.20) — `merge-base`, `log`, `diff`.
- `tmux` — already a preflight in launch-phase.sh; the `set-hook` feature
  used here is available in tmux >= 2.3 (predates any supported distro).

### Internal APIs reused

- `resolve_row_dir`, `find_focused_row`, `find_active_rows` — from bin/rws.
- `extract_md_section`, `replace_md_section` — from bin/rws; used to place
  the rendered markdown between the begin/end markers.
- `update_state "$name" "."` — timestamp bump, consistent with other
  summary operations.
