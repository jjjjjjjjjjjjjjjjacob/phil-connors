#!/bin/bash

# Phil-Connors Create Checkpoint Script
# Creates a snapshot of current loop state for later rollback
# Compatible with bash 3.x (macOS default)

set -euo pipefail

# Parse arguments
DESCRIPTION=""
AUTO_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --auto)
      AUTO_MODE=true
      shift
      ;;
    --help|-h)
      cat << 'HELP_EOF'
Phil-Connors Checkpoint - Save a snapshot of current loop state

USAGE:
  /phil-connors-checkpoint "description"

DESCRIPTION:
  Creates a checkpoint that captures the current state of your phil-connors
  loop, including learnings, context, and iteration progress. You can later
  rollback to this checkpoint if an iteration goes wrong.

EXAMPLES:
  /phil-connors-checkpoint "Before refactoring auth module"
  /phil-connors-checkpoint "Tests passing - safe point"
  /phil-connors-checkpoint "After implementing user registration"

WHAT'S SAVED:
  - Current iteration number and continuation count
  - All accumulated learnings
  - Task context (priority files, constraints, success criteria)
  - Session history

USE CASES:
  - Before making risky changes
  - After reaching a stable state
  - Before trying a different approach
  - After tests pass
HELP_EOF
      exit 0
      ;;
    *)
      if [[ -z "$DESCRIPTION" ]]; then
        DESCRIPTION="$1"
      else
        DESCRIPTION="$DESCRIPTION $1"
      fi
      shift
      ;;
  esac
done

# Validate description
if [[ -z "$DESCRIPTION" ]]; then
  echo "Error: Checkpoint description required" >&2
  echo "" >&2
  echo "Usage: /phil-connors-checkpoint \"description\"" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  /phil-connors-checkpoint \"Before refactoring auth module\"" >&2
  exit 1
fi

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/parse-state.sh"
source "$SCRIPT_DIR/lib/state-update.sh"

# Read and validate state
STATE_FILE=".agent/phil-connors/state.md"
validate_state_exists "$STATE_FILE" || exit 1
validate_state_active || exit 1

TASK_ID="${PC_TASK_ID:-}"
ITERATION="${PC_ITERATION:-1}"
LEARNING_COUNT="${PC_LEARNING_COUNT:-0}"
CONTINUATION_COUNT="${PC_CONTINUATION_COUNT:-0}"

# Setup directories
TASK_DIR=".agent/phil-connors/tasks/$TASK_ID"
CHECKPOINTS_DIR="$TASK_DIR/checkpoints"
INDEX_FILE="$CHECKPOINTS_DIR/index.md"
CONTEXT_FILE="$TASK_DIR/context.md"
LEARNED_DIR="$TASK_DIR/learned"

# Create checkpoints directory if it doesn't exist
mkdir -p "$CHECKPOINTS_DIR"

# Determine next checkpoint ID
CHECKPOINT_COUNT=0
if [[ -f "$INDEX_FILE" ]]; then
  # Extract checkpoint_count from index frontmatter
  INDEX_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$INDEX_FILE" 2>/dev/null || echo "")
  CHECKPOINT_COUNT=$(echo "$INDEX_FRONTMATTER" | grep '^checkpoint_count:' | sed 's/checkpoint_count: *//' || echo "0")
  if [[ ! "$CHECKPOINT_COUNT" =~ ^[0-9]+$ ]]; then
    CHECKPOINT_COUNT=0
  fi
fi

NEXT_ID=$((CHECKPOINT_COUNT + 1))
PADDED_ID=$(printf "%03d" $NEXT_ID)
CHECKPOINT_DIR="$CHECKPOINTS_DIR/cp-$PADDED_ID"
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Create checkpoint directory
mkdir -p "$CHECKPOINT_DIR/learned"

# Copy state file
cp "$STATE_FILE" "$CHECKPOINT_DIR/state.md"

# Copy context file
if [[ -f "$CONTEXT_FILE" ]]; then
  cp "$CONTEXT_FILE" "$CHECKPOINT_DIR/context.md"
fi

# Copy all learning files
LEARNING_FILES_COPIED=0
if [[ -d "$LEARNED_DIR" ]]; then
  for f in "$LEARNED_DIR"/*.md; do
    if [[ -f "$f" ]]; then
      cp "$f" "$CHECKPOINT_DIR/learned/"
      LEARNING_FILES_COPIED=$((LEARNING_FILES_COPIED + 1))
    fi
  done
fi

# Create checkpoint metadata
cat > "$CHECKPOINT_DIR/_meta.md" << META_EOF
---
checkpoint_id: $NEXT_ID
iteration: $ITERATION
continuation_count: $CONTINUATION_COUNT
created_at: "$TIMESTAMP"
description: "$DESCRIPTION"
learning_count: $LEARNING_COUNT
learning_files: $LEARNING_FILES_COPIED
auto_checkpoint: $AUTO_MODE
---

## Checkpoint #$NEXT_ID

**Created**: $TIMESTAMP
**Iteration**: $ITERATION
**Continuation**: $CONTINUATION_COUNT
**Learnings**: $LEARNING_COUNT

### Description

$DESCRIPTION

### Files Captured

- state.md (loop state at this point)
- context.md (task context)
- learned/ ($LEARNING_FILES_COPIED learning files)
META_EOF

# Update or create index file
if [[ -f "$INDEX_FILE" ]]; then
  # Update checkpoint_count in frontmatter atomically
  state_update "$INDEX_FILE" "checkpoint_count" "$NEXT_ID"

  # Append new row to table
  echo "| $PADDED_ID | $ITERATION | $TIMESTAMP | $DESCRIPTION |" >> "$INDEX_FILE"
else
  # Create new index file
  cat > "$INDEX_FILE" << INDEX_EOF
---
task_id: "$TASK_ID"
checkpoint_count: $NEXT_ID
created_at: "$TIMESTAMP"
---

# Checkpoints

Checkpoints allow you to save snapshots of your loop state and rollback if needed.

## Commands

- \`/phil-connors-checkpoints\` - List all checkpoints
- \`/phil-connors-rollback <id>\` - Restore to a checkpoint

## Checkpoint History

| ID | Iteration | Created | Description |
|----|-----------|---------|-------------|
| $PADDED_ID | $ITERATION | $TIMESTAMP | $DESCRIPTION |
INDEX_EOF
fi

# Output confirmation
if [[ "$AUTO_MODE" == "true" ]]; then
  echo "Auto-checkpoint #$NEXT_ID created"
else
  echo "=== Checkpoint Created ==="
  echo ""
  echo "Checkpoint ID: $PADDED_ID"
  echo "Task: $TASK_ID"
  echo "Iteration: $ITERATION"
  echo "Learnings: $LEARNING_COUNT"
  echo "Description: $DESCRIPTION"
  echo ""
  echo "To restore: /phil-connors-rollback $PADDED_ID"
  echo "To list all: /phil-connors-checkpoints"
fi
