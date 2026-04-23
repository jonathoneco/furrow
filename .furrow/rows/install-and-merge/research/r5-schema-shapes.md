# R5: Schema Shapes — merge-policy.yaml + reintegration.schema.json

Informed by R1 (mutation inventory), R2 (common.sh split), R3 (evidence of
current contamination), and the merge-process-skill + worktree-reintegration-
summary deliverables.

---

## Part A — `schemas/merge-policy.yaml`

### Purpose
Single tracked file listing file globs and their **merge disposition** when
landing a worktree branch into main. /furrow:merge reads this to generate the
resolution plan. `frw doctor` reads it to validate.

### Shape

```yaml
# schemas/merge-policy.yaml
schema_version: "1.0"

# Globs that may NEVER be auto-merged. The merge plan ALWAYS proposes "HEAD
# wins" unless the human overrides per-commit.
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

# Globs whose conflicts can be machine-resolved via sort-by-id (deliverable 1).
# /furrow:merge runs the sort on both sides, then unions by id.
machine_mergeable:
  - path: ".furrow/seeds/seeds.jsonl"
    strategy: "sort-by-id-union"
    key: "id"
  - path: ".furrow/almanac/todos.yaml"
    strategy: "sort-by-id-union"
    key: "id"

# Globs that should default to "prefer ours" (main's version) on conflict
# because any worktree-side change is install-artifact noise.
prefer_ours:
  - path: "bin/*.bak"
    reason: "Install backups should never be in main."
  - path: ".claude/rules/*.bak"
    reason: "Same."
  - path: ".gitignore"
    condition: "diff is entirely under the '# furrow:managed' block"
    reason: "Consumer-project gitignore additions don't belong in source repo."

# Globs that should be DELETED on the merge-produced commit if they appear
# only in the worktree side.
always_delete_from_worktree_only:
  - "bin/*.bak"
  - ".claude/rules/*.bak"

# Optional per-deliverable overrides (not used in v1; room to grow).
overrides: {}
```

### Why this shape

- **Globs, not paths**: evidence from R3 showed 22 symlinks under
  `.claude/commands/specialist:*.md` — one glob covers all of them.
- **`reason` required**: policy is a live doc for humans writing merge plans,
  not just a machine input. Evidence: R3's historical commits all had to
  re-invent the reasoning.
- **Sort-by-id as a first-class strategy**: deliverable 1 commits to it
  anyway; making `/furrow:merge` aware of it means consumer projects get the
  conflict-free merge for free.
- **Machine-mergeable is explicit**: a default-prefer-ours for seeds.jsonl
  would lose worktree-added seeds, which is exactly what we want to avoid.

### Validation
A JSON-Schema peer (`schemas/merge-policy.schema.json`) will be added as part
of merge-process-skill implementation. Shape: required fields `schema_version`,
`protected`, `machine_mergeable`, `prefer_ours`, `always_delete_from_worktree_only`.

---

## Part B — `schemas/reintegration.schema.json`

### Purpose
Machine-readable contract for the `## Reintegration` section in `summary.md`.
Produced by `rws generate-reintegration` at worktree-complete; consumed by
`/furrow:merge` as the primary handoff input.

### Shape (JSON Schema draft-07)

