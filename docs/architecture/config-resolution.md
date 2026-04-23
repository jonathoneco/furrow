# Config Resolution Architecture

Furrow resolves configuration values through a three-tier precedence chain.
The chain ensures that project-specific settings always win over user-global
settings, which always win over compiled-in defaults.

---

## Three-Tier Chain

```
PROJECT_ROOT  →  XDG_CONFIG_HOME  →  FURROW_ROOT
```

| Tier | Path | Purpose |
|------|------|---------|
| 1 — Project | `$PROJECT_ROOT/.furrow/furrow.yaml` | Per-project overrides; tracked in the project repo |
| 2 — XDG User | `${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml` | User-global defaults; shared across projects |
| 3 — Compiled-in | `$FURROW_ROOT/.furrow/furrow.yaml` | Furrow source defaults; shipped with the harness |

**First hit wins.** Keys are resolved independently — there is no nested merge
across tiers. A tier that defines `cross_model.provider` wins for that key only;
sibling keys (e.g., `cross_model.fallback_provider`) are still resolved
independently through the full chain.

---

## XDG Compliance

The path to tier-2 is never hardcoded. Resolution always uses:

```sh
${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml
```

When `XDG_CONFIG_HOME` is set in the environment, that value is used.
When it is unset, the fallback is `$HOME/.config`. This follows the
[XDG Base Directory Specification](https://specifications.freedesktop.org/basedir-spec/latest/).

---

## Implementation

`resolve_config_value` lives in `bin/frw.d/lib/common.sh` (NOT in
`common-minimal.sh`, because it requires `yq` and is not hook-safe):

```sh
# resolve_config_value KEY
# KEY is a dotted path (e.g. "cross_model.provider").
# Output: resolved string value; exit 0 if found, exit 1 if unset everywhere.
resolve_config_value() {
  _rcv_key="$1"

  # Tier 1: project-local .furrow/furrow.yaml
  if [ -f "${PROJECT_ROOT}/.furrow/furrow.yaml" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "${PROJECT_ROOT}/.furrow/furrow.yaml")"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi

  # Tier 2: XDG global config (honors $XDG_CONFIG_HOME)
  _rcv_xdg="${XDG_CONFIG_HOME:-${HOME}/.config}/furrow/config.yaml"
  if [ -f "$_rcv_xdg" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "$_rcv_xdg")"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi

  # Tier 3: compiled-in default under $FURROW_ROOT
  if [ -f "${FURROW_ROOT}/.furrow/furrow.yaml" ]; then
    _rcv_v="$(yq -r ".${_rcv_key} // \"\"" "${FURROW_ROOT}/.furrow/furrow.yaml")"
    [ -n "$_rcv_v" ] && [ "$_rcv_v" != "null" ] && { printf '%s\n' "$_rcv_v"; return 0; }
  fi

  return 1
}
```

---

## Specialist Resolution

Specialists (prompt templates in `specialists/{name}.md`) follow the same
three-tier pattern via `find_specialist` in `bin/frw.d/lib/common.sh`:

```
PROJECT_ROOT/specialists/{name}.md        ← tier 1 (project-local)
XDG_CONFIG_HOME/furrow/specialists/{name}.md  ← tier 2 (user-global)
FURROW_ROOT/specialists/{name}.md         ← tier 3 (compiled-in)
```

`find_specialist name` returns the absolute path of the first match or exits 1
with a `[furrow:error]` message to stderr if no tier contains the specialist.

The shared specialists directory (`${XDG_CONFIG_HOME:-$HOME/.config}/furrow/specialists/`)
allows users to define overrides that apply across all projects without
checking them into any project repo.

---

## Global Config Schema

`${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml` — all fields optional:

```yaml
# Global Furrow defaults. Overridden per-project by .furrow/furrow.yaml.
cross_model:
  provider: gemini          # {gemini, openai, claude-direct}; default gemini

gate_policy: supervised     # {autonomous, supervised, strict}; default supervised

preferred_specialists:      # list[string]
  - harness-engineer
  - shell-specialist

promotion_targets_path: ~/.config/furrow/promotion-targets.yaml
  # Path to promotion-targets registry (SCAFFOLDING — Phase 2 lights this up)
```

Unknown top-level keys cause `frw doctor` to emit a **warning** (not an error),
preserving forward compatibility with Phase 2 additions.

---

## Decision Anchors

- **AD-3**: XDG split (state vs config); three-tier resolution chain chosen over
  single-file merge to keep override semantics simple and avoid merge conflicts.
- **Ideation Q2 + Q4**: User selected the XDG approach for both machine state and
  global config.
- **Constraint `constraints[4]`**: `$XDG_CONFIG_HOME` must be honored; path never
  hardcoded in shell code.

---

## Field → Consumer → Test Audit

Every field in `~/.config/furrow/config.yaml` must have at least one runtime
consumer and a regression test covering the project → XDG → compiled-in
precedence chain. `bin/frw.d/scripts/doctor-config-audit.sh` enumerates this
table at doctor-time and emits a non-gating warning for any field with zero
call sites.

| Field | Runtime consumer(s) | Resolver call site | Test coverage |
|-------|---------------------|--------------------|----------------|
| `cross_model.provider` | `bin/frw.d/scripts/cross-model-review.sh` (adopted by wave-3 `cross-model-per-deliverable-diff`; lines 79, 280, 446, 631) | `resolve_config_value "cross_model.provider"` (via the wave-3 deliverable) | `tests/integration/test-config-resolution.sh::test_three_tier_precedence` exercises the full chain for `cross_model.provider`; wave-3 adds a reviewer-level integration test. |
| `gate_policy` | `bin/rws::read_gate_policy` (called by `rws transition` at line ~1648) and `bin/frw.d/hooks/stop-ideation.sh` | `resolve_config_value gate_policy` | `tests/integration/test-config-resolution.sh::test_gate_policy_chain` (project override / XDG fallback / compiled-in default). |
| `preferred_specialists.<role>` | `skills/shared/specialist-delegation.md` decompose-time selection step | `resolve_config_value "preferred_specialists.${role}"` | `tests/integration/test-config-resolution.sh::test_preferred_specialists_chain` (project override / XDG fallback / unset → exit 1 / fallback logic). |
| `promotion_targets_path` | (none — SCAFFOLDING; Phase 2 lights this up) | (no call site yet) | N/A (doctor audit emits a WARN until a consumer lands). |

**Canonical resolver** is `resolve_config_value` in `bin/frw.d/lib/common.sh`
(lines ~121-151). No wrapper or default-accepting variant exists; callers use
the `value=$(resolve_config_value key) || value="default"` idiom.
Duplicating the helper is a review-blocker (see definition.yaml constraint
"Canonical resolver reuse").
