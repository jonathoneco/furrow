# Spec: config-cleanup

Wave-2 deliverable in row `install-and-merge`. Depends on `install-architecture-overhaul`
(wave 1). Paired with `worktree-reintegration-summary` in wave 2 under a disjoint file
ownership set (AD-6).

Decision anchors:
- AD-3 — XDG split (state vs config); resolution chain is three-tier
- AD-5 — `source_todos` schema extension already landed during ideation; this deliverable
  wires it through runtime
- R1 §4 — `frw upgrade` lives as a top-level dispatcher case (parallels `init` /
  `migrate-to-furrow`), not a subcommand of `install`
- Ideation Q2 + Q4 — user selected XDG approach for both machine state and global config

---

## Interface Contract

### 1. `~/.config/furrow/config.yaml` — global defaults

Location: `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml`.

Schema (all fields optional; resolution falls through to compiled-in defaults under
`$FURROW_ROOT/.furrow/furrow.yaml` when absent):

```yaml
# Global Furrow defaults. Overridden per-project by .furrow/furrow.yaml.
cross_model:
  provider: gemini          # string; {gemini, openai, claude-direct}; default gemini

gate_policy: supervised   # {autonomous, supervised, strict}; default supervised

preferred_specialists:            # list[string]; referenced by specialist: fields
  - harness-engineer
  - shell-specialist

promotion_targets_path: ~/.config/furrow/promotion-targets.yaml
  # string; path to promotion-targets registry. SCAFFOLDING — no consumer in this row.
```

Required fields: none. Unknown top-level keys MUST cause `frw doctor` to emit a warning
(not an error), to stay forward-compatible with Phase 2 additions.

### 2. `~/.config/furrow/specialists/` — shared specialists directory

Location: `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/specialists/{name}.md`.

Precedence rule (highest → lowest):
1. `$PROJECT_ROOT/specialists/{name}.md` — project-local override
2. `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/specialists/{name}.md` — user global
3. `$FURROW_ROOT/specialists/{name}.md` — compiled-in

First hit wins; no merging. Resolution happens in `common.sh:find_specialist(name)`
(new function in this deliverable).

### 3. `~/.config/furrow/promotion-targets.yaml` — scaffolding

Location: `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/promotion-targets.yaml`.

This deliverable produces:
- `schemas/promotion-targets.schema.yaml` — JSON-Schema-flavored YAML describing
  the shape (`targets: [{id, path, category, promoted_at}]`).
- An empty but valid `~/.config/furrow/promotion-targets.yaml` (only `targets: []`)
  is written by `frw upgrade --apply` and by the wave-1 install flow's first run.

No loader, no reader, no CLI — Phase 2 ambient-promotion lights it up. `frw doctor`
MUST NOT fail if the file is absent.

### 4. Resolution chain algorithm

Implemented in `bin/frw.d/lib/common.sh` as `resolve_config_value()`:

```sh
# resolve_config_value KEY
# KEY is a dotted path (e.g. "cross_model.provider").
# Output: resolved string value; exit 0 if found, exit 1 if unset everywhere.
resolve_config_value() {
  key="$1"

  # Tier 1: project-local .furrow/furrow.yaml
  if [ -f "$PROJECT_ROOT/.furrow/furrow.yaml" ]; then
    v=$(yq -r ".$key // \"\"" "$PROJECT_ROOT/.furrow/furrow.yaml")
    [ -n "$v" ] && [ "$v" != "null" ] && { printf '%s\n' "$v"; return 0; }
  fi

  # Tier 2: XDG global config (honors $XDG_CONFIG_HOME)
  xdg_config="${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml"
  if [ -f "$xdg_config" ]; then
    v=$(yq -r ".$key // \"\"" "$xdg_config")
    [ -n "$v" ] && [ "$v" != "null" ] && { printf '%s\n' "$v"; return 0; }
  fi

  # Tier 3: compiled-in default under $FURROW_ROOT
  if [ -f "$FURROW_ROOT/.furrow/furrow.yaml" ]; then
    v=$(yq -r ".$key // \"\"" "$FURROW_ROOT/.furrow/furrow.yaml")
    [ -n "$v" ] && [ "$v" != "null" ] && { printf '%s\n' "$v"; return 0; }
  fi

  return 1
}
```

