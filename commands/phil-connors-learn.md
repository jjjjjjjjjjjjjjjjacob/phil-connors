---
description: "Add a categorized learning during phil-connors iteration"
argument-hint: "[OPTIONS] \"insight or discovery\""
allowed-tools: ["Bash"]
---

# Phil-Connors Learn

Add, update, or manage learnings for the current task:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/add-learning.sh" $ARGUMENTS
```

Use this command to record:
- Discoveries about the codebase
- Patterns that work well
- Anti-patterns to avoid
- Key insights for future iterations

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--category <cat>` | `-c` | Category for the learning (default: discovery) |
| `--importance <lvl>` | `-i` | Importance: low, medium, high, critical (default: medium) |
| `--file <path>` | `-f` | Related file path (can specify multiple times) |
| `--update <id>` | `-u` | Update an existing learning by ID |
| `--deprecate <id>` | `-d` | Mark a learning as deprecated (won't show in summaries) |
| `--list` | `-l` | List all learnings with their IDs and status |
| `--help` | `-h` | Show help |

## Categories

- `discovery` - General findings (default)
- `pattern` - Useful patterns to follow
- `anti-pattern` - Things NOT to do
- `file-location` - Important file locations
- `constraint` - Constraints or requirements discovered
- `solution` - Solutions that worked
- `blocker` - Issues blocking progress

## Examples

```
# Basic learning (default: discovery category, medium importance)
/phil-connors-learn "JWT library requires async operations"

# Categorized learnings
/phil-connors-learn --category pattern "Always validate token before processing"
/phil-connors-learn -c anti-pattern -i high "Don't store tokens in localStorage"
/phil-connors-learn -c file-location -f src/auth/jwt.ts "JWT validation logic here"
/phil-connors-learn -c solution "Fixed by adding null check at line 42"
/phil-connors-learn -c constraint "Must support both OAuth and API key auth"
/phil-connors-learn -c blocker "Redis connection failing in CI environment"

# Lifecycle management
/phil-connors-learn --list                           # See all learnings with IDs
/phil-connors-learn --update 3 -i critical "Now critical"  # Update importance
/phil-connors-learn --deprecate 2                    # Mark as deprecated
```

## Learning Lifecycle

Learnings are:
- Stored as individual files in `.agent/phil-connors/tasks/{task-id}/learned/`
- Automatically included in future iterations
- Auto-summarized when threshold reached (organized by category and importance)
- Can be updated retroactively (`--update`) to change category/importance
- Can be deprecated (`--deprecate`) when no longer relevant (excluded from summaries)
