#!/bin/sh
# update-state.sh — Single mutation entry point for state.json
#
#
# Usage: update-state.sh <name> <jq-expression>
#   name          — work unit name (kebab-case)
#   jq-expression — jq filter to apply to state.json (e.g., '.title = "New Title"')
#
# All mutations go through this script. It:
#   1. Applies the jq expression to current state
#   2. Updates updated_at to current timestamp
#   3. Validates the result against the JSON schema
#   4. Writes atomically (temp file + move)
#
# Exit codes:
#   0 — success
#   1 — usage/argument error
#   2 — state.json not found
#   3 — schema validation failed
#   4 — jq expression failed

set -eu

# --- argument validation ---

if [ "$#" -lt 2 ]; then
  echo "Usage: update-state.sh <name> <jq-expression>" >&2
  exit 1
fi

name="$1"
jq_expr="$2"

# --- locate files ---

work_dir=".work/${name}"
state_file="${work_dir}/state.json"

if [ ! -f "${state_file}" ]; then
  echo "State file not found: ${state_file}" >&2
  exit 2
fi

# --- locate schema ---

script_dir="$(cd "$(dirname "$0")" && pwd)"
furrow_root="$(cd "${script_dir}/.." && pwd)"
schema_file="${furrow_root}/schemas/state.schema.json"

if [ ! -f "${schema_file}" ]; then
  echo "Schema file not found: ${schema_file}" >&2
  exit 1
fi

# --- apply mutation + update timestamp ---

now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

tmp_file="${state_file}.tmp.$$"

if ! jq --arg now "${now}" "${jq_expr} | .updated_at = \$now" "${state_file}" > "${tmp_file}" 2>/dev/null; then
  rm -f "${tmp_file}"
  echo "Failed to apply jq expression: ${jq_expr}" >&2
  exit 4
fi

# --- validate against schema ---

# Use jq-based schema validation (check required fields, enums, types)
# Full JSON Schema validation requires ajv or similar; we do structural checks here
# Check required fields exist and have correct types
validation_result="$(jq -r '
  def check_enum(val; allowed):
    if (val | type) != "string" then "type"
    elif ([val] | inside(allowed) | not) then "enum"
    else "ok"
    end;

  def check_nullable_string(val):
    if val == null then "ok"
    elif (val | type) == "string" then "ok"
    else "type"
    end;

  # Check required fields exist
  if .name == null then "missing:name"
  elif (.name | type) != "string" then "type:name"
  elif .title == null and (.title | type) != "string" then "type:title"
  elif (.description | type) != "string" then "type:description"
  elif check_enum(.step; ["ideate","research","plan","spec","decompose","implement","review"]) != "ok" then "invalid:step"
  elif check_enum(.step_status; ["not_started","in_progress","completed","blocked"]) != "ok" then "invalid:step_status"
  elif (.steps_sequence | type) != "array" then "type:steps_sequence"
  elif (.steps_sequence | length) != 7 then "length:steps_sequence"
  elif (.deliverables | type) != "object" then "type:deliverables"
  elif (.gates | type) != "array" then "type:gates"
  elif check_enum(.mode; ["code","research"]) != "ok" then "invalid:mode"
  elif (.base_commit | type) != "string" then "type:base_commit"
  elif (.created_at | type) != "string" then "type:created_at"
  elif (.updated_at | type) != "string" then "type:updated_at"
  elif check_nullable_string(.archived_at) != "ok" then "type:archived_at"
  elif check_nullable_string(.epic_id) != "ok" then "type:epic_id"
  elif check_nullable_string(.issue_id) != "ok" then "type:issue_id"
  elif check_nullable_string(.force_stop_at) != "ok" then "type:force_stop_at"
  elif check_nullable_string(.branch) != "ok" then "type:branch"
  else "ok"
  end
' "${tmp_file}" 2>/dev/null)" || validation_result="parse_error"

if [ "${validation_result}" != "ok" ]; then
  rm -f "${tmp_file}"
  echo "Schema validation failed: ${validation_result}" >&2
  exit 3
fi

# Validate deliverable entries if any exist
deliv_check="$(jq -r '
  [.deliverables | to_entries[] |
    if (.value | type) != "object" then "type:\(.key)"
    elif (.value.status | type) != "string" then "type:\(.key).status"
    elif ([.value.status] | inside(["not_started","in_progress","completed","blocked"]) | not) then "enum:\(.key).status"
    elif (.value.wave | type) != "number" then "type:\(.key).wave"
    elif (.value.corrections | type) != "number" then "type:\(.key).corrections"
    else empty
    end
  ] | if length == 0 then "ok" else .[0] end
' "${tmp_file}" 2>/dev/null)" || deliv_check="ok"

if [ "${deliv_check}" != "ok" ]; then
  rm -f "${tmp_file}"
  echo "Schema validation failed for deliverable: ${deliv_check}" >&2
  exit 3
fi

# Validate gate entries if any exist
gate_check="$(jq -r '
  def valid_step: . as $s | ["ideate","research","plan","spec","decompose","implement","review"] | index($s) != null;
  [.gates[] |
    if (.boundary | type) != "string" then "type:boundary"
    elif (.boundary | split("->") | length) != 2 then "format:boundary"
    elif (.boundary | split("->") | .[0] | valid_step | not) then "enum:boundary_from"
    elif (.boundary | split("->") | .[1] | valid_step | not) then "enum:boundary_to"
    elif ([.outcome] | inside(["pass","fail","conditional"]) | not) then "enum:outcome"
    elif ([.decided_by] | inside(["manual","evaluated","prechecked"]) | not) then "enum:decided_by"
    elif (.evidence | type) != "string" then "type:evidence"
    elif (.evidence | length) == 0 then "empty:evidence"
    elif (.timestamp | type) != "string" then "type:timestamp"
    elif .outcome == "conditional" and (.conditions | type) != "array" then "missing:conditions"
    elif .outcome != "conditional" and .conditions != null then "extra:conditions"
    else empty
    end
  ] | if length == 0 then "ok" else .[0] end
' "${tmp_file}" 2>/dev/null)" || gate_check="ok"

if [ "${gate_check}" != "ok" ]; then
  rm -f "${tmp_file}"
  echo "Schema validation failed for gate: ${gate_check}" >&2
  exit 3
fi

# --- atomic write ---

mv "${tmp_file}" "${state_file}"

echo "State updated: ${state_file}"
