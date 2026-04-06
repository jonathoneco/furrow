# Source Inventory — {Task Name}

Sources consulted during research, with relevance ratings and contributions.

## Source Hierarchy

Consult sources in priority order. Higher-tier sources override lower-tier ones on conflicts.

| Tier | Sources | Use when |
|------|---------|----------|
| Primary | Official docs, source code, changelogs, CLI `--help`, API responses | Always for version/behavior/config claims. First resort. |
| Secondary | Blog posts, tutorials, StackOverflow, conference talks | When primary is ambiguous or insufficient. Cross-reference with primary. |
| Tertiary | Training data (model knowledge) | Well-established facts only (language syntax, stdlib APIs). Never for version-specific claims. |

If a claim cannot be verified against a primary source, flag it as **unverified**.

## Source Types

| Type | Attribution Format | Description |
|------|--------------------|-------------|
| Codebase | `codebase:{relative-path}:{line-range}` or `codebase:{relative-path}::{symbol-name}` | Files, symbols, patterns in the project |
| Documentation | `docs:{url}` or `docs:{relative-path}` | Official docs, READMEs, architecture docs |
| Web | `web:{url}` (with access date) | External articles, blog posts, official sites |
| Command output | `cmd:{command}` (with truncated output) | Results from running tools or scripts |
| Git history | `git:{sha}:{summary}` or `git:log:{query}` | Commit messages, blame, log analysis |
| MCP/tool | `tool:{server}:{tool-name}:{query-summary}` | Results from MCP server queries |

## Sources

| # | Source | Type | Relevance | Contribution |
|---|--------|------|-----------|--------------|
| 1 | {attribution} | {type} | high/medium/low | {one-line summary} |

## Citation Format

Use bracketed references in deliverables with a corresponding reference section:

```markdown
The system uses a sliding window algorithm [1] with per-key counters [2].

## References
1. codebase:internal/middleware/ratelimit/window.go:15-42
2. docs:internal/middleware/README.md
```
