# Spec: harness-integration

## Interface Contract
- **Files modified**: `.claude/harness.yaml`, `.claude/CLAUDE.md`, `todos.yaml`
- **Purpose**: Wire /work-roadmap into harness config and docs

## Changes

### 1. harness.yaml

Add `roadmap` section after `context_docs`:

```yaml
# Roadmap generation settings
roadmap:
  template: ""   # Optional path to custom roadmap template (overrides default)
```

### 2. CLAUDE.md

Add `/work-roadmap` to the command table:

```markdown
| /work-roadmap | Generate ROADMAP.md from todos.yaml |
```

### 3. todos.yaml

Update the `roadmap-process-from-todos` entry:
- Change all references from "TODOS.md" to "todos.yaml" in `context` and `work_needed` fields
- Bump `updated_at` timestamp

## Acceptance Criteria
1. `harness.yaml` has `roadmap.template` key (optional, empty default)
2. CLAUDE.md command table includes `/work-roadmap` with description
3. `todos.yaml` entry `roadmap-process-from-todos` references `todos.yaml` not `TODOS.md`
4. `scripts/validate-todos.sh` passes after todos.yaml update

## Implementation Notes
- harness.yaml change is additive — no existing keys affected
- CLAUDE.md table insert at alphabetical position
- todos.yaml update is content-only (no schema change needed, just prose correction)
