#!/bin/sh
# validate-definition.sh — Validate definition.yaml against spec 00 SS1.1
#
# Usage: validate-definition.sh <path-to-definition.yaml>
#
# Exit codes:
#   0 — valid
#   1 — usage error
#   2 — file not found
#   3 — validation failure

set -eu

if [ "$#" -lt 1 ]; then
  echo "Usage: validate-definition.sh <path-to-definition.yaml>" >&2
  exit 1
fi

def_file="$1"

if [ ! -f "${def_file}" ]; then
  echo "Definition file not found: ${def_file}" >&2
  exit 2
fi

if ! command -v yq > /dev/null 2>&1; then
  echo "Required tool 'yq' not found" >&2
  exit 1
fi

errors=""

# --- required fields ---

objective="$(yq -r '.objective // ""' "${def_file}")"
if [ -z "${objective}" ]; then
  errors="${errors}Missing required field: objective\n"
fi

gate_policy="$(yq -r '.gate_policy // ""' "${def_file}")"
if [ -z "${gate_policy}" ]; then
  errors="${errors}Missing required field: gate_policy\n"
else
  case "${gate_policy}" in
    supervised|delegated|autonomous) ;;
    *)
      errors="${errors}Invalid gate_policy: '${gate_policy}'. Must be supervised, delegated, or autonomous.\n"
      ;;
  esac
fi

# --- mode enum (optional) ---

mode="$(yq -r '.mode // ""' "${def_file}")"
if [ -n "${mode}" ]; then
  case "${mode}" in
    code|research) ;;
    *)
      errors="${errors}Invalid mode: '${mode}'. Must be code or research.\n"
      ;;
  esac
fi

# --- deliverables (min 1) ---

deliv_count="$(yq -r '.deliverables | length' "${def_file}" 2>/dev/null)" || deliv_count="0"
if [ "${deliv_count}" -eq 0 ]; then
  errors="${errors}At least 1 deliverable required.\n"
fi

# --- deliverable name uniqueness ---

if [ "${deliv_count}" -gt 0 ]; then
  total_names="$(yq -r '.deliverables[].name' "${def_file}" 2>/dev/null | wc -l)"
  unique_names="$(yq -r '.deliverables[].name' "${def_file}" 2>/dev/null | sort -u | wc -l)"
  if [ "${total_names}" -ne "${unique_names}" ]; then
    errors="${errors}Duplicate deliverable names found.\n"
  fi

  # --- each deliverable needs acceptance_criteria ---
  idx=0
  while [ "${idx}" -lt "${deliv_count}" ]; do
    dname="$(yq -r ".deliverables[${idx}].name // \"\"" "${def_file}")"
    if [ -z "${dname}" ]; then
      errors="${errors}Deliverable at index ${idx} missing name.\n"
    fi
    ac_count="$(yq -r ".deliverables[${idx}].acceptance_criteria | length" "${def_file}" 2>/dev/null)" || ac_count="0"
    if [ "${ac_count}" -eq 0 ]; then
      errors="${errors}Deliverable '${dname}' must have at least 1 acceptance criterion.\n"
    fi
    idx=$((idx + 1))
  done

  # --- depends_on validation ---
  all_names="$(yq -r '.deliverables[].name' "${def_file}" 2>/dev/null)"
  all_deps="$(yq -r '.deliverables[].depends_on[]? // empty' "${def_file}" 2>/dev/null)" || all_deps=""
  if [ -n "${all_deps}" ]; then
    for dep in ${all_deps}; do
      if ! echo "${all_names}" | grep -qx "${dep}"; then
        errors="${errors}Dangling depends_on reference: '${dep}' does not match any deliverable name.\n"
      fi
    done
  fi
fi

# --- context_pointers (min 1) ---

cp_count="$(yq -r '.context_pointers | length' "${def_file}" 2>/dev/null)" || cp_count="0"
if [ "${cp_count}" -eq 0 ]; then
  errors="${errors}At least 1 context_pointer required.\n"
fi

# --- report ---

if [ -n "${errors}" ]; then
  printf "definition.yaml validation failed:\n%b" "${errors}" >&2
  exit 3
fi

echo "definition.yaml is valid"
