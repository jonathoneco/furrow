# Research: project-root-resolution

## FURROW_ROOT Audit Results

### Summary
- **Total references**: 127 across bin/, bin/frw.d/, install.sh, tests/
- **Install-relative (correct)**: 98
- **Project-relative (BUG)**: 11 across 8 files
- **Ambiguous**: 4 (measure-context.sh, doctor.sh — accept parameters, default to FURROW_ROOT)
- **Definition/Export**: 2
- **Test fixtures**: 2

### Project-Relative Bugs (11 references in 8 files)

All follow the same pattern: `$FURROW_ROOT/.furrow/rows/${name}/...` or `$FURROW_ROOT/.claude/furrow.yaml`.

| File | Line | Reference | Fix |
|------|------|-----------|-----|
| generate-plan.sh | 29 | `$FURROW_ROOT/.furrow/rows/${name}/definition.yaml` | `$PROJECT_ROOT/.furrow/rows/...` |
| generate-plan.sh | 30 | `$FURROW_ROOT/.furrow/rows/${name}/plan.json` | `$PROJECT_ROOT/.furrow/rows/...` |
| check-artifacts.sh | 32 | `$FURROW_ROOT/.furrow/rows/${name}` | `$PROJECT_ROOT/.furrow/rows/...` |
| evaluate-gate.sh | 28 | `$FURROW_ROOT/.furrow/rows/${name}/definition.yaml` | `$PROJECT_ROOT/.furrow/rows/...` |
| select-gate.sh | 22 | `$FURROW_ROOT/.furrow/rows/${name}/state.json` | `$PROJECT_ROOT/.furrow/rows/...` |
| select-dimensions.sh | 26 | `$FURROW_ROOT/.furrow/rows/${name}/state.json` | `$PROJECT_ROOT/.furrow/rows/...` |
| run-gate.sh | 39 | `$FURROW_ROOT/.furrow/rows/${name}` | `$PROJECT_ROOT/.furrow/rows/...` |
| run-ci-checks.sh | 25 | `$FURROW_ROOT/.furrow/rows/${name}` | `$PROJECT_ROOT/.furrow/rows/...` |
| run-ci-checks.sh | 30 | `$FURROW_ROOT/.claude/furrow.yaml` | `$PROJECT_ROOT/.furrow/furrow.yaml` |
| cross-model-review.sh | 23 | `$FURROW_ROOT/.furrow/rows/${name}` | `$PROJECT_ROOT/.furrow/rows/...` |
| cross-model-review.sh | 26 | `$FURROW_ROOT/.claude/furrow.yaml` | `$PROJECT_ROOT/.furrow/furrow.yaml` |

### Ambiguous References (4 in 2 files)

- **measure-context.sh:10** — `ROOT="${1:-$FURROW_ROOT}"` — accepts project root as arg, FURROW_ROOT is fallback
- **doctor.sh:18** — `ROOT="${ROOT:-$FURROW_ROOT}"` — same pattern

These work correctly in practice because callers pass the project root. After PROJECT_ROOT is introduced, the fallback should change to `${1:-$PROJECT_ROOT}`.

### Resolution Design

**FURROW_ROOT** (unchanged): Install directory. Resolves from script path via `readlink -f`.
```sh
FURROW_ROOT="$(cd "$(dirname "$SCRIPT_PATH")" && cd .. && pwd)"
```

**PROJECT_ROOT** (new): Consumer project root. Defaults to PWD.
```sh
PROJECT_ROOT="${PROJECT_ROOT:-$(pwd)}"
export PROJECT_ROOT
```

Both exported by `bin/frw` at startup. Scripts sourced by frw inherit both.

### Open Questions Answered

**Q: What happens when no .furrow/ exists in PWD hierarchy?**
Commands that need active rows (generate-plan, check-artifacts, evaluate-gate, etc.) fail with file-not-found errors. Commands that only need install structure (doctor, validate-definition, init, install, root) work fine. PROJECT_ROOT should default to PWD without walking up — the harness assumes you run from the project root.

**Q: Do any scripts resolve symlinks?**
`bin/frw` uses `readlink -f` on line 7 to resolve the script path before computing FURROW_ROOT. No `pwd -P` usage found. This is correct — FURROW_ROOT needs the physical path to find Furrow's code.

**Q: How do rws, sds, alm resolve their root?**
`bin/rws` (active file) defines `FURROW_YAML=".claude/furrow.yaml"` (PWD-relative). It does NOT recompute FURROW_ROOT — it inherits from the environment. `bin/rws.bak` has the old resolution logic. `bin/sds` and `bin/alm` also use PWD-relative paths for project data.

### Surprising Findings

1. The integration test helper (helpers.sh:94) explicitly sets `FURROW_ROOT="$PROJECT_ROOT"` — it already uses the PROJECT_ROOT concept, just conflates the two variables.
2. The bugs are concentrated in `bin/frw.d/scripts/` — these are the "late addition" scripts that were added after the initial PWD-relative convention was established in rws/sds/alm.

## Sources Consulted

- bin/frw (primary — FURROW_ROOT definition, all module dispatch)
- bin/frw.d/scripts/*.sh (primary — all 11 bug locations)
- bin/frw.d/hooks/*.sh (primary — hook FURROW_ROOT usage)
- bin/rws, bin/sds, bin/alm (primary — alternate CLIs)
- install.sh (primary — bootstrap path resolution)
- tests/integration/helpers.sh (primary — test fixture setup)
