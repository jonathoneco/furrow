#!/bin/sh
# validate-definition.sh — Validate a definition.yaml against schema and cross-field rules.
#
# Usage: frw validate-definition <path-to-definition.yaml>
# Return 0 on valid, 1 on errors. Reports all errors before returning.

frw_validate_definition() {
  set -eu

  if [ $# -ne 1 ]; then
    echo "Usage: frw validate-definition <definition.yaml>" >&2
    return 1
  fi

  DEFINITION_FILE="$1"
  SCHEMA_FILE="$FURROW_ROOT/schemas/definition.schema.json"
  errors=""

  if [ ! -f "$DEFINITION_FILE" ]; then
    echo "Error: File not found: $DEFINITION_FILE" >&2
    return 1
  fi

  if [ ! -f "$SCHEMA_FILE" ]; then
    echo "Error: Schema not found: $SCHEMA_FILE" >&2
    return 1
  fi

  # Step 1: Schema validation (requires yq and ajv or python)
  # Convert YAML to JSON then validate
  if command -v yq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
    json_tmp=$(mktemp)
    if ! yq -o=json '.' "$DEFINITION_FILE" > "$json_tmp" 2>/dev/null; then
      errors="${errors}Invalid YAML syntax in $DEFINITION_FILE\n"
    else
      schema_errors=$(python3 -c "
import json, sys
try:
    from jsonschema import validate, ValidationError, Draft7Validator
except ImportError:
    print('SKIP: jsonschema not installed', file=sys.stderr)
    sys.exit(0)
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
validator = Draft7Validator(schema)
errs = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
for e in errs:
    path = '.'.join(str(p) for p in e.absolute_path) or '(root)'
    print(f'Schema error at {path}: {e.message}')
" "$SCHEMA_FILE" "$json_tmp" 2>&1)
      if [ -n "$schema_errors" ]; then
        errors="${errors}${schema_errors}\n"
      fi
    fi
    rm -f "$json_tmp"
  elif command -v yq >/dev/null 2>&1; then
    echo "Warning: python3 not found; skipping schema validation" >&2
  else
    echo "Warning: yq not found; skipping schema validation" >&2
  fi

  # Step 2: Cross-field checks using yq
  if command -v yq >/dev/null 2>&1; then
    # Check deliverable name uniqueness
    names=$(yq -r '.deliverables[].name' "$DEFINITION_FILE" 2>/dev/null)
    if [ -n "$names" ]; then
      dupes=$(echo "$names" | sort | uniq -d)
      for dupe in $dupes; do
        errors="${errors}Duplicate deliverable name: ${dupe}\n"
      done

      # Check dangling depends_on references
      deps=$(yq -r '.deliverables[].depends_on[]?' "$DEFINITION_FILE" 2>/dev/null) || deps=""
      for dep in $deps; do
        if ! echo "$names" | grep -qx "$dep"; then
          # Find which deliverable references this
          referrer=$(yq -r ".deliverables[] | select(.depends_on[]? == \"$dep\") | .name" "$DEFINITION_FILE" 2>/dev/null | head -1)
          errors="${errors}Dangling dependency: ${referrer} depends on ${dep} which does not exist\n"
        fi
      done

      # Check for dependency cycles using DFS
      cycle_errors=$(python3 -c "
import subprocess, sys, json
try:
    import yaml
except ImportError:
    # Fall back to yq for YAML parsing
    result = subprocess.run(['yq', '-o=json', '.', sys.argv[1]],
                          capture_output=True, text=True)
    data = json.loads(result.stdout)
else:
    with open(sys.argv[1]) as f:
        data = yaml.safe_load(f)

deliverables = data.get('deliverables', [])
graph = {}
for d in deliverables:
    name = d.get('name', '')
    deps = d.get('depends_on', []) or []
    graph[name] = deps

# DFS cycle detection
WHITE, GRAY, BLACK = 0, 1, 2
color = {n: WHITE for n in graph}
path = []

def dfs(node):
    color[node] = GRAY
    path.append(node)
    for dep in graph.get(node, []):
        if dep not in color:
            continue
        if color[dep] == GRAY:
            cycle_start = path.index(dep)
            cycle = path[cycle_start:] + [dep]
            print('Dependency cycle detected: ' + ' -> '.join(cycle))
            return True
        if color[dep] == WHITE:
            if dfs(dep):
                return True
    path.pop()
    color[node] = BLACK
    return False

for node in graph:
    if color[node] == WHITE:
        dfs(node)
" "$DEFINITION_FILE" 2>&1)
      if [ -n "$cycle_errors" ]; then
        errors="${errors}${cycle_errors}\n"
      fi
    fi
  fi

  # Report results
  if [ -n "$errors" ]; then
    printf "%b" "$errors" | sed '/^$/d' >&2
    return 1
  fi

  echo "definition.yaml is valid"
  return 0
}
