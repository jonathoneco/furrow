#!/bin/sh
# harness-doctor.sh — Self-diagnosis for V2 work harness structural health.
#
# Usage: harness-doctor.sh [--research] [harness-root]
# Exit 0 = all pass, 1 = failures found.

set -eu

research=0
ROOT=""
for arg in "$@"; do
  case "$arg" in
    --research) research=1 ;;
    *) ROOT="$arg" ;;
  esac
done
ROOT="${ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
failures=0
warnings=0

# --- output helpers ---

section() { echo ""; echo "--- $1 ---"; }
check_pass() { echo "  [PASS] $1"; }
check_fail() { echo "  [FAIL] $1" >&2; failures=$((failures + 1)); }
check_warn() { echo "  [WARN] $1"; warnings=$((warnings + 1)); }

# ============================================================
# Tier 1: Structural (always run)
# ============================================================

echo "=== Harness Doctor ==="

# --- Check 1: Context budget ---
section "Context budgets"
if "$ROOT/scripts/measure-context.sh" "$ROOT" > /dev/null 2>&1; then
  check_pass "context budgets within limits"
else
  check_fail "context budget violations (run scripts/measure-context.sh for details)"
fi

# --- Check 2: No inline exists_because/delete_when ---
section "Rationale containment"
_stray=$(grep -rl 'exists_because:\|delete_when:' "$ROOT" 2>/dev/null \
  | grep -v '_rationale\.yaml' | grep -v '\.git' \
  | grep -v '/specs/' | grep -v '/research/' | grep -v '/plan/' \
  | grep -v '/docs/' | grep -v '\.work/' \
  | grep -v '\.sh$' | grep -v '\.py$' || true)
if [ -z "$_stray" ]; then
  _count=$(grep -c 'exists_because:' "$ROOT/_rationale.yaml" 2>/dev/null || echo 0)
  check_pass "rationale contained ($_count entries in _rationale.yaml, 0 inline)"
else
  for _f in $_stray; do
    _short=$(echo "$_f" | sed "s|^$ROOT/||")
    check_fail "inline rationale in $_short"
  done
fi

# --- Check 3: All _rationale.yaml paths exist on disk ---
section "Rationale manifest integrity"
if command -v yq > /dev/null 2>&1; then
  _paths=$(yq -r '.components[].path' "$ROOT/_rationale.yaml" 2>/dev/null) || _paths=""
  _missing=0
  _total=0
  for _p in $_paths; do
    _total=$((_total + 1))
    if [ ! -e "$ROOT/$_p" ]; then
      check_fail "rationale path missing: $_p"
      _missing=$((_missing + 1))
    fi
  done
  if [ "$_missing" -eq 0 ]; then
    check_pass "all $_total rationale paths exist on disk"
  fi
else
  check_warn "yq not available; skipping rationale manifest check"
fi

