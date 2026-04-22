## Architecture Decisions

### AD-1 — Split line for common.sh is line 168
**Decision**: Introduce `bin/frw.d/lib/common-minimal.sh` as a new additive file with the 7 hook-safe functions (log_warning, log_error, find_active_row, find_focused_row, read_state_field, row_name, extract_row_from_path, is_row_file). Hooks switch to sourcing it; `common.sh` shrinks accordingly.
**Rationale**: Additive landing eliminates the bootstrap window — hooks keep working while `common-minimal.sh` ships, THEN common.sh can be reduced.
**Sources**:
- `.furrow/rows/install-and-merge/research/r2-commonsh-split.md` §1 (Symbol Inventory), §2 (Hook Usage Matrix), §4 (Proposed Split) — line 168 is the exact boundary; all 12 hooks use only the 7 functions proposed for the minimal subset.
- `.furrow/rows/install-and-merge/research/r2-commonsh-split.md` §5 (Risk Analysis) — validates the split-line boundaries.
**Trade-off accepted**: Two files to maintain instead of one. Small cost; big safety win.

### AD-2 — `frw rescue` is a standalone script under bin/frw.d/scripts/rescue.sh
**Decision**: Rescue sources NOTHING from common.sh or any other lib. Uses only POSIX sh + `git`. Recovery primary path: `git show HEAD:bin/frw.d/lib/common.sh`; fallback: bundled baseline heredoc (OQ-4).
**Rationale**: Out-of-band installer pattern from nix; update-reset pattern from Homebrew; bundled-template pattern from git init. All point in the same direction: the repair tool must not depend on the thing it repairs.
**Sources**:
- `.furrow/rows/install-and-merge/research/r4-rescue-prior-art.md` §"Synthesized principles" and §"Implied design for frw rescue" — informs the two-path recovery model and the "out-of-band" constraint.
- `.furrow/rows/install-and-merge/research/r2-commonsh-split.md` §"Interplay with frw rescue" (lines 134–140) — confirms rescue.sh stays standalone and can reimplement find_active_row inline if needed.
**Trade-off accepted**: The bundled heredoc drifts from common-minimal.sh over time. **Mitigation commitment**: a CI diff-on-push gate compares the heredoc against the live `common-minimal.sh`. Landed as wave-1 step **1m** (new) and tested in step **1e** (extended).

### AD-3 — XDG Base Dir split: state vs config
**Decision**: `$XDG_STATE_HOME/furrow/{repo-slug}/` holds machine state (install-state.json, .bak files, symlink staging); `$XDG_CONFIG_HOME/furrow/` holds global defaults, shared specialists, promotion-targets scaffolding; in-repo `.furrow/` is project-only.
**Rationale**: User preference (ideation Q2 + Q4 — Option B XDG approach). Matches Linux convention; makes `rm -rf ~/.local/state/furrow/` the "reset" primitive without touching project data.
**Sources**:
- `.furrow/rows/install-and-merge/ideation-decisions.md` Q2 and Q4 — user selection of XDG approach for both machine state and global config.
- `.furrow/rows/install-and-merge/research/r1-install-mutations.md` §3 (Quarantine Candidates) — concrete split: `.bak` + install-state.json → XDG state; rows/almanac/seeds/furrow.yaml → in-repo.
**Trade-off accepted**: Three-tier resolution chain is more complex than two-tier. Mitigated by the resolver regression test (definition.yaml `config-cleanup` AC 5).

### AD-4 — Sort by (created_at, id) with LC_ALL=C
**Decision**: seeds.jsonl and todos.yaml are sorted by tuple `(created_at, id)` on every write, with `LC_ALL=C` locked. ISO-8601 timestamps sort bytewise-correctly.
**Rationale**: User chose OQ-1 Option C — chronology-visible in `less`/`cat`. ID as tiebreaker guarantees determinism.
**Sources**:
- Plan-step decision OQ-1 (user choice C, this session).
- `.furrow/rows/install-and-merge/research/r1-install-mutations.md` §"Mutation Inventory" rows for `.furrow/seeds/seeds.jsonl` and `.furrow/almanac/todos.yaml` — these are the append-ordered conflict-prone files.
**Trade-off accepted**: A record whose `created_at` is later-edited will appear to "move" in the file on next sort. Acceptable because created_at is immutable by convention.

