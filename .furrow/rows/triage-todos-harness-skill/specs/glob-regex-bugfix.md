# Spec: glob-regex-bugfix

- **Deliverable**: Fix bare directory handling in `scripts/triage-todos.sh`
- **Specialist**: harness-engineer

## The Bug

In `triage-todos.sh` lines 202-203, the glob-to-regex conversion:

```jq
gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")
```

Fails on bare directory paths like `skills/shared/` because:
1. No glob characters → no conversion happens
2. `test("skills/shared/")` against `skills/shared/red-flags.md` fails (trailing `/` requires exact termination)
3. Result: files under that directory silently produce no conflict matches

## The Fix

Add a preprocessing step before the glob conversion that normalizes trailing `/` to `/**`:

```jq
gsub("/$"; "/**") | gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")
```

This converts:
- `skills/shared/` → `skills/shared/**` → `skills/shared/.*` (matches all files under directory)
- `scripts/*.sh` → unchanged → `scripts/[^/]*.sh` (unchanged behavior)
- `**/*.md` → unchanged → `.*[^/]*.md` (unchanged behavior)

## Location

Apply the fix in **both** `test()` calls on lines 202-203:

```jq
($fa | test($fb | gsub("/$"; "/**") | gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*"))) or
($fb | test($fa | gsub("/$"; "/**") | gsub("\\*\\*"; ".*") | gsub("\\*"; "[^/]*")))
```

## Acceptance Criteria Verification

- [x] Bare directory paths (e.g., `skills/shared/`) handled correctly
- [x] Directory paths treated as prefix globs (`skills/shared/` → `skills/shared/**`)
- [x] Existing glob patterns (`**`, `*`) continue to work unchanged
