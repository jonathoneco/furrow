# Research: JSON Schema Discriminator Idiom

## Recommendation

Use **`allOf` of `if/then` pairs keyed on `const`** for both the `kind` and
`triggered_by.type` discriminators in `observations.schema.yaml`. Each branch is
`{if: {properties: {<tag>: {const: <value>}}, required: [<tag>]}, then: {<fields>}}`,
wrapped in an outer `allOf`. This idiom is:

- **Unambiguous to the validator** — only the matching branch's `then` runs,
  so a failure is reported as a concrete missing/invalid field (e.g. `Schema
  error at signal: 'signal' is a required property`), not as a meta-error like
  "is not valid under any of the given schemas".
- **Well-supported by the repo's pipeline** — `yq -o=json` plus Python
  `jsonschema.Draft202012Validator.iter_errors(...)` (see `bin/alm` lines
  844-881; fallback to `Draft7Validator`) handles `if/then/else` natively in
  both drafts.
- **Shorter in YAML** — no duplication of the `base` property set per branch,
  because the outer object carries the shared required fields and each branch
  adds only its variant-specific fields.

Keep `additionalProperties: false` on the outer object (and set it explicitly
on the nested `resolution` objects, which also differ between `watch` and
`decision-review`).

## Idiom comparison

| Dimension | `oneOf` with duplicated base | `allOf` of `if/then` on `const` |
|---|---|---|
| Error clarity on discriminator typo (e.g. `kind: watchh`) | Reports "is not valid under any of the given schemas" plus deprioritized sub-errors; `jsonschema` marks `oneOf` as a `WEAK_MATCH` so its children rank low | `if` fails silently (correct behavior), no `then` runs; root `enum` on `kind` catches the typo directly with a clear error |
| Error clarity on missing variant field (e.g. `kind: watch` without `signal`) | Validator tries every branch; surfaces N unrelated errors ("missing signal", "question is required", etc.); user must guess which branch was intended | Only the `watch` branch's `then` runs once `if` matches; single clean error "'signal' is a required property" |
| Python `jsonschema` `best_match()` behavior | Descends into weak-keyword context but returns the "deepest" error, which may be the wrong branch's leaf | Prefers strong-keyword errors from `then`/`required`/`properties` — matches intent |
| YAML verbosity | Each branch restates all shared fields (`id`, `created_at`, etc.) | Shared fields live once on the root; branches only list variant-specific additions |
| `additionalProperties: false` interaction | Works, but each `oneOf` branch must enumerate every allowed property (shared + variant) or the branch will reject valid instances | Works cleanly when the outer schema enumerates all properties (union of all variants) and each `then` only adds `required`; no per-branch `additionalProperties` needed |
| Spec support | Draft 2020-12 §10.2.1.3 (applicator) — standard | Draft 2020-12 §10.2.2 (`if`/`then`/`else`) — standard since draft-07 |
| Performance caveat (from json-schema.org) | "the nature of [oneOf] requires verification of every sub-schema which can lead to increased processing times" | `if` short-circuits: if `if` doesn't match, `then` is skipped |

The official `understanding-json-schema` conditionals page explicitly
recommends the `allOf`-of-`if/then` pattern for this use case: *"You can,
however, wrap pairs of `if` and `then` inside an `allOf` to create something
that would scale"* and notes *"`required` keyword is necessary in the `if`
schemas"* to prevent unintended application when the discriminator is absent.

## Repo precedent

Searched for discriminated-union idioms in existing schemas:

- `/home/jonco/src/furrow-post-ship-reexamination/adapters/shared/schemas/todos.schema.yaml` — flat object with `enum`-constrained fields (`source_type`, `urgency`, `status`); no variant-specific required fields (lines 48-58, 75-104).
- `/home/jonco/src/furrow-post-ship-reexamination/adapters/shared/schemas/definition.schema.yaml` — flat object; `gate_policy` and `mode` are plain `enum`s (lines 86-92). No `oneOf` / `anyOf` / `if` / `allOf` / `discriminator` usage anywhere.
- `/home/jonco/src/furrow-post-ship-reexamination/schemas/*.schema.json`, `/home/jonco/src/furrow-post-ship-reexamination/adapters/shared/schemas/*.schema.{json,yaml}` — `grep` for `oneOf|anyOf|if:|then:|else:|allOf|discriminator` across both directories returns **zero matches**.

**No existing precedent to mirror.** The `observations` schema will be the
first discriminated union in the repo; the choice sets the house style. The
recommendation aligns with the existing `enum`-heavy flat-object aesthetic:
the root lists every allowed property once, `enum` constrains the tag, and
`allOf` adds lightweight conditional `required` rules underneath.

## Validation pipeline compatibility

Confirmed by reading the actual validator (the task description mentioned
`bin/frw.d/scripts/validate-todos.sh`, which does not exist; the real
validator is `alm validate`):

