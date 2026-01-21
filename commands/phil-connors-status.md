---
description: "Show current phil-connors loop status dashboard"
argument-hint: ""
allowed-tools: ["Bash"]
---

# Phil-Connors Status

Display the current loop status:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/show-status.sh" $ARGUMENTS
```

This shows a formatted dashboard with:
- Current iteration and progress
- Learning statistics by category
- Checkpoint history
- Recent session activity
- Task metadata
