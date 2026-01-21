---
description: "Update task context during phil-connors iteration"
argument-hint: "[OPTIONS] \"context update\""
allowed-tools: ["Bash"]
---

# Phil-Connors Context Update

Update the task context during a phil-connors loop:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/update-context.sh" $ARGUMENTS
```

Use this command to evolve task context as you discover new requirements:

## Options

| Option | Short | Description |
|--------|-------|-------------|
| `--priority-file <path>` | `-p` | Add a priority file (can specify multiple times) |
| `--constraint <text>` | `-c` | Add a constraint discovered during iteration |
| `--success-criterion <text>` | `-s` | Add a success criterion |
| `--note <text>` | `-n` | Add a task note |
| `--help` | `-h` | Show help |

## Examples

```
# Add a priority file discovered during work
/phil-connors-context-update --priority-file src/auth/jwt.ts

# Add multiple priority files at once
/phil-connors-context-update -p src/auth/jwt.ts -p src/middleware/auth.ts

# Add a constraint discovered during iteration
/phil-connors-context-update --constraint "Must maintain backwards compatibility with v2 API"

# Add a success criterion as scope becomes clearer
/phil-connors-context-update --success-criterion "All auth unit tests pass"

# Add a note about the task
/phil-connors-context-update --note "JWT library was upgraded to v9 - breaking changes"

# Combine multiple updates
/phil-connors-context-update -p src/auth.ts -c "No external dependencies" -s "Tests pass"
```

## Why Use This

Task context is created at loop start, but requirements often emerge during work:
- You discover critical files that weren't initially obvious
- You find constraints that must be respected
- Success criteria become clearer as you understand the scope

Instead of adding these to learnings (which are summarized/archived),
use this command to update the task context (Tier 2), ensuring these
discoveries remain visible in every iteration.
