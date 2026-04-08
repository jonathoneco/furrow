# Spec: pre-staged-outputs

## Interface Contract

- Directory: `.furrow/demo/` (created if not exists)
- File: `.furrow/demo/next-prompt.txt` — captured furrow:next output
- Existing files verified: `.furrow/almanac/roadmap.md`, `.furrow/almanac/roadmap.yaml`

## Acceptance Criteria (Refined)

1. `.furrow/demo/next-prompt.txt` exists and contains the handoff prompt output from `alm next`
2. `.furrow/almanac/roadmap.md` exists and is non-empty (already generated — verify only)
3. `parallel-agent-orchestration-adoption` todo confirmed as active in `todos.yaml` and referenced in the next-prompt output

## Test Scenarios

### Scenario: furrow:next output captured
- **Verifies**: AC 1
- **WHEN**: `cat .furrow/demo/next-prompt.txt`
- **THEN**: Output contains `/work` command and scope section
- **Verification**: `grep -q '/work' .furrow/demo/next-prompt.txt && echo ok`

### Scenario: roadmap ready
- **Verifies**: AC 2
- **WHEN**: `wc -l .furrow/almanac/roadmap.md`
- **THEN**: File has > 50 lines
- **Verification**: `test $(wc -l < .furrow/almanac/roadmap.md) -gt 50 && echo ok`

## Implementation Notes

- Run `alm next` and pipe stdout to `.furrow/demo/next-prompt.txt`
- If `alm next` requires interactive input, may need to use `--phase 1` or similar flag
- Roadmap already exists — just verify, don't regenerate

## Dependencies

- `demo-script` deliverable (wave 1) — informs what the pre-staged output needs to contain
- `alm` CLI tool (symlinked from furrow source)
