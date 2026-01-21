---
description: "List all checkpoints for current task"
argument-hint: ""
allowed-tools: ["Bash"]
---

# Phil-Connors Checkpoints

List all saved checkpoints for the current task:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/list-checkpoints.sh" $ARGUMENTS
```

Displays a table showing:
- Checkpoint ID (for use with `/phil-connors-rollback`)
- Iteration number when created
- Number of learnings at that point
- Creation timestamp
- Description

## Usage

```
/phil-connors-checkpoints
```

## Example Output

```
=== Checkpoints for Task: refactor-auth-20260121 ===

Total checkpoints: 3

ID     Iter   Learnings  Created                Description
------ ------ ---------- ---------------------- --------------------
001    3      2          2026-01-21 01:00       Before auth refactor
002    7      5          2026-01-21 01:30       Tests passing [LATEST]
```

## Related Commands

| Command | Description |
|---------|-------------|
| `/phil-connors-checkpoint "desc"` | Create a new checkpoint |
| `/phil-connors-rollback <id>` | Restore to a checkpoint |
