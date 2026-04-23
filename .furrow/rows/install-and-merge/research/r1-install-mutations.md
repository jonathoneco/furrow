# R1: Install Flow Mutations & Legacy Detection

## 1. Mutation Inventory

| Path | Type | Trigger | Source Location | Tracked? |
|------|------|---------|-----------------|----------|
| `$_user_bin/{frw,sds,rws,alm}` | symlink | install.sh bootstrap + frw install | `install.sh:71-86`, `bin/frw.d/install.sh:501-512` | N (user ~/bin) |
| `$_proj_root/bin/{sds,rws,alm}` | symlink | `frw install --project\|--global` | `bin/frw.d/install.sh:505-506` | N (gitignored) |
| `$_proj_root/{skills,schemas,evals,specialists,references,adapters,templates,tests}` | symlink | `frw install` | `bin/frw.d/install.sh:460-487` | N (gitignored) |
| `.claude/commands/furrow:*.md` | symlink | `frw install` | `bin/frw.d/install.sh:310-314` | N (gitignored) |
| `.claude/commands/specialist:*.md` | symlink | `frw install` | `bin/frw.d/install.sh:329-336` | N (gitignored) |
| `.claude/commands/lib/*` | symlink | `frw install` | `bin/frw.d/install.sh:317-322` | N (gitignored) |
| `.claude/rules/*.md` | symlink | `frw install` (skip if self-install) | `bin/frw.d/install.sh:347-351` | N (gitignored except source repo) |
| `$_target/{file}.bak` | file write | symlink creation if dest exists as regular file | `bin/frw.d/install.sh:99-101` | N (not tracked) |
| `.claude/settings.json` | file create/merge | `frw install` | `bin/frw.d/install.sh:360-382` | Y (source repo) |
| `.furrow/furrow.yaml` | file copy | `frw install` (first run only) | `bin/frw.d/install.sh:391-396` | Y |
| `.claude/CLAUDE.md` | file create/append | `frw install` | `bin/frw.d/install.sh:436-446` | Y (source repo) |
| `.gitignore` | file append | `frw install` (skip if self-install) | `bin/frw.d/install.sh:545-551` | Y |
| `.furrow/rows/` | mkdir | `frw init` | `bin/frw.d/init.sh:40-43` | Y |
| `.furrow/almanac/` | mkdir | `frw init` | `bin/frw.d/init.sh:45-50` | Y |
| `.furrow/furrow.yaml` | file create + sed edits | `frw init` auto-detection | `bin/frw.d/init.sh:56-107` | Y |
| `.furrow/rows/*/` | directory move | `frw migrate-to-furrow` (from `.work/`) | `bin/frw.d/scripts/migrate-to-furrow.sh:33-48` | Y |
| `.furrow/seeds/seeds.jsonl` | file move | `frw migrate-to-furrow` (from `.beans/issues.jsonl`) | `bin/frw.d/scripts/migrate-to-furrow.sh:63-64` | Y |
| `.furrow/almanac/todos.yaml` | file move | `frw migrate-to-furrow` (from project root) | `bin/frw.d/scripts/migrate-to-furrow.sh:78-81` | Y |
| `.furrow/almanac/rationale.yaml` | file move | `frw migrate-to-furrow` (from `_rationale.yaml`) | `bin/frw.d/scripts/migrate-to-furrow.sh:86-89` | Y |
| `.gitattributes` | file sed edit | `frw migrate-to-furrow` (if `.beans/` path exists) | `bin/frw.d/scripts/migrate-to-furrow.sh:108-114` | Y |

**Mutation cascade summary**: Install produces ~12 symlinks (gitignored), up to 7 file writes/edits (mostly in-repo), and up to 7 `.bak` backups (not tracked). Migrate moves legacy paths under `.furrow/` (in-repo). None of the `.bak` files are currently in gitignore.

---

## 2. Legacy-install Detection

**Proposed heuristic** (two-tier):
1. **Presence check**: `.claude/furrow.yaml` OR `bin/{alm,rws,sds}.bak` present → legacy pre-XDG
2. **Absence check**: `.furrow/furrow.yaml` OR `.furrow/rows/` OR `.furrow/seeds/seeds.jsonl` absent → not yet migrated

