---
description: "Search through learnings by keyword, category, or importance"
argument-hint: "\"query\" [--category CAT] [--importance LVL]"
allowed-tools: ["Bash"]
---

# Phil-Connors Search

Search through learnings in the current task:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/search-learnings.sh" $ARGUMENTS
```

This searches learnings by:
- Text content (keyword matching)
- Category filter
- Importance filter

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--category <cat>` | `-c` | Filter by category |
| `--importance <lvl>` | `-i` | Filter by importance (low, medium, high, critical) |
| `--all` | `-a` | Search all tasks, not just current |

## Examples

```bash
/phil-connors-search "auth"                    # Find learnings mentioning "auth"
/phil-connors-search -c pattern                # All pattern learnings
/phil-connors-search -i critical               # All critical learnings
/phil-connors-search "token" -c anti-pattern   # Anti-patterns about tokens
```
