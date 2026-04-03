#!/bin/sh
# init.sh — Initialize Furrow in the current project.
#
# Sourced by bin/frw; not executed directly.
# Expects: FURROW_ROOT set by the dispatcher.

frw_init() {
  _prefix=""

  # --- parse args ---
  while [ $# -gt 0 ]; do
    case "$1" in
      --prefix)
        [ $# -ge 2 ] || { echo "frw init: --prefix requires a value" >&2; return 1; }
        _prefix="$2"; shift 2 ;;
      *)
        echo "frw init: unknown argument '$1'" >&2; return 1 ;;
    esac
  done

  # --- 1. Seeds ---
  if [ -f ".furrow/seeds/seeds.jsonl" ]; then
    echo "  [SKIP] seeds (already initialized)"
  else
    # Derive prefix if not provided
    if [ -z "$_prefix" ]; then
      _prefix="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"
    fi
    if sds init --prefix "$_prefix"; then
      echo "  [OK]   seeds (prefix: $_prefix)"
    else
      echo "  [FAIL] sds init failed" >&2
      return 1
    fi
  fi

  # --- 2. Directories ---
  if [ -d ".furrow/rows" ]; then
    echo "  [SKIP] .furrow/rows/ (exists)"
  else
    mkdir -p ".furrow/rows"
    echo "  [OK]   .furrow/rows/ created"
  fi

  if [ -d ".furrow/almanac" ]; then
    echo "  [SKIP] .furrow/almanac/ (exists)"
  else
    mkdir -p ".furrow/almanac"
    echo "  [OK]   .furrow/almanac/ created"
  fi

  # --- 3. Config ---
  if [ -f ".claude/furrow.yaml" ]; then
    echo "  [SKIP] .claude/furrow.yaml (exists)"
  else
    mkdir -p ".claude"
    cp "$FURROW_ROOT/.claude/furrow.yaml" ".claude/furrow.yaml"

    # Auto-detect project name
    _proj_name="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]')"
    sed -i "s|^  name: \"furrow\"|  name: \"${_proj_name}\"|" ".claude/furrow.yaml"

    # Auto-detect repo (owner/repo from git remote)
    _repo=""
    _remote="$(git remote get-url origin 2>/dev/null)" || _remote=""
    if [ -n "$_remote" ]; then
      case "$_remote" in
        git@*:*)
          # SSH: git@github.com:owner/repo.git
          _repo="${_remote#*:}"
          ;;
        https://*|http://*)
          # HTTPS: https://github.com/owner/repo.git
          # Strip scheme and host: everything after the third slash
          _repo="${_remote#*://}"
          _repo="${_repo#*/}"
          ;;
      esac
      # Strip trailing .git
      _repo="${_repo%.git}"
    fi
    if [ -n "$_repo" ]; then
      sed -i "s|^  repo: \"\"|  repo: \"${_repo}\"|" ".claude/furrow.yaml"
    fi

    # Auto-detect language
    _lang=""
    if [ -f "go.mod" ]; then
      _lang="go"
    elif [ -f "package.json" ]; then
      _lang="typescript"
    elif [ -f "pyproject.toml" ] || [ -f "requirements.txt" ]; then
      _lang="python"
    fi
    if [ -n "$_lang" ]; then
      sed -i "s|^  language: \"\"|  language: \"${_lang}\"|" ".claude/furrow.yaml"
    fi

    # Set seeds prefix
    if [ -z "$_prefix" ]; then
      _prefix="$(basename "$(pwd)" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g')"
    fi
    sed -i "s|^  prefix: \"\"|  prefix: \"${_prefix}\"|" ".claude/furrow.yaml"

    echo "  [OK]   .claude/furrow.yaml created"
    echo "  Review .claude/furrow.yaml and fill in remaining fields"
  fi
}
