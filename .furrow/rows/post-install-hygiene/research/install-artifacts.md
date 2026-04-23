# Post-Install Hygiene: Install-Artifacts Research

## Section A: bin/frw dispatcher exec path

### bin/frw dispatcher invocation mechanism

Line 207 (rescue command) uses direct `exec`:
```shell
rescue)
  exec "$FURROW_ROOT/bin/frw.d/scripts/rescue.sh" "$@"
  ;;
```

Line 184 (merge-sort-union) also uses `exec`:
```shell
merge-sort-union)
  exec "$FURROW_ROOT/bin/frw.d/scripts/merge-sort-union.sh" "$@"
  ;;
```

Lines 196 and 210 invoke scripts via `exec /bin/bash -c` wrapper or plain `exec` for shell-exec delegation.

Most other commands (lines 91–205) use shell **sourcing** (`. script.sh`) followed by function invocation, NOT direct exec. The pattern is: source library files → source the actual script → call the function defined in that script.

### Failure mode when non-executable script is invoked

When a non-executable file (mode 100644) is passed to `exec`, the kernel returns **EACCES** (Permission denied). The shell translates this to:
```
exec: permission denied: /path/to/script.sh
```

This prevents the command's subshell from starting entirely.

### Git modes of bin/frw.d/scripts/*.sh

From `git ls-files -s bin/frw.d/scripts/`:

**Executable (100755):**
- ci-contamination-check.sh
- generate-reintegration.sh
- launch-phase.sh
- merge-audit.sh
- merge-classify.sh
- merge-execute.sh
- merge-resolve-plan.sh
- merge-sort-union.sh
- merge-verify.sh
- normalize-seeds.sh
- normalize-todos.sh

**Non-executable (100644):**
- check-artifacts.sh
- cross-model-review.sh
- doctor.sh
- evaluate-gate.sh
- generate-plan.sh
- measure-context.sh
- merge-lib.sh
- merge-to-main.sh
- migrate-to-furrow.sh
- rescue.sh ← **Will fail when exec'd**
- run-ci-checks.sh
- run-gate.sh
- run-integration-tests.sh
- select-dimensions.sh
- select-gate.sh
- update-deliverable.sh
- update-state.sh
- upgrade.sh
- validate-definition.sh
- validate-naming.sh

**Total:** 30 scripts tracked, 11 executable (100755), 19 non-executable (100644).

### Sources Consulted
- `/home/jonco/src/furrow-post-install-hygiene/bin/frw` (lines 184, 196, 207, 210)
- `git ls-files -s bin/frw.d/scripts/` (bash output above)

---

## Section B: Existing hooks inventory

### Files in bin/frw.d/hooks/

1. **auto-install.sh** — SessionStart hook: verifies Furrow installation; runs `frw install --check` silently, self-heals if needed.
2. **correction-limit.sh** — PreToolUse hook (matcher: Write|Edit): enforces correction step limits.
3. **gate-check.sh** — PreToolUse hook (matcher: Bash): validates gate state before execution.
4. **ownership-warn.sh** — PreToolUse hook (matcher: Write|Edit): warns on ownership changes.
5. **post-compact.sh** — PostCompact hook: triggered after compaction events.
6. **pre-commit-bakfiles.sh** — Blocks staging of `bin/*.bak` and `.claude/rules/*.bak` files (install-artifacts).
7. **pre-commit-typechange.sh** — Blocks type-changes (regular file ↔ symlink) on protected paths.
8. **script-guard.sh** — PreToolUse hook (matcher: Bash): validates script safety.
9. **state-guard.sh** — PreToolUse hook (matcher: Write|Edit): protects state integrity.
10. **stop-ideation.sh** — Stop hook: prevents ideation-phase mutations.
11. **validate-definition.sh** — PreToolUse hook (matcher: Write|Edit): validates work row definitions.
12. **validate-summary.sh** — Stop hook: validates row summary before closure.
13. **verdict-guard.sh** — PreToolUse hook (matcher: Write|Edit): guards verdict mutations.
14. **work-check.sh** — Stop hook: validates work row status transitions.

### Pre-commit hooks validating script modes

**pre-commit-bakfiles.sh** (lines 1–3):
```shell
#!/bin/sh
# pre-commit-bakfiles.sh — Block staging of install-artifact .bak files.
# Called directly by the git pre-commit dispatcher (not via frw hook).
```

