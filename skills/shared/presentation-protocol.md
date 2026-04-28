---
layer: shared
---

# Presentation Protocol

Artifact content presented in conversation must use explicit section markers:

```md
<!-- {phase}:section:{name} -->
```

Use lowercase phase names (`ideate`, `research`, `plan`, `spec`, `decompose`,
`implement`, `review`, or `presentation`) and stable kebab-case section names.

Do not paste full canonical row artifacts into conversation without markers.
When a user-facing summary needs artifact content, present only the relevant
sections, each preceded by a marker. Refer to artifact paths as supporting
references after the marked section rather than as a substitute for the section.

Furrow backend scanners consume normalized presentation text. Runtime adapters
own runtime-specific extraction:

- Claude adapters read Stop-hook transcript payloads and pass the final
  assistant text to `furrow presentation scan`.
- Pi adapters should pass the message text they are about to display to the
  same normalized command when a comparable presentation lifecycle event exists.

Engine-layer output is not user presentation. Engines return evidence to the
driver/operator boundary; the operator is responsible for final user-facing
presentation under this protocol.