Override semantics: **full-key override, not merge**. A tier that sets `cross_model.provider`
wins for that key only; sibling keys like `cross_model.fallback_provider` still resolve
independently. There is no nested-merge across tiers — each leaf key is resolved on its own.

`$XDG_CONFIG_HOME` MUST be honored when set; when unset, fall back to `$HOME/.config`.
The path is never hardcoded (constraint: AD-3 / definition.yaml `constraints[4]`).

### 5. `frw upgrade` CLI

New top-level dispatcher case in `bin/frw` (added between `migrate-to-furrow` and
`run-integration-tests` cases per R1 §4). Dispatched as:

```sh
upgrade)
  . "$FURROW_ROOT/bin/frw.d/lib/common-minimal.sh"
  . "$FURROW_ROOT/bin/frw.d/scripts/upgrade.sh"
  frw_upgrade "$@"
  ;;
```

Script: `bin/frw.d/scripts/upgrade.sh`. Sources `common-minimal.sh` only (per AD-1 — the
minimal subset is hook-safe and sufficient for log_error / log_warning / find_active_row).

Interface:

```
frw upgrade [--check] [--apply] [--from <legacy-path>]
```

Arguments:
- `--check` (default): report what upgrade would do; exit 0 if already current,
  exit 10 if migration needed, exit 2 on fatal detection error.
- `--apply`: perform the migration. Exit 0 on success, exit 1 on partial failure
  (rolled back to pre-upgrade state), exit 2 on fatal error.
- `--from <legacy-path>`: override auto-detection; points at a legacy `.claude/furrow.yaml`
  or similar. Used in tests and recovery.

Idempotency: second `--apply` run on an already-migrated install exits 0 with no
changes made. The `install-state.json` (created in wave 1, `$XDG_STATE_HOME/furrow/{slug}/`)
stores a `migration_version` field; upgrade reads it, compares against the current
migration schema version, and skips if equal.

Interaction with wave-1 `install-state.json`: upgrade writes `migration_version` and
`last_upgrade_at` under the same JSON root. Upgrade MUST NOT create a second state file.

### 6. `source_todos` runtime threading

Schema change: `schemas/definition.schema.json` gains `source_todos` (array of strings)
as a peer of the legacy `source_todo` (singular, still accepted — AD-5). At least one
of the two (or neither) is permitted; supplying both is a validation error.

State initialization: `state.json` (created by `rws init` during ideate → research
transition) copies the array verbatim into a new top-level field `source_todos`. For
legacy definitions with `source_todo` (singular), state.json stores it as a single-
element array under the new field (backfill). Schema change: `schemas/state.schema.json`
gains the new field as optional.

Handoff prompt (`commands/next.md` §3b + §5): the `/furrow:next` prompt generator reads
`state.json.source_todos` (preferred) with fallback to `state.json.source_todo`; emits
one line per id under the "Source TODOs" heading in the prompt block. Existing behavior
for single-id definitions MUST remain intact — no visible diff in generated prompts for
the legacy case.

---

## Acceptance Criteria (Refined)

Seven refined ACs, one per definition.yaml AC. Each is testable.

### AC-1 (global config tier wired)
**Refined**: When `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml` exists with
`cross_model.provider: gemini`, `resolve_config_value cross_model.provider` returns
`gemini` AND exits 0, even when no project-local `.furrow/furrow.yaml` is present.

### AC-2 (shared specialists precedence)
**Refined**: `find_specialist harness-engineer` returns `$PROJECT_ROOT/specialists/harness-engineer.md`
when present; returns `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/specialists/harness-engineer.md`
when only the XDG copy exists; returns `$FURROW_ROOT/specialists/harness-engineer.md` when
only the compiled-in copy exists. Exit 1 when none of the three exists.