### AD-5 — source_todos schema extension already landed
**Decision**: Schema carries both `source_todo` (singular, legacy) and `source_todos` (array). Definition.yaml for this row uses `source_todos: [...]`. Back-compat preserved.
**Rationale**: Applied during ideation when needed to validate this row's own definition. The schema sync into `/home/jonco/src/furrow/schemas/...` was a deliberate boundary crossing.
**Sources**:
- `.furrow/rows/install-and-merge/learnings.jsonl` entry timestamped `2026-04-22T17:52:00Z` — documents the boundary violation during ideation.
- `schemas/definition.schema.json` in this worktree (diff this session) and the mirrored `/home/jonco/src/furrow/schemas/definition.schema.json`.
**Trade-off accepted**: The boundary crossing itself is the thing this row fixes. Ironic but documented.

### AD-6 — Wave 2 parallelism between config-cleanup and worktree-reintegration-summary
**Decision**: File ownership is disjoint (see plan.json `parallel_safety`). Both deliverables can have specialist work happening in parallel without write-conflict risk.
**Rationale**: config-cleanup owns the dispatcher + definition/state/promotion-targets schemas + frw upgrade. reintegration-summary owns rws + skills/implement + schemas/reintegration + templates + launch-phase.sh. Overlap set is empty within wave 2.
**Sources**:
- `.furrow/rows/install-and-merge/plan.json` wave 2 `file_ownership` fields (verified: no intersection).
- `.furrow/rows/install-and-merge/definition.yaml` deliverable `file_ownership` sections.
**Trade-off accepted**: Coordination overhead of two simultaneous specialist sub-agents. Small because both are solo-harness-engineer.
**Note on launch-phase.sh**: definition.yaml also listed `bin/frw.d/scripts/launch-phase.sh` under install-architecture-overhaul's file_ownership, but wave-1 internal_sequencing does NOT modify it. See AD-8.

### AD-7 — Specialist consultants engaged per wave, not per step
**Decision**: shell-specialist (waves 1+3), complexity-skeptic (wave 1 end + wave 2 start), test-engineer (all waves, once per deliverable). Read-only; findings must be addressed or rejected with rationale.
**Rationale**: Full co-authorship would double context size and slow the main thread. Structured consultation catches category errors (bash-ism, scope creep, un-testable ACs) at the right moment.
**Sources**:
- `.furrow/rows/install-and-merge/team-plan.md` §"Consultants" and §"Engagement protocol".
**Trade-off accepted**: If consultants miss something, review-step dual-reviewer is the backstop.

### AD-8 — launch-phase.sh ownership is scoped by sequence, not set
**Decision**: `bin/frw.d/scripts/launch-phase.sh` is listed in two deliverables' file_ownership: `install-architecture-overhaul` (wave 1) and `worktree-reintegration-summary` (wave 2). Resolution: **wave 1 does not edit launch-phase.sh**; wave 2 is the sole modifier, adding the worktree-complete → `rws generate-reintegration` invocation. Plan.json wave-1 file_ownership **keeps launch-phase.sh listed for read-protection** (other waves can't touch it until wave-1 ships), but wave-1 edits are limited to the install-artifact sub-surface (install.sh, frw.d/install.sh), which touches launch-phase.sh only if install mutates it (R1 confirms launch-phase.sh has no tracked-file mutations during install).
**Rationale**: Addresses fresh-reviewer concern about wave-2 launch-phase.sh overlap. Sequential-not-parallel ownership is the honest model.
**Sources**:
- Fresh-reviewer feedback this session (top risk #1).
- `.furrow/rows/install-and-merge/research/r1-install-mutations.md` §"Mutation Inventory" — launch-phase.sh not in the mutation set.
**Trade-off accepted**: Implicit scoping is weaker than per-function file ownership; documented here and enforced by sub-step discipline.

### AD-9 — `--no-verify` bypass path is explicitly tested
**Decision**: Add an integration test asserting that the pre-commit hook's `[furrow:warning]` fires on the stderr when the hook is invoked via a `--no-verify` bypass path. Also a CI contamination-check script (per OQ-2) asserts the banned patterns fail the build on push.
**Rationale**: Addresses fresh-reviewer concern #3 — the accepted trade-off had no enforcement.
**Sources**:
- Fresh-reviewer feedback this session (top risk #3).
- Plan-step decision OQ-2 (user confirmed, this session).
**Trade-off accepted**: CI must be maintained as the belt-and-suspenders layer; if CI is broken, the project leaks one layer of protection. Acceptable because pre-commit still blocks the default path.
