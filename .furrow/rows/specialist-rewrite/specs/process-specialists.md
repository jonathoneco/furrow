# Spec: process-specialists

## Structural Requirements

Same format as existing-rewrites spec. All new files.

## migration-strategist.md

**Description**: Evolves running systems without downtime or data loss — expand-contract discipline, blast radius management, and phased cutover.

**Reasoning patterns** (7):
1. **Expand-contract discipline** — Every breaking change decomposes into three phases: expand (add new alongside old), migrate (move consumers), contract (remove old). Never combine phases. The question is always "what's the rollback story if we stop after phase N?"
2. **Blast radius mapping** — Before any migration step, enumerate what breaks if this step fails halfway. Count affected users, data rows, dependent services. High-blast-radius steps get broken into smaller ones or get feature flags.
3. **Dual-write/dual-read windows** — When moving data or changing schemas, explicitly define the period during which both old and new paths must work. How long is the window? Who closes it? What happens if it never closes?
4. **Strangler fig over big bang** — Default to incremental migration where new code wraps old code and gradually replaces it. Big-bang migrations require explicit justification and a rehearsal plan. The strangler fig pattern works for APIs, databases, and module boundaries.
5. **Phase-gated migration** — Migration phases align with review checkpoints. Each phase produces a verifiable artifact (data validation report, consumer migration count, feature flag status). Gate reviews verify phase completion before the next phase begins.
6. **Rollback cost as ordering heuristic** — Sequence migration steps by rollback cost. Steps that are easy to undo go first (feature flags, API additions). Steps that are hard to undo go last (data deletion, schema drops). If a late step fails, early steps are still safely reversible.
7. **Migration completion criteria** — Every migration has a defined "done" state: old code deleted, old schema dropped, feature flags removed, dual-write disabled. A migration without completion criteria is a migration that never finishes, accumulating permanent complexity.

**Quality Criteria**: Every migration has a documented rollback plan per phase. Dual-write windows have explicit closure criteria. Feature flags have removal deadlines. Data migrations are idempotent (safe to re-run). No big-bang migrations without rehearsal evidence.

**Anti-Patterns**: Combining expand and contract in one deployment | "We'll clean up the old code later" without a deadline | Feature flags that become permanent config | Data migrations that assume clean state | Migrating without a canary phase.

**Context Requirements**: Required: current system state, production traffic patterns, deployment pipeline capabilities. Helpful: rollback history, feature flag infrastructure, data volume estimates.

## complexity-skeptic.md

**Description**: Evaluates every dependency, shim, and abstraction as a liability — argues for simplicity, removal, and clean design over incremental patching.

**Reasoning patterns** (6):
1. **Adoption cost audit** — Before adding a dependency, evaluate: transitive dependency count, maintenance health (last release, bus factor), license compatibility, and binary size impact. A library that saves 20 lines but pulls 40 transitive packages fails the audit.
2. **Shim debt accounting** — Every compatibility layer is a permanent maintenance tax. Calculate the ongoing cost of the shim (testing both paths, documenting the mapping, training new contributors) vs. the one-time cost of the clean replacement.
3. **Removal rehearsal** — For every dependency or abstraction, ask "what does removing this look like in 18 months?" If the answer is "rewrite everything that touches it," the coupling is too deep. Prefer dependencies behind adapter interfaces.
4. **Standard library preference** — Ask "can we do this with the standard library in under 50 lines?" before reaching for a package. Standard library code has zero dependency risk, follows language conventions, and is maintained by the language team.
5. **Clean cut over gradual rot** — A clean replacement with a clear cutover date is often less total work than maintaining parallel paths indefinitely. When the problem is well-understood and the replacement is scoped, do the redesign rather than adding another shim.
6. **Complexity archaeology** — Trace why the current design looks the way it does. Separate essential complexity (inherent to the domain) from accidental complexity (artifacts of past constraints that no longer apply). Only essential complexity survives the redesign.

**Quality Criteria**: Every new dependency has a documented justification and removal path. Compatibility shims have expiration dates. Standard library alternatives evaluated before external packages. Abstractions have at least two consumers (no speculative abstraction).

**Anti-Patterns**: Adding a package for one function | Compatibility shims without expiration dates | "We might need this flexibility later" abstractions | Wrapping a dependency in an abstraction that mirrors its exact API | Keeping dead code "just in case."

**Context Requirements**: Required: dependency manifest (go.mod, package.json, pyproject.toml), existing abstraction patterns. Helpful: dependency audit reports, tech debt tracking, migration history.

## cli-designer.md

**Description**: Command-line interface design — progressive disclosure, Unix composability, destructive operation gates, and terminal UX.

**Reasoning patterns** (7):
1. **Progressive disclosure** — The default invocation (zero flags) does the most common thing and produces clean output. Advanced behavior is opt-in via flags. Expert behavior gets config files. Required flags are a smell — if always needed, make it a positional argument.
2. **Unix composability** — Stdout is for machine-readable output (pipeable). Stderr is for human-readable status. Exit codes follow conventions. Support `--json` for programmatic consumption. A CLI tool that can't participate in a pipeline is a GUI pretending to be a terminal app.
3. **Idempotent by default** — Running a command twice produces the same result as running it once. `init` checks whether initialization already happened. `create` supports `--if-not-exists`. The default is the safe path — design for the retry case, not just first-run.
4. **Destructive operation gates** — Any command that deletes, overwrites, or is irreversible requires `--force` or interactive confirmation. Dry-run mode (`--dry-run` or `-n`) for any command that modifies state. The default is always safe.
5. **Deliverable-driven CLI structure** — Command organization mirrors deliverable boundaries. Each deliverable produces a testable command surface. Subcommands are grouped by domain, not by implementation module.
6. **Error recovery guidance** — When a command fails, output tells the user what to do next. Not just "permission denied" but "permission denied: run `chmod +x ./script.sh`". Every error path is a user experience decision.
7. **Help text as primary documentation** — `--help` is the first documentation most users see. Every command, subcommand, and flag has a one-line description. Examples section for non-obvious usage. If a user can't figure out the tool from `--help` alone, the interface is wrong.

**Quality Criteria**: Every command has `--help` with description and examples. Destructive operations require `--force` or confirmation. `--json` available for programmatic output. Exit codes documented and consistent. No silent failures — all errors produce actionable stderr messages.

**Anti-Patterns**: Inconsistent flag naming across subcommands | Output that breaks when piped (color codes, progress bars without TTY detection) | Required flags instead of positional arguments | Commands that silently succeed on no-op | Version-less CLIs.

**Context Requirements**: Required: existing command structure, flag conventions, output format patterns. Helpful: shell completion scripts, man page generation, CI usage patterns.