### AC-3 (promotion-targets scaffolding)
**Refined**: After `frw upgrade --apply` on a fresh install:
(a) `schemas/promotion-targets.schema.yaml` exists and validates as YAML;
(b) `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/promotion-targets.yaml` exists and contains
`targets: []`;
(c) no loader/consumer references the file (`grep -r promotion-targets bin/ commands/`
finds only the schema file, the scaffolding writer, and `frw doctor` skip-check).

### AC-4 (resolution chain documented + implemented)
**Refined**: `docs/architecture/config-resolution.md` exists and diagrams the PROJECT_ROOT
→ XDG_CONFIG_HOME → FURROW_ROOT chain with pseudocode matching `resolve_config_value()`.
`bin/frw.d/lib/common.sh` exports `resolve_config_value` and `find_specialist` functions.

### AC-5 (resolver regression test)
**Refined**: An integration test `tests/integration/test-config-resolution.sh` asserts:
(a) project value wins over XDG value wins over compiled-in value;
(b) setting `$XDG_CONFIG_HOME` to a tmpdir redirects tier-2 reads to that tmpdir;
(c) an unset key in all three tiers exits 1 without printing to stdout.
Test exits 0 overall iff all three cases pass.

### AC-6 (source_todos end-to-end)
**Refined**: A definition.yaml with `source_todos: [a, b, c]` (a) passes
`frw validate-definition`, (b) results in `state.json.source_todos == ["a","b","c"]`
after row init, and (c) `/furrow:next` generates a handoff prompt containing the three
ids each on its own line under "Source TODOs". A legacy definition with
`source_todo: a` (singular) passes validation and produces an identical prompt shape
to `source_todos: [a]`.

### AC-7 (idempotent migration + migration_version recorded)
**Refined**: Given a fixture legacy install (`.claude/furrow.yaml` present, no
`$XDG_CONFIG_HOME/furrow/config.yaml`), `frw upgrade --apply` exits 0 and produces:
(a) `$XDG_CONFIG_HOME/furrow/config.yaml` whose contents match the pre-migration
`.claude/furrow.yaml` by key;
(b) the legacy `.claude/furrow.yaml` is replaced by a symlink to the XDG copy
(keeps back-compat for any caller still reading the old path; no flag needed);
(c) `$XDG_STATE_HOME/furrow/{slug}/install-state.json` has
`migration_version == "1.0"` (string, matching wave-1 contract) and a valid
`last_upgrade_at` ISO-8601 timestamp. A second invocation of `frw upgrade --apply`
exits 0 with zero diff (bytewise) on all written files.

---

## Test Scenarios

### Scenario: resolution-chain-regression
- **Verifies**: AC-5
- **WHEN**: Three-tier fixture set up — project `.furrow/furrow.yaml` sets
  `cross_model.provider: alpha`; XDG config sets `cross_model.provider: beta`;
  compiled-in `$FURROW_ROOT/.furrow/furrow.yaml` sets `cross_model.provider: gamma`.
  First call resolves with all three. Second call removes project file. Third call
  removes XDG file.
- **THEN**: First call returns `alpha`, second returns `beta`, third returns `gamma`.
- **Verification**:
  `tests/integration/test-config-resolution.sh::test_three_tier_precedence` runs
  `resolve_config_value cross_model.provider` in a subshell with tiered fixtures;
  asserts stdout at each step.

### Scenario: xdg-override-honored
- **Verifies**: AC-5 (b), definition.yaml `constraints[4]` (XDG compliance)
- **WHEN**: `unset XDG_CONFIG_HOME`; `export XDG_CONFIG_HOME=$(mktemp -d)`; write
  `$XDG_CONFIG_HOME/furrow/config.yaml` with `gate_policy: strict`; call
  `resolve_config_value gate_policy` with no project-local file.
