# Spec: harness-engineer-grounding

## File
`specialists/harness-engineer.md` — update Context Requirements section only.

## Current Context Requirements (lines 45-50)
```
- Required: hooks/lib/common.sh, hooks/lib/validate.sh, scripts/update-state.sh patterns
- Required: schemas/ directory for JSON schema patterns
- Helpful: .claude/settings.json for hook registration patterns
- Helpful: _rationale.yaml for understanding component justifications
```

## Additions (grouped, one line each)

### Required pointers to add
- `references/gate-protocol.md` — gate evaluation lifecycle and trust gradients
- `references/row-layout.md` — .furrow/ directory structure and ownership rules
- `skills/work-context.md` — step sequence, file conventions, active row recovery
- `skills/shared/gate-evaluator.md` — isolated evaluator contract and dimension loading
- `skills/shared/eval-protocol.md` — two-phase review protocol and dimension structure
- `adapters/shared/conventions.md` — naming, paths, step sequence, write ownership

### Helpful pointers to add
- `.furrow/seeds/` — seed registry (seeds.jsonl format, config for project prefix)
- `.furrow/almanac/` — centralized knowledge (rationale.yaml, todos.yaml)
- `adapters/claude-code/` — Claude Code runtime adapter (commands, skills, progressive-loading)
- `adapters/agent-sdk/` — Agent SDK adapter bindings (templates, callbacks)
- `evals/gates/*.yaml` — gate dimension rubrics per step transition
- `evals/dimensions/*.yaml` — quality dimension definitions for artifact review
- `bin/rws`, `bin/sds`, `bin/alm` — CLI entry points for row, seed, and almanac management

## Rules
- Preserve all existing content (Domain Expertise, reasoning patterns, anti-patterns)
- Each pointer: path + dash + role (one line, no prose)
- No content duplication from referenced files
