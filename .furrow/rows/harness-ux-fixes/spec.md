# Spec: Harness UX Fixes

## summary-protocol-fragment

**New file**: `skills/shared/summary-protocol.md`

Content (under 30 lines):
- Title: "Summary Section Protocol"
- Declare the three agent-written sections: Key Findings, Open Questions, Recommendations
- Step-aware table: ideate → Open Questions only; research+ → all three
- Content requirements: >=2 non-empty bullet points per required section
- Timing: update sections BEFORE requesting step transition
- Format: bullet points starting with `- `, substantive (not "TBD" or "None")

**Modified files**: All 7 step skills (`skills/{ideate,research,plan,spec,decompose,implement,review}.md`)
- Add to "Shared References" section: `- \`skills/shared/summary-protocol.md\` — before completing step`
- Ideate gets: `- \`skills/shared/summary-protocol.md\` — Open Questions only at this step`

## summary-transition-block

**Modified file**: `commands/lib/step-transition.sh`
- Insert between line 91 (end of artifact validation) and line 121 (regeneration):
  ```
  # --- 1d. Validate summary sections ---
  current_step="$(jq -r '.step' "${state_file}")"
  "${scripts_dir}/../hooks/validate-summary.sh" "${current_step}" || {
    echo "Summary validation failed. Populate Key Findings, Open Questions, and Recommendations before advancing." >&2
    exit 4
  }
  ```
- Note: `current_step` is already computed at line 50 — reuse that variable

**Modified file**: `hooks/validate-summary.sh`
- Accept optional argument `$1` as step name (for step-aware mode)
- When called with step argument AND step is "ideate":
  - Only check Open Questions section (skip Key Findings, Recommendations)
- When called without argument (stop hook mode): check all three as today
- When called with step argument AND step is NOT "ideate": check all three
- Implementation: wrap the agent-written section loop (lines 62-73) with step-aware logic

## state-schema-init-hints

**Modified file**: `schemas/state.schema.json`
- Add to `properties` object (before `additionalProperties`):
  ```json
  "source_todo": {
    "type": ["string", "null"],
    "pattern": "^[a-z][a-z0-9]*(-[a-z0-9]+)*$",
    "description": "TODO entry ID this work unit was created from, or null"
  },
  "gate_policy_init": {
    "type": ["string", "null"],
    "enum": ["supervised", "delegated", "autonomous", null],
    "description": "Init-time gate policy hint for ideate step, or null"
  }
  ```
- Both fields are NOT in `required` array — they're optional with null defaults

**Modified file**: `adapters/shared/schemas/state.schema.json` — identical changes

**Modified file**: `commands/lib/init-work-unit.sh`
- Add `--source-todo` flag parsing (after --gate-policy block, same pattern):
  ```sh
  --source-todo)
    source_todo="${2:-}"
    shift 2 || { echo "Missing value for --source-todo" >&2; exit 1; }
    if ! echo "${source_todo}" | grep -qE '^[a-z][a-z0-9]*(-[a-z0-9]+)*$'; then
      echo "Invalid source-todo: must be kebab-case: '${source_todo}'" >&2
      exit 1
    fi
    ;;
  ```
- Add `source_todo=""` initialization with other vars (line 37)
- Modify jq template (lines 133-158) to include both new fields:
  - `--arg source_todo "${source_todo:-null}"` (use jq `if $x == "null" then null else $x end` pattern)
  - `--arg gate_policy_init "${gate_policy}"` (already resolved from flag or harness.yaml)
  - Add to JSON: `source_todo: (if $source_todo == "null" then null else $source_todo end)`
  - Add to JSON: `gate_policy_init: (if $gate_policy_init == "" then null else $gate_policy_init end)`
- Remove `.gate_policy_hint` file creation (delete lines 162-166)
- Update header comment to document --source-todo flag

## ideate-reads-init-hints

**Modified file**: `skills/ideate.md`
- In step 5 "Section-by-section approval", add after existing gate_policy line:
  ```
  If `state.json` has non-null `source_todo`, include it in definition.yaml.
  If `state.json` has non-null `gate_policy_init`, use it as the default for
  gate_policy in definition.yaml (user can override during approval).
  ```
