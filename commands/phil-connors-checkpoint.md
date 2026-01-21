---
description: "Create a checkpoint snapshot of current loop state"
argument-hint: "\"description of checkpoint\""
allowed-tools: ["Bash"]
---

# Phil-Connors Checkpoint

Create a snapshot of the current loop state that you can later rollback to:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/create-checkpoint.sh" $ARGUMENTS
```

Checkpoints capture:
- Current iteration number and continuation count
- All accumulated learnings
- Task context (priority files, constraints, success criteria)
- Session history at that point

## Usage

```
/phil-connors-checkpoint "description"
```

## Examples

```
# Create a checkpoint before risky changes
/phil-connors-checkpoint "Before refactoring auth module"

# Save state after reaching a stable point
/phil-connors-checkpoint "All tests passing - safe point"

# Mark progress milestones
/phil-connors-checkpoint "User registration complete"
```

## When to Create Checkpoints

- **Before risky changes**: Save state before trying something that might break things
- **After reaching stability**: When tests pass or a feature is working
- **Before trying alternatives**: If you want to try a different approach
- **At milestones**: Mark significant progress points

## Related Commands

| Command | Description |
|---------|-------------|
| `/phil-connors-checkpoints` | List all checkpoints |
| `/phil-connors-rollback <id>` | Restore to a checkpoint |
