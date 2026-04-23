# Ideation Decisions — post-install-hygiene

Row: `post-install-hygiene`
Branch: `work/post-install-hygiene`
Base: `5110add`
Source: Phase 1 of `.furrow/almanac/roadmap.yaml` — 8 review-findings from install-and-merge post-ship review.

---

## Shape & premise (brief)

**Shape**: Moderate bundle. 8 deliverables, most small effort. Dominant specialist: `harness-engineer`. One `test-engineer` deliverable. Most deliverables are independent; a few shared-schema dependencies.

**Premise check — is the Phase-1 bundling correct?**

- Safety: `audit-test-install-*` (live-worktree mutation) is the only HIGH-urgency entry — leading it is right.
- Coherence: All 8 trace to the same post-ship review and touch overlapping subsystems (install / test / review-pipeline / schemas). Bundling saves 7 branch ceremonies.
- One candidate to challenge: `ac-10-e2e-fixture-split` is LOW/LOW and could be deferred — but it lives in the same test infra as the isolation audit, so landing together is cheaper.
- No obvious conflict with in-flight work. Branch is already checked out.

**Recommendation**: keep all 8 in scope as-triaged.

---

## Decisions needed

Each decision has options and a stated lean. Comment inline or reply with `D1: A`, `D2: B`, etc.

---

### D1 — Specialist symlink unification direction

<!-- ideation:section:specialist-symlink-direction -->

**Context**: 14 specialists are tracked in git; 8 are `.gitignored` and point at the install-time source dir. Must unify.

- **Option A — Track all 22**
  Remove the gitignore pattern. Predictable, self-contained checkout; bigger git surface.

- **Option B — Untrack all 22, treat all as install-time artifacts**
  Remove the 14 tracked ones. Matches the "symlinks are install artifacts" policy from install-and-merge; consumer repos get them via `install.sh`; cleaner source/consumer separation.

**Lean: Option B.** install-and-merge just established that install artifacts live outside the tracked repo. Tracking 22 symlinks pointing at `../../specialists/` is fine inside the source repo, but the policy direction is "install-time, not committed." This aligns the 8 outliers with the 14, not the reverse.

**Your call / comments:** Agreed

---

### D2 — `rescue.sh` exec contract

<!-- ideation:section:rescue-sh-contract -->

- **Option A — 100755 standalone executable**
  Matches every other `bin/frw.d/scripts/*.sh`. Fix via `git update-index --chmod=+x`.

- **Option B — Leave 100644, dispatcher routes via `sh "$script"`**
  Special-cases rescue; documented as "hook-cascade-safe."

**Lean: Option A.** install-and-merge's rescue design was "standalone, does NOT source common.sh" — the file-mode bug is the anomaly, not the dispatcher. Simpler fix, no dispatcher carve-out.

**Your call / comments:** Agreed

---

### D3 — AC-10 e2e fixture strategy

<!-- ideation:section:ac-10-fixture-strategy -->

- **Option A — Merge existing two fixtures**
  Into one combined (contamination + feature commits + protected-file conflict + approved-execute + verify-green).

- **Option B — Add a third fixture**
  Alongside, leaving the two existing scenarios intact as focused sub-phase tests.

**Lean: Option B (add third).** Per AC-10's wording ("single unified fixture…through all five subphases") the new test is the end-to-end scenario. The existing two stay as focused sub-phase tests. Total e2e coverage grows; nothing regresses.

**Your call / comments:** Agreed

---

### D4 — Scope of XDG config audit deliverable

<!-- ideation:section:xdg-config-audit-scope -->

- **Option A — Full wire-through**
  Audit every field, wire missing consumers, add per-field resolution tests. Closes the AC-1/AC-4 gap in-row.

- **Option B — Catalog-only**
  List which fields have/lack consumers, open follow-up TODOs. Defer wiring to whatever row actually needs each field.

**Lean: Option A (full wire-through).** The three named fields (`cross_model.provider`, `preferred_specialists`, `gate_policy` default) are all referenced by existing code paths — wiring is ~1-day work and produces real behavior change. Catalog-only leaves the shipped config file as a "sometimes respected" surface, which is the worst UX.

**Your call / comments:** Agreed

---

### D5 — Cross-model reviewer per-deliverable diff scope

<!-- ideation:section:cross-model-diff-scoping -->

- **Option A — File-ownership globs only**
  Simpler; uses declared `file_ownership` to constrain the diff passed to codex.

- **Option B — Commit-range tracing**
  `git log --pretty=%H -- <globs>` to find commits that touched deliverable files, then diff only those commits.

- **Option C — Both**
  Glob-scoped diff + commit-range intersection.

**Lean: Option B (commit-range tracing).** Per the TODO's own `work_needed`. Pure glob-scoped diff misses cross-file refactors that are legitimately part of the deliverable but happen to touch a peripheral file. Commit-range is the authoritative signal.

**Your call / comments:** Agreed

---

## Next step

Once D1–D5 are answered I'll draft `definition.yaml` section-by-section: objective → 8 deliverables → context_pointers → constraints → `gate_policy: supervised`. Structure mirrors install-and-merge.

### Provisional deliverable → TODO mapping (for sanity-checking scope)

| #   | Deliverable name (draft)             | TODO id                                              | Specialist       | Depends on                                      |
| --- | ------------------------------------ | ---------------------------------------------------- | ---------------- | ----------------------------------------------- |
| 1   | `test-isolation-guard`               | `audit-test-install-sh-and-test-upgrade-sh-for-live` | test-engineer    | —                                               |
| 2   | `rescue-sh-exec-fix`                 | `bin-frw-d-scripts-rescue-sh-committed-as-100644-di` | harness-engineer | —                                               |
| 3   | `cross-model-per-deliverable-diff`   | `codex-cross-model-reviewer-flags-other-deliverable` | harness-engineer | —                                               |
| 4   | `reintegration-schema-consolidation` | `generate-reintegration-sh-should-use-canonical-sch` | harness-engineer | —                                               |
| 5   | `xdg-config-consumer-wiring`         | `audit-xdg-config-fields-for-runtime-consumers-pref` | harness-engineer | —                                               |
| 6   | `promote-learnings-schema-fix`       | `commands-lib-promote-learnings-sh-reads-null-for-e` | harness-engineer | —                                               |
| 7   | `specialist-symlink-unification`     | `unify-tracked-14-vs-gitignored-8-specialist-symlin` | harness-engineer | —                                               |
| 8   | `ac-10-e2e-fixture`                  | `ac-10-e2e-fixture-split-across-contaminated-stop-a` | test-engineer    | `test-isolation-guard` (reuse hardened harness) |

Most are parallel-safe. Only dependency: AC-10 fixture consumes the isolation guard's sandboxing helpers, so it lands after.
