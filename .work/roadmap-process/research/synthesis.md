# Research Synthesis: /work-roadmap Command

## 1. Schema Extension (todos-schema-extension)

**Single source**: `adapters/shared/schemas/todos.schema.yaml` — no JSON copy to sync (unlike definition.schema which had YAML/JSON drift). Validation script (`scripts/validate-todos.sh`) converts YAML→JSON at runtime via yq.

**Critical constraint**: `additionalProperties: false` — every new field must be added to the `properties` object.

**Only consumer**: `/work-todos` command reads/writes todos.yaml. No other scripts parse todo fields. Zero breakage risk from additive optional fields.

**New fields to add** (all optional):
- `depends_on`: array of TODO IDs (same pattern as deliverable `depends_on` in definition.yaml)
- `files_touched`: array of file glob patterns (similar to `references` but for ownership)
- `urgency`: enum `critical | high | medium | low`
- `impact`: enum `high | medium | low`
- `effort`: enum `small | medium | large`
- `phase`: integer (assigned by roadmap generation)
- `status`: enum `active | done | blocked | deferred`

**Existing prose data**: Current TODO entries already contain dependency/urgency/impact language in `context` and `work_needed` fields — Claude can extract this for initial triage.

## 2. Template System (roadmap-template)

**ROADMAP.md section types** (from current manual roadmap):
1. Header — title, updated date, phase status
2. Dependency DAG — ASCII graph with phase grouping, `──` (hard dep), `···` (independent)
3. Legend — graph notation key
4. File Conflict Zones — table: Zone | Files | TODOs affected
5. Phase sections (repeating) — `## Phase N — {Title} — {Status}`, tracks with branch/files/conflicts
6. Worktree Quick Reference — shell commands per phase

**Existing template patterns**: `templates/` directory has research templates using `{placeholder}` syntax. `regenerate-summary.sh` uses heredoc + `${var}` substitution + awk section extraction + atomic writes — this is the rendering model.

**Template design**:
- `templates/roadmap.md.tmpl` — markdown with section markers and `{placeholder}` slots
- `templates/roadmap-sections.yaml` — section registry: name, required/optional, order, repeating flag
- Resolution: `harness.yaml` config > `.claude/roadmap.tmpl` > harness default

## 3. Triage Script (triage-script)

**Reusable from generate-plan.sh**:
- Kahn's algorithm with BFS wave assignment (Python subprocess, lines 66-137)
- Pattern: shell reads YAML via yq, pipes JSON to Python for graph ops, jq for output assembly
- Wave assignment: `wave(node) = max(wave(deps)) + 1`, wave 1 for no-dep nodes
- Cycle detection: compare topo-sort output length to input length

**Reusable from check-wave-conflicts.sh**:
- Glob-to-regex: `gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")`
- Per-pair conflict detection: for each TODO pair, check files_touched overlap

**Tools**: yq 4.52.4, jq 1.8.1, python3 3.14.0 — all via mise.

**Output structure** for triage-todos.sh:
```json
{
  "todos": [...with triage data per entry],
  "graph": { "topo_order": [...], "waves": [...], "cycles": [] },
  "conflicts": [{ "todo_a": "id1", "todo_b": "id2", "overlapping_files": [...] }]
}
```

## 4. Command Skill (command-skill)

**Standard command pattern** (from analysis of 7 existing commands):
1. Header: `# /command-name [args] [--flags]` + one-line description
2. Syntax block with arrow annotations
3. Context Detection (detect-context.sh or name argument)
4. Behavior (numbered steps)
5. Validation (validate before write)
6. Output (what user sees)

**Flag conventions**: `--flagname` or `--flagname value`. Mutually exclusive flags documented explicitly.

**For /work-roadmap**:
- Read-only state.json access (no mutations — roadmap is an output artifact)
- Calls `scripts/triage-todos.sh` for dependency graph + conflict data
- Claude reads script output + todo prose to make grouping/phasing decisions
- Presents phase grouping proposal for user confirmation
- Writes ROADMAP.md via template rendering
- Git commit: `chore: generate roadmap` or `docs: refresh ROADMAP.md`
- `--full` flag for complete regeneration vs incremental update

**Confirmation pattern** (from work-todos.md):
- Present proposals with numbering
- User responds: `ok` (accept all), `{number}: {action}` (override), `cancel` (abort)

## Key Decisions for Plan Step

1. **triage-todos.sh adapts generate-plan.sh pattern** — shell + Python subprocess, not pure shell
2. **Template uses existing `{placeholder}` convention** from templates/ directory
3. **Command follows work-todos.md structure** as closest pattern match
4. **No state.json mutations** — roadmap command is read-only for harness state
5. **Schema extension is purely additive** — single file change, zero breakage
