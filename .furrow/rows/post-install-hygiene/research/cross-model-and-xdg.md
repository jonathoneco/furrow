# Research: cross-model-per-deliverable-diff + xdg-config-consumer-wiring

## Section A — cross-model-review.sh current diff computation

Current diff invocation at `bin/frw.d/scripts/cross-model-review.sh:116`:

```sh
changes="$(git diff --stat "${base_commit}..HEAD" 2>/dev/null || echo "(no diff available)")"
```

- `base_commit` is read from `state.json` (line 93).
- The **entire** `base_commit..HEAD` range is passed to codex. No per-deliverable scoping.
- The deliverable name IS available in scope (line 61, `deliverable="$2"`) but only used for acceptance-criteria lookup (line 107) and review file naming (line 256).
- `file_ownership` is NOT currently read from `definition.yaml`.
- `definition_file` is loaded (line 64) but parsed only for ACs via yq (line 107).
- Reference implementation for reading `file_ownership` exists at `bin/frw.d/scripts/check-artifacts.sh:77-106`.

Needed yq query pattern:
```sh
file_ownership="$(name="${deliverable}" yq -r '.deliverables[] | select(.name == env(name)) | .file_ownership[]?' "$definition_file")"
```

Missing-file_ownership fallback: not handled today; emits empty/null with no warning.

### Sources Consulted
- `bin/frw.d/scripts/cross-model-review.sh:61-124`
- `bin/frw.d/scripts/check-artifacts.sh:77-106` (reference impl)
- `.furrow/rows/post-install-hygiene/definition.yaml:41-53`

## Section B — git log commit-range semantics (verified)

**`--follow` is single-path only.** Per `git help log`: "continue listing the history of a file beyond renames (works only for a single file)." With multiple paths/globs `--follow` must be omitted and rename-tracing is lost. Our ACs do not require rename tracking — acceptable.

**Merges included by default.** `git log <base>..HEAD -- <globs>` includes merge commits. Recommend `--no-merges` unless we have a reason to review merge commits.

**`git diff <first>^..<last>` is WRONG for non-contiguous commits.** That syntax diffs everything in the range, not just the selected commits. For commits 1,3,5 out of 1–6 it would include 2,4,6 too. Correct alternatives:
- **Option A**: `git show <c1> <c2> <c3>` — accumulate show output per commit.
- **Option B** (recommended): `git log -p <base>..HEAD -- <globs>` — single command outputs metadata + patches, naturally filters to matching paths.
- Option C: temporary merge-base manipulation — overcomplicated.

**Recommendation**: use `git log -p --no-merges <base>..HEAD -- <globs>` for the per-deliverable diff input to codex. Amend the definition AC that currently says `git diff <first>^..<last>`.

### Sources Consulted
- `git help log` / `git help diff` (man pages)
- Empirical: `git log --pretty=format:%H --no-merges HEAD -- bin/frw` on this repo

## Section C — current config-reading + existing resolver

Current `cross_model.provider` read at `bin/frw.d/scripts/cross-model-review.sh:79-83`:

```sh
provider="$(yq -r '.cross_model.provider // ""' "$furrow_config")"
if [ -z "$provider" ]; then
  echo "Cross-model review skipped: no provider configured" >&2
  return 1
fi
```

Script searches `.furrow/furrow.yaml` then `.claude/furrow.yaml` (lines 66–70). **No XDG fallback.**

### Existing resolver — `resolve_config_value` at `bin/frw.d/lib/common.sh:121-144`

```sh
resolve_config_value() {
  _rcv_key="$1"
  # Tier 1: project-local .furrow/furrow.yaml
  if [ -f "${PROJECT_ROOT}/.furrow/furrow.yaml" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "${PROJECT_ROOT}/.furrow/furrow.yaml" 2>/dev/null || true)"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi
  # Tier 2: XDG global config (honors $XDG_CONFIG_HOME)
  _rcv_xdg="${XDG_CONFIG_HOME:-${HOME}/.config}/furrow/config.yaml"
  if [ -f "$_rcv_xdg" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "$_rcv_xdg" 2>/dev/null || true)"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi
  # Tier 3: compiled-in default under $FURROW_ROOT
  if [ -f "${FURROW_ROOT}/.furrow/furrow.yaml" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "${FURROW_ROOT}/.furrow/furrow.yaml" 2>/dev/null || true)"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi
  return 1
}
```

