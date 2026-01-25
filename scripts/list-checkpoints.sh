#!/bin/bash

# Phil-Connors List Checkpoints Script
# Lists all checkpoints for the current task
# Compatible with bash 3.x (macOS default)

set -euo pipefail

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --help|-h)
      cat << 'HELP_EOF'
Phil-Connors Checkpoints - List all saved checkpoints

USAGE:
  /phil-connors-checkpoints

DESCRIPTION:
  Lists all checkpoints for the current phil-connors task, showing:
  - Checkpoint ID (use with /phil-connors-rollback)
  - Iteration number when checkpoint was created
  - Timestamp
  - Description

OUTPUT:
  Displays a table of all checkpoints with their metadata.
  The most recent checkpoint is marked with [LATEST].

EXAMPLES:
  /phil-connors-checkpoints
HELP_EOF
      exit 0
      ;;
    *)
      echo "Warning: Unknown argument: $1" >&2
      shift
      ;;
  esac
done

# Source the state parser library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/parse-state.sh"

# Read and parse state
STATE_FILE=".agent/phil-connors/state.md"
validate_state_exists "$STATE_FILE" || exit 1
validate_state_active || exit 1

TASK_ID="${PC_TASK_ID:-}"
ACTIVE="${PC_ACTIVE:-false}"

# Setup paths
TASK_DIR=".agent/phil-connors/tasks/$TASK_ID"
CHECKPOINTS_DIR="$TASK_DIR/checkpoints"
INDEX_FILE="$CHECKPOINTS_DIR/index.md"

# Check if checkpoints directory exists
if [[ ! -d "$CHECKPOINTS_DIR" ]]; then
  echo "=== Checkpoints for Task: $TASK_ID ==="
  echo ""
  echo "No checkpoints created yet."
  echo ""
  echo "Create one with:"
  echo "  /phil-connors-checkpoint \"description\""
  exit 0
fi

# Check if index file exists
if [[ ! -f "$INDEX_FILE" ]]; then
  echo "=== Checkpoints for Task: $TASK_ID ==="
  echo ""
  echo "No checkpoints created yet."
  echo ""
  echo "Create one with:"
  echo "  /phil-connors-checkpoint \"description\""
  exit 0
fi

# Parse index to get checkpoint count
INDEX_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$INDEX_FILE" 2>/dev/null || echo "")
CHECKPOINT_COUNT=$(echo "$INDEX_FRONTMATTER" | grep '^checkpoint_count:' | sed 's/checkpoint_count: *//' || echo "0")

if [[ "$CHECKPOINT_COUNT" == "0" ]] || [[ -z "$CHECKPOINT_COUNT" ]]; then
  echo "=== Checkpoints for Task: $TASK_ID ==="
  echo ""
  echo "No checkpoints created yet."
  echo ""
  echo "Create one with:"
  echo "  /phil-connors-checkpoint \"description\""
  exit 0
fi

# Output header
echo "=== Checkpoints for Task: $TASK_ID ==="
echo ""
echo "Total checkpoints: $CHECKPOINT_COUNT"
echo ""

# Table header
printf "%-6s %-6s %-10s %-22s %s\n" "ID" "Iter" "Learnings" "Created" "Description"
printf "%-6s %-6s %-10s %-22s %s\n" "------" "------" "----------" "----------------------" "--------------------"

# List each checkpoint by reading metadata files
for cp_dir in "$CHECKPOINTS_DIR"/cp-*/; do
  if [[ -d "$cp_dir" ]]; then
    META_FILE="${cp_dir}_meta.md"
    if [[ -f "$META_FILE" ]]; then
      # Parse metadata
      META_CONTENT=$(cat "$META_FILE")
      CP_ID=$(echo "$META_CONTENT" | grep '^checkpoint_id:' | sed 's/checkpoint_id: *//' | head -1)
      CP_ITER=$(echo "$META_CONTENT" | grep '^iteration:' | sed 's/iteration: *//' | head -1)
      CP_CREATED=$(echo "$META_CONTENT" | grep '^created_at:' | sed 's/created_at: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
      CP_DESC=$(echo "$META_CONTENT" | grep '^description:' | sed 's/description: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
      CP_LEARNINGS=$(echo "$META_CONTENT" | grep '^learning_count:' | sed 's/learning_count: *//' | head -1)

      # Format ID with padding
      PADDED_ID=$(printf "%03d" "$CP_ID")

      # Truncate description if too long
      if [[ ${#CP_DESC} -gt 30 ]]; then
        CP_DESC="${CP_DESC:0:27}..."
      fi

      # Mark latest
      LATEST_MARKER=""
      if [[ "$CP_ID" == "$CHECKPOINT_COUNT" ]]; then
        LATEST_MARKER=" [LATEST]"
      fi

      # Format date for display (shorter format)
      CP_DATE_SHORT=$(echo "$CP_CREATED" | sed 's/T/ /' | cut -c1-16)

      printf "%-6s %-6s %-10s %-22s %s%s\n" "$PADDED_ID" "$CP_ITER" "$CP_LEARNINGS" "$CP_DATE_SHORT" "$CP_DESC" "$LATEST_MARKER"
    fi
  fi
done

echo ""
echo "Commands:"
echo "  /phil-connors-checkpoint \"desc\"  - Create new checkpoint"
echo "  /phil-connors-rollback <id>      - Restore to checkpoint"
