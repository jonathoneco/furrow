# Spec: rename-to-furrow

## Overview
Rename project namespace from "harness" to "furrow" across all non-archived files, preceded by a denormalization audit to ensure each piece of information has a single source of truth.

## Pre-Step: Denormalization Audit

### Audit 1: Command table drift
- **Source of truth**: `install.sh` `_harness_block` template (lines 274-296)
- **Check**: Compare CLAUDE.md injected block (`<!-- harness:start -->` to `<!-- harness:end -->`) against install.sh template
- **Fix**: If diverged, delete CLAUDE.md block and re-run install.sh to regenerate
- **AC**: After rename, install.sh is sole owner of the command table content

### Audit 2: Other content duplication
- **Scan**: architecture description in docs/architecture/file-structure.md, docs/research/findings-gap-review.md, .claude/CLAUDE.md
- **Decision**: Accept as intentional — different audiences, different levels of detail
- **No action required**

## Phase 1: Mechanical Replacements (Category A)

Execute in order (most specific patterns first to avoid partial matches):

### 1a. Variable names (sed -E, all .sh files excluding archived .work/)
```
HARNESS_ROOT → FURROW_ROOT
harness_root → furrow_root
_harness_yaml → _furrow_yaml
_harness_config → _furrow_config
harness_config → furrow_config
```
**Files**: All `.sh` files in `hooks/`, `scripts/`, `commands/lib/`, `tests/integration/`, `install.sh`
**Count**: ~120 replacements across 28 files

### 1b. Command prefix (sed, .md and .sh files)
```
harness: → furrow:
```
**Files**: `.claude/CLAUDE.md`, `install.sh`, `commands/*.md`, `adapters/shared/schemas/todos.schema.yaml`
**Count**: ~43 replacements across 8 files

### 1c. CLAUDE.md markers
```
<!-- harness:start --> → <!-- furrow:start -->
<!-- harness:end --> → <!-- furrow:end -->
```
**Files**: `.claude/CLAUDE.md`, `install.sh`

### 1d. Log prefixes
```
[harness:warning] → [furrow:warning]
[harness:error] → [furrow:error]
```
**Files**: `hooks/lib/common.sh` (lines 12, 16)

### 1e. Config file references
```
harness.yaml → furrow.yaml
```
**Files**: `install.sh`, `scripts/run-ci-checks.sh`, `scripts/cross-model-review.sh`, `hooks/correction-limit.sh`, `commands/lib/init-work-unit.sh`, `commands/triage.md`

### 1f. Script name references
```
harness-doctor → furrow-doctor
```
**Files**: `scripts/harness-doctor.sh` (internal), `commands/harness.md`

## Phase 2: Project Name Replacements (Category B)

### 2a. Config values
- `.claude/harness.yaml` line 6: `name: "work-harness-v2"` → `name: "furrow"`
- `.serena/project.yml` line 2: `project_name: "work-harness-v2"` → `project_name: "furrow"`

### 2b. Titles and headings
- `install.sh`: `V2 Work Harness` → `Furrow` (comments, output messages, CLAUDE.md template)
- `.claude/CLAUDE.md`: `## V2 Work Harness` → `## Furrow` (both instances)
- `docs/architecture/file-structure.md`: `work-harness-v2/` → `furrow/`

## Phase 3: File Renames

| Current | Target |
|---------|--------|
| `.claude/harness.yaml` | `.claude/furrow.yaml` |
| `commands/harness.md` | `commands/furrow.md` |
| `scripts/harness-doctor.sh` | `scripts/furrow-doctor.sh` |

## Phase 4: Prose Review (Category C)

Manual review of ~40 occurrences in:
- `docs/architecture/*.md` — "the harness" → "Furrow" in project-referencing prose
- `docs/research/findings-gap-review.md` — same pattern
- `adapters/_meta.yaml` — header comment
- `commands/furrow.md` (post-rename) — internal descriptions
- `specialists/harness-engineer.md` — update domain description references to project, BUT keep specialist name

**Rule**: "harness" as a concept (e.g., "harness infrastructure") may stay in `harness-engineer.md`. All other prose references to the project change.

## Phase 5: Migration Sequence

1. Delete all old `.claude/commands/harness:*.md` symlinks
2. Delete all old `.claude/commands/lib/*.sh` symlinks
3. Update `install.sh` `PREFIX="harness"` → `PREFIX="furrow"`
4. Run `install.sh` to recreate symlinks with `furrow:*` names
5. Run `install.sh --check` to verify

## Phase 6: Verification

1. `grep -r "harness" --include="*.sh" --include="*.md" --include="*.yaml" --include="*.json" . | grep -v ".work/" | grep -v ".git/" | grep -v "harness-engineer"` — should return zero results (except possibly the active `.work/namespace-rename/` unit)
2. `install.sh --check` passes
3. All `furrow:*` commands are listed in CLAUDE.md
4. `scripts/furrow-doctor.sh` runs without error

## Excluded

- `.work/` archived directories (21 units with `archived_at != null`)
- `specialists/harness-engineer.md` filename
- `.git/` directory
- Active `.work/namespace-rename/` content (self-referential)

## Acceptance Criteria Mapping

| AC | Phase |
|----|-------|
| Zero occurrences of 'harness' as project identifier in non-archived files | Phase 6.1 |
| All commands use furrow:* namespace | Phase 5 + 6.2 |
| install.sh --check passes | Phase 6.2 |
| CLAUDE.md injection markers use furrow:start/end | Phase 1c |
| No denormalized content | Pre-step audit |
| harness.yaml renamed to furrow.yaml | Phase 3 |
