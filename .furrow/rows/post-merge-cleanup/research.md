# Research: Post-Merge Cleanup

## Findings

The beans-integration merge moved `_rationale.yaml`, `todos.yaml`, and `roadmap.yaml` from project root into `.furrow/almanac/`. Also renamed `_rationale.yaml` → `rationale.yaml` (dropped underscore prefix). Scripts, commands, and docs were not updated to match.

### Stale References by File

| File | Count | What's stale |
|------|-------|-------------|
| scripts/furrow-doctor.sh | 6 | `_rationale.yaml` → `.furrow/almanac/rationale.yaml` (lines 50, 51, 59, 62, 336, 378) |
| scripts/measure-context.sh | 3 | `_rationale.yaml` → `.furrow/almanac/rationale.yaml` (lines 72, 142, 143) |
| bin/alm | 1 | Legacy `./todos.yaml` fallback (lines 54-55) |
| commands/furrow.md | 3 | `_rationale.yaml` docs (lines 11, 31, 36) |
| commands/triage.md | 10 | `todos.yaml` without `.furrow/almanac/` prefix |
| commands/work-todos.md | 7 | `todos.yaml` without `.furrow/almanac/` prefix |
| commands/next.md | 5 | `todos.yaml` without `.furrow/almanac/` prefix |
| commands/archive.md | 6 | `todos.yaml` without `.furrow/almanac/` prefix |

### CLI PATH Issue

`install.sh` symlink logic (lines 360-390) is correct but CLIs are not currently installed. Running `install.sh` or manually symlinking to `~/.local/bin` resolves this.

### Stale State

`.furrow/.focused` still points to `merge-specialist-and-legacy-todos` which is archived.

## Decision

All fixes are mechanical text replacements. No design decisions needed.