```json
{
  "$schema": "https://json-schema.org/draft-07/schema#",
  "title": "Worktree Reintegration Summary",
  "description": "Structured handoff from a completed worktree to the main session.",
  "type": "object",
  "required": ["schema_version", "row_name", "branch", "commits", "files_changed", "decisions", "open_items", "test_results"],
  "additionalProperties": false,
  "properties": {
    "schema_version": { "const": "1.0" },
    "row_name": {
      "type": "string",
      "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$"
    },
    "branch": {
      "type": "string",
      "description": "Branch name (e.g., work/install-and-merge)."
    },
    "base_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{7,40}$",
      "description": "Commit sha where the branch diverged from main."
    },
    "head_sha": {
      "type": "string",
      "pattern": "^[0-9a-f]{7,40}$"
    },
    "commits": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["sha", "subject", "conventional_type"],
        "additionalProperties": false,
        "properties": {
          "sha": { "type": "string", "pattern": "^[0-9a-f]{7,40}$" },
          "subject": { "type": "string", "maxLength": 100 },
          "conventional_type": {
            "type": "string",
            "enum": ["feat", "fix", "chore", "docs", "refactor", "test", "infra", "merge", "revert"]
          },
          "install_artifact_risk": {
            "type": "string",
            "enum": ["none", "low", "medium", "high"],
            "description": "Audit-phase classification — how likely this commit contains install-artifact contamination."
          }
        }
      }
    },
    "files_changed": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["path_glob", "count"],
        "additionalProperties": false,
        "properties": {
          "path_glob": { "type": "string" },
          "count": { "type": "integer", "minimum": 1 },
          "category": {
            "type": "string",
            "enum": ["source", "test", "doc", "config", "schema", "install-artifact"]
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
          "title": { "type": "string", "maxLength": 120 },
          "resolution": { "type": "string" },
          "rationale": { "type": "string" },
          "ideation_section": {
            "type": "string",
            "description": "Link back to the <!-- ideation:section:... --> marker."
          }
        }
      }
    },
    "open_items": {
      "type": "array",
      "description": "Items that the main session must resolve after merge.",
      "items": {
        "type": "object",
        "required": ["title", "urgency"],
        "additionalProperties": false,
        "properties": {
          "title": { "type": "string" },
          "urgency": { "type": "string", "enum": ["low", "medium", "high"] },
          "suggested_todo_id": { "type": "string" }
        }
      }
    },
    "test_results": {
      "type": "object",
      "required": ["pass"],
      "additionalProperties": false,
      "properties": {
        "pass": { "type": "boolean" },
        "evidence_path": { "type": "string", "description": "Relative path to the test output / log." },
        "skipped": {
          "type": "array",
          "items": { "type": "string" }
        }
      }
    },
    "merge_hints": {
      "type": "object",
      "description": "Direct hints to /furrow:merge. Produced when the worktree agent notices a likely conflict.",
      "additionalProperties": false,
      "properties": {
        "expected_conflicts": {
          "type": "array",
          "items": { "type": "string" }
        },
        "rescue_likely_needed": { "type": "boolean" }
      }
    }
  }
}
```

### Why this shape

- **schema_version**: lets us evolve the contract without breaking
  `/furrow:merge`.
- **commits.install_artifact_risk**: directly feeds /furrow:merge's classify
  phase ("safe / redundant-with-main / destructive / mixed") — the worktree
  is in the best position to label its own commits.
- **files_changed.category**: R3 showed that many commits mix source +
  install-artifact changes; categorizing at write-time is cheaper than
  re-classifying at merge time.
- **decisions.ideation_section**: ties the reintegration back to the marker
  format the ideate skill already uses (`<!-- ideation:section:... -->`) so
  reviewers can trace resolution → original debate.
- **merge_hints**: optional, lets the worktree flag "I touched common.sh,
  consider rescue" so /furrow:merge can prompt for `frw rescue` readiness.

### Relation to summary.md rendering

The markdown section is generated from the JSON via a simple template. The
JSON is the source of truth; the markdown is a view. Round-trip: `rws
update-summary install-and-merge reintegration` accepts the markdown
template only; any machine read uses the JSON.

---

## Sources consulted

| Source | Tier | Contribution |
|---|---|---|
| `.furrow/rows/install-and-merge/research/r1-install-mutations.md` | Primary (R1) | Informs protected-files list (install-produced paths). |
| `.furrow/rows/install-and-merge/research/r2-commonsh-split.md` | Primary (R2) | Informs common-minimal.sh as a protected glob. |
| `.furrow/rows/install-and-merge/research/r3-boundary-evidence.md` | Primary (R3) | Provides real glob patterns (.claude/rules/*, bin/*.bak). |
| `.furrow/rows/install-and-merge/definition.yaml` | Primary (spec) | ACs that the schemas must satisfy. |
| `schemas/definition.schema.json` | Primary (convention) | Style/shape precedent for new schemas. |
| `skills/ideate.md` — ideation:section marker format | Primary | Provides the link format used in `decisions.ideation_section`. |

## Key finding

**The merge policy and the reintegration contract are tightly coupled**: the
worktree classifies its own commits and files at write time (while it has full
context); /furrow:merge reads those classifications and applies the policy.
Building both schemas together avoids a future "the worktree didn't tell us
enough" rework. The shapes above are designed so /furrow:merge needs zero
free-form prose parsing.
