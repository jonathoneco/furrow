# Legacy Shell Cutoff Audit

Date: 2026-04-29
Row: `work/legacy-shell-cutoff-audit`

## Executive Verdict

Furrow is already past the point where the shell CLIs should be treated as
canonical workflow truth. The Go backend owns the row state read/write contract,
transition blocker baseline, archive readiness, review artifact semantics,
almanac validation, context bundles, handoff rendering/validation, adapter
rendering, layer policy decisions, presentation checks, and several validation
surfaces.

The legacy shell layer is still live for compatibility and for several semantic
paths that do not yet have Go parity. The next cleanup should not broadly delete
`bin/` yet. It should first collapse active command markdown into thin adapters
over Go-owned behavior and explicitly mark shell-only paths as compatibility or
temporary semantic holdouts.

Cutoff posture:

- Treat `furrow` and `internal/cli/` as canonical for implemented backend
  behavior.
- Treat `bin/frw`, `bin/rws`, `bin/alm`, `bin/sds`, and `bin/frw.d/**` as
  compatibility-only unless this document classifies a path as
  `shell-semantic`.
- Do not let active prompts or command markdown present shell behavior as the
  enduring source of truth when Go owns the same behavior.
- Defer deletion of shell code until the blocked removals below have Go parity
  or are intentionally retired.

Recommended next row:
`work/command-markdown-thin-adapter-collapse`.

## Removal/Routing Update: 2026-04-29

Row: `work/legacy-shell-cutoff-and-removal`

This follow-up made only loaded-path cuts with live Go parity:

- `frw validate-definition` remains as a compatibility entrypoint, but its
  fallback now runs the Go validator from `FURROW_ROOT/cmd/furrow` instead of
  assuming the caller's project contains `./cmd/furrow`.
- `frw hook validate-definition` no longer owns yq-based validation rules. It
  only adapts the Claude hook JSON envelope and calls `furrow validate
  definition --path <definition.yaml>`, preserving the legacy hook surface while
  routing validation semantics to Go.
- `rws status`, `rws list`, `rws focus`, and `rws repair-deliverables` now exec
  `furrow row status`, `furrow row list`, `furrow row focus`, and
  `furrow row repair-deliverables` respectively. These are compatibility aliases
  over loaded Go row paths.
- `skills/shared/layer-protocol.md` now names `furrow row transition` as the
  operator-owned transition path and limits `rws`/`alm`/`sds` to temporary
  holdouts where Go parity does not exist.

No shell entrypoint was deleted in this row. The active runtime/documentation
surface still depends on shell-owned install/init/upgrade, doctor, hooks,
summary mutation, user actions, merge/reintegration, gate execution,
cross-model review, almanac extraction/triage/observation/rationale, and seed
behavior.

## Classification Table

