# Spec: summary-generation-fix

## Overview
Fix regenerate-summary.sh to write empty sections instead of placeholder text, and read deliverable count from definition.yaml pre-decompose.

## Files to Modify
- `scripts/regenerate-summary.sh` — remove placeholder fallback, fix deliverable count

## Implementation

### 1. Remove placeholder fallback (lines 139-153)
Replace the placeholder logic:
```sh
# Current (remove):
if [ -z "${key_findings}" ] || [ "${kf_lines}" -lt 2 ]; then
  key_findings="Key Findings: To be written by step agent"
fi
# ... same for open_questions and recommendations
```

With empty-section behavior:
```sh
# New: leave empty if agent hasn't written content
# Validation hook (validate-summary.sh) enforces content at transition time
```

Simply remove the fallback assignments. When `key_findings` is empty, the heredoc writes `## Key Findings` followed by an empty line, which is valid markdown and clearly signals "not yet written."

### 2. Fix deliverable count (lines 50-51)
Current:
```sh
total_deliverables="$(jq -r '.deliverables | length' "${state_file}")"
completed_deliverables="$(jq -r '[.deliverables | to_entries[] | select(.value.status == "completed")] | length' "${state_file}")"
```

New logic:
```sh
total_deliverables="$(jq -r '.deliverables | length' "${state_file}")"
if [ "${total_deliverables}" -eq 0 ] && [ -f "${definition_file}" ] && command -v yq > /dev/null 2>&1; then
  total_deliverables="$(yq -r '.deliverables | length' "${definition_file}" 2>/dev/null)" || total_deliverables="0"
  completed_deliverables="0"
else
  completed_deliverables="$(jq -r '[.deliverables | to_entries[] | select(.value.status == "completed")] | length' "${state_file}")"
fi
```

This reads from definition.yaml when state.json has no deliverables (pre-decompose), falling back to 0 if definition.yaml isn't available.

### 3. Display format
When using definition.yaml count: `Deliverables: 0/6 (defined)`
When using state.json count: `Deliverables: 3/6`

## Acceptance Criteria Verification
- AC1: "regenerate-summary.sh reads deliverable count from definition.yaml when state.json has none" — verify count shows definition deliverables pre-decompose
- AC2: "Placeholder text for agent sections is removed" — verify no "To be written" text in output
- AC3: "step-transition.sh requires agent-written sections to be populated before accepting transition" — already enforced by existing summary validation in step-transition.sh (step 5 in current flow)
- AC4: "No catch-22 between placeholder text and validation hook" — verify empty sections pass regeneration but fail validation only at transition time
