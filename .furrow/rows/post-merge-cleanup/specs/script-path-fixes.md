# Spec: script-path-fixes

## furrow-doctor.sh — 6 replacements

| Line | Old | New |
|------|-----|-----|
| 50 | `"$ROOT/_rationale.yaml"` | `"$ROOT/.furrow/almanac/rationale.yaml"` |
| 51 | `entries in _rationale.yaml` | `entries in rationale.yaml` |
| 59 | `Check 3: All _rationale.yaml paths` | `Check 3: All rationale.yaml paths` |
| 62 | `"$ROOT/_rationale.yaml"` | `"$ROOT/.furrow/almanac/rationale.yaml"` |
| 336 | `'$ROOT/_rationale.yaml'` (2x) | `'$ROOT/.furrow/almanac/rationale.yaml'` |
| 378 | `'$ROOT/_rationale.yaml'` | `'$ROOT/.furrow/almanac/rationale.yaml'` |

## measure-context.sh — 3 replacements

| Line | Old | New |
|------|-----|-----|
| 72 | `excludes _rationale.yaml` | `excludes rationale.yaml` |
| 142 | `"$ROOT/_rationale.yaml"` | `"$ROOT/.furrow/almanac/rationale.yaml"` |
| 143 | `_rationale.yaml:` | `rationale.yaml:` |

## AC
- furrow-doctor.sh checks .furrow/almanac/rationale.yaml
- measure-context.sh references .furrow/almanac/ paths
- furrow-doctor.sh passes with no path-related failures
