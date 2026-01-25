#!/bin/bash

# Phil-Connors Rollback Checkpoint Script
# Restores loop state to a previously saved checkpoint
# Compatible with bash 3.x (macOS default)

set -euo pipefail

# Parse arguments
CHECKPOINT_ID=""
NO_SAFETY=false
LIST_MODE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-safety-checkpoint)
      NO_SAFETY=true
      shift
      ;;
    --list|-l)
      LIST_MODE=true
      shift
      ;;
    --help|-h)
      cat << 'HELP_EOF'
Phil-Connors Rollback - Restore to a previous checkpoint

USAGE:
  /phil-connors-rollback <checkpoint-id>
  /phil-connors-rollback --list

DESCRIPTION:
  Restores the loop state to a previously saved checkpoint. This will:
  - Reset iteration counter to the checkpoint's iteration
  - Restore all learnings to the checkpoint's state
  - Restore task context to the checkpoint's state
  - Create a safety checkpoint before rollback (unless --no-safety-checkpoint)

OPTIONS:
  --no-safety-checkpoint  Skip creating a pre-rollback safety checkpoint
  --list, -l              List available checkpoints (same as /phil-connors-checkpoints)
  --help, -h              Show this help

EXAMPLES:
  /phil-connors-rollback 001
  /phil-connors-rollback 002 --no-safety-checkpoint
  /phil-connors-rollback --list

SAFETY:
  By default, a safety checkpoint is created before rollback. This allows you
  to recover if you rollback to the wrong checkpoint. Use --no-safety-checkpoint
  to skip this (not recommended).

WARNING:
  Rollback will REPLACE your current learnings with the checkpoint's learnings.
  Any learnings added after the checkpoint will be lost (unless you created
  a safety checkpoint, which is done by default).
HELP_EOF
      exit 0
      ;;
    *)
      if [[ -z "$CHECKPOINT_ID" ]]; then
        CHECKPOINT_ID="$1"
      fi
      shift
      ;;
  esac
done

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/parse-state.sh"
source "$SCRIPT_DIR/lib/state-update.sh"

# Read and validate state
STATE_FILE=".agent/phil-connors/state.md"
validate_state_exists "$STATE_FILE" || exit 1
validate_state_active || exit 1

TASK_ID="${PC_TASK_ID:-}"
CURRENT_ITERATION="${PC_ITERATION:-1}"

# Setup paths
TASK_DIR=".agent/phil-connors/tasks/$TASK_ID"
CHECKPOINTS_DIR="$TASK_DIR/checkpoints"
CONTEXT_FILE="$TASK_DIR/context.md"
LEARNED_DIR="$TASK_DIR/learned"

# Handle list mode
if [[ "$LIST_MODE" == "true" ]]; then
  SCRIPT_DIR="$(dirname "$0")"
  if [[ -x "$SCRIPT_DIR/list-checkpoints.sh" ]]; then
    exec "$SCRIPT_DIR/list-checkpoints.sh"
  else
    echo "Error: list-checkpoints.sh not found" >&2
    exit 1
  fi
fi

# Check if checkpoints exist
if [[ ! -d "$CHECKPOINTS_DIR" ]]; then
  echo "Error: No checkpoints found for this task" >&2
  echo "" >&2
  echo "Create a checkpoint first with:" >&2
  echo "  /phil-connors-checkpoint \"description\"" >&2
  exit 1
fi