# --- Check 4: Step skill Read pointer targets exist ---
section "Skill Read pointers"
_read_missing=0
for _skill in "$ROOT"/skills/*.md "$ROOT"/skills/shared/*.md; do
  [ -f "$_skill" ] || continue
  _refs=$(grep -oE '`[a-z][^`]*\.(md|yaml|json)`' "$_skill" | tr -d '`' || true)
  for _ref in $_refs; do
    # Skip template variables like {step}.md or {artifact-type}.yaml
    case "$_ref" in *"{"*) continue ;; esac
    case "$_ref" in
      skills/*|references/*|evals/*|docs/*|specialists/*|schemas/*|scripts/*)
        if [ ! -e "$ROOT/$_ref" ]; then
          _skill_short=$(echo "$_skill" | sed "s|^$ROOT/||")
          check_fail "$_skill_short -> $_ref (not found)"
          _read_missing=$((_read_missing + 1))
        fi
        ;;
    esac
  done
done
if [ "$_read_missing" -eq 0 ]; then
  check_pass "all skill Read pointers resolve"
fi

# --- Check 5: settings.json has entries for all hooks/*.sh ---
section "Hook registrations"
_hook_missing=0
for _hook in "$ROOT"/hooks/*.sh; do
  [ -f "$_hook" ] || continue
  # Skip validation scripts that aren't lifecycle hooks (they take args, not stdin JSON)
  grep -q '^# Hook:' "$_hook" 2>/dev/null || continue
  _hook_rel="hooks/$(basename "$_hook")"
  if ! grep -q "$_hook_rel" "$ROOT/.claude/settings.json" 2>/dev/null; then
    check_fail "hook not registered in settings.json: $_hook_rel"
    _hook_missing=$((_hook_missing + 1))
  fi
done
if [ "$_hook_missing" -eq 0 ]; then
  check_pass "all hooks/*.sh registered in settings.json"
fi

# --- Check 6: No stale adapter YAML artifacts ---
section "Adapter binding integrity"
_stale=0
for _yaml in "$ROOT"/adapters/claude-code/hooks/*.yaml; do
  [ -f "$_yaml" ] || continue
  _cmd=$(grep '^command:' "$_yaml" 2>/dev/null | sed 's/command:[[:space:]]*"//; s/".*//' | awk '{print $1}')
  if [ -n "$_cmd" ] && [ ! -f "$ROOT/$_cmd" ]; then
    _yaml_short=$(echo "$_yaml" | sed "s|^$ROOT/||")
    check_fail "stale binding: $_yaml_short -> $_cmd (not found)"
    _stale=$((_stale + 1))
  fi
done
if [ "$_stale" -eq 0 ]; then
  check_pass "no stale adapter YAML bindings"
fi

# --- Check 7: Step skills within 50-line budget ---
section "Step skill line budgets"
_over=0
for _step in ideate research plan spec decompose implement review; do
  _sf="$ROOT/skills/${_step}.md"
  if [ -f "$_sf" ]; then
    _n=$(wc -l < "$_sf")
    if [ "$_n" -gt 50 ]; then
      check_fail "skills/${_step}.md = ${_n} lines (budget: 50)"
      _over=$((_over + 1))
    fi
  fi
done
if [ "$_over" -eq 0 ]; then
  check_pass "all step skills within 50-line budget"
fi

# --- Check 8: No dedup violations (layer-pair comparison) ---
section "Cross-layer deduplication"
_dupes=0
# Extract instruction-like lines (>= 20 chars) from each layer
_ambient_lines=$(grep -rh '^- \|^[0-9]\. ' "$ROOT/.claude/" 2>/dev/null | sed 's/^[[:space:]]*//' | awk 'length >= 20' | sort -u || true)
_work_lines=$(grep -h '^- \|^[0-9]\. ' "$ROOT/skills/work-context.md" 2>/dev/null | sed 's/^[[:space:]]*//' | awk 'length >= 20' | sort -u || true)
_step_lines=$(cat "$ROOT"/skills/ideate.md "$ROOT"/skills/research.md "$ROOT"/skills/plan.md "$ROOT"/skills/spec.md "$ROOT"/skills/decompose.md "$ROOT"/skills/implement.md "$ROOT"/skills/review.md 2>/dev/null | grep '^- \|^[0-9]\. ' | sed 's/^[[:space:]]*//' | awk 'length >= 20' | sort -u || true)

# Compare layer pairs (not step-vs-step)
_check_pair() {
  _pair_name="$1"
  _a="$2"
  _b="$3"
  if [ -n "$_a" ] && [ -n "$_b" ]; then
    _overlap=$(echo "$_a" | while IFS= read -r _line; do
      echo "$_b" | grep -Fxq "$_line" 2>/dev/null && echo "$_line"
    done || true)
    if [ -n "$_overlap" ]; then
      _count=$(echo "$_overlap" | wc -l | tr -d ' ')
      check_fail "$_count duplicate lines: $_pair_name"
      _dupes=$((_dupes + _count))
    fi
  fi
}
_check_pair "ambient-vs-work" "$_ambient_lines" "$_work_lines"
_check_pair "ambient-vs-step" "$_ambient_lines" "$_step_lines"
_check_pair "work-vs-step" "$_work_lines" "$_step_lines"
if [ "$_dupes" -eq 0 ]; then
  check_pass "no duplicate instructions across layers"
