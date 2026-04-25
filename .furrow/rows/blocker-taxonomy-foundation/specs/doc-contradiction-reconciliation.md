# Spec: doc-contradiction-reconciliation

> See `specs/shared-contracts.md` for cross-cutting decisions; that document overrides any conflicting detail here.

Row: `blocker-taxonomy-foundation`
Wave: 1 (parallel with D1)
Specialist: documentation-generator:technical-writer
Date: 2026-04-25

---

## Interface Contract

This deliverable produces four inline doc amendments — no new files, no
structural changes to the documents touched. Each amendment is a short
reconciliation note inserted at a fixed location within an existing section.
The four documents and their insertion contracts follow.

---

### Document 1: `docs/architecture/pi-almanac-operating-model.md`

**Insertion site**: immediately after line 156 (the end of the bullet list under
`## Seeds replace TODOs`), before the existing prose `todos.yaml may remain
temporarily only as migration compatibility...` at line 158.

**Before** (lines 148-159, verbatim from research Section D.1):

```
148  ## Seed-backed planning model
149
150  ## Seeds replace TODOs
151
152  Furrow should converge to **A1**:
153  - seeds replace TODOs as the canonical planning primitive
154  - `todos.yaml` is retired rather than preserved as a permanent parallel system
155  - roadmap and triage read from the seed graph
156  - almanac stops being the canonical task registry
157
158  `todos.yaml` may remain temporarily only as migration compatibility, but Pi
159  should not be designed around it as the long-term model.
```

**After** (amendment in place — insert between line 156 and line 158):

```
148  ## Seed-backed planning model

150  ## Seeds replace TODOs

152  Furrow should converge to **A1**:
153  - seeds replace TODOs as the canonical planning primitive
154  - `todos.yaml` is retired rather than preserved as a permanent parallel system
155  - roadmap and triage read from the seed graph
156  - almanac stops being the canonical task registry

     > **Transitional authority rule (authoritative until Phase 5 cutover)**:
     > `todos.yaml` remains the authoritative planning registry until the Phase 5
     > seed cutover. Rows MUST read TODOs and MAY consult seeds; rows MUST NOT
     > operate seeds-only. The "seeds replace TODOs" target above describes the
     > post-cutover end state, not the current authority. See "Sequencing" below
     > for the cutover gate.

158  `todos.yaml` may remain temporarily only as migration compatibility, but Pi
159  should not be designed around it as the long-term model.
```

**Insertion type**: amendment in place (blockquote injected between existing
lines 156 and 158).

**Word-count budget**: 4 sentences, ~60 words. Stay within that budget.

---

### Document 2: `docs/architecture/migration-stance.md`

**Insertion site**: immediately after line 89 (end of the
`### 7. Shared semantics across hosts remain real` body), before the
`## Non-invariants` heading at line 91.

**Before** (lines 86-91, verbatim from research Section D.2):

```
86  ### 7. Shared semantics across hosts remain real
87
88  Pi and Claude-compatible flows do not need identical UX, but they should not
89  silently diverge on canonical workflow semantics.
90
91  ## Non-invariants
```

**After** (amendment in place — insert between line 89 and line 91):

```
86  ### 7. Shared semantics across hosts remain real

88  Pi and Claude-compatible flows do not need identical UX, but they should not
89  silently diverge on canonical workflow semantics.

     > **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**:
     > the asymmetry where Pi-side blocker codes were canonically enumerated in
     > `pi-step-ceremony-and-artifact-enforcement.md` while Claude-side
     > enforcement was undefined is closed by deliverables
     > `canonical-blocker-taxonomy` + `normalized-blocker-event-and-go-emission-path`
     > + `hook-migration-and-quality-audit` + `coverage-and-parity-tests` of that
     > row. The durable anti-drift mechanism is
     > `tests/integration/test-blocker-parity.sh`, which fails CI when the two
     > adapters produce non-identical canonical envelopes for any migrated code.
     > (Forward citation: `tests/integration/test-blocker-parity.sh` is authored
     > by deliverable `coverage-and-parity-tests` in Wave 4 of this row and does
     > not exist until that deliverable lands.)

91  ## Non-invariants
```

**Insertion type**: amendment in place (blockquote injected between line 89
and line 91).

**Word-count budget**: 5 sentences including the forward-citation parenthetical,
~80 words.

---

### Document 3: `docs/architecture/go-cli-contract.md`