- **THEN**: stdout is `strict`, exit 0.
- **Verification**:
  `tests/integration/test-config-resolution.sh::test_xdg_override` asserts tmpdir
  is the effective source via `strace -e openat` (optional) or via path-printing
  `resolve_config_source` helper.

### Scenario: frw-upgrade-idempotency
- **Verifies**: AC-7
- **WHEN**: Fixture legacy install tree built under `tests/fixtures/legacy-install/`
  (contains `.claude/furrow.yaml` with three keys, no XDG copy, no install-state.json).
  Run `frw upgrade --apply`. Capture all file hashes. Run `frw upgrade --apply`
  a second time. Capture hashes again.
- **THEN**: First run exit 0, second run exit 0, hash sets identical between the two
  captures. `install-state.json` has `migration_version` set after first run and
  unchanged after second run.
- **Verification**:
  `tests/integration/test-upgrade-idempotency.sh`; uses `find … -exec sha256sum` and
  `diff` on the two hash manifests.

### Scenario: source-todos-backcompat
- **Verifies**: AC-6 (legacy path)
- **WHEN**: `definition.yaml` uses `source_todo: install-architecture-overhaul`
  (singular). Row init runs. `/furrow:next` executes against the phase.
- **THEN**: Validation passes (exit 0). `state.json.source_todos == ["install-architecture-overhaul"]`.
  `/furrow:next` prompt contains one "Source TODO" line with that id.
- **Verification**:
  `tests/integration/test-source-todos.sh::test_legacy_singular` uses a
  golden-file prompt comparison.

### Scenario: source-todos-new-form
- **Verifies**: AC-6 (new array path)
- **WHEN**: `definition.yaml` uses `source_todos: [a, b, c]`. Row init runs.
  `/furrow:next` executes.
- **THEN**: `state.json.source_todos == ["a","b","c"]`. Prompt contains three
  distinct "Source TODO" lines, one per id, order preserved.
- **Verification**:
  `tests/integration/test-source-todos.sh::test_array_form`; golden-file comparison.

### Scenario: migration-fixture-end-to-end
- **Verifies**: AC-7 (full path)
- **WHEN**: Synthesized legacy-install fixture created by
  `tests/fixtures/make-legacy-install.sh` produces: `.claude/furrow.yaml`,
  `.claude/commands/furrow:*.md` symlinks, no `.furrow/furrow.yaml`, no
  `$XDG_CONFIG_HOME/furrow/`. `frw upgrade --apply` run against this tree with
  `$XDG_CONFIG_HOME` + `$XDG_STATE_HOME` overridden to tmpdirs.
- **THEN**: Post-state asserts:
  (a) `$XDG_CONFIG_HOME/furrow/config.yaml` has all keys from `.claude/furrow.yaml`;
  (b) `$XDG_CONFIG_HOME/furrow/promotion-targets.yaml` contains `targets: []`;
  (c) `.claude/furrow.yaml` is a symlink to the XDG copy;
  (d) `install-state.json` has `migration_version == "1.0"`.
- **Verification**:
  `tests/integration/test-upgrade-migration.sh`; structured assertions per subitem.

### Scenario: shared-specialists-precedence
- **Verifies**: AC-2
- **WHEN**: Three-tier specialist fixture —
  (i) `$PROJECT_ROOT/specialists/harness-engineer.md` present ⇒ tier-1;
  (ii) remove tier-1, keep `$XDG_CONFIG_HOME/furrow/specialists/harness-engineer.md` ⇒ tier-2;
  (iii) remove tier-2, keep `$FURROW_ROOT/specialists/harness-engineer.md` ⇒ tier-3;
  (iv) remove all three ⇒ not found.
  Call `find_specialist harness-engineer` after each mutation.