fi

# ============================================================
# Tier 1.5: Spec completeness (always run)
# ============================================================

section "Spec-mandated files (Phase 4: Ceremony/Lifecycle/Learnings/Git)"
_spec_missing=0
_spec_check() {
  _spec="$1"; _path="$2"
  if [ -e "$ROOT/$_path" ]; then
    : # pass silently to keep output focused on gaps
  else
    check_fail "[$_spec] missing: $_path"
    _spec_missing=$((_spec_missing + 1))
  fi
}

# Spec 09: Ideation ceremony
_spec_check "Spec 09" "hooks/stop-ideation.sh"
_spec_check "Spec 09" "hooks/validate-definition.sh"

# Spec 10: Step sequence & auto-advance
_spec_check "Spec 10" "hooks/validate-summary.sh"

# Spec 12: Knowledge & learnings
_spec_check "Spec 12" "skills/shared/learnings-protocol.md"
_spec_check "Spec 12" "commands/lib/validate-learning.sh"
_spec_check "Spec 12" "commands/lib/append-learning.sh"
_spec_check "Spec 12" "commands/lib/promote-learnings.sh"

# Spec 13: Git workflow
_spec_check "Spec 13" "skills/shared/git-conventions.md"
_spec_check "Spec 13" "scripts/create-work-branch.sh"
_spec_check "Spec 13" "scripts/merge-to-main.sh"

if [ "$_spec_missing" -eq 0 ]; then
  check_pass "all Phase 4 spec-mandated files exist"
fi

section "Spec-mandated files (Phase 5: Commands/Research)"
_p5_missing=0
_p5_check() {
  _spec="$1"; _path="$2"
  if [ -e "$ROOT/$_path" ]; then
    :
  else
    check_fail "[$_spec] missing: $_path"
    _p5_missing=$((_p5_missing + 1))
  fi
}

# Spec 11: Command layer (8 commands consolidated from V1's 24)
_p5_check "Spec 11" "commands/checkpoint.md"
_p5_check "Spec 11" "commands/archive.md"
_p5_check "Spec 11" "commands/status.md"
_p5_check "Spec 11" "commands/review.md"
_p5_check "Spec 11" "commands/reground.md"
_p5_check "Spec 11" "commands/redirect.md"

# Spec 14: Research work type
_p5_check "Spec 14" "references/research-mode.md"
_p5_check "Spec 14" "evals/dimensions/research-implement.yaml"
_p5_check "Spec 14" "evals/dimensions/research-spec.yaml"

if [ "$_p5_missing" -eq 0 ]; then
  check_pass "all Phase 5 spec-mandated files exist"
fi

