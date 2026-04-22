#!/bin/sh
# launch-phase.sh — Create worktrees, tmux sessions, and launch Claude for a roadmap phase
#
# Usage: launch-phase.sh [--phase N] [--yolo]
#
# Reads .furrow/almanac/roadmap.yaml to extract rows for the target phase,
# creates git worktrees, writes prompt files, creates tmux sessions, and
# launches interactive Claude sessions in each.
#
# Requires: tmux, yq, jq, claude

set -eu

# --- parse args ---
phase=""
yolo=""
while [ $# -gt 0 ]; do
  case "$1" in
    --phase) phase="$2"; shift 2 ;;
    --yolo)  yolo="--dangerously-skip-permissions"; shift ;;
    *)       echo "Usage: launch-phase.sh [--phase N] [--yolo]" >&2; exit 1 ;;
  esac
done

# --- preflight ---
command -v tmux >/dev/null 2>&1 || { echo "error: tmux is not installed" >&2; exit 1; }
command -v yq >/dev/null 2>&1   || { echo "error: yq is not installed" >&2; exit 1; }
command -v claude >/dev/null 2>&1 || { echo "error: claude is not installed" >&2; exit 1; }

# --- locate files ---
furrow_yaml=""
for candidate in .furrow/furrow.yaml .claude/furrow.yaml furrow.yaml; do
  if [ -f "$candidate" ]; then
    furrow_yaml="$candidate"
    break
  fi
done
[ -n "$furrow_yaml" ] || { echo "error: no furrow.yaml found" >&2; exit 1; }

roadmap=".furrow/almanac/roadmap.yaml"
[ -f "$roadmap" ] || { echo "error: no $roadmap found. Run /furrow:triage first." >&2; exit 1; }

project_name=$(yq -r '.project.name // "project"' "$furrow_yaml")

# --- resolve phase ---
if [ -z "$phase" ]; then
  phase=$(yq -r '[.phases[] | select(.status == "planned" or .status == "in_progress")] | .[0].number // empty' "$roadmap")
  [ -n "$phase" ] || { echo "All phases complete. Run /furrow:triage to plan next work." >&2; exit 0; }
fi

phase_data=$(yq -o=json ".phases[] | select(.number == $phase)" "$roadmap")
[ -n "$phase_data" ] || { echo "error: phase $phase not found in $roadmap" >&2; exit 1; }

phase_title=$(printf '%s' "$phase_data" | jq -r '.title')
row_count=$(printf '%s' "$phase_data" | jq -r '.rows | length')

echo "Phase $phase — $phase_title ($row_count rows)"
echo ""

# --- process each row ---
printf '%s' "$phase_data" | jq -c '.rows[]' | while IFS= read -r row; do
  branch=$(printf '%s' "$row" | jq -r '.branch')
  description=$(printf '%s' "$row" | jq -r '.description')
  row_name=$(printf '%s' "$branch" | sed 's|^work/||')
  worktree_dir="../${project_name}-${row_name}"
  session_name="${project_name}-${row_name}"
  prompt_file="/tmp/furrow-prompt-${row_name}.txt"

  # Collect TODO info
  todo_lines=""
  todo_ids=$(printf '%s' "$row" | jq -r '.todos[]')
  for tid in $todo_ids; do
    title=$(yq -r ".[] | select(.id == \"$tid\") | .title" .furrow/almanac/todos.yaml 2>/dev/null || echo "$tid")
    todo_lines="${todo_lines}
- ${tid} — ${title}"
  done

  # Collect key files
  key_files=$(printf '%s' "$row" | jq -r '.key_files[]' 2>/dev/null | sort -u | sed 's/^/- /')

  # Create worktree if it doesn't exist
  if [ -d "$worktree_dir" ]; then
    echo "  Worktree $worktree_dir already exists, reusing"
  else
    echo "  Creating worktree $worktree_dir on branch $branch"
    if git rev-parse --verify "$branch" >/dev/null 2>&1; then
      git worktree add "$worktree_dir" "$branch"
    else
      git worktree add "$worktree_dir" -b "$branch"
    fi
  fi

  # Write prompt file
  cat > "$prompt_file" <<PROMPT
/furrow:work ${row_name} — ${description}

Scope: $(printf '%s' "$row" | jq -r '.todos | length') deliverables on branch ${branch}.
See .furrow/almanac/roadmap.yaml Phase ${phase} for rationale and ordering.

Source TODOs in .furrow/almanac/todos.yaml (read context and work_needed for full detail):${todo_lines}

Key files:
${key_files}
- .furrow/almanac/todos.yaml — detailed context and work_needed for each TODO
- .furrow/almanac/roadmap.yaml — Phase ${phase} plan and dependency reasoning
PROMPT

  # Create tmux session and launch claude
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "  tmux session $session_name already exists, skipping"
  else
    echo "  Creating tmux session: $session_name"
    tmux new-session -d -s "$session_name" -c "$(cd "$worktree_dir" && pwd)"
    tmux send-keys -t "$session_name" "claude $yolo \"\$(cat $prompt_file)\"" Enter
    # Hook: generate reintegration summary when the worktree's primary session ends.
    # Runs out-of-band via tmux set-hook so the launcher itself remains non-blocking.
    if [ "${FURROW_AUTO_REINTEGRATE:-1}" = "1" ]; then
      tmux set-hook -t "$session_name" session-closed \
        "run-shell 'cd \"$(cd "$worktree_dir" && pwd)\" && rws generate-reintegration \"$row_name\" >/dev/null 2>&1 || true'"
    fi
  fi

  echo ""
done

echo "Done. Attach with: tmux attach -t ${project_name}-<row-name>"
echo ""
tmux list-sessions 2>/dev/null | grep "^${project_name}-" || true
