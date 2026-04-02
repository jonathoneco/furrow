# Spec: test-check-artifacts

## File
`tests/integration/test-check-artifacts.sh`

## Fixture Requirements
- `.work/{name}/state.json` with mode and base_commit
- `.work/{name}/definition.yaml` with deliverable and acceptance_criteria
- `.work/{name}/plan.json` with file_ownership globs (for code mode)
- Real git repo in temp dir (git init, commits) for code mode tests
- `.work/{name}/deliverables/` directory for research mode tests

## Test Cases

### test_code_mode_owned_files_changed
- git repo with base commit, then add files matching glob
- state: mode="code", base_commit set
- plan: deliverable owns `src/*.sh`
- Git diff shows `src/foo.sh` changed
- Expected: exit 0, reviews/phase-a-results.json verdict="pass"

### test_code_mode_no_owned_files
- git repo with base commit, no changes matching glob
- Expected: exit 1, verdict="fail", artifacts_present=false

### test_research_mode_non_empty
- state: mode="research"
- Create `deliverables/findings.md` with content
- Expected: exit 0, verdict="pass"

### test_research_mode_empty
- state: mode="research"
- Create `deliverables/` dir but empty (or only empty files)
- Expected: exit 1, verdict="fail"

### test_missing_base_commit
- state: mode="code", base_commit=null
- Expected: exit 1, verdict="fail"
