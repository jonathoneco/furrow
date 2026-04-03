# Spec: language-specialists

## Structural Requirements

Same format as existing-rewrites spec. All new files — no existing content to preserve.

## go-specialist.md

**Description**: Go idioms, concurrency patterns, interface design, and error propagation strategy.

**Reasoning patterns** (7):
1. **Error chain narration** — Every error return site adds context that, read bottom-up, tells the full story. Before wrapping, ask "if I read this in a log, can I locate the failure without looking at code?" Wrap with `%w` when callers need `errors.Is/As`; `%v` when the error is an implementation detail.
2. **Interface discovery, not invention** — Never define an interface at the provider site. Interfaces emerge at the consumer from what it actually calls. One-method interfaces are the default; multi-method interfaces need justification. More than three methods signals a disguised concrete type.
3. **Zero-value readiness** — Every struct is designed so its zero value is useful or safe. Constructors exist only when initialization requires validation or external resources. Ask "what happens if someone uses `var x MyType` and starts calling methods?"
4. **Goroutine lifecycle ownership** — The goroutine creator owns it and is responsible for termination. Every `go func()` has a visible shutdown path (context cancellation, channel close, WaitGroup). No shutdown path = no goroutine.
5. **Package boundary as API** — Exported names are the package's public API. Unexported names are implementation details that can change freely. Before exporting a function, ask "does a consumer outside this package need this?" If not, keep it unexported.
6. **Composition over embedding** — Embedding promotes all methods of the embedded type, including ones you didn't intend to expose. Prefer explicit delegation unless promoting the full interface is intentional. Embedding for interface satisfaction is fine; embedding for code reuse is dangerous.
7. **Table-driven testing as default** — Test cases are data, not code. Every test function with more than two scenarios becomes a table. The table structure makes coverage gaps visible — missing edge cases show up as missing rows, not missing test functions.

**Quality Criteria**: `go vet` and `staticcheck` clean. Errors wrapped with `fmt.Errorf("context: %w", err)`. Structured logging via `slog`. Constructor injection for dependencies. No `init()` functions without justification.

**Anti-Patterns**: Swallowing errors with `_ =` | Panicking in library code | Returning concrete types from constructors (accept interfaces, return structs) | Using `sync.Mutex` when a channel would eliminate shared state | Exported types in internal packages.

**Context Requirements**: Required: go.mod (module path, Go version), existing package structure, error handling conventions. Helpful: linter config, test patterns, CI pipeline.

## shell-specialist.md

**Description**: POSIX-portable shell scripting, safe argument handling, pipeline composition, and process lifecycle management.

**Reasoning patterns** (7):
1. **Quote by default, unquote by exception** — Every variable expansion is double-quoted unless word splitting is explicitly desired (rare). Unquoted `$var` is a bug until proven intentional. Glob patterns get controlled expansion contexts.
2. **Exit code as API contract** — A script's exit codes are its return type. Define semantics up front (0=success, 1=usage, 2=not-found, etc.) and document them. Never exit non-zero without writing to stderr. Never exit zero after a partial failure.
3. **Pipeline failure awareness** — In `cmd1 | cmd2`, only `cmd2`'s exit code is checked by default. Use `set -o pipefail` or restructure to avoid silent pipeline failures. Prefer `if ! cmd; then` over `cmd || true` because the latter hides the failure.
4. **Portability boundary awareness** — Know where POSIX ends and bash begins. Use `#!/bin/sh` and POSIX-only constructs unless a bash feature is genuinely needed, then switch to `#!/bin/bash` and document why. Never use bashisms accidentally.
5. **Atomic file operations** — Write to a temp file, then `mv` to the target. Never write directly to a file that another process might read mid-write. `mktemp` for temp files, `trap` for cleanup on EXIT.
6. **Stderr discipline** — Diagnostic messages, progress indicators, and errors go to stderr. Data output goes to stdout. A script whose stderr and stdout are mixed is a script that can't be piped.
7. **set -eu as baseline** — Start every script with `set -eu` (exit on error, error on undefined variables). Understand the exceptions: command substitution in assignment doesn't trigger `-e`, and `||`/`&&` guards suppress it. Know when to add `set -o pipefail`.

**Quality Criteria**: `shellcheck` clean (with documented exceptions). All variables double-quoted. Atomic writes for any file mutation. `set -eu` at top of every script. Temp files cleaned via trap. Exit codes documented in header comment.

**Anti-Patterns**: Unquoted variables in conditionals | Parsing `ls` output | Using `eval` without extreme justification | Hardcoded paths instead of `$0`-relative resolution | `cat file | grep` instead of `grep file`.

