#!/bin/sh
# install.sh — Bootstrap Furrow installation.
#
# Symlinks CLI tools (frw, sds, rws, alm) to a user bin directory on PATH,
# then delegates all real work to `frw install`.
#
# This script exists because frw isn't on PATH yet when you first clone Furrow.
# After first install, use `frw install` directly.
set -eu

FURROW_ROOT="$(cd "$(dirname "$0")" && pwd)"

# --- Detect user-level bin directory on PATH ---
_user_bin=""
if [ -d "$HOME/.local/bin" ] && echo "$PATH" | tr ':' '\n' | grep -q "$HOME/.local/bin"; then
  _user_bin="$HOME/.local/bin"
elif [ -d "$HOME/bin" ] && echo "$PATH" | tr ':' '\n' | grep -q "$HOME/bin"; then
  _user_bin="$HOME/bin"
fi

if [ -z "$_user_bin" ]; then
  echo "error: neither ~/.local/bin nor ~/bin is on PATH" >&2
  echo "Add one to your PATH, then re-run." >&2
  exit 1
fi

# --- Symlink CLI tools ---
for _cli in frw sds rws alm; do
  _src="$FURROW_ROOT/bin/$_cli"
  _dst="$_user_bin/$_cli"
  if [ ! -e "$_src" ]; then continue; fi
  if [ -L "$_dst" ] && [ "$(readlink "$_dst")" = "$_src" ]; then
    continue  # already correct
  fi
  [ -L "$_dst" ] && rm "$_dst"
  ln -s "$_src" "$_dst"
  echo "  [LINK] $_dst -> $_src"
done

# --- Delegate to frw install ---
exec "$FURROW_ROOT/bin/frw" install "$@"
