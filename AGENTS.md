## System

- EndeavourOS (Arch-based), Sway WM, zsh, foot terminal
- Tool versioning via mise (Go, Node, Python)
- Packages: check AUR before compiling from source
- Desktop notifications via notify-send (swaync)

## Git

- Conventional commits: `feat:`, `fix:`, `chore:`, `docs:`, `refactor:`, `test:`, `infra:`
- Never force push to `main`/`master`
- Prefer specific file staging over `git add -A`

## Go Conventions

- Error wrapping: `fmt.Errorf("context: %w", err)`
- Structured logging: `slog`
- Table-driven tests, colocated `_test.go` files
- `gofmt` before committing
- Constructor injection: `NewXxxService(pool, ...)`

## Shell & Scripting

- Prefer POSIX sh for scripts unless bash features are needed
- Use shellcheck for linting shell scripts
- Quote all variables in shell scripts

## Furrow Harness

This repository is the Furrow harness. Current project work is grounded in
Furrow commands and artifacts: `furrow`, `frw`, `bin/alm`, and `.furrow/`.

At session start:

- Ground in the git state and the user's current request.
- If implementation is requested, use a git worktree for non-trivial work.
- Exploration and planning may happen on `main`; implementation should happen
  off `main` unless the user explicitly asks for a small direct patch.

The older `.workflows` Workflow Harness protocol is not the operating model for
this repository. Only use it if the user explicitly asks to inspect or operate a
legacy `.workflows` workflow.