| Surface | Classification | Evidence | Cutoff implication |
| --- | --- | --- | --- |
| `cmd/furrow/main.go` | `go-canonical` | Executes `internal/cli.App` as the Go CLI entrypoint. | Keep as canonical binary entrypoint. |
| `internal/cli/app.go` root dispatch | `go-canonical` | Implements live groups: `row`, `review`, `almanac validate`, `validate`, `guard`, `context`, `handoff`, `render`, `hook`, `layer`, `presentation`, `doctor`. | Adapter and prompt surfaces should route to this where behavior exists. |
| `furrow row list/status` | `go-canonical` | Implemented in `internal/cli/row.go` with tolerant state reads, focused-row resolution, blockers, artifacts, and JSON output. | Replace active `rws list/status` instructions with Go commands. |
| `furrow row transition/complete/archive` | `go-canonical` | Implemented in `internal/cli/row.go` with narrow but real lifecycle mutation, blockers, archive readiness, and evidence. | Shell `rws transition`, `complete-step`, and `archive` are not canonical for gated rows. |
| `furrow row init/focus/scaffold` | `go-canonical` | Implemented in `internal/cli/row_workflow.go`. | `rws init/focus` can become wrappers once worktree/branch side effects are either ported or retired. |
| `furrow row repair-deliverables` | `go-canonical` | Implemented in `internal/cli/row_repair.go`. | Shell deliverable repair logic should not grow. |
| `furrow review status/validate` | `go-canonical` | Implemented in `internal/cli/review.go` and review semantics helpers. | Active review prompts should use Go for review-state truth. |
| `furrow almanac validate` | `go-canonical` | Implemented in `internal/cli/almanac.go` for live todos, observations, and roadmap shapes. | `alm validate` should become a compatibility wrapper or be removed from active instructions. |
| `furrow validate definition` | `go-canonical` | Implemented in `internal/cli/validate_definition.go`. | `frw validate-definition` and related hook shell should route to Go or remain temporary shims only. |
| `furrow validate ownership` | `go-canonical` | Implemented in `internal/cli/validate_ownership.go`; precommit/hook shell surfaces reference protected paths. | Shell ownership warnings are adapter shims around backend policy. |
| `furrow validate layer-policy/skill-layers/driver-definitions` | `go-canonical` | Implemented in `internal/cli/validate_layer_policy.go`, `validate_skill_layers.go`, and `validate_driver_definitions.go`. | Keep backend validation canonical. |
| `furrow guard` | `go-canonical` | Implemented in `internal/cli/guard.go` to translate normalized blocker events. | Shell hook emitters should not define blocker semantics independently. |
| `furrow context for-step` | `go-canonical` | Implemented in `internal/cli/context/cmd.go` and strategy packages. | Command markdown should not use `rws load-step` as canonical context loading. |
| `furrow handoff render/validate` | `go-canonical` | Implemented in `internal/cli/handoff/cmd.go`. | Driver/engine handoff prompts correctly route to Go. |
| `furrow render adapters` | `go-canonical` | Implemented in `internal/cli/render/adapters.go`. | Adapter file generation belongs in Go. |
| `furrow hook layer-guard` and `furrow hook presentation-check` | `go-canonical` | Implemented in `internal/cli/hook/`. | Claude hook settings already call these Go hooks alongside shell hooks. |
| `furrow layer decide` and `furrow presentation scan` | `go-canonical` | Implemented in `internal/cli/layer` and `internal/cli/hook` paths. | Backend owns layer/presentation decisions. |
| `furrow doctor` | `go-canonical` | Implemented in `internal/cli/doctor.go` for backend readiness, not full shell parity. | Use for backend health; do not claim it replaces every `frw doctor` check yet. |
| `furrow gate`, `furrow seeds`, `furrow merge`, `furrow init` | `reserved-or-vaporware` | `internal/cli/app.go` returns reserved-group help or `not_implemented`. | Keep hidden/reserved in UX; do not route workflows to them as live behavior. |
| `furrow row checkpoint/summary/validate` | `reserved-or-vaporware` | `internal/cli/app.go` routes these leaves to `not_implemented`. | Keep shell summary/checkpoint wrappers until Go parity exists. |
| `furrow review run/cross-model` | `reserved-or-vaporware` | `internal/cli/review.go` returns `not_implemented`. | Cross-model review remains shell/provider-specific until ported or retired. |
| `bin/frw` dispatcher | `compat-wrapper` | Routes to `bin/frw.d/**` shell scripts and rejects `rws|alm|sds` as separate CLIs. | Keep as compatibility dispatcher until subcommands are either Go wrappers or deleted. |
| `bin/frw root/help` | `compat-wrapper` | Local dispatcher convenience only. | Safe to preserve until installer/compat story changes. |
| `bin/frw init/install/upgrade` and `bin/frw.d/init.sh`, `install.sh`, `scripts/upgrade.sh` | `shell-semantic` | Go `furrow init` is reserved; install/upgrade are shell-only. | Must remain until Go bootstrap/install parity exists or install flow is retired. |
| `bin/frw doctor` and `bin/frw.d/scripts/doctor*.sh` | `shell-semantic` | `frw doctor` checks broader shell-era install, skills, hooks, and repo hygiene that Go doctor explicitly does not cover. | Keep until Go doctor absorbs or intentionally drops each check. |
| `bin/frw hook *` and `bin/frw.d/hooks/**` | mixed: `compat-wrapper` plus `shell-semantic` | Some hooks wrap Go-backed validation concepts; others still implement shell-only checks like append-learning, auto-install, script-guard, summary validation, and work-check. | Split hook-by-hook in a future row; do not delete the tree as one unit. |
| `bin/frw update-state/update-deliverable` | `shell-semantic` | Shell mutates row state directly; no generic Go patch/update-deliverable command exists. | Blocked until mutation paths are removed from active prompts or ported. |
| `bin/frw check-artifacts/run-gate/evaluate-gate/select-gate/select-dimensions` | `shell-semantic` | Go has transition blockers and review validation, but `furrow gate` is reserved and full gate orchestration is not implemented. | Keep until gate orchestration is ported or command markdown stops using these paths. |
| `bin/frw generate-plan` | `shell-semantic` | Builds `plan.json` from `definition.yaml`; no equivalent Go command exists. | Keep until decompose planning generation is backend-owned or retired. |
| `bin/frw validate-definition/validate-naming` | mixed: `compat-wrapper` and `shell-semantic` | Definition validation routes to `furrow validate definition`; naming validation remains shell-only. | Keep definition as a compatibility wrapper; port naming or delete it later. |
| `bin/frw measure-context` | `shell-semantic` | Shell-only context budget accounting; Go context bundle assembly does not enforce this budget. | Keep until context budget validation is Go-backed or retired. |
| `bin/frw run-ci-checks/run-integration-tests` | `shell-semantic` | Project/test orchestration is shell-only. | Keep or replace with explicit repo test commands. |
| `bin/frw cross-model-review` | `shell-semantic` | Go review run/cross-model are reserved; active driver prompts still call shell. | Must remain until review execution is ported or removed. |
| `bin/frw merge-*`, `merge-sort-union`, `merge-to-main`, `rescue`, `launch-phase` | `shell-semantic` | Go `furrow merge` is reserved; command markdown still uses merge and launch shell flows. | Keep until merge/phase launch behavior is ported or retired. |
| `bin/frw migrate-*`, `normalize-seeds`, `normalize-todos` | `shell-semantic` | Data migration and normalization are shell-only. | Keep as maintenance tools until replacement or one-time retirement. |
| `bin/frw.d/lib/**` | mixed support code | Shared shell libraries support the remaining shell-semantic and hook paths. | Delete only after dependent shell paths are gone. |
| `bin/rws` row lifecycle CLI | mixed: `compat-wrapper` plus `shell-semantic` | `status`, `list`, `focus`, and `repair-deliverables` route to Go; transition/archive/init/complete still retain shell-only compatibility semantics or incompatible flags; summary, user actions, reintegration, sort invariant, diff, worktree summary, and load-step remain shell-only. | Preserve shell-only commands until parity or retirement. |
| `rws load-step` | `shell-semantic` | Active docs now prefer `furrow context for-step`, but this shell command still owns legacy skill loading. | Candidate for deletion after command markdown collapse verifies no active route uses it. |
| `rws regenerate-summary/validate-summary/update-summary` | `shell-semantic` | Go `row summary` is reserved; active checkpoint/archive docs still call these wrappers. | Must remain until Go summary command exists or summary mutation is retired. |
| `rws add/complete/list-user-action` | `shell-semantic` | Step sequence rule explicitly says pending user actions use `rws complete-user-action` until Go command exists. | Must remain until Go user-action commands exist. |
| `rws generate-reintegration/get-reintegration-json/validate-sort-invariant` | `shell-semantic` | Merge command markdown and shell merge pipeline consume these. | Must remain until merge pipeline is ported or retired. |
| `bin/alm validate` | `compat-wrapper` candidate | Go `furrow almanac validate` owns validation. | Safe to route through Go later. |
| `bin/alm add/extract/list/show/triage/next/render/learn/observe/rationale/docs/specialists/history` | `shell-semantic` | Go only implements `almanac validate`; active command docs still call `alm triage`, `alm extract`, and observations. | Must remain until almanac/TODO/observation behaviors are ported or removed. |
| `bin/sds` seed CLI | `shell-semantic` | Go `furrow seeds` is reserved; row init and shell checks still create/read/update seeds. | Must remain until seed graph parity exists or seed paths are retired. |
| `commands/work.md` and `commands/work.md.tmpl` | `go-canonical` adapter surface | Routes context, handoff, render, complete, and transition through Go. | Keep thin; remove remaining embedded workflow semantics in the next row. |
| `commands/status.md`, `reground.md`, `redirect.md`, `review.md` | `go-canonical` adapter surface | Use Go row/review/status surfaces. | Keep as thin prompt adapters. |
| `commands/checkpoint.md` | mixed: `go-canonical` plus `shell-semantic` | Uses Go complete/transition but shell `rws regenerate-summary`. | Collapse after Go summary parity or explicit summary-retirement decision. |
| `commands/archive.md` | mixed: `go-canonical` plus `shell-semantic` | Uses Go archive but shell `alm extract`, `alm observe`, and `rws regenerate-summary`. | Keep until archive ceremony/TODO/observation/summary paths are resolved. |
| `commands/triage.md` and `work-todos.md` | `shell-semantic` adapter surface | Explicitly say no Go-backed triage/TODO extraction command exists and call `alm`. | Leave labeled; do not grow before source-of-truth simplification. |
| `commands/init.md` | `shell-semantic` adapter surface | Calls legacy `frw init` and `sds init`; Go init and seeds are reserved. | Keep until bootstrap/seed parity exists. |
| `commands/next.md` | `shell-semantic` adapter surface | Uses roadmap selection plus `frw launch-phase`. | Keep until phase launch is ported or retired. |
| `commands/merge.md` | `reserved-or-vaporware` plus `shell-semantic` | Labels `/furrow:merge` and `furrow merge` reserved, then routes to shell merge scripts. | Keep labeled; do not advertise Go merge as live. |
| `commands/doctor.md` | `compat-wrapper` | Calls `frw doctor`; Go doctor is narrower. | Keep until checks are split into Go doctor vs shell install doctor. |
| `commands/lib/*.sh` | `shell-semantic` | Command-local shell helpers for learnings/components. | Keep until archive/learnings promotion flow is ported or retired. |
| `.claude/settings.json` | mixed adapter surface | Calls both shell hooks and Go hooks. | Keep; future row should replace shell hooks individually as Go parity lands. |
| `.claude/agents/driver-*.md` | mixed adapter surface | Mostly route to Go handoff/row commands, but still call `frw cross-model-review`, `frw validate-definition`, `rws gate-check`, `rws init`, and `alm observe`. | Next row should thin these to backend-owned truth and label shell fallbacks. |
| `.claude/rules/cli-mediation.md` | mixed adapter rule | Correctly labels summary/deliverable commands as legacy compatibility wrappers. | Keep but update when Go summary/deliverable parity exists. |
| `.claude/rules/step-sequence.md` | mixed adapter rule | Go transition is canonical; `rws complete-user-action` remains explicit until Go exists. | Keep until user-action parity exists. |
| `.claude/CLAUDE.md` | `compat-wrapper` adapter rule | Says `furrow`/`frw` are CLI tools and legacy `bin/rws`, `bin/alm`, `bin/sds` are compatibility wrappers only. | Directionally correct, but overbroad because several shell paths still own semantics. |
| `.claude/furrow.yaml` | support config | Contains seed prefix and runtime settings consumed by shell and Go. | Not a CLI surface; keep as shared config until config ownership is clarified. |
| Archived docs, research, handoffs, and tests mentioning shell | `historical` | Many docs record old architecture, audits, or test fixtures rather than live instructions. | Do not chase historical references unless active docs promote them as current behavior. |