- `/home/jonco/src/furrow-post-ship-reexamination/bin/alm` lines 827-890 implement `cmd_validate`. Pipeline:
  1. `yq -o=json '.' "$todos_path" > "$json_tmp"` (YAML -> JSON)
  2. `yq -o=json '.' "$SCHEMA_FILE" > "$schema_tmp"` (schema YAML -> JSON)
  3. Python script runs `jsonschema.Draft202012Validator(schema, format_checker=FormatChecker()).iter_errors(instance)`, falling back to `Draft7Validator` when 2020-12 is unavailable (lines 858-863).
  4. Errors printed as `Schema error at <path>: <message>`.
- `/home/jonco/src/furrow-post-ship-reexamination/bin/frw.d/scripts/validate-definition.sh` lines 36-56 uses the same `yq | python3 -c "... Draft7Validator ..."` shape for `definition.yaml`.

Both `if/then/else` and `oneOf` are supported in **Draft 7** and **Draft
2020-12**, so either idiom works with the fallback path. `if/then/else` was
added in draft-07 and has been in every draft since — no risk of drift if
the Python env only has older `jsonschema` installed (the 4.x wheel supports
2020-12; the minimum 3.x supports draft-07).

`yq` emits JSON that preserves the YAML structure faithfully; there is no
known `yq`-specific issue with nested `allOf`/`if`/`then` keys. Test will be:
a single fixture with `kind: watch` missing `signal` should produce exactly
one `Schema error at signal: ...` line, not a cascade.

## Risks / edge cases

1. **Forgetting `required: [kind]` inside the `if` schema.** If the `if` block
   is only `{properties: {kind: {const: watch}}}`, then an instance with no
   `kind` at all vacuously matches (all instances satisfy `properties` when
   the key is absent), and `then` fires incorrectly. Every branch's `if` must
   include `required: [kind]`. Same for `triggered_by.type`.
2. **`additionalProperties: false` at root must enumerate every variant's
   fields.** The union of watch's and decision-review's properties must all
   appear in the root `properties` block, otherwise a valid `decision-review`
   instance will be rejected for having a `question` property the root
   doesn't know about. This is the main cost of the pattern — but it's a
   one-time write, not a per-branch repetition.
3. **Nested `resolution` shape differs between `kind`s.** Model as a
   discriminator-dependent sub-schema inside each `then`: `watch`'s
   `then` sets `properties: {resolution: {<outcome-shape>}}` and
   `decision-review`'s `then` sets the `{option_id, rationale}` shape. Do
   **not** put a single `resolution` schema at root; that would force one
   shape to subsume the other.
4. **`Draft7Validator` fallback path** — draft-07 `if/then/else` semantics
   are identical to 2020-12 for this use; no behavioral risk. Only `$defs`
   (vs. `definitions`) and `$dynamicRef` differ, and we use neither.
5. **`best_match` inversion for `oneOf`.** If someone later refactors to
   `oneOf`, the Python library's "weak match" treatment will cascade
   less-useful errors into CLI output. The `allOf`/`if` idiom avoids this
   trap entirely.
6. **Integer constraint for `rows_since.count`.** Use `type: integer,
   minimum: 1` inside the `rows_since` branch's `then`. `yq` will emit
   integers as JSON numbers; `jsonschema`'s `integer` keyword accepts them.

## Sources Consulted

- [primary] — https://json-schema.org/understanding-json-schema/reference/conditionals — Normative behavior of `if`/`then`/`else`: *"If `if` is valid, `then` must also be valid (and `else` is ignored.) If `if` is invalid, `else` must also be valid (and `then` is ignored)."* Explicit recommendation to `allOf`-wrap `if/then` pairs for discriminated unions and to include `required` in the `if` schema.
- [primary] — https://json-schema.org/understanding-json-schema/reference/combining — `oneOf` semantics: *"valid against exactly one of the given subschemas"* plus perf caveat *"the nature of it requires verification of every sub-schema which can lead to increased processing times."*
- [primary] — https://json-schema.org/draft/2020-12/json-schema-core — Confirms both `oneOf` and `if`/`then`/`else` live in §10.2 Applicator keywords in draft 2020-12 (detail truncated by fetch; normative support confirmed).
- [secondary] — https://github.com/python-jsonschema/jsonschema/blob/main/jsonschema/exceptions.py — Shows `oneOf` is in `WEAK_MATCHES`; `best_match()` deprioritizes its sub-errors and inverts descent, which means `oneOf` failures produce worse CLI output than `if/then` failures in the exact pipeline this repo uses.
- [tertiary] — `/home/jonco/src/furrow-post-ship-reexamination/bin/alm` lines 827-890 — Actual `alm validate` implementation; confirms `yq | python3 jsonschema Draft202012Validator (fallback Draft7Validator) + FormatChecker + iter_errors` pipeline.
- [tertiary] — `/home/jonco/src/furrow-post-ship-reexamination/bin/frw.d/scripts/validate-definition.sh` lines 29-62 — Confirms the same pipeline shape for `definition.yaml`, using `Draft7Validator`.
- [tertiary] — `/home/jonco/src/furrow-post-ship-reexamination/adapters/shared/schemas/{todos,definition}.schema.yaml` — Repo style precedent: flat objects, `enum` constraints, `additionalProperties: false`. No existing `oneOf`/`if` usage.