- **THEN**: (i) returns tier-1 path exit 0; (ii) tier-2 path exit 0; (iii) tier-3 path exit 0; (iv) exit 1 with empty stdout and stderr `[furrow:error] specialist not found: harness-engineer`.
- **Verification**:
  `tests/integration/test-specialist-precedence.sh`; asserts stdout path + exit code per mutation.

### Scenario: promotion-targets-scaffolding
- **Verifies**: AC-3
- **WHEN**: Fresh install (`frw upgrade --apply` on a clean tree with no prior XDG state).
- **THEN**: (a) `schemas/promotion-targets.schema.yaml` exists and `yq 'has("targets")' schemas/promotion-targets.schema.yaml` prints `true`; (b) `$XDG_CONFIG_HOME/furrow/promotion-targets.yaml` exists and `yq '.targets' $XDG_CONFIG_HOME/furrow/promotion-targets.yaml` prints `[]`; (c) `grep -rn promotion-targets bin/ commands/` returns ONLY lines from the scaffolding writer and the `frw doctor` skip-check — no loader or consumer references.
- **Verification**:
  `tests/integration/test-promotion-targets-scaffolding.sh` runs the three checks and asserts each.

### Scenario: resolver-docs-and-exports
- **Verifies**: AC-4
- **WHEN**: After `frw upgrade --apply`, check for the documentation file and exported functions.
- **THEN**: (a) `docs/architecture/config-resolution.md` exists and contains the literal substrings "PROJECT_ROOT", "XDG_CONFIG_HOME", "FURROW_ROOT" in that order (grep -F sequence); (b) sourcing `bin/frw.d/lib/common.sh` in a subshell makes `resolve_config_value` and `find_specialist` available (`command -v resolve_config_value` exits 0).
- **Verification**:
  `tests/integration/test-resolver-exports.sh` — two grep + `command -v` assertions.

---

## Implementation Notes

### Dispatcher placement (R1 §4)
`frw upgrade` is a **top-level** case in `bin/frw`, not a subcommand of `install`.
Rationale: parallels `init` and `migrate-to-furrow`, both of which are top-level
transition commands. Grouping under `install` would require arg-parsing to detect
pre-XDG state, which R1 flags as fragile.

