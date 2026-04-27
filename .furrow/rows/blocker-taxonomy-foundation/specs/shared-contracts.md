# Spec: shared-contracts (cross-deliverable contract lock)

This document locks the cross-cutting contracts that D1, D2, D3, D4 share.
Authored after cross-spec review identified contract drift across the five specs.
**Each individual spec defers to this document where conflicts arise.**

## C1 — Event-type catalog and naming

**Decision**: per-hook event types (~10), not collapsed semantic categories.

**Rationale**: collapsing ≥2 hooks onto one event type pushes condition-branching into
Go handlers, then re-expands them through payload discriminators. Per-hook 1:1 mapping
keeps the dispatch trivial and matches the mental model "this hook calls this backend
function." The slightly larger event-type catalog is a fixed-size cost paid once.

**Naming convention**: snake_case with explicit category prefix; underscore-separated.

**Final catalog** (10 entries — one per emit-bearing hook):

| Event type | Source hook | Codes emitted |
|------------|-------------|---------------|
| `pre_write_state_json` | `state-guard.sh` | `state_json_direct_write` |
| `pre_write_verdict` | `verdict-guard.sh` | `verdict_direct_write` |
| `pre_write_correction_limit` | `correction-limit.sh` | `correction_limit_reached` |
| `pre_bash_internal_script` | `script-guard.sh` | `script_guard_internal_invocation` |
| `pre_commit_bakfiles` | `pre-commit-bakfiles.sh` | `precommit_install_artifact_staged` |
| `pre_commit_typechange` | `pre-commit-typechange.sh` | `precommit_typechange_to_symlink` |
| `pre_commit_script_modes` | `pre-commit-script-modes.sh` | `precommit_script_mode_invalid` |
| `stop_ideation_completeness` | `stop-ideation.sh` | `ideation_incomplete_definition_fields` |
| `stop_summary_validation` | `validate-summary.sh` | `summary_section_missing`, `summary_section_empty` |
| `stop_work_check` | `work-check.sh` | `state_validation_failed_warn`, `summary_section_missing_warn`, `summary_section_empty_warn` |

`gate-check.sh` is dead code and contributes no event type — deleted in D3.

D2 catalog (`schemas/blocker-event.yaml`) MUST list these 10 entries verbatim.
D3 hook table MUST reference these 10 names verbatim. D4 fixtures MUST key off
these 10 names verbatim.

## C2 — `furrow guard` CLI contract

**Invocation**: `furrow guard <event-type>` (no flags). Reads normalized event JSON on stdin.

**Stdout**: a JSON **array** of zero or more `BlockerEnvelope` objects. Empty array = trigger
condition not met. **Always an array, never a bare object** — uniform shape removes branching
for callers and tests.

```
[]                                   # no trigger
[{...envelope...}]                   # single emit (most common)
[{...env1...}, {...env2...}]         # multi-emit (e.g., pre_commit_bakfiles with multiple paths)
```

**Exit codes** (`furrow guard` itself):
- `0` — ran cleanly. Stdout is an array (possibly empty).
- `1` — invocation error (unknown event type, malformed input, internal error). Stderr carries the diagnostic.

`furrow guard` **NEVER exits 2**. Host-blocking exit codes are produced only by the shell
helper `emit_canonical_blocker` translating envelope `severity` to host exit codes.

## C3 — `BlockerEnvelope` shape (canonical)

```json
{
  "code": "string",
  "category": "string",
  "severity": "block | warn | info",
  "message": "string (interpolated from message_template)",
  "remediation_hint": "string (single source of prose)",
  "confirmation_path": "block | warn-with-confirm | silent"
}
```

**Six fields. No more, no less.**

`details` is **NOT** part of the envelope. If a caller has detail context (e.g., the
specific path that triggered a state-mutation block), the caller stores it in a SIBLING
struct/map alongside the envelope, never inside it. D4 fixtures contain the envelope only;
parity comparison is over the envelope only.

D1 spec amendment: detail-key handling stays with the caller (`row_semantics.go` callers),
not in the envelope.

## C4 — Shell helper contract (`bin/frw.d/lib/blocker_emit.sh`)

**Owner**: D2 lands the file with the contract below. D3 sources it.

**Exports** (POSIX sh functions):