**Evidence**:
- `.claude/furrow.yaml` (line `bin/frw.d/install.sh:387`) is the pre-XDG config location; in this source repo it exists at `/home/jonco/src/furrow-install-and-merge/.claude/furrow.yaml` (ls output confirms).
- `.bak` files are created when install symlinks over regular files (install.sh:99-101); present `.bak` → a previous unidirectional symlink attempted.
- Confirmed `.bak` presence: `bin/{alm,rws,sds}.bak` all exist in the current repo (bash output).
- Current repo also has `.furrow/furrow.yaml` (dual location for migration in-progress state).

**Alternative indicators** (weaker but corroborating):
- No `.furrow/SOURCE_REPO` sentinel (absence → consumer, not source repo; this is inverse, use only if building source detection).
- Missing `.furrow/install-state.json` (planned in config-cleanup deliverable; not yet implemented).

---

## 3. Quarantine Candidates

**Should move to `$XDG_STATE_HOME/furrow/{repo-slug}/`**:
- All `.bak` backups (not project-owned, temporary fixtures of install; currently not in gitignore — **MUST ADD**)
- `.furrow/install-state.json` (when added in config-cleanup) — install metadata, not project content

**Should stay in-repo**:
- `.furrow/rows/`, `.furrow/almanac/`, `.furrow/seeds/` — project-owned content
- `.furrow/furrow.yaml` — project config, even though template-sourced at install
- `.gitignore` additions under `# furrow:managed` — part of repo initialization contract
- `.claude/CLAUDE.md` — user-facing documentation, evolves with project

**Rationale**: XDG state is for install *machinery* (backups, version tracking, lock files); project *data* (rows, todos, config) stays in-repo. Gitignore edits are part of the install contract and stay tracked.

---

## 4. frw upgrade Home Recommendation

**Decision: Top-level command (`frw upgrade`), not subcommand of `frw install`.**

**Rationale (tied to dispatcher)**: 
- `bin/frw` (lines 68-177) uses explicit `case` dispatch; `upgrade` semantically parallels `init` (both are transition commands, not install variants).
- `init` is a top-level dispatcher case (line 79-81); grouping `upgrade` under `install` would violate symmetry and require install.sh to detect pre-XDG state *before* arg parsing (fragile).
- `migrate-to-furrow` already exists as a top-level command (line 152-154); `upgrade` is its successor, so same level.
- **Implementation**: Add `upgrade` case to frw dispatcher (after line 155), source `bin/frw.d/scripts/upgrade.sh`, invoke `frw_upgrade` function. Upgrade will call migrate-to-furrow internally if needed, then proceed to XDG config migration (phase 2 work).

---

## 5. Sources Consulted

| File | Tier | Contribution |
|------|------|--------------|
| `/install.sh` (lines 1-90) | Primary | Bootstrap symlink logic; user-bin PATH detection pattern |
| `bin/frw.d/install.sh` (lines 1-565) | Primary | Complete install mutation inventory; .bak creation trigger; gitignore synthesis |
| `bin/frw.d/init.sh` (lines 1-109) | Primary | Project init mutations: .furrow/{rows,almanac,furrow.yaml}; auto-detection logic |
| `bin/frw.d/scripts/migrate-to-furrow.sh` (lines 1-124) | Primary | Legacy path mapping; .gitattributes migration; idempotency checks |
| `bin/frw.d/scripts/launch-phase.sh` (lines 1-123) | Primary | Worktree mutations: reads .furrow/almanac/, creates tmux; no tracked file writes |
| `bin/frw` (lines 1-177) | Primary | Dispatcher pattern; command routing evidence |
| `.furrow/rows/install-and-merge/definition.yaml` (lines 1-146) | Context | Deliverable scope; legacy-detection requirement; SOURCE_REPO sentinel context |

---

## Key Findings

1. **Install currently commits `.bak` files to `.gitignore` implicitly but doesn't add them** — add `*.bak` to gitignore bootstrap (install.sh:527-543).
2. **Dual config locations exist** (`.claude/furrow.yaml` and `.furrow/furrow.yaml`) — install.sh:387 writes to `.furrow/`, but legacy check must look for `.claude/furrow.yaml` (line 32 of launch-phase.sh confirms fallback order).
3. **launch-phase.sh does NOT mutate tracked files** — it only reads roadmap.yaml, creates worktrees (git-native), and writes `/tmp/furrow-prompt-*.txt` (ephemeral).
4. **dispatcher supports `frw upgrade` addition cleanly** — no refactoring needed; just add case, source script, call function.