**Context Requirements**: Required: target shell (POSIX sh vs bash), existing script conventions, exit code standards. Helpful: shellcheck config, CI lint pipeline, shared library files (e.g., `hooks/lib/common.sh`).

## typescript-specialist.md

**Description**: TypeScript type system design, narrowing patterns, module boundaries, and runtime/compile-time separation.

**Reasoning patterns** (7):
1. **Type narrowing over type assertion** — Never use `as` to fix a type error; restructure so TypeScript narrows through control flow. Every `as` cast is a suppressed bug that resurfaces at runtime. Exception: `as const` for literal narrowing adds safety.
2. **Discriminated union as domain model** — Model domain states as discriminated unions (`{ status: 'ok'; data: T } | { status: 'error'; error: E }`) rather than optional fields on a single type. Ask "can this object exist in a meaningless state?" If yes, split the type.
3. **Module boundary as type boundary** — Export narrow types (pick/omit projections, branded types) even when the internal type is richer. The exported type is the contract. Changing an internal field should never require downstream changes.
4. **Runtime is not compile-time** — Type-level guarantees are erased at runtime. Never trust data from network, JSON.parse, or user input based on its TypeScript type alone. External data gets runtime validation (Zod, io-ts) that produces a typed result.
5. **Strict mode as floor** — `strict: true` in tsconfig is the starting point, not a goal. Add `noUncheckedIndexedAccess`, `exactOptionalPropertyTypes` where the codebase supports it. Treat `any` as technical debt with a migration path.
6. **Generic constraint discipline** — Generics solve real polymorphism, not type-level cleverness. If a generic type parameter has only one instantiation in the codebase, it's premature abstraction. Prefer concrete types until the second consumer appears.
7. **Satisfies over assertion** — Use `satisfies` to validate a value matches a type without widening it. Use `as const satisfies` for validated literal types. Reserve `as` for the rare cases where you genuinely know more than the compiler (FFI, test doubles).

**Quality Criteria**: `strict: true` minimum. Zero `any` in production code (allowed in test doubles with justification). All external data validated at runtime. Discriminated unions for state modeling. No `@ts-ignore` without linked issue.

**Anti-Patterns**: `as any` to silence errors | Optional fields instead of discriminated unions | `enum` (use `as const` objects or union types) | `namespace` in modern codebases | Barrel files that re-export everything.

**Context Requirements**: Required: tsconfig.json, module resolution strategy, existing type patterns. Helpful: lint config (eslint/biome), test framework types, API response schemas.

## python-specialist.md

**Description**: Pythonic patterns, protocol-based design, dependency management, and runtime safety in a dynamic language.

**Reasoning patterns** (7):
1. **Protocol over inheritance** — Prefer structural typing (`Protocol` classes) over inheritance hierarchies. When tempted to create a base class, ask "do the subclasses share behavior, or just an interface?" If just an interface, Protocol is cheaper and more flexible.
2. **Explicit dependency boundaries** — Every module's imports tell a dependency story. Circular imports are a design bug, not an import-order problem. When a circular import appears, the two modules belong in the same bounded context and should be restructured.
3. **Generator as memory architecture** — Use generators and iterators as default for sequences of unknown size. Ask "does the caller need all items at once, or can it process them one at a time?" This is an architectural decision about memory contracts, not premature optimization.
4. **Type annotation as documentation contract** — Type hints on all function signatures and public attributes. `Any` is technical debt. Use `TypeVar` and `ParamSpec` for generic utilities. Types are advisory in Python — pair with runtime validation at trust boundaries.
5. **Context manager discipline** — Any resource with setup/teardown (files, connections, locks, temp directories) uses a context manager. `__enter__`/`__exit__` for classes, `@contextmanager` for simple cases. Bare `open()` without `with` is a resource leak.
6. **Exception hierarchy awareness** — Catch specific exceptions, never bare `except:`. Define custom exception hierarchies for library code. Let unexpected exceptions propagate — catching `Exception` at a low level hides bugs that should crash loudly.
7. **Packaging as interface** — `pyproject.toml` defines the project's public contract. Pin exact versions in applications, use ranges in libraries. Separate dev/test/prod dependency groups. A project without lockfile reproducibility is a project that works on one machine.

**Quality Criteria**: Type annotations on all public APIs. `mypy --strict` clean (or `pyright`). No bare `except`. All resources managed via context managers. Dependencies pinned in lockfile.

**Anti-Patterns**: Mutable default arguments | `from module import *` | Circular imports papered over with `TYPE_CHECKING` | God modules (>500 lines) | Bare `except: pass`.

**Context Requirements**: Required: pyproject.toml/setup.cfg, existing package structure, type checking config. Helpful: test framework, CI pipeline, linter config (ruff/flake8).
