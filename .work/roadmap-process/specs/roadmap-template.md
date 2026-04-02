# Spec: roadmap-template

## Interface Contract
- **Input**: None (creates new files)
- **Output**: `templates/roadmap.md.tmpl` + `templates/roadmap-sections.yaml`
- **Consumers**: `/work-roadmap` command reads both to structure its output

## File 1: templates/roadmap-sections.yaml

Section registry defining what ROADMAP.md contains:

```yaml
# roadmap-sections.yaml — Section registry for ROADMAP.md generation
# Defines section order, requirements, and rendering hints for /work-roadmap

sections:
  - name: header
    required: true
    order: 1
    description: "Title, updated date, overall phase status"

  - name: dependency-dag
    required: true
    order: 2
    description: "ASCII dependency graph showing TODO relationships and phases"

  - name: legend
    required: false
    order: 3
    description: "Notation key for DAG symbols"

  - name: conflict-zones
    required: false
    order: 4
    description: "Table of file overlap zones between TODOs in same phase"

  - name: phase
    required: true
    order: 5
    repeating: true
    description: "Per-phase section with tracks, branches, files, conflict analysis, rationale"

  - name: worktree-commands
    required: true
    order: 6
    description: "Shell commands for launching parallel worktrees per phase"
```

## File 2: templates/roadmap.md.tmpl

Markdown template with section markers. Claude reads this to understand expected structure, then generates content section by section.

```markdown
# Roadmap

> Last updated: {date} | {status_summary}

<!-- section:dependency-dag -->
## Dependency DAG (active items only)

{dag_content}

Legend: `──` hard dependency · `···` independent (no dependency) · `[terminal]` = end of chain

<!-- section:conflict-zones -->
## File Conflict Zones

| Zone | Files | TODOs affected |
|------|-------|----------------|
{conflict_rows}

<!-- section:phase -->
## Phase {phase_number} — {phase_title} — {phase_status}

{phase_rationale}

{phase_tracks}

<!-- section:worktree-commands -->
## Worktree Quick Reference

{worktree_blocks}
```

## Acceptance Criteria
1. `templates/roadmap-sections.yaml` validates as proper YAML with yq
2. `templates/roadmap.md.tmpl` contains section markers for all 6 section types
3. Phase section is marked as `repeating: true` in the sections registry
4. Template uses `{placeholder}` syntax consistent with existing templates in `templates/`
5. Layered resolution documented: harness.yaml config > .claude/roadmap.tmpl > templates/roadmap.md.tmpl

## Implementation Notes
- Template is guidance, not a mechanical renderer — Claude interprets structure and generates rich content
- Phase section repeats once per phase in the output
- Conflict zones section is optional (omitted if no conflicts detected)
- Legend section is optional (omitted if DAG is empty)