## Cutoff Candidates

Safe later deletions or wrapper conversions once the named blockers are closed:

- Convert `alm validate` to `furrow almanac validate`.
- Convert `rws transition`, `rws complete-step`, `rws archive`, and the row-state
  portions of `rws init` to wrappers over `furrow row ...` only after their
  shell-only flags, failure/conditional behavior, summary side effects, and
  bootstrap side effects are either ported or retired. `rws status`, `rws list`,
  `rws focus`, and `rws repair-deliverables` are already compatibility aliases
  over Go.
- Delete `bin/frw.d/hooks/validate-definition.sh` only if
  `.claude/settings.json` no longer registers the legacy
  `frw hook validate-definition` surface.
- Retire `rws load-step` after active command markdown and driver prompts route
  only through `furrow context for-step` and rendered handoffs.
- Retire active references to `rws gate-check` where `furrow row transition`
  already enforces the relevant blocker.
- Split `frw doctor` into Go backend readiness and shell install/compat checks;
  after that, keep only the checks that protect active adapter installation.
- Remove or archive shell merge commands only after `/furrow:merge` and
  `furrow merge` are either implemented or intentionally killed.
- Archive shell migration scripts after their migration has been run or a
  replacement is named.

## Blocked Removals And Why

- `bin/frw` cannot be removed because it is still the compatibility dispatcher
  used by active Claude hook settings and command markdown.