**pre-commit-typechange.sh** — Blocks symlink/file type changes on protected paths (bin/alm, bin/rws, bin/sds, .claude/rules/*).

**No existing hook validates script permissions (100755 vs 100644).** This is the gap.

### Hook installation mechanism

From `bin/frw.d/install.sh` (lines 602–630+):
```shell
# --- Symlink validator (AC-B) ---
# Verify all specialist: and rules/ symlinks resolve after creation.
_validate_symlinks "$TARGET"

# --- 3. Hooks (settings.json merge) ---
echo ""
echo "--- Hooks ---"
_furrow_settings="$FURROW_ROOT/.claude/settings.json"
_target_settings="$TARGET/settings.json"
if [ ! -f "$_target_settings" ]; then
  cp "$_furrow_settings" "$_target_settings"
  _ok "settings.json created with Furrow hooks"
elif grep -q "frw hook state-guard" "$_target_settings" 2>/dev/null; then
  _skip "settings.json already has Furrow hooks"
else
  # Merge: add Furrow hooks to existing settings
  if command -v jq > /dev/null 2>&1; then
    _merged=$(jq -s '
      .[0] as $existing | .[1] as $furrow |
      $existing * {hooks: ($existing.hooks // {} | to_entries + ($furrow.hooks | to_entries) | from_entries)}
    ' "$_target_settings" "$_furrow_settings" 2>/dev/null) || _merged=""
    ...
```

**Hooks are NOT symlinked to .git/hooks.** They are **merged into `.claude/settings.json`** as configuration. The Claude Code harness reads this config and executes hooks at the prescribed lifecycle points (SessionStart, PreToolUse, Stop, PostCompact).

### Sources Consulted
- `ls -la /home/jonco/src/furrow-post-install-hygiene/bin/frw.d/hooks/` (14 files)
- Each hook file's header comment (bash)
- `/home/jonco/src/furrow-post-install-hygiene/bin/frw.d/install.sh` lines 602–630+

---

## Section C: Specialist symlink inventory

### Tracked specialist:*.md entries (git ls-files)

14 tracked symlinks in `.claude/commands/`:
```
specialist:api-designer.md
specialist:cli-designer.md
specialist:complexity-skeptic.md
specialist:document-db-architect.md
specialist:go-specialist.md
specialist:harness-engineer.md
specialist:migration-strategist.md
specialist:python-specialist.md
specialist:relational-db-architect.md
specialist:security-engineer.md
specialist:shell-specialist.md
specialist:systems-architect.md
specialist:test-engineer.md
specialist:typescript-specialist.md
```

### Working-tree specialist:*.md entries (ls -la)

14 existing symlinks on disk (same list above). All symlink targets are relative: `../../specialists/{name}.md`.

### Full 22-specialist roster from specialists/_meta.yaml

| Specialist | Tracked | Gitignored | Target Exists |
|---|---|---|---|
| api-designer | ✓ | — | ✓ |
| cli-designer | ✓ | — | ✓ |
| complexity-skeptic | ✓ | — | ✓ |
| document-db-architect | ✓ | — | ✓ |
| go-specialist | ✓ | — | ✓ |
| harness-engineer | ✓ | — | ✓ |
| merge-specialist | — | ✓ | ✓ |
| migration-strategist | ✓ | — | ✓ |
| python-specialist | ✓ | — | ✓ |
| relational-db-architect | ✓ | — | ✓ |
| security-engineer | ✓ | — | ✓ |
| shell-specialist | ✓ | — | ✓ |
| systems-architect | ✓ | — | ✓ |
| test-engineer | ✓ | — | ✓ |
| typescript-specialist | ✓ | — | ✓ |
| frontend-designer | — | ✓ | ✓ |
| css-specialist | — | ✓ | ✓ |
| accessibility-auditor | — | ✓ | ✓ |
| prompt-engineer | — | ✓ | ✓ |
| technical-writer | — | ✓ | ✓ |
| llm-specialist | — | ✓ | ✓ |
| test-driven-specialist | — | ✓ | ✓ |

**Summary:** 14 tracked, 8 gitignored; all 22 targets exist in `specialists/`.

### .gitignore rule

Line 30 of `.gitignore`:
```
.claude/commands/specialist:*
```

Pattern is literal `specialist:*` (not `specialist:*.md`), matching all specialist symlink names. Rule is correctly scoped but **violated** by 14 tracked entries.

### Sources Consulted
- `git ls-files .claude/commands/ | grep "specialist:"` (14 results)
- `ls -la .claude/commands/specialist:*.md` (14 symlinks, targets all relative)
- `/home/jonco/src/furrow-post-install-hygiene/specialists/` (22 .md files + _meta.yaml)
- `/home/jonco/src/furrow-post-install-hygiene/.gitignore` line 30

---

## Section D: install.sh symlink creation

### How install.sh creates specialist symlinks

From `bin/frw.d/install.sh` lines 572–581:
```shell
# --- 1b. Specialists (registered as specialist:name commands) ---
echo ""
echo "--- Specialists ---"
if [ -d "$FURROW_ROOT/specialists" ]; then
  for spec in "$FURROW_ROOT"/specialists/*.md; do
    [ -f "$spec" ] || continue
    _basename="$(basename "$spec" .md)"
    # Skip _meta.yaml and similar non-specialist files
    case "$_basename" in _*) continue ;; esac
    symlink "$spec" "$TARGET/commands/specialist:${_basename}.md"
  done
fi
```

**Source of truth:** `$FURROW_ROOT/specialists/*.md` (discovered at install time, filtered to exclude files starting with `_`).

**Target:** `$TARGET/commands/specialist:{basename}.md`

**Manifest:** No explicit list. The `specialists/_meta.yaml` is for documentation/rationale only; the actual list is computed dynamically by glob `*.md` excluding `_*` patterns.

### Self-hosting behavior

From `bin/frw.d/install.sh` lines 240–250 (validation section):
```shell
# Check specialist: commands
for _link in "${_vsym_target}/commands/specialist:"*.md; do
  ...
```

When `INSTALL_MODE=source` (self-hosting), `install.sh` is invoked on the Furrow source repo itself. It runs the same loop:
- Iterates `$FURROW_ROOT/specialists/*.md`
- Creates symlinks at `.claude/commands/specialist:{name}.md`
- Uses `symlink()` function (line 81+) which skips if target already points to the right place, or re-creates if broken.

**For source-hosting self-install:** The symlinks created use relative paths (`../../specialists/X.md`) because both source and target are within the same repo root. Consumer installs also use relative paths computed by `_relpath()`.

### Sources Consulted
- `/home/jonco/src/furrow-post-install-hygiene/bin/frw.d/install.sh` lines 572–581
- `symlink()` function implementation (lines 81–110)
- INSTALL_MODE detection (lines 483–490)
- `/home/jonco/src/furrow-post-install-hygiene/specialists/` directory listing

---

## Section E: Install architecture documentation

### docs/architecture/install-architecture.md

**Does not exist.** The closest document is `self-hosting.md`.

### docs/architecture/self-hosting.md structure

**Outline:**
1. Self-Hosting Architecture (header)
2. Source form vs installed form
3. Path differences
4. Boundary enforcement points
5. (Implicit: implications for install)

**Current sections focus on semantic differences** (source repo vs consumer checkout, symlink targets, XDG state quarantine, repo_slug derivation).

**Best fit for new section:** After "Boundary enforcement points" (line ~52), before implicit conclusion. New section could be:
- **"Specialist symlinks as install-time artifacts"** — explains 22-specialist list, why tracked entries violate .gitignore, install.sh as sole producer, integration with pre-commit validation.

### Sources Consulted
- `ls docs/architecture/` (no install-architecture.md found)
- `/home/jonco/src/furrow-post-install-hygiene/docs/architecture/self-hosting.md` (full read, 110 lines)

---

## Section F: Test references to specialists

### Grep results for specialist: and specialist- in tests/integration/

**test-ci-contamination.sh:**
- Line: "`.claude/commands/specialist:x.md` symlink with escaping target → exit 1"
- Adds tracked specialist symlink via `git update-index --add --cacheinfo` to test CI rejection.
- **Test depends on symlink validation during `ci-contamination-check.sh`.**

**test-install-source-mode.sh:**
- Creates `specialist:test-engineer.md` and `specialist:shell-specialist.md` symlinks explicitly.
- Counts total symlinks: `find "$tgt_dir/.claude/commands" -name 'specialist:*.md' -type l | wc -l`
- Validates resolution: `readlink -f "$link" > /dev/null 2>&1`
- **Tests break if symlinks don't exist or point to invalid targets during install.**

**test-lifecycle.sh, test-rws.sh, test-generate-plan.sh:**
- Reference `specialist: test-eng` (note hyphen, not colon) in YAML row definitions.
- These are **role assignments in work row specs**, not direct symlink references.
- **Tests depend on specialist command being available** (which requires the symlink).

### Summary

**5 integration tests exercise specialist symlinks:**
- `test-ci-contamination.sh` (escaping symlink detection)
- `test-install-source-mode.sh` (symlink creation and resolution)
- `test-lifecycle.sh` (specialist role assignment)
- `test-rws.sh` (specialist role assignment)
- `test-generate-plan.sh` (specialist role assignment — 13 occurrences)

**Risk during untracking:** If specialist symlinks are temporarily absent during re-install, these tests may fail if run in the interim. **Solution:** Ensure `install.sh` runs before tests or document that tests require post-install state.

### Sources Consulted
- `grep -r "specialist:" tests/integration/` (bash output above)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-install-source-mode.sh` (sample review)
- `/home/jonco/src/furrow-post-install-hygiene/tests/integration/test-ci-contamination.sh` (sample review)

---

## Summary Table: Two Deliverables

| Deliverable | Issue | Finding | Next Step |
|---|---|---|---|
| **rescue-sh-exec-fix** | `rescue.sh` is mode 100644 (non-exec); `frw rescue` uses `exec`, fails with "Permission denied" | 19 of 30 scripts are 100644 (non-exec); only 11 are 100755. **rescue.sh confirmed as 100644.** | Fix: `git update-index --chmod=+x bin/frw.d/scripts/rescue.sh` (and 18 others). Add pre-commit hook validating all `bin/frw.d/scripts/*.sh` are 100755. |
| **specialist-symlink-unification** | 14 of 22 specialists are tracked, violating `.gitignore` line 30 (`specialist:*`). Goal: untrack all 22; make install.sh sole producer. | **14 tracked, 8 gitignored (correct).** All 22 exist on disk and in `specialists/_meta.yaml`. No manifest file; install.sh discovers via glob `$FURROW_ROOT/specialists/*.md`. | Fix: Untrack 14 symlinks via `git rm --cached`. Ensure `.gitignore` blocks all 22. Document in self-hosting.md that symlinks are install-artifacts. Validate pre-commit rejects any new specialist: additions. |

