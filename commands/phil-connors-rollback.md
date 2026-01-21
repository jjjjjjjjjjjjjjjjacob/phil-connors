---
description: "Restore loop state to a previous checkpoint"
argument-hint: "<checkpoint-id> [--no-safety-checkpoint]"
allowed-tools: ["Bash"]
---

# Phil-Connors Rollback

Restore the loop state to a previously saved checkpoint:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/rollback-checkpoint.sh" $ARGUMENTS
```

Rollback will:
- Reset iteration counter to the checkpoint's iteration
- Restore all learnings to the checkpoint's state
- Restore task context to the checkpoint's state
- Create a safety checkpoint before rollback (by default)

## Usage

```
/phil-connors-rollback <checkpoint-id>
/phil-connors-rollback <checkpoint-id> --no-safety-checkpoint
/phil-connors-rollback --list
```

## Options

| Option | Description |
|--------|-------------|
| `--no-safety-checkpoint` | Skip creating a pre-rollback safety checkpoint |
| `--list`, `-l` | List available checkpoints |

## Examples

```
# Rollback to checkpoint 001
/phil-connors-rollback 001

# Rollback without safety checkpoint (not recommended)
/phil-connors-rollback 002 --no-safety-checkpoint

# List available checkpoints
/phil-connors-rollback --list
```

## Safety Checkpoint

By default, a safety checkpoint is automatically created before any rollback.
This allows you to recover if you accidentally rollback to the wrong checkpoint.
The safety checkpoint captures your current state before the rollback happens.

Use `--no-safety-checkpoint` to skip this (not recommended unless you're sure).

## Warning

Rollback will **REPLACE** your current learnings with the checkpoint's learnings.
Any learnings added after the checkpoint will be lost (unless captured by the
safety checkpoint).

## Related Commands

| Command | Description |
|---------|-------------|
| `/phil-connors-checkpoint "desc"` | Create a new checkpoint |
| `/phil-connors-checkpoints` | List all checkpoints |
