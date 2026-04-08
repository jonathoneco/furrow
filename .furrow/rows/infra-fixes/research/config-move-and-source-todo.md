# Research: config-move-and-source-todo

## Part A: furrow.yaml Reference Map

### Active Source Files (excluding .furrow/rows/ artifacts)

| File | Line(s) | Path Construction | Relative To | Notes |
|------|---------|-------------------|-------------|-------|
| bin/frw.d/init.sh | 53-106 | `.claude/furrow.yaml` hardcoded | Mixed (PWD for check, FURROW_ROOT for copy) | Copies template, auto-detects project info |
| bin/frw.d/install.sh | 387-393, 551 | `$FURROW_ROOT/.claude/furrow.yaml` → `$TARGET/furrow.yaml` | FURROW_ROOT (source), TARGET (dest) | Template copy during install |
| bin/frw.d/hooks/auto-install.sh | 10-11 | `.claude/furrow.yaml` OR `furrow.yaml` | PWD | **Already checks both candidates** |
| bin/frw.d/hooks/correction-limit.sh | 46-47 | `.claude/furrow.yaml` | PWD | Reads correction_limit |
| bin/frw.d/scripts/cross-model-review.sh | 26 | `$FURROW_ROOT/.claude/furrow.yaml` | FURROW_ROOT (**BUG**) | Reads cross_model.provider |
| bin/frw.d/scripts/launch-phase.sh | 32-38 | `.claude/furrow.yaml` OR `furrow.yaml` | PWD | **Already checks both candidates** |
| bin/frw.d/scripts/run-ci-checks.sh | 7, 30 | `$FURROW_ROOT/.claude/furrow.yaml` | FURROW_ROOT (**BUG**) | Reads CI commands |
| tests/integration/helpers.sh | 50-51 | `${TEST_DIR}/.claude/furrow.yaml` | TEST_DIR | Test setup |
| commands/work.md | 34 | `.claude/furrow.yaml` | Text reference | Pre-flight check |
| commands/init.md | 19, 27 | `.claude/furrow.yaml` | Text reference | Init documentation |
| commands/triage.md | 24 | `furrow.yaml` key `roadmap.template` | Text reference | Triage docs |
| commands/update.md | 5 | `.claude/furrow.yaml` | Text reference | Update docs |

### Migration Plan

**Template source** (in Furrow repo): Move `.claude/furrow.yaml` → `.furrow/furrow.yaml` (or keep as template at install root)

**Consumer project target**: `.furrow/furrow.yaml` (was `.claude/furrow.yaml`)

**Candidate fallback pattern** (already used by 2 files):
```sh
for candidate in .furrow/furrow.yaml .claude/furrow.yaml; do
  if [ -f "$candidate" ]; then
    furrow_yaml="$candidate"
    break
  fi
done
```

**Files requiring update**:
1. `bin/frw.d/init.sh` — change target from `.claude/furrow.yaml` to `.furrow/furrow.yaml`
2. `bin/frw.d/install.sh` — change target directory from `.claude/` to `.furrow/`
3. `bin/frw.d/hooks/correction-limit.sh` — add candidate loop
4. `bin/frw.d/scripts/cross-model-review.sh` — use PROJECT_ROOT + candidate loop
5. `bin/frw.d/scripts/run-ci-checks.sh` — use PROJECT_ROOT + candidate loop
6. `tests/integration/helpers.sh` — update test setup path
7. `commands/work.md`, `commands/init.md`, `commands/update.md` — update text references
8. `.claude/CLAUDE.md` — update topic routing table
9. `.furrow/almanac/rationale.yaml` — update path reference

**Already compatible** (no changes needed):
- `bin/frw.d/hooks/auto-install.sh` — already checks both candidates
- `bin/frw.d/scripts/launch-phase.sh` — already checks both candidates

### Backward Compatibility

The candidate loop ensures existing consumer projects with `.claude/furrow.yaml` continue to work. New projects get `.furrow/furrow.yaml`. No forced migration needed.

---

## Part B: source_todo Flow

### Schema
`schemas/state.schema.json` includes:
```json
"source_todo": {
  "type": ["string", "null"],
  "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$",
  "description": "TODO entry ID this row was created from, or null"
}
```

### Current Flow
1. `rws init` accepts `--source-todo <id>` flag (kebab-case validated)
2. Stored in `state.json` as `source_todo` (string or null)
3. Used during seed integration and archive flow (TODO pruning)
4. **NOT used by `/furrow:next`** — handoff prompts reference roadmap.yaml TODO IDs, not state.json source_todo

### Handoff Template (roadmap.yaml)
```yaml
handoff:
  template: |-
    Start with: `/furrow:work {branch} — {description}`
    Source TODOs in `.furrow/almanac/todos.yaml`: {todo_ids}
    Key files: {key_files}
    See `.furrow/almanac/roadmap.yaml` Phase {phase} for rationale.
```

### Wiring Plan
The `/furrow:next` command (commands/next.md) generates handoff prompts from roadmap.yaml. To wire source_todo:

1. When generating handoff for an existing row (not just roadmap-planned), read `state.json`
2. If `source_todo` is non-null, append to the handoff prompt:
   ```
   Source TODO: `{source_todo}` (see `.furrow/almanac/todos.yaml`)
   ```
3. This is a commands/next.md skill change (text instructions to the agent), not a shell script change

---

## Part C: Cross-Model Ideation Review

### Current Script Behavior
`frw cross-model-review <name> <deliverable>`:
1. Reads definition.yaml → extracts deliverable acceptance criteria
2. Reads evaluation dimensions via `frw select-dimensions`
3. Builds implementation review prompt
4. Invokes codex exec (or claude --model) — **missing approval_policy="never"**
5. Parses JSON response, writes to `reviews/{deliverable}-cross.json`

### Ideation Mode Design

**Detection**: Add `--ideation` flag. When present, use ideation prompt instead of deliverable prompt.

**Ideation prompt inputs**:
- `definition.yaml` → objective, deliverables (names + dependencies), constraints
- `summary.md` → Open Questions section
- Ideation evaluation dimensions (from `evals/gates/ideate.yaml` if available)

**Ideation prompt output format**:
```json
{
  "dimensions": [
    {"name": "feasibility", "verdict": "pass|fail|conditional", "evidence": "..."},
    {"name": "alignment", "verdict": "...", "evidence": "..."},
    {"name": "dependency_validity", "verdict": "...", "evidence": "..."},
    {"name": "risk_assessment", "verdict": "...", "evidence": "..."}
  ],
  "framing_quality": "sound|questionable|unsound",
  "suggested_revisions": ["..."]
}
```

**Output location**: `.furrow/rows/{name}/reviews/ideation-cross.json`

### Codex Fix
Add `-c 'approval_policy="never"'` to both codex exec invocations (lines 120, 128).

## Sources Consulted

- bin/frw.d/init.sh (primary — furrow.yaml creation)
- bin/frw.d/install.sh (primary — furrow.yaml template copy)
- bin/frw.d/hooks/*.sh (primary — furrow.yaml reads)
- bin/frw.d/scripts/*.sh (primary — furrow.yaml reads)
- schemas/state.schema.json (primary — source_todo schema)
- commands/next.md (primary — handoff prompt generation)
- .furrow/almanac/roadmap.yaml (primary — handoff template)
- bin/frw.d/scripts/cross-model-review.sh (primary — current implementation)
