# R4: Prior Art — Rescue / Bootstrap / Self-Repair Patterns

## Research question
What do established tools do when their own runtime state (binary, config, core library) gets corrupted, and what design patterns for `frw rescue` emerge from that prior art?

## Survey

### Git hooks
- **Symptom**: `.git/hooks/pre-commit` fails and blocks every commit until deleted.
- **Recovery**: no built-in rescue. Users `rm .git/hooks/<hook>` manually. `git commit --no-verify` bypasses.
- **Pattern contributed**: **escape hatch**. A way to bypass a broken guard without a working guard.
- **Relevance**: we already have `git commit --no-verify` as an emergency bypass; `frw rescue` should not claim this role. It should restore the guard instead.

### Homebrew
- **Symptoms**: broken `brew` shell, corrupted tap, incompatible core.
- **Tools**: `brew doctor` (read-only diagnosis), `brew update-reset` (hard git reset of the Homebrew clone), `brew reinstall <formula>` (one-package repair).
- **Patterns contributed**:
  - **Diagnose before repair** (`doctor` is read-only; `update-reset` is opt-in).
  - **Self-contained bootstrap**: the `brew` script itself is carried in the Homebrew git repo — if the repo is fixable via git, `brew` is too.
  - **Reset to a known good point** (HEAD of origin/master) as the recovery primitive.
- **Relevance (strong)**: `frw rescue` should do `git show HEAD:bin/frw.d/lib/common.sh > common.sh` as its primary repair, mirroring `update-reset`'s "match origin" philosophy.

### Nix
- **Symptoms**: corrupted `/nix/store` paths, broken profile symlinks.
- **Tools**: `nix-store --verify`, `nix-store --repair-path`, re-running the installer.
- **Patterns contributed**:
  - **Content-addressed verification**: verify before repair, repair idempotently.
  - **Out-of-band installer** (`sh <(curl ...)`): the installer has no runtime dependency on the existing install.
- **Relevance**: `frw rescue` should be in a file that sources nothing from common.sh (per deliverable-1 AC 6). Same "out-of-band" principle.

### rustup / asdf / mise
- **Patterns contributed**:
  - **`reshim`** (mise): regenerates the thin shim layer from a known manifest. Cheap, idempotent.
  - **`self uninstall` + reinstall** (rustup): nuclear option. No in-place repair.
- **Relevance**: `frw rescue` should be more surgical than "nuclear" — target just the file that's broken, not a full reinstall.

### Chezmoi
- **Tools**: `chezmoi doctor` (diagnosis only), manual re-init for repair.
- **Relevance**: validates the pattern "diagnosis tool separate from repair tool" — `frw doctor` already exists (diagnose), `frw rescue` is the paired repair tool.

### Git's own bootstrap
- `git init --template=<dir>` lets you recover a corrupted hooks directory by copying from a template. The template is bundled with git's install.
- **Relevance**: confirms the pattern of "bundle a known-good baseline alongside the tool" — our `frw rescue` can ship a frozen `common.sh` baseline as a fallback when HEAD is unreadable.

## Synthesized principles for `frw rescue`

| Principle | Source tools | Applied to frw rescue |
|---|---|---|
| Out-of-band | nix installer, `sh <(curl …)` | rescue.sh sources NOTHING from common.sh (AC 6, deliverable 1) |
| Restore from VCS HEAD | brew update-reset | primary path: `git show HEAD:bin/frw.d/lib/common.sh` |
| Bundled baseline fallback | git init templates | secondary path: embedded minimal common.sh string, used when HEAD is unreadable (bare worktree, pre-first-commit) |
| Diagnose before repair | brew doctor → update-reset, chezmoi doctor | rescue prints what it would restore, requires `--apply` to write (or prompts) |
| Idempotent | nix repair-path | rescue no-ops when common.sh already parses |
| Surgical, not nuclear | mise reshim | rescue targets common.sh specifically; other breakage falls to `frw doctor` + manual fix |

## Implied design for `frw rescue`

```
frw rescue [--apply] [--file bin/frw.d/lib/common.sh]

Default behavior:
  1. If target file parses (sh -n), print "OK: no rescue needed" and exit 0.
  2. If git HEAD has a version of the target file, diff it against current; propose restoration.
  3. If git HEAD is unavailable (shallow clone, bare worktree, orphan), fall back to a
     bundled baseline embedded in rescue.sh as a here-doc.
  4. With --apply, write the restoration; without, print the plan only.

Exits:
  0 — nothing to do / rescue applied successfully
  1 — target missing AND no baseline available
  2 — rescue could not parse target / could not write target
```

Rescue MUST:
- Not source `bin/frw.d/lib/common.sh` anywhere.
- Not require `frw`, `rws`, `alm`, `sds` on PATH — use absolute `git` and POSIX shell only.
- Be callable as `./bin/frw.d/scripts/rescue.sh` directly (bypass the dispatcher if the dispatcher itself is broken).

## Sources consulted

| Source | Tier | Contribution |
|---|---|---|
| Homebrew docs — `brew update-reset`, `brew doctor` (docs.brew.sh) | Secondary (from training data) | update-reset pattern, doctor/repair separation |
| Nix manual — `nix-store --repair-path`, installer bootstrap | Secondary | content-addressed verify-then-repair, out-of-band installer |
| git-hooks(5), `git init --template` | Primary (known syntax) | bundled-template pattern |
| Chezmoi `doctor` subcommand | Secondary | diagnose/repair separation |
| mise/asdf `reshim` | Secondary | surgical-not-nuclear |
| rustup `self uninstall` | Secondary | anti-pattern (nuclear) |

Claims marked Secondary are from training data (cutoff Jan 2026) and describe well-established tool behavior; no version-specific claim depends on them. No claim here requires primary-source verification beyond what's already in the tools' man pages.

## Key finding

**Bundle-the-baseline + restore-from-HEAD is the dominant pattern for self-repair in tools that manage their own runtime.** `frw rescue` should implement both paths (HEAD first, bundled fallback), mirror Homebrew's `doctor`/`update-reset` split against our existing `frw doctor`, and live in a file that sources zero runtime dependencies — exactly what deliverable-1 AC 6 already requires.
