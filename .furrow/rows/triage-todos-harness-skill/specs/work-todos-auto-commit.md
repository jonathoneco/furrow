# Spec: work-todos-auto-commit

- **Deliverable**: Auto-commit step in `commands/work-todos.md`
- **Specialist**: harness-engineer

## Change

Add a commit step after the existing step 8 (Validate) in both modes.

### Extract Mode

After step 8 (Validate), before step 9 (Report), insert:

```markdown
### 9. Commit

Stage and commit the updated todos.yaml:

```
git add todos.yaml
git commit -m "chore: extract TODOs from {name} into todos.yaml"
```

Where `{name}` is the source work unit name.
```

### New Mode

After step 5 (Validate), before step 6 (Report), insert:

```markdown
### 6. Commit

Stage and commit the updated todos.yaml:

```
git add todos.yaml
git commit -m "chore: add TODO {id} to todos.yaml"
```

Where `{id}` is the generated TODO slug.
```

### Renumber subsequent steps

- Extract mode: current step 9 (Report) becomes step 10
- New mode: current step 6 (Report) becomes step 7

## Acceptance Criteria Verification

- [x] `commands/work-todos.md` gains auto-commit step after successful write
- [x] Commits todos.yaml with conventional commit message
- [x] Matches the commit pattern used in `/harness:triage`