# Placeholder sections in step skills (should be filled by their owning work items)
section "Unfilled placeholder sections"
_placeholders=0
for _skill in "$ROOT"/skills/*.md; do
  [ -f "$_skill" ] || continue
  _ph=$(grep -c '<!-- Section:.*owner:' "$_skill" 2>/dev/null || true)
  _ph=$(echo "$_ph" | tr -d '[:space:]')
  [ -z "$_ph" ] && _ph=0
  if [ "$_ph" -gt 0 ]; then
    _skill_short=$(echo "$_skill" | sed "s|^$ROOT/||")
    check_warn "$_skill_short has $_ph unfilled placeholder sections"
    _placeholders=$((_placeholders + _ph))
  fi
done
if [ "$_placeholders" -eq 0 ]; then
  check_pass "no unfilled placeholder sections in step skills"
fi

# ============================================================
# Tier 2: Research compliance (--research flag)
# ============================================================

if [ "$research" -eq 1 ]; then
  section "Settled Decisions (SD1-SD15)"

  _sd() {
    _id="$1"; _desc="$2"; shift 2
    if eval "$@" > /dev/null 2>&1; then
      check_pass "SD-$_id: $_desc"
    else
      check_fail "SD-$_id: $_desc"
    fi
  }

  _sd 1 "rationale manifest exists with entries" \
    "test -f '$ROOT/_rationale.yaml' && grep -q 'exists_because:' '$ROOT/_rationale.yaml'"

  _sd 2 "three enforcement levels present" \
    "test -d '$ROOT/hooks' && test -d '$ROOT/skills' && test -f '$ROOT/hooks/lib/validate.sh'"

  _sd 3 "context budget script exists and passes" \
    "'$ROOT/scripts/measure-context.sh' '$ROOT'"

  _sd 4 "definition schema has required fields" \
    "test -f '$ROOT/schemas/definition.schema.json' && grep -q 'objective' '$ROOT/schemas/definition.schema.json'"

  _sd 5 "gate records require outcome field" \
    "grep -q 'outcome' '$ROOT/schemas/state.schema.json'"

  _sd 6 "two-phase review methodology defined" \
    "grep -q 'Phase A' '$ROOT/references/review-methodology.md' && grep -q 'Phase B' '$ROOT/references/review-methodology.md'"

  _sd 7 "summary regeneration script exists" \
    "test -x '$ROOT/scripts/regenerate-summary.sh' || test -f '$ROOT/scripts/regenerate-summary.sh'"

  _sd 8 "gate records are append-only" \
    "grep -q '.gates += ' '$ROOT/scripts/record-gate.sh'"

  _sd 9 "instruction budget enforced" \
    "'$ROOT/scripts/measure-context.sh' '$ROOT'"

  _sd 10 "file-based agent communication" \
    "! grep -rq 'shared_memory\|shared_state\|IPC_' '$ROOT/hooks/' '$ROOT/scripts/' --exclude='harness-doctor.sh' 2>/dev/null"

  _sd 11 "dual-runtime adapters exist" \
    "test -d '$ROOT/adapters/claude-code' && test -d '$ROOT/adapters/agent-sdk'"

  _sd 12 "trust gradient modes defined" \
    "grep -q 'supervised' '$ROOT/references/gate-protocol.md' && grep -q 'autonomous' '$ROOT/references/gate-protocol.md'"

  _sd 13 "post-compact reads only state+summary+skill" \
    "grep -q 'state.json\|summary.md' '$ROOT/hooks/post-compact.sh'"

  _sd 14 "findings as first-class entities" \
    "grep -q 'OPEN\|FIXED\|DEFERRED\|WONTFIX' '$ROOT/docs/architecture/handoffs/phase-5-knowledge.md' 2>/dev/null || grep -q 'OPEN' '$ROOT/references/review-methodology.md' 2>/dev/null"

  _sd 15 "designed to shrink (delete_when present)" \
    "grep -c 'delete_when:' '$ROOT/_rationale.yaml' | grep -qv '^0$'"

  section "Additional Tier 2 checks"

  _sd 16 "advance-step rejects fail outcomes" \
    "grep -q 'outcome.*pass.*conditional\|outcome == .pass' '$ROOT/scripts/advance-step.sh'"

  _sd 17 "naming validation exists" \
    "test -f '$ROOT/scripts/validate-naming.sh'"

  _sd 18 "step sequence is 7-step canonical" \
    "grep -c 'ideate\|research\|plan\|spec\|decompose\|implement\|review' '$ROOT/skills/work-context.md' | awk '\$1 >= 7'"
fi

# ============================================================
# Summary
# ============================================================

echo ""
echo "=== Harness Doctor Summary ==="
echo "  Failures: $failures"
echo "  Warnings: $warnings"
if [ "$failures" -gt 0 ]; then
  echo "  RESULT: FAIL"
  exit 1
else
  echo "  RESULT: PASS"
  exit 0
fi