### Chained migration
`frw upgrade` detects two legacy tiers (this deliverable's scope):
1. Pre-XDG: `.claude/furrow.yaml` present, no `$XDG_CONFIG_HOME/furrow/config.yaml` →
   perform XDG migration.
2. Current: install-state.json has `migration_version == "1.0"` → no-op (idempotent).

`migration_version` is updated from `"0"` (pre-XDG) to `"1.0"` (XDG) on apply.
Very-legacy states (`.beans/` or `.work/`) are OUT OF SCOPE for this deliverable —
`frw migrate-to-furrow` remains the explicit tool for that transition and the user
is expected to run it first. A future migration version (e.g., `"2.0"`) can chain
legacy steps; not needed here.

### Schema extension (AD-5)
`source_todos` (array) was already added to `schemas/definition.schema.json` during
ideation — this deliverable does NOT re-land that change. This deliverable wires it
through:
- `state.json` init (bin/rws or equivalent): copy definition's `source_todos` array into
  state verbatim; if only legacy `source_todo` is present, wrap into 1-element array.
- `schemas/state.schema.json`: add optional `source_todos: [string]` field.
- `commands/next.md` §3b and §5: read `source_todos` array (preferred) with fallback
  to `source_todo` singular; render one line per id.

### Hook safety (AD-1)
`resolve_config_value` and `find_specialist` live in `common.sh` (full lib), NOT in
`common-minimal.sh`. Hooks do not consume them; they are used by `frw` subcommands
and `commands/*.md` runtimes. This preserves the hook-cascade guarantee from wave 1.

`bin/frw.d/scripts/upgrade.sh` sources `common-minimal.sh` only (log_error,
log_warning, find_active_row), consistent with wave-1 AD-1 layering.

### Promotion-targets scope discipline
This deliverable produces the file and the schema. It does NOT produce a loader,
reader, or any consumer logic. Phase 2 ambient-promotion will light this up. A unit
test asserts `grep -r "promotion-targets" bin/frw.d/ commands/` returns only the
scaffolding writer in `upgrade.sh` and (optionally) a `frw doctor` advisory check,
never a loader.

### XDG override semantics
Every path lookup uses `${XDG_CONFIG_HOME:-$HOME/.config}` and `${XDG_STATE_HOME:-$HOME/.local/state}`.
No literal `~/.config` or `~/.local/state` strings in shell code (enforced by grep-
based contamination check in `tests/integration/test-xdg-compliance.sh`).

### Back-compat guarantee
Running `/furrow:next` against a state.json with only the legacy `source_todo`
(singular) field MUST produce the same prompt text as it did prior to this
deliverable. Golden-file fixtures in `tests/fixtures/next-prompts/` capture the
pre-change output for regression comparison.

### File ownership (wave 2, disjoint from reintegration-summary)
Per plan.json wave 2, this deliverable owns:
- `bin/frw.d/install.sh` (XDG scaffolding hooks only; no overlap with wave-1 surface)
- `bin/frw.d/lib/common.sh` (add `resolve_config_value`, `find_specialist`)
- `bin/frw.d/lib/common-minimal.sh` (read-only; upgrade.sh sources it)
- `bin/frw.d/scripts/upgrade.sh` (new)
- `bin/frw` (add `upgrade` dispatcher case)
- `commands/next.md` (source_todos rendering)
- `.furrow/furrow.yaml` (project config, if template needs a source_todos example)
- `schemas/definition.schema.json` (source_todos already landed in ideation — verify)
- `schemas/state.schema.json` (add optional source_todos field)
- `schemas/promotion-targets.schema.yaml` (new, scaffolding)
- `docs/architecture/config-resolution.md` (new)

---

## Dependencies

### Wave-1 prerequisites (install-architecture-overhaul)
- `.furrow/SOURCE_REPO` sentinel — `frw upgrade` refuses to write XDG artifacts on
  source-repo detection to avoid polluting developer `~/.config`.
- `$XDG_STATE_HOME/furrow/{repo-slug}/install-state.json` — this deliverable's
  upgrade writes `migration_version` (string, `"0"` → `"1.0"`) and `last_upgrade_at`
  (RFC3339 timestamp) fields into that file. Schema defined in wave-1 spec.
  Must exist (wave 1 creates it).
- `bin/frw.d/lib/common-minimal.sh` — `upgrade.sh` sources it for `log_error` /
  `log_warning` (AD-1 layering).
- Sort-by-id on seeds.jsonl / todos.yaml — upgrade MUST NOT break sort invariants
  if it ever touches those files (it should not, but a post-upgrade `frw doctor`
  run confirms sort order).

### External dependencies
- `jq` — read/write install-state.json; required; `frw doctor` already asserts its
  presence.
- `yq` — read/write YAML config and promotion-targets scaffolding; required; already
  listed in `frw doctor` dependency check.
- POSIX sh — portable shell per row-level constraint; no bashisms in upgrade.sh or
  the new `common.sh` functions.

### Downstream consumers
- `merge-process-skill` (wave 3) depends on `config-cleanup` per plan.json. The
  `/furrow:merge` skill reads `resolve_config_value merge.policy_path` (Phase 2
  hook) and relies on the three-tier chain being in place.
- `/furrow:next` (this row, `commands/next.md`) directly consumes `source_todos`
  from state.json.

### Blockers / gaps
- `migrate-to-furrow` script location (`bin/frw.d/scripts/migrate-to-furrow.sh`) is
  stable from wave 1; upgrade.sh invokes it via `frw migrate-to-furrow` rather than
  sourcing to preserve subprocess isolation.
- If the very-legacy branch is exercised by a consumer, `migrate-to-furrow` must
  itself be idempotent (R1 confirms it is; wave-1 idempotency test covers it).
