# Team Plan: namespace-rename

## Scope Analysis

2 deliverables in sequential waves. Both use the same specialist (shell-specialist). No parallel execution possible due to dependency chain.

## Team Composition

Single agent executes both waves sequentially. No multi-agent coordination needed.

| Wave | Deliverable | Specialist | File Ownership |
|------|-------------|------------|----------------|
| 1 | rename-to-furrow | shell-specialist | install.sh, commands/**, .claude/*, hooks/**, scripts/**, docs/**, schemas/**, _rationale.yaml, specialists/harness-engineer.md, .serena/project.yml |
| 2 | cross-platform-compatibility | shell-specialist | scripts/**, hooks/**, commands/lib/**, install.sh |

## Task Assignment

### Wave 1: rename-to-furrow
1. Denormalization pre-step: verify install.sh is sole command table owner
2. Mechanical sed replacements (Category A: variables, prefixes, markers, log prefixes, config refs)
3. Project name replacements (Category B: config values, titles)
4. File renames (3 files)
5. Prose review (Category C: ~40 occurrences)
6. Migration: delete old symlinks, update PREFIX, re-run install, verify
7. Post-rename grep verification

### Wave 2: cross-platform-compatibility
1. Add portable `_canonicalize()` function to install.sh, replace readlink -f
2. Fix expr comparison in hooks/lib/common.sh
3. Run shellcheck on all #!/bin/sh scripts
4. Document residual risk (platform support note)

## Coordination

No inter-agent coordination — single agent, sequential execution. Wave 2 starts only after wave 1 is verified.

## Skills

- `specialist:shell-specialist` — POSIX shell scripting, sed patterns, cross-platform portability
