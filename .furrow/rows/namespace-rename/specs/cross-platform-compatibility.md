# Spec: cross-platform-compatibility

## Overview
Fix the 2 portability issues found in research and run shellcheck validation on all POSIX scripts. Document residual risk.

## Fix 1: readlink -f in install.sh

**Location**: `install.sh` lines 62-63, 327-328
**Issue**: `readlink -f` is GNU-only; BSD (macOS) readlink doesn't support `-f`
**Current code**:
```sh
_existing="$(readlink -f "$_dst" 2>/dev/null || readlink "$_dst")"
```
**Problem with fallback**: BSD `readlink` without `-f` only resolves one symlink level, not the full canonical path. This could cause symlink comparison to report false mismatches.

**Fix**: Replace with a portable canonicalization function:
```sh
_canonicalize() {
  # Resolve symlink chain portably (works on GNU and BSD)
  _path="$1"
  while [ -L "$_path" ]; do
    _dir="$(cd "$(dirname "$_path")" && pwd)"
    _path="$(readlink "$_path")"
    # Handle relative symlink targets
    case "$_path" in
      /*) ;;
      *) _path="$_dir/$_path" ;;
    esac
  done
  # Final canonicalization via cd/pwd
  _dir="$(cd "$(dirname "$_path")" && pwd)"
  echo "$_dir/$(basename "$_path")"
}
```

Add this function near the top of install.sh and replace all `readlink -f` calls with `_canonicalize`.

## Fix 2: expr string comparison in hooks/lib/common.sh

**Location**: `hooks/lib/common.sh` line 34
**Issue**: `expr "$_updated" \> "$_best_ts"` — locale-dependent string comparison
**Current code**:
```sh
if [ -z "$_best_dir" ] || expr "$_updated" \> "$_best_ts" > /dev/null 2>&1; then
```

**Fix**: Use POSIX shell string comparison:
```sh
if [ -z "$_best_dir" ] || [ "$_updated" \> "$_best_ts" ]; then
```
Note: `\>` in `[ ]` is POSIX for lexicographic comparison. ISO 8601 timestamps are lexicographically orderable, so this is correct.

## Validation: shellcheck

Run on all `#!/bin/sh` scripts:
```sh
find scripts/ hooks/ commands/lib/ -name '*.sh' -exec head -1 {} \; -print | \
  grep -B1 '#!/bin/sh' | grep -v '^#' | \
  xargs shellcheck --shell=sh --severity=warning
```

Expected: clean pass (research found no shebang/feature mismatches).

Address any findings at warning level or above.

## Residual Risk Documentation

Add to project docs or CLAUDE.md a note:
```
## Platform Support
Tested on: Linux (EndeavourOS/Arch)
Designed for: Linux, macOS, WSL
Not tested on: macOS (BSD userland) — shellcheck-verified but no runtime testing
Not supported: Native Windows (symlinks require elevated permissions)
```

## Acceptance Criteria Mapping

| AC | Section |
|----|---------|
| shellcheck passes on all #!/bin/sh scripts | Validation |
| No (( )) or [[ ]] in #!/bin/sh scripts | Already satisfied (research confirmed) |
| readlink -f has BSD-compatible fallback | Fix 1 |
| GNU-specific flags documented or replaced | Fix 1 + Fix 2 |
| Residual risk documented | Residual Risk Documentation |
