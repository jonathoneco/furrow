# Specialist Delegation Protocol

When a step involves domain-specific reasoning, select and delegate to specialists:

1. **Scan** — read `specialists/_meta.yaml` scenarios index. Match `When` descriptions
   against the current task context (definition.yaml objective, deliverable names, file patterns).
2. **Consult preferred-specialist overrides** — for each role implied by the match
   (e.g. `harness`, `test-engineer`, `shell`), call
   `resolve_config_value "preferred_specialists.<role>"` via
   `bin/frw.d/lib/common.sh`. If the resolver returns a specialist name (exit 0),
   prefer that specialist over the scenario's default. If the resolver exits 1,
   fall through to the scenario-based selection from step 1.
3. **Select** — choose specialists whose scenarios (or preferred-specialist overrides)
   are relevant. Prefer fewer specialists (1-2) over broad coverage. When no scenario
   matches and no override is set, proceed without specialist delegation.
4. **Delegate** — dispatch selected specialists as **sub-agents** (never load into the
   orchestration session). Include the specialist template (`specialists/{name}.md`) in
   the sub-agent's context alongside the task-specific artifacts.
5. **Record** — note specialist selections in `summary.md` key-findings with rationale
   (e.g., "Selected go-specialist — scenario: error chain design for new CLI commands"
   or "Selected harness-engineer-beta via preferred_specialists.harness override").

The Step-Level Specialist Modifier in each step skill defines the emphasis shift
when working with a specialist at that step. Delegation is advisory at early steps
(ideate, research) and authoritative at later steps (decompose, implement).

## Preferred-specialist lookup (reference implementation)

The preferred-specialists override is the first runtime consumer of the
`preferred_specialists` XDG config field (previously write-only at install time).

```sh
# In a selection context where $role is e.g. "harness", "test-engineer":
#   PROJECT_ROOT and FURROW_ROOT must be exported (done by bin/frw and bin/rws).
. "${FURROW_ROOT}/bin/frw.d/lib/common.sh"

if override="$(resolve_config_value "preferred_specialists.${role}")"; then
  specialist="$override"          # project/XDG/compiled-in override wins
else
  specialist="$default_for_role"  # fall back to scenario-matched default
fi
```

Resolution order (first hit wins): project `.furrow/furrow.yaml` → XDG
`${XDG_CONFIG_HOME:-$HOME/.config}/furrow/config.yaml` → compiled-in
`${FURROW_ROOT}/.furrow/furrow.yaml`. See
`docs/architecture/config-resolution.md` for the full three-tier contract.
