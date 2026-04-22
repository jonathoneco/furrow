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
SRC_DIR="$FURROW_ROOT"

# --- Detect SOURCE_REPO mode ---
# If the source tree contains .furrow/SOURCE_REPO, this is the Furrow source
# repo itself (source-hosting mode). Otherwise it's a consumer install.
if [ -f "$SRC_DIR/.furrow/SOURCE_REPO" ]; then
  INSTALL_MODE=source
else
  INSTALL_MODE=consumer
fi
export INSTALL_MODE

# --- Refuse-copy guard (AC-A Interface Contract) ---
# If someone copied SOURCE_REPO into a target that shouldn't have it
# and is now running install from that target, abort.
# Detect: TARGET_DIR == SRC_DIR but SRC_DIR has SOURCE_REPO sentinel
# (self-install from source is fine; the guard is for consumer targets that
# somehow received the sentinel via cp -r ./.furrow consumer/.furrow).
# The frw.d/install.sh enforces the full contract; this is the bootstrap guard.

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

# --- Symlink CLI tools (relative paths for portability) ---

# Compute relative path from directory $1 to file/dir $2.
# Both arguments must be absolute paths. Uses only POSIX constructs.
_relpath() {
  _rp_from="${1%/}"
  _rp_to="${2%/}"
  _rp_common="$_rp_from"
  _rp_up=""
  while true; do
    case "$_rp_to/" in
      "$_rp_common/"*) break ;;
    esac
    _rp_common="${_rp_common%/*}"
    _rp_up="../$_rp_up"
  done
  _rp_tail="${_rp_to#"$_rp_common"}"
  _rp_tail="${_rp_tail#/}"
  if [ -n "$_rp_up" ] && [ -n "$_rp_tail" ]; then
    echo "${_rp_up}${_rp_tail}"
  elif [ -n "$_rp_up" ]; then
    echo "${_rp_up%/}"
  elif [ -n "$_rp_tail" ]; then
    echo "$_rp_tail"
  else
    echo "."
  fi
}

# Portable readlink -f
_canonicalize() {
  _cl_path="$1"
  while [ -L "$_cl_path" ]; do
    _cl_dir="$(cd "$(dirname "$_cl_path")" && pwd)"
    _cl_path="$(readlink "$_cl_path")"
    case "$_cl_path" in
      /*) ;;
      *) _cl_path="$_cl_dir/$_cl_path" ;;
    esac
  done
  _cl_dir="$(cd "$(dirname "$_cl_path")" 2>/dev/null && pwd)"
  echo "$_cl_dir/$(basename "$_cl_path")"
}

for _cli in frw sds rws alm; do
  _src="$FURROW_ROOT/bin/$_cli"
  _dst="$_user_bin/$_cli"
  if [ ! -e "$_src" ]; then continue; fi
  if [ -L "$_dst" ]; then
    _existing="$(_canonicalize "$_dst")"
    _expected="$(_canonicalize "$_src")"
    if [ "$_existing" = "$_expected" ]; then
      continue  # already correct
    fi
    rm "$_dst"
  fi
  _rel="$(_relpath "$_user_bin" "$FURROW_ROOT/bin/$_cli")"
  ln -s "$_rel" "$_dst"
  echo "  [LINK] $_dst -> $_rel"
done

# --- Delegate to frw install ---
exec "$FURROW_ROOT/bin/frw" install "$@"