- `bin/frw.d/hooks/**` cannot be removed as a group because several live Claude
  hooks still call shell-only checks.
- `bin/frw.d/scripts/doctor.sh` cannot be removed because Go doctor explicitly
  does not cover the full shell-era install/hook/skill check set.
- `bin/frw.d/scripts/cross-model-review.sh` cannot be removed because Go review
  execution and cross-model review are reserved.
- `bin/frw.d/scripts/run-gate.sh`, `evaluate-gate.sh`, `select-gate.sh`, and
  `select-dimensions.sh` cannot be removed until `furrow gate` exists or gate
  execution is retired from active flows.
- `bin/frw.d/scripts/generate-plan.sh` cannot be removed until decompose plan
  generation is backend-owned or no active workflow requires generated plans.
- `bin/frw.d/scripts/merge-*.sh`, `merge-sort-union.sh`, `merge-to-main.sh`,
  `rescue.sh`, and `launch-phase.sh` cannot be removed while merge and phase
  launch flows remain shell-only.
- `bin/rws` cannot be removed because summary mutation, user actions,
  reintegration JSON, sort invariant checks, worktree summaries, and some
  legacy row operations have no Go equivalent.
- `bin/alm` cannot be removed because TODO extraction, triage, roadmap next,
  observations, learnings, rationale, docs, specialists, and history commands
  have no Go equivalent.
