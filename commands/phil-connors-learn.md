---
description: "Add a learning during phil-connors iteration"
argument-hint: "\"insight or discovery\""
allowed-tools: ["Bash"]
hide-from-slash-command-tool: "true"
---

# Phil-Connors Learn

Add a learning to the current task:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/add-learning.sh" $ARGUMENTS
```

Use this command to record:
- Discoveries about the codebase
- Patterns that work well
- Anti-patterns to avoid
- Key insights for future iterations

Learnings are:
- Stored as individual files in `.agent/phil-connors/tasks/{task-id}/learned/`
- Automatically included in future iterations
- Auto-summarized when the threshold is reached (default: 10 learnings)

## Examples

```
/phil-connors-learn "JWT library requires async operations for production"
/phil-connors-learn "Tests must reset auth state between runs"
/phil-connors-learn "The config loader caches on first call - restart required for changes"
```
