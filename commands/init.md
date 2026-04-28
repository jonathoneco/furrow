# /furrow init [--prefix <name>]

Initialize Furrow in the current project. Called automatically by `/work` when needed.

## Implementation

Go `furrow init` is reserved and unimplemented. This slash command currently
uses the legacy `frw init` compatibility wrapper and reports the results.

```sh
frw init [--prefix <name>]
```

Report each line of output to the user. If `frw init` exits non-zero, stop and surface the error.

## Detection

The project needs initialization if any of these are true:
- `.furrow/seeds/seeds.jsonl` does not exist (sds not initialized)
- `.furrow/furrow.yaml` does not exist (no project config)

## What it does

1. **Seeds**: If `.furrow/seeds/seeds.jsonl` does not exist:
   - Derive prefix from directory name (lowercase, non-alphanumeric → dash).
   - Run the legacy compatibility wrapper `sds init --prefix "{prefix}"`.

2. **Config**: If `.furrow/furrow.yaml` does not exist:
   - Detect stack from project files:
     - `go.mod` → language: go
     - `package.json` → language: typescript
     - `pyproject.toml` / `requirements.txt` → language: python
   - Detect repo from `git remote get-url origin` (extract `owner/repo`).
   - Copy template from Furrow install path, fill in detected values.
   - Tell user to review and fill in remaining fields.

3. **Almanac**: If `.furrow/almanac/` does not exist:
   - `mkdir -p .furrow/almanac`

4. **Rows**: If `.furrow/rows/` does not exist:
   - `mkdir -p .furrow/rows`

5. Report what was created. Do not create a row — that's `/work`'s job.
