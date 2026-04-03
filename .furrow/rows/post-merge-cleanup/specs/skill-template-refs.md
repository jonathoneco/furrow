# Spec: skill-template-refs

## Problem
skills/plan.md tells agents to produce plan.json but doesn't reference templates/plan.json. Agents guess at the schema and get rejected by rws validation.

## Change
Add to skills/plan.md after line 8:
```
  Use `templates/plan.json` as the schema reference for plan.json structure.
```

Check other step skills for similar gaps — any that produce templated artifacts should reference their template.

## AC
- skills/plan.md references templates/plan.json for schema
- Any other step skills with templated artifacts also reference their templates