# Validate checkpoint ID
if [[ -z "$CHECKPOINT_ID" ]]; then
  echo "Error: Checkpoint ID required" >&2
  echo "" >&2
  echo "Usage: /phil-connors-rollback <checkpoint-id>" >&2
  echo "" >&2
  echo "Available checkpoints:" >&2
  echo ""

  # List available checkpoints
  for cp_dir in "$CHECKPOINTS_DIR"/cp-*/; do
    if [[ -d "$cp_dir" ]]; then
      META_FILE="${cp_dir}_meta.md"
      if [[ -f "$META_FILE" ]]; then
        META_CONTENT=$(cat "$META_FILE")
        CP_ID=$(echo "$META_CONTENT" | grep '^checkpoint_id:' | sed 's/checkpoint_id: *//' | head -1)
        CP_DESC=$(echo "$META_CONTENT" | grep '^description:' | sed 's/description: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
        PADDED_ID=$(printf "%03d" "$CP_ID")
        echo "  $PADDED_ID - $CP_DESC"
      fi
    fi
  done
  echo ""
  exit 1
fi

# Normalize checkpoint ID (handle both "1" and "001")
if [[ "$CHECKPOINT_ID" =~ ^[0-9]+$ ]]; then
  PADDED_CP_ID=$(printf "%03d" "$((10#$CHECKPOINT_ID))")
else
  PADDED_CP_ID="$CHECKPOINT_ID"
fi

CHECKPOINT_DIR="$CHECKPOINTS_DIR/cp-$PADDED_CP_ID"

if [[ ! -d "$CHECKPOINT_DIR" ]]; then
  echo "Error: Checkpoint $PADDED_CP_ID not found" >&2
  echo "" >&2
  echo "Use /phil-connors-checkpoints to see available checkpoints" >&2
  exit 1
fi

# Read checkpoint metadata
META_FILE="$CHECKPOINT_DIR/_meta.md"
if [[ ! -f "$META_FILE" ]]; then
  echo "Error: Checkpoint metadata not found" >&2
  exit 1
fi

META_CONTENT=$(cat "$META_FILE")
CP_ITERATION=$(echo "$META_CONTENT" | grep '^iteration:' | sed 's/iteration: *//' | head -1)
CP_CONTINUATION=$(echo "$META_CONTENT" | grep '^continuation_count:' | sed 's/continuation_count: *//' | head -1)
CP_LEARNING_COUNT=$(echo "$META_CONTENT" | grep '^learning_count:' | sed 's/learning_count: *//' | head -1)
CP_DESCRIPTION=$(echo "$META_CONTENT" | grep '^description:' | sed 's/description: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
CP_CREATED=$(echo "$META_CONTENT" | grep '^created_at:' | sed 's/created_at: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)

# Default continuation count if not present
[[ -z "$CP_CONTINUATION" ]] && CP_CONTINUATION=0

echo "=== Rollback to Checkpoint $PADDED_CP_ID ==="
echo ""
echo "Checkpoint: $CP_DESCRIPTION"
echo "Created: $CP_CREATED"
echo "Iteration: $CP_ITERATION"
echo "Learnings: $CP_LEARNING_COUNT"
echo ""

# Create safety checkpoint before rollback
if [[ "$NO_SAFETY" != "true" ]]; then
  echo "Creating safety checkpoint before rollback..."
  SCRIPT_DIR="$(dirname "$0")"
  if [[ -x "$SCRIPT_DIR/create-checkpoint.sh" ]]; then
    "$SCRIPT_DIR/create-checkpoint.sh" --auto "Pre-rollback safety (before rollback to $PADDED_CP_ID)" 2>/dev/null || true
    echo "Safety checkpoint created."
    echo ""
  fi
fi

# Perform rollback
echo "Restoring state..."

# 1. Restore state.md (but keep active: true and update iteration)
if [[ -f "$CHECKPOINT_DIR/state.md" ]]; then
  # Copy checkpoint state
  cp "$CHECKPOINT_DIR/state.md" "$STATE_FILE"

  # Ensure active remains true and update timestamp atomically
  state_batch_update "$STATE_FILE" \
    "active=true" \
    "iteration=$CP_ITERATION" \
    "learning_count=$CP_LEARNING_COUNT" \
    "continuation_count=$CP_CONTINUATION" \
    "last_iteration_at=\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""

  # Append rollback event to session history
  echo "- Rollback to checkpoint $PADDED_CP_ID ($(date +"%H:%M:%S")): restored iteration $CP_ITERATION" >> "$STATE_FILE"

  echo "  - State restored (iteration: $CP_ITERATION)"
fi

# 2. Restore context.md
if [[ -f "$CHECKPOINT_DIR/context.md" ]]; then
  cp "$CHECKPOINT_DIR/context.md" "$CONTEXT_FILE"
  echo "  - Context restored"
fi

# 3. Restore learnings
if [[ -d "$CHECKPOINT_DIR/learned" ]]; then
  # Remove current learnings
  rm -f "$LEARNED_DIR"/*.md 2>/dev/null || true

  # Copy checkpoint learnings
  LEARNING_COUNT=0
  for f in "$CHECKPOINT_DIR/learned"/*.md; do
    if [[ -f "$f" ]]; then
      cp "$f" "$LEARNED_DIR/"
      LEARNING_COUNT=$((LEARNING_COUNT + 1))
    fi
  done

  echo "  - Learnings restored ($LEARNING_COUNT files)"
fi

echo ""
echo "=== Rollback Complete ==="
echo ""
echo "Loop state has been restored to checkpoint $PADDED_CP_ID."
echo "Current iteration: $CP_ITERATION"
echo ""
echo "You can continue working from this point."
if [[ "$NO_SAFETY" != "true" ]]; then
  echo "A safety checkpoint was created in case you need to undo this rollback."
fi