- `bin/sds` cannot be removed because `furrow seeds` is reserved and seed
  create/update/list/show/close/ready/dep behavior is shell-only.
- `commands/checkpoint.md` and `commands/archive.md` cannot be made fully
  Go-only until summary regeneration and archive/TODO/observation ceremony are
  either ported or explicitly retired.
- `.claude/settings.json` cannot drop shell hooks until each hook's enforcement
  value is either ported to Go or intentionally removed.

## Recommended Next Row

`work/command-markdown-thin-adapter-collapse`

Scope for that row:

- Rewrite active `commands/*.md` and active `.claude/agents/*.md` surfaces so
  they present Go-owned behavior as canonical wherever Go parity exists.
- Preserve shell calls only when classified here as `shell-semantic`, and label
  those calls as temporary compatibility holdouts.
- Remove prompt wording that treats shell CLIs as semantic authority for row
  state, transition, review-state truth, almanac validation, context loading,
  handoff rendering, adapter rendering, layer policy, or presentation checks.
- Do not implement new Go command families in that row.
- Do not delete broad shell code in that row.

## Explicit Non-Goals

- No broad deletion of shell CLIs or `bin/frw.d/**`.
- No new roadmap, TODO, seed, Pi UX, dashboard, TUI, or planning surface.
- No seed cutover and no `todos.yaml` retirement.
- No new process layer or architecture abstraction.
- No implementation of reserved Go command groups (`gate`, `seeds`, `merge`,
  `init`) in this audit row.
- No claim that Go doctor fully replaces `frw doctor`.
- No changes to historical docs merely because they mention shell commands.
- No TODO filing as a substitute for fixing narrow active-label mismatches in
  the next adapter-collapse row.
