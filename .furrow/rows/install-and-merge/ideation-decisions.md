# install-and-merge — Ideation Decisions

Annotate in place. Write answers under each question (keep, change, expand).
Save, then tell me "ready" and I'll draft `definition.yaml` section by section.

---

## 1. Brainstorm — Dimensions of the Problem

This row bundles four TODOs that share the **install/merge blast radius**. Three layers:

- **Install-time hygiene** (what the harness does to the filesystem): `install-architecture-overhaul` + `config-cleanup`. Self-hosting detection, symlink target repair, artifact quarantine, pre-commit guards, `~/.config/furrow/` tier, FURROW_ROOT resolution.
- **Merge-time discipline** (how we land worktree branches): `merge-process-skill`. Pre-merge audit of symlink-ification, overlap with main, common.sh syntax check, rescue path.
- **Handoff back to the spawning session**: `worktree-reintegration-summary`. Structured summary so the main session doesn't re-investigate.

Through-line: **we keep breaking our own tools by letting install-artifact mutations cross trust boundaries** (into commits, into merges, into the main repo's source files). Every fix is about drawing and enforcing a boundary.

---

## 2. Premise Challenge

- **Conventional wisdom**: "install scripts manipulate the filesystem." _Challenge_: ours also commits its manipulations. The real fix is making install a pure function of (source tree + config), with all state in a namespaced untracked location.
- **Prior art**: `frw launch-phase` already distinguishes worktree/source; hooks already distinguish tracked/untracked paths. But no single place says "this file is install-owned, don't commit it."
- **First principles**: A self-hosting tool must be able to tell its source-form from its installed-form. Absent that, every install is ambiguous.

### Comments / amendments:

<!-- write here -->

---

## 3. Key Decisions

### <!-- ideation:section:self-hosting-detection -->

**Q1 — Self-hosting detection mechanism**

- **A)** Sentinel file `.furrow/SOURCE_REPO` committed in source — explicit, grep-able, survives clones.
- **B)** Check git remote URL against a known pattern.
- **C)** Env var `FURROW_SELF_HOSTED=1` set by a `bootstrap-source.sh` script.

**Lean: A** — zero ambiguity, works offline, visible in `ls`.

**Your answer:** Agreed

## <!-- write here -->

### <!-- ideation:section:artifact-quarantine -->

**Q2 — Install artifact location**

- **A)** `.furrow/install-state/` (under the Furrow umbrella, gitignored).
- **B)** `.local/furrow/` (neutral, matches XDG-ish expectations).
- **C)** Split: `.furrow/install-state/` for machine state, keep `.gitignore` additions as repo-tracked comment blocks for consumer repos.

**Lean: A** — keeps everything under `.furrow/`, one place to `rm -rf`.

**Your answer:** I feel like we should take the XDG, the repo keeps only project artifacts / local configs / anything necessary to know that furrow is installed, the .config folder keeps any common / repeated resources / global configs

---

### <!-- ideation:section:merge-conflict-reduction -->

**Q3 — seeds.jsonl + todos.yaml conflict reduction**

- **A)** Sort-by-id on write (both files); conflicts become rare line-order issues.
- **B)** Shard: `.furrow/seeds/seeds.d/{id}.json` and `.furrow/almanac/todos.d/{id}.yaml`. Near-zero conflicts. Bigger migration.
- **C)** Leave as-is, document as a `/furrow:merge` pre-check.

**Lean: A now, B as a follow-up TODO** — shard-per-id is correct long-term but risks scope blowup in this row.

**Your answer:** Agreed, but I worry this makes high level views / reading of these painful, jq is very useful for seeds for example

---

### <!-- ideation:section:global-config-tier -->

**Q4 — `~/.config/furrow/` contents**

- **A)** Minimal: cross-project defaults (`cross_model.provider`, preferred specialists, gate_policy default). Resolution: project → global → compiled-in.
- **B)** Full: global defaults + shared specialists directory + promotion-target registry.

**Lean: A** — TODO calls out effort=small; deeper structure belongs in Phase 2 (ambient promotion).

**Your answer:** Option B, I don't want to defer work here, I want to take an XDG approach to this

---

### <!-- ideation:section:merge-skill-scope -->

**Q5 — `/furrow:merge` command scope**

- **A)** Full land-and-reconcile: pre-merge audit → classify commits → auto-resolve protected files → `frw rescue` fallback → post-merge verify.
- **B)** Audit-only first (`/furrow:merge --audit`) that reports what a merge would do; manual merge; follow-up row wires auto-resolution.
- **C)** A but without auto-resolve — always produce a conflict resolution plan and let the user apply it.

**Lean: C** — full flow, but the human stays in the loop on resolution. Auto-overwrite of "protected files" sounds good until it isn't.

**Your answer:** Agreed, Option C

---

### <!-- ideation:section:reintegration-summary-format -->

**Q6 — Worktree reintegration summary**

- **A)** New file `.furrow/rows/{name}/reintegration.md` generated at worktree-complete; main session reads on `/furrow:merge`.
- **B)** Section in `summary.md`, keyed by marker — reuses existing plumbing.
- **C)** JSON artifact + rendered markdown for both agent and human consumption.

**Lean: B** — `summary.md` is already the handoff surface; adding a marker is cheap.

**Your answer:** Agreed

---

### <!-- ideation:section:deliverable-decomposition -->

**Q7 — Deliverable count / sequencing**

Roadmap estimates 5 sessions. Proposing 4 deliverables aligned with the 4 TODOs — implementation order:

1. **install-architecture-overhaul** (foundation — new boundary)
2. **config-cleanup** (sits on top of the new boundary)
3. **worktree-reintegration-summary** (unblocks #4)
4. **merge-process-skill** (consumes #1–#3)

**Lean: as above.** Alternative: fold #3 into #4 as a single deliverable. I think they're big enough to separate.

**Your answer:** Agreed to keep seperate

<!-- write here -->

---

## 4. Anything I Missed?

<!-- write here: new questions, concerns, constraints, or scope edits -->