**Key finding**: the resolver is already implemented with the exact semantics we want. The definition AC proposes a new `get_config_field <dotted.key> <default>` — this should either (a) alias the existing `resolve_config_value`, (b) wrap it to add the `<default>` fallback, or (c) rename it. The existing function does not accept a default — caller handles that via `|| echo "$default"`.

**Decision needed at plan time**: new wrapper vs rename vs caller-side defaults.

### Sources Consulted
- `bin/frw.d/scripts/cross-model-review.sh:65-83`
- `bin/frw.d/lib/common.sh:121-144`

## Section D — consumer sites per field

### `cross_model.provider`
Writes:
- `bin/frw.d/install.sh:836-847` bootstraps empty XDG config on consumer install.

Reads (all currently project-only, no XDG fallback):
- `bin/frw.d/scripts/cross-model-review.sh:79` (post-step review)
- `bin/frw.d/scripts/cross-model-review.sh:280` (`_cross_model_ideation`)
- `bin/frw.d/scripts/cross-model-review.sh:446` (`_cross_model_plan`)
- `bin/frw.d/scripts/cross-model-review.sh:631` (`_cross_model_spec`)

Four call sites to rewire.

### `gate_policy` default
Reads:
- `bin/rws:117-124` `read_gate_policy()` reads `definition.yaml` only; hardcoded fallback `"supervised"`. No XDG resolution.
- `bin/frw.d/hooks/stop-ideation.sh` ~line 41 — reads `definition.yaml` only, empty fallback, no XDG.

### `preferred_specialists`
**Zero consumers today.** Grep returns only the schema definition in `docs/architecture/config-resolution.md:110-112` and test fixtures. Field is write-only at install time.

**Scope implication**: wiring `preferred_specialists` is *creating* a new consumer in `skills/shared/specialist-delegation.md`, not wiring an existing one. This is additive scope — should be reflected in that deliverable's AC. Plan step should confirm this is in scope or defer to a follow-up TODO.

### Sources Consulted
- `bin/rws:117-124`
- `bin/frw.d/hooks/stop-ideation.sh`
- `bin/frw.d/scripts/cross-model-review.sh:79, 280, 446, 631`
- `docs/architecture/config-resolution.md:105-116`

## Section E — existing XDG path conventions

`install.sh:830-856` (consumer install mode only):

```sh
_xdg_cfg_home="${XDG_CONFIG_HOME:-${HOME}/.config}"
_furrow_cfg_dir="${_xdg_cfg_home}/furrow"
_cfg_yaml="${_furrow_cfg_dir}/config.yaml"
if [ ! -f "$_cfg_yaml" ]; then
  printf '# Global Furrow defaults. Overridden per-project by .furrow/furrow.yaml.\n{}\n' > "$_cfg_yaml"
  _ok "config.yaml bootstrapped at $_cfg_yaml"
fi
```

Conventions:
- `${XDG_CONFIG_HOME:-${HOME}/.config}` pattern used everywhere; no hardcoded `~/.config`.
- Source-mode install does NOT touch XDG state.
- `docs/architecture/config-resolution.md` already documents the three-tier chain and all three fields.

### Sources Consulted
- `bin/frw.d/install.sh:830-856`
- `bin/frw.d/lib/common.sh:131`
- `docs/architecture/config-resolution.md`

## Findings summary (actionable)

1. **AC revision needed**: the definition currently proposes `git diff <first>^..<last>` for per-deliverable diff. Replace with `git log -p --no-merges <base>..HEAD -- <globs>` — the other approach is semantically wrong.
2. **AC revision needed**: existing `resolve_config_value` in `common.sh` already does what `get_config_field` proposes. Plan should decide between rename, wrap-with-default, or just point all consumers at the existing function.
3. **Scope flag**: `preferred_specialists` has zero consumers today. Wiring it means *creating* a new consumer in `skills/shared/specialist-delegation.md`. Confirm whether this is in-row scope or a follow-up TODO.
4. **Four cross-model-review.sh sites** to wire to the resolver (79, 280, 446, 631) — plus `bin/rws:117-124` and `bin/frw.d/hooks/stop-ideation.sh` for `gate_policy`.
5. **No renaming support**: `git log --follow` is single-path; multi-glob commit-range tracing will not follow renames. Acceptable per ACs.
6. **Merge commits**: add `--no-merges` to the commit-range query.