**Insertion site**: immediately after line 399 (end of the "still does NOT
enforce" bullet list), before `Current exit behavior:` at line 401.

**Corrected citation note**: the source TODO cites `go-cli-contract.md:385-388`
for the "does NOT enforce" passage. Lines 385-388 are the *does-enforce* list.
The actual "does NOT enforce" block is **lines 392-399**. This spec uses
the corrected range throughout.

**Before** (lines 392-404, verbatim from research Section D.3):

```
392  It still does **not** enforce:
393
394  - evaluator-grade semantic validation or full gate-engine parity
395  - full gate-policy enforcement beyond adapter-driven supervised confirmation
396  - summary regeneration
397  - conditional/fail outcomes
398  - broader review orchestration behavior
399  - richer merge/archive ceremony beyond the narrow archive checkpoint path
400
401  Current exit behavior:
402
403  - `0` success
404  - `1` usage error
```

**After** (amendment in place — insert between line 399 and line 401):

```
392  It still does **not** enforce:

394  - evaluator-grade semantic validation or full gate-engine parity
395  - full gate-policy enforcement beyond adapter-driven supervised confirmation
396  - summary regeneration
397  - conditional/fail outcomes
398  - broader review orchestration behavior
399  - richer merge/archive ceremony beyond the narrow archive checkpoint path

     > **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**:
     > there is currently scope ambiguity between the not-enforced list above and
     > `pi-step-ceremony-and-artifact-enforcement.md:374-388`, which describes
     > per-step artifact validation, decompose-artifact validation, and
     > review-artifact validation as enforced preconditions. The boundary between
     > "narrow blocker baseline" (this contract) and "per-step artifact
     > validation" (Pi-step-ceremony doc) is deferred to TODO
     > `artifact-validation-per-step-schema` (`.furrow/almanac/todos.yaml`),
     > which will define `schemas/step-artifact-requirements.yaml` and bind both
     > documents to a single authoritative spec. Until that TODO closes, treat
     > per-step artifact validation as in-scope for the backend and
     > `pi-step-ceremony-and-artifact-enforcement.md:374-388` as the operative
     > description.

401  Current exit behavior:
```

**Insertion type**: amendment in place (blockquote injected between line 399
and line 401).

**Word-count budget**: 4 sentences, ~90 words.

---

### Document 4: `docs/architecture/documentation-authority-taxonomy.md`

**Insertion site**: append a new subsection `### 5. Contract-doc precedence rule`
immediately before the `## Documentation policy for the current migration`
section (currently line 241). This is additive — existing taxonomy sections
are not restructured or renumbered.

**Before** (lines 239-247, verbatim from file):

```
239
240
241  ## Documentation policy for the current migration
242
243  - keep canonical system truths in canonical docs
244  - keep transitional migration strategy in migration docs
245  - keep row/slice truth in row artifacts and handoffs
246  - keep sequencing in roadmap/todos
247  - when a doc mixes classes, either split it or add clearly bounded sections
```

**After** (new subsection inserted before `## Documentation policy`):

```
     ### 5. Contract-doc precedence rule

     **Anti-pattern**: a target-state or implementation-state document states a
     scope that exceeds the scope declared in the contract document covering the
     same surface, with no explicit temporal qualifier or precedence rule
     reconciling them. The contract document appears narrower but the sibling
     document's broader claim is never invalidated.

     **Examples in this codebase**:
     - `pi-almanac-operating-model.md` states "seeds replace TODOs as the
       canonical planning primitive" (forward-leaning target) without temporal
       qualification, conflicting with the Phase 5 deferral in the same file.
     - `pi-step-ceremony-and-artifact-enforcement.md:374-388` claims per-step
       artifact validation is enforced; `go-cli-contract.md:392-399` lists those
       behaviors as not-yet-enforced without a reconciling precedence rule.

     **Precedence rule**: when scope language in a target-state or
     implementation-state document conflicts with scope language in a contract
     document, the contract document wins. The broader claim in the sibling
     document must add an explicit temporal qualifier (date, phase, or TODO
     closure condition) before it supersedes the contract. Until that qualifier
     is present, assume the narrower contract scope is operative.

241  ## Documentation policy for the current migration
```

**Insertion type**: new subsection added to the `## Anti-patterns to avoid`
section (which runs through line 239 before this insertion), numbered `5`
to follow the existing patterns 1-4. Do not renumber existing anti-patterns.

**Word-count budget**: ~130 words. Keep the anti-pattern description and the
two examples concrete; the precedence rule needs one unambiguous sentence.

---

## Acceptance Criteria (Refined)

### AC.1 — Contradiction (1): seed-timing transitional rule

**Section amended**: `docs/architecture/pi-almanac-operating-model.md`,
within `## Seeds replace TODOs`, between the A1 bullet list and the
`todos.yaml may remain temporarily` sentence.

**Reconciliation wording** (final, ready to insert):

```
> **Transitional authority rule (authoritative until Phase 5 cutover)**:
> `todos.yaml` remains the authoritative planning registry until the Phase 5
> seed cutover. Rows MUST read TODOs and MAY consult seeds; rows MUST NOT
> operate seeds-only. The "seeds replace TODOs" target above describes the
> post-cutover end state, not the current authority. See "Sequencing" below
> for the cutover gate.
```

**Testable condition**: the amended file contains the string
`todos.yaml` remains the authoritative planning registry until the Phase 5`
in the section preceding `todos.yaml may remain temporarily`.

**Verification grep**:
```sh
grep -n "todos.yaml remains the authoritative planning registry" \
  docs/architecture/pi-almanac-operating-model.md
```
Expected: one match, on a line that precedes the `todos.yaml may remain
temporarily` line.

---

### AC.2 — Contradiction (2): blocker-enforcement split

**Section amended**: `docs/architecture/migration-stance.md`,
`### 7. Shared semantics across hosts remain real`, between line 89 and the
`## Non-invariants` heading.

**Reconciliation wording** (final, ready to insert):

```
> **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**:
> the asymmetry where Pi-side blocker codes were canonically enumerated in
> `pi-step-ceremony-and-artifact-enforcement.md` while Claude-side
> enforcement was undefined is closed by deliverables
> `canonical-blocker-taxonomy` + `normalized-blocker-event-and-go-emission-path`
> + `hook-migration-and-quality-audit` + `coverage-and-parity-tests` of that
> row. The durable anti-drift mechanism is
> `tests/integration/test-blocker-parity.sh`, which fails CI when the two
> adapters produce non-identical canonical envelopes for any migrated code.
> (Forward citation: `tests/integration/test-blocker-parity.sh` is authored
> by deliverable `coverage-and-parity-tests` in Wave 4 of this row and does
> not exist until that deliverable lands.)
```

**Testable condition**: the amended file contains both the reconciliation
date string and the forward-citation parenthetical within section 7.

**Verification grep**:
```sh
grep -n "test-blocker-parity.sh" docs/architecture/migration-stance.md
```
Expected: two matches — one citing the test as the anti-drift mechanism,
one as the forward-citation note.

```sh
grep -n "Forward citation" docs/architecture/migration-stance.md
```
Expected: one match confirming the forward-reference note is present.

---

### AC.3 — Contradiction (3): artifact-validation scope deferral

**Section amended**: `docs/architecture/go-cli-contract.md`, immediately
after line 399 (end of the "still does NOT enforce" bullet list), before
`Current exit behavior:`.

**Corrected line range**: the contradicting passage is lines 392-399
("It still does not enforce"), NOT lines 385-388 (those are the does-enforce
list). The reconciliation note is inserted after 399.

**Reconciliation wording** (final, ready to insert):

```
> **Reconciliation note (2026-04-25, row `blocker-taxonomy-foundation`)**:
> there is currently scope ambiguity between the not-enforced list above and
> `pi-step-ceremony-and-artifact-enforcement.md:374-388`, which describes
> per-step artifact validation, decompose-artifact validation, and
> review-artifact validation as enforced preconditions. The boundary between
> "narrow blocker baseline" (this contract) and "per-step artifact
> validation" (Pi-step-ceremony doc) is deferred to TODO
> `artifact-validation-per-step-schema` (`.furrow/almanac/todos.yaml`),
> which will define `schemas/step-artifact-requirements.yaml` and bind both
> documents to a single authoritative spec. Until that TODO closes, treat
> per-step artifact validation as in-scope for the backend and
> `pi-step-ceremony-and-artifact-enforcement.md:374-388` as the operative
> description.
```

**Testable conditions**:
1. The amended file contains the deferral date `2026-04-25`.
2. The amended file contains the TODO name `artifact-validation-per-step-schema`.
3. The note appears between the end of the "does NOT enforce" bullet list and
   the `Current exit behavior:` heading.
4. `pi-step-ceremony-and-artifact-enforcement.md` is NOT modified (owned by D1).

**Verification greps**:
```sh
grep -n "artifact-validation-per-step-schema" \
  docs/architecture/go-cli-contract.md
```
Expected: one match, on a line after line 399.

```sh
grep -n "2026-04-25" docs/architecture/go-cli-contract.md
```
Expected: one match within the reconciliation note.

```sh
grep -n "Reconciliation note" \
  docs/architecture/pi-step-ceremony-and-artifact-enforcement.md
```
Expected: zero matches (D5 does not touch this file).

---

### AC.4 — Meta-pattern: contract-doc precedence rule

**Section amended**: `docs/architecture/documentation-authority-taxonomy.md`,
new subsection `### 5. Contract-doc precedence rule` inserted before
`## Documentation policy for the current migration`.

**Testable conditions**:
1. The file contains the string `Contract-doc precedence rule`.
2. The file contains the precedence rule sentence asserting contract docs win.
3. Both contradictions (1) and (3) are named as examples.
4. Existing anti-patterns `### 1` through `### 4` are unchanged.
5. The existing `## Documentation policy for the current migration` section
   still exists and is immediately after the new subsection.

**Verification greps**:
```sh
grep -n "Contract-doc precedence rule" \
  docs/architecture/documentation-authority-taxonomy.md
```
Expected: one match (the new subsection heading).

```sh
grep -n "contract document wins" \
  docs/architecture/documentation-authority-taxonomy.md
```
Expected: one match (the precedence rule sentence).

---

## Test Scenarios

### Scenario (a): contradiction-1-transitional-rule-exists

- **Verifies**: AC.1
- **WHEN**: `docs/architecture/pi-almanac-operating-model.md` has been amended
  per this spec.
- **THEN**: the phrase `todos.yaml remains the authoritative planning registry`
  appears in the file, and it appears on a line that precedes the line
  containing `todos.yaml may remain temporarily only as migration compatibility`.
- **Verification**:
  ```sh
  file=docs/architecture/pi-almanac-operating-model.md
  auth_line=$(grep -n "todos.yaml remains the authoritative planning registry" \
    "$file" | cut -d: -f1)
  compat_line=$(grep -n "todos.yaml may remain temporarily only as migration" \
    "$file" | cut -d: -f1)
  [ -n "$auth_line" ] && [ -n "$compat_line" ] && \
    [ "$auth_line" -lt "$compat_line" ] && echo PASS || echo FAIL
  ```
  Additionally verify the wording contains both the MUST/MAY operator
  directives and the "post-cutover end state, not the current authority"
  qualification:
  ```sh
  grep -q "rows MUST read TODOs and MAY consult seeds" "$file" && echo PASS || echo FAIL
  grep -q "post-cutover end state, not the current authority" "$file" && echo PASS || echo FAIL
  ```

---

### Scenario (b): contradiction-2-blocker-split-closed-with-forward-citation

- **Verifies**: AC.2
- **WHEN**: `docs/architecture/migration-stance.md` has been amended per this
  spec.
- **THEN**: the reconciliation note appears within section 7, cites all four
  deliverable names, names `tests/integration/test-blocker-parity.sh` as the
  anti-drift mechanism, and includes the forward-citation parenthetical.
- **Verification**:
  ```sh
  file=docs/architecture/migration-stance.md
  # Reconciliation note present
  grep -q "blocker-taxonomy-foundation" "$file" && echo PASS || echo FAIL
  # All four deliverables cited
  grep -q "canonical-blocker-taxonomy" "$file" && echo PASS || echo FAIL
  grep -q "normalized-blocker-event-and-go-emission-path" "$file" && echo PASS || echo FAIL
  grep -q "hook-migration-and-quality-audit" "$file" && echo PASS || echo FAIL
  grep -q "coverage-and-parity-tests" "$file" && echo PASS || echo FAIL
  # Parity test path cited
  grep -q "tests/integration/test-blocker-parity.sh" "$file" && echo PASS || echo FAIL
  # Forward citation present (two occurrences of the test path)
  count=$(grep -c "test-blocker-parity.sh" "$file")
  [ "$count" -ge 2 ] && echo PASS || echo FAIL
  # Forward-citation note present
  grep -q "Forward citation" "$file" && echo PASS || echo FAIL
  # Forward-citation note mentions Wave 4
  grep -q "Wave 4" "$file" && echo PASS || echo FAIL
  ```

---

### Scenario (c): contradiction-3-artifact-validation-deferral-in-corrected-range

- **Verifies**: AC.3
- **WHEN**: `docs/architecture/go-cli-contract.md` has been amended per this
  spec.
- **THEN**: the reconciliation note appears after the "still does NOT enforce"
  bullet list (at the corrected range 392-399) and before `Current exit
  behavior:`, contains the deferral date `2026-04-25`, names the TODO
  `artifact-validation-per-step-schema`, and references the Pi-step-ceremony
  doc at lines 374-388.
- **Verification**:
  ```sh
  file=docs/architecture/go-cli-contract.md
  # Deferral date
  grep -q "2026-04-25" "$file" && echo PASS || echo FAIL
  # Named TODO
  grep -q "artifact-validation-per-step-schema" "$file" && echo PASS || echo FAIL
  # Pi-step-ceremony line reference
  grep -q "pi-step-ceremony-and-artifact-enforcement.md:374-388" "$file" && echo PASS || echo FAIL
  # Note appears before "Current exit behavior:"
  note_line=$(grep -n "artifact-validation-per-step-schema" "$file" | cut -d: -f1)
  exit_line=$(grep -n "Current exit behavior:" "$file" | cut -d: -f1)
  [ -n "$note_line" ] && [ -n "$exit_line" ] && \
    [ "$note_line" -lt "$exit_line" ] && echo PASS || echo FAIL
  # Note appears after the "does NOT enforce" list (after line 392)
  [ "$note_line" -gt 399 ] && echo PASS || echo "FAIL (note appeared before line 399)"
  ```

---

### Scenario (d): meta-pattern-note-added-to-taxonomy

- **Verifies**: AC.4
- **WHEN**: `docs/architecture/documentation-authority-taxonomy.md` has been
  amended per this spec.
- **THEN**: the file contains a new `### 5. Contract-doc precedence rule`
  subsection with the anti-pattern description, both concrete examples, and
  the precedence rule; existing anti-patterns 1-4 are present and unchanged.
- **Verification**:
  ```sh
  file=docs/architecture/documentation-authority-taxonomy.md
  # New subsection heading
  grep -q "Contract-doc precedence rule" "$file" && echo PASS || echo FAIL
  # Precedence rule sentence
  grep -q "contract document wins" "$file" && echo PASS || echo FAIL
  # Example 1 (contradiction 1) cited
  grep -q "pi-almanac-operating-model.md" "$file" && echo PASS || echo FAIL
  # Example 3 (contradiction 3) cited
  grep -q "go-cli-contract.md:392-399" "$file" && echo PASS || echo FAIL
  # Existing anti-patterns 1-4 still present
  grep -q "### 1. Architecture docs as migration diaries" "$file" && echo PASS || echo FAIL
  grep -q "### 2. Row handoffs as de facto architecture" "$file" && echo PASS || echo FAIL
  grep -q "### 3. Planning docs defining semantics" "$file" && echo PASS || echo FAIL
  grep -q "### 4. Migration tactics presented as timeless philosophy" "$file" && echo PASS || echo FAIL
  # Policy section still follows
  grep -q "## Documentation policy for the current migration" "$file" && echo PASS || echo FAIL
  ```

---

### Scenario (e): pi-step-ceremony-doc-not-modified

- **Verifies**: D5 `file_ownership` boundary (D1 owns that doc; D5 does not).
- **WHEN**: all D5 amendments have been applied.
- **THEN**: `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`
  has no D5-sourced additions — specifically no `Reconciliation note` blockquote
  and no `artifact-validation-per-step-schema` string.
- **Verification**:
  ```sh
  file=docs/architecture/pi-step-ceremony-and-artifact-enforcement.md
  grep -q "Reconciliation note" "$file" && echo FAIL || echo PASS
  grep -q "artifact-validation-per-step-schema" "$file" && echo FAIL || echo PASS
  ```
  Both commands must print `PASS`.

---

## Implementation Notes

### Edit order

Apply edits in dependency-independent order. All four are independent; the
recommended sequence minimises re-reading:

1. `pi-almanac-operating-model.md` (contradiction 1 — simplest insertion, no
   forward citations, no line-number corrections needed).
2. `migration-stance.md` (contradiction 2 — include forward-citation
   parenthetical in the same edit pass; do not return to this file).
3. `go-cli-contract.md` (contradiction 3 — use corrected range 392-399, NOT
   385-388 as the source TODO cited; insert after line 399).
4. `documentation-authority-taxonomy.md` (meta-pattern — additive only;
   insert the new `### 5` subsection before `## Documentation policy`; do not
   reorder or renumber existing content).

### Verbatim source passages

Use the passages quoted in
`research/test-infra-and-contradiction-passages.md` Section D as the ground
truth for the existing text to match before each insertion. Do not rely on
line numbers alone — verify the surrounding prose matches the verbatim
excerpts in that document before applying the Edit tool.

Key passages to anchor each edit:

- **Edit 1 anchor**: `almanac stops being the canonical task registry` (end
  of the A1 bullet list at original line 156). Insert the transitional-authority
  blockquote immediately after this line.
- **Edit 2 anchor**: `silently diverge on canonical workflow semantics.`
  (original line 89). Insert the blocker-split reconciliation blockquote
  immediately after this sentence, before `## Non-invariants`.
- **Edit 3 anchor**: `richer merge/archive ceremony beyond the narrow archive
  checkpoint path` (original line 399, last bullet in the does-NOT-enforce
  list). Insert the artifact-validation deferral blockquote immediately after
  this line, before `Current exit behavior:`.
- **Edit 4 anchor**: the end of `### 4. Migration tactics presented as timeless
  philosophy` (currently the last anti-pattern subsection before
  `## Documentation policy for the current migration`). Insert the new
  `### 5. Contract-doc precedence rule` subsection here.

### Forward-citation handling

The reconciliation note for contradiction (2) cites
`tests/integration/test-blocker-parity.sh`. That file does not exist until
Wave 4 (deliverable `coverage-and-parity-tests`) lands. The note must include
the parenthetical:

> (Forward citation: `tests/integration/test-blocker-parity.sh` is authored
> by deliverable `coverage-and-parity-tests` in Wave 4 of this row and does
> not exist until that deliverable lands.)

This parenthetical is part of the reconciliation wording — it is not a comment
to be removed later. A mid-row reader who finds the note before Wave 4 lands
will see why the file is missing. Do not omit it on the grounds that the note
becomes redundant after Wave 4; it provides audit trail.

### Scope constraint enforcement

- D5 does NOT own `docs/architecture/pi-step-ceremony-and-artifact-enforcement.md`.
  That file is owned by D1 (`canonical-blocker-taxonomy`). No edit to that
  file in this deliverable, not even a symmetric reconciliation note.
- D5 does NOT own `.furrow/almanac/todos.yaml`. The off-by-N line citation
  in the source TODO (`385-388` vs the correct `392-399`) is documented in
  `research/test-infra-and-contradiction-passages.md` Section D.3 as a
  research-step finding. Do not "correct" the TODO text.
- The meta-pattern note in `documentation-authority-taxonomy.md` is additive.
  Do not restructure the existing four anti-patterns, rename headings, or add
  any content beyond the single new subsection specified here.

### Citation correction summary

The source TODO (`.furrow/almanac/todos.yaml:3824-3840`) cites
`go-cli-contract.md:385-388` as the "does NOT enforce X" passage. As verified
in `research/test-infra-and-contradiction-passages.md` Section D.3:

- Lines 385-388 are the **does-enforce** list (`step_status=completed` required,
  current-step artifact presence, scaffold detection, backend structural
  validation).
- Lines **392-399** are the **does-NOT-enforce** list ("evaluator-grade
  semantic validation", "full gate-policy enforcement", "conditional/fail
  outcomes", etc.).

All references to contradiction (3) in this spec use the corrected range
392-399. The implement step must insert the reconciliation note after line 399,
not after line 388.

---

## Dependencies

None. D5 is a Wave 1 deliverable running in parallel with D1. It has no
dependency on D1, D2, D3, or D4.

- D5 does not depend on the taxonomy changes in D1 (different files, no shared
  state).
- D5 does not depend on the Go emission path in D2.
- D5 does not depend on the hook migration in D3.
- D5 does not depend on the parity tests in D4 (it cites the parity test path
  as a forward citation precisely because that file does not yet exist when D5
  runs).

All four documents touched by D5 exist in the current worktree and can be
amended without waiting for any other deliverable to complete.
