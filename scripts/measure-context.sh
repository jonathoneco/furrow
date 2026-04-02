#!/bin/sh
# measure-context.sh — Report per-layer line counts and enforce budgets.
#
# Usage: measure-context.sh [harness-root]
# Exit 0 if all budgets pass, 1 if any violated.

set -eu

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
errors=0

# Count lines in a file (0 if missing)
count_lines() {
  if [ -f "$1" ]; then
    wc -l < "$1"
  else
    echo 0
  fi
}

# Count lines across files matching a glob
count_dir_lines() {
  total=0
  for f in "$1"/*.md; do
    [ -f "$f" ] || continue
    n=$(wc -l < "$f")
    total=$((total + n))
  done
  echo "$total"
}

# --- Ambient layer: CLAUDE.md + rules/ ---
claude_md=$(count_lines "$ROOT/.claude/CLAUDE.md")
rules_lines=$(count_dir_lines "$ROOT/.claude/rules")
ambient=$((claude_md + rules_lines))

# --- Work layer ---
work_layer=$(count_lines "$ROOT/skills/work-context.md")

# --- Step layer (per step) ---
step_max=0
step_max_name=""
step_errors=""
for step in ideate research plan spec decompose implement review; do
  step_file="$ROOT/skills/${step}.md"
  if [ -f "$step_file" ]; then
    n=$(wc -l < "$step_file")
    if [ "$n" -gt 50 ]; then
      step_errors="${step_errors}  FAIL: skills/${step}.md = ${n} lines (budget: 50)\n"
      errors=1
    fi
    if [ "$n" -gt "$step_max" ]; then
      step_max="$n"
      step_max_name="$step"
    fi
  fi
done

# --- Reference layer ---
ref_lines=$(count_dir_lines "$ROOT/references")

# --- Shared skill blocks (Reference layer, NOT Step layer) ---
shared_lines=0
if [ -d "$ROOT/skills/shared" ]; then
  for f in "$ROOT/skills/shared"/*.md; do
    [ -f "$f" ] || continue
    n=$(wc -l < "$f")
    shared_lines=$((shared_lines + n))
  done
fi

# --- Total injected (excludes _rationale.yaml, skills/shared/) ---
total_injected=$((ambient + work_layer + step_max))

# --- Report ---
echo "=== Context Budget Report ==="
echo ""
echo "Ambient layer (CLAUDE.md + rules/):"
echo "  .claude/CLAUDE.md:    ${claude_md} lines"
echo "  .claude/rules/:       ${rules_lines} lines"
echo "  Total:                ${ambient} lines (budget: 100)"

if [ "$ambient" -gt 100 ]; then
  echo "  FAIL: ambient layer exceeds budget"
  errors=1
else
  echo "  OK"
fi

echo ""
echo "Work layer:"
echo "  skills/work-context.md: ${work_layer} lines (budget: 150)"

if [ "$work_layer" -gt 150 ]; then
  echo "  FAIL: work layer exceeds budget"
  errors=1
else
  echo "  OK"
fi

echo ""
echo "Step layer (largest: ${step_max_name} = ${step_max} lines, budget: 50 each):"
if [ -n "$step_errors" ]; then
  printf "%b" "$step_errors"
else
  echo "  OK"
fi

echo ""
echo "Total injected (ambient + work + largest step):"
echo "  ${ambient} + ${work_layer} + ${step_max} = ${total_injected} (budget: 300)"

if [ "$total_injected" -gt 300 ]; then
  echo "  FAIL: total injected exceeds budget"
  errors=1
else
  echo "  OK"
fi

echo ""
echo "Reference layer (on-demand, NOT injected):"
echo "  references/:          ${ref_lines} lines"
echo "  skills/shared/:       ${shared_lines} lines"
ref_total=$((ref_lines + shared_lines))
echo "  Total:                ${ref_total} lines (target: ~600)"

# Warn if reference layer deviates >20% from 600
if [ "$ref_total" -gt 0 ]; then
  low=$((600 * 80 / 100))
  high=$((600 * 120 / 100))
  if [ "$ref_total" -lt "$low" ] || [ "$ref_total" -gt "$high" ]; then
    echo "  WARN: reference layer deviates >20% from 600-line target"
  else
    echo "  OK"
  fi
else
  echo "  WARN: no reference files found"
fi

echo ""
echo "Excluded from budgets:"
rationale_lines=$(count_lines "$ROOT/_rationale.yaml")
echo "  _rationale.yaml:      ${rationale_lines} lines (not injected)"

echo ""
if [ "$errors" -ne 0 ]; then
  echo "RESULT: FAIL — budget violations detected"
  exit 1
else
  echo "RESULT: PASS — all budgets within limits"
  exit 0
fi
