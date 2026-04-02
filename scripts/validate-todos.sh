#!/bin/sh
# validate-todos.sh — Validate a todos.yaml against schema and cross-field rules.
#
# Usage: validate-todos.sh [path-to-todos.yaml]
#   Default path: ./todos.yaml
# Exit 0 on valid, 1 on errors. Reports all errors before exiting.

set -eu

TODOS_FILE="${1:-./todos.yaml}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEMA_FILE="$SCRIPT_DIR/../adapters/shared/schemas/todos.schema.yaml"
errors=""

if [ ! -f "$TODOS_FILE" ]; then
  echo "Error: File not found: $TODOS_FILE" >&2
  exit 1
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "Error: Schema not found: $SCHEMA_FILE" >&2
  exit 1
fi

# Step 1: Schema validation (requires yq and python3)
if command -v yq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1; then
  json_tmp=$(mktemp)
  schema_tmp=$(mktemp)
  trap 'rm -f "$json_tmp" "$schema_tmp"' EXIT

  if ! yq -o=json '.' "$TODOS_FILE" > "$json_tmp" 2>/dev/null; then
    errors="${errors}Invalid YAML syntax in $TODOS_FILE\n"
  elif ! yq -o=json '.' "$SCHEMA_FILE" > "$schema_tmp" 2>/dev/null; then
    errors="${errors}Invalid YAML syntax in schema: $SCHEMA_FILE\n"
  else
    schema_errors=$(python3 -c "
import json, sys
try:
    from jsonschema import Draft202012Validator, FormatChecker
except ImportError:
    try:
        from jsonschema import Draft7Validator as Draft202012Validator
        FormatChecker = None
    except ImportError:
        print('SKIP: jsonschema not installed', file=sys.stderr)
        sys.exit(0)
with open(sys.argv[1]) as f:
    schema = json.load(f)
with open(sys.argv[2]) as f:
    instance = json.load(f)
kwargs = {}
if FormatChecker is not None:
    try:
        kwargs['format_checker'] = FormatChecker()
    except Exception:
        pass
validator = Draft202012Validator(schema, **kwargs)
errs = sorted(validator.iter_errors(instance), key=lambda e: list(e.path))
for e in errs:
    path = '.'.join(str(p) for p in e.absolute_path) or '(root)'
    print(f'Schema error at {path}: {e.message}')
" "$schema_tmp" "$json_tmp" 2>&1)
    if [ -n "$schema_errors" ]; then
      errors="${errors}${schema_errors}\n"
    fi
  fi
elif command -v yq >/dev/null 2>&1; then
  echo "Warning: python3 not found; skipping schema validation" >&2
else
  echo "Warning: yq not found; skipping all validation" >&2
  exit 0
fi

# Step 2: Cross-field checks — unique IDs
if command -v yq >/dev/null 2>&1; then
  ids=$(yq -r '.[].id' "$TODOS_FILE" 2>/dev/null) || ids=""
  if [ -n "$ids" ]; then
    dupes=$(echo "$ids" | sort | uniq -d)
    for dupe in $dupes; do
      errors="${errors}Duplicate TODO id: ${dupe}\n"
    done
  fi
fi

# Report results
if [ -n "$errors" ]; then
  printf "%b" "$errors" | sed '/^$/d' >&2
  exit 1
fi

echo "todos.yaml is valid"
exit 0