| Function | Stdin | Args | Behavior | Exit code |
|----------|-------|------|----------|-----------|
| `claude_tool_input_to_event` | Claude `PreToolUse` JSON | `<event_type>` | Translates Claude event shape → normalized event JSON; writes to stdout | 0 always (input validation errors → upstream caller fails) |
| `furrow_guard` | normalized event JSON | `<event_type>` | Calls `go run ./cmd/furrow guard <event_type>` (or `$FURROW_BIN` override); writes envelope-array stdout | 0 if guard ran cleanly, 1 on guard invocation error |
| `emit_canonical_blocker` | envelope-array JSON | _(none)_ | Reads envelope array; if non-empty, prints `message`/`remediation_hint` to stderr in host-native format; sets process exit code per highest envelope severity (`block`→2, `warn`→0 with stderr, `info`→0 silent) | 0 if no block emissions; 2 if any envelope has severity `block` |
| `precommit_init` | _(none)_ | _(none)_ | Sets up pre-commit hook environment (git rev-parse, staged-paths capture); writes setup output to stdout for sourcing | 0 always |

**D3 may NOT modify these signatures.** D3 may add new helpers to `bin/frw.d/lib/` if shared
by ≥2 shims, with each new helper documented in the `research/hook-audit-final.md` audit report.

## C5 — Hook shim canonical shape

Each migrated hook is reduced to this exact 4-step pattern (≤30 executable lines):

```sh
#!/bin/sh
. "${FURROW_ROOT}/bin/frw.d/lib/blocker_emit.sh"

main() {
  claude_tool_input_to_event <event_type> | furrow_guard <event_type> | emit_canonical_blocker
}

main
```

For pre-commit hooks the first step is `precommit_init` instead of `claude_tool_input_to_event`.
Any deviation (e.g., conditional logic, message construction, project-file reads) is a domain-logic
violation per D3 AC-2.2.

## C6 — Go layout

**Single file**: `internal/cli/guard.go` houses the `furrow guard` dispatch and handler registry.
Per-event handlers MAY live in sibling files (`internal/cli/guard_handlers.go` or one per
event type) — but the registry and CLI entry point are in `guard.go`.

Domain-logic ports for non-trivial hooks (e.g., script-guard.sh's awk parser) live in
**dedicated sibling Go files**, not in `guard.go`:
- `internal/cli/shellparse.go` — `script-guard` awk port
- `internal/cli/correction_limit.go` — correction-limit logic
- `internal/cli/work_check.go` — work-check warn-path logic

D3 spec references `internal/cli/guard/*.go` — that path is replaced by `internal/cli/guard.go`
+ siblings per this contract.

## C7 — Coverage / parity test invariants

**Taxonomy walk** (D4): `yq '.blockers[].code' schemas/blocker-taxonomy.yaml`. The taxonomy
top-level is `{version, blockers: [...]}` (per D1's `Taxonomy` struct in `internal/cli/blocker_envelope.go`).

**Coverage assertion**: for every code in the taxonomy, a fixture set exists at
`tests/integration/fixtures/blocker-events/<code>/` containing 4 files (`normalized.json`,
`claude.json`, `pi.json`, `expected-envelope.json`).

**Parity comparison**: `jq -S` over the **envelope array** (not single object). Both Claude-shape
and Pi-shape invocations produce arrays of the same length, and pairwise byte-equal envelopes
after sorting by `.code`.

**Pi-handler-absent skip rule**: for codes whose Pi-side handler does not yet exist in
`adapters/pi/validate-actions.ts`, parity test SKIPS with logged reason `"Pi handler not yet
implemented for <code> — see follow-up TODO pi-tool-call-canonical-schema-and-surface-audit"`.
This prevents the trivial-pass case where both sides invoke the same Go binary because the Pi
adapter hasn't been wired for that code.

**Deferred-code skip rule**: for codes mapped to W3-deferred hooks, parity test SKIPS with
logged reason naming the deferral TODO.

## C8 — Test wiring boundary

`tests/integration/run-all.sh` already auto-discovers `test-*.sh`. **No Makefile, no CI YAML,
no edits to `run-all.sh`** are part of any deliverable.

CI invocation of `run-all.sh` is **out of scope for this row** — captured as a follow-up TODO
if not already covered elsewhere.

## C9 — Spec-revision precedence

When an individual spec (D1–D5) conflicts with this shared-contracts spec, **shared-contracts
wins**. The implementer MUST treat shared-contracts as canonical and the per-deliverable spec
as supplementary.

Each individual spec carries a one-line note at the top: "See `specs/shared-contracts.md` for
cross-cutting decisions; that document overrides any conflicting detail here."
