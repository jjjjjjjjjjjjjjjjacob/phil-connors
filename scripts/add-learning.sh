#!/bin/bash

# Phil-Connors Add Learning Script
# Adds a learning to the current task's learned directory

set -euo pipefail

# Get learning text from arguments
LEARNING_TEXT="$*"

if [[ -z "$LEARNING_TEXT" ]]; then
  echo "Error: No learning text provided" >&2
  echo "" >&2
  echo "Usage: /phil-connors-learn \"your insight or discovery\"" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /phil-connors-learn \"JWT library requires async operations\"" >&2
  echo "  /phil-connors-learn \"Tests must reset state between runs\"" >&2
  exit 1
fi

# Read current state
STATE_FILE=".agent/phil-connors/state.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "Error: No active phil-connors loop" >&2
  echo "" >&2
  echo "Start a loop first with:" >&2
  echo "  /phil-connors \"your task\" --completion-promise \"done criteria\"" >&2
  exit 1
fi

FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
TASK_ID=$(echo "$FRONTMATTER" | grep '^task_id:' | sed 's/task_id: *//' | sed 's/^"\(.*\)"$/\1/')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
LEARNING_COUNT=$(echo "$FRONTMATTER" | grep '^learning_count:' | sed 's/learning_count: *//' || echo "0")
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')

if [[ "$ACTIVE" != "true" ]]; then
  echo "Error: Phil-connors loop is not active" >&2
  exit 1
fi

# Calculate next learning ID
if [[ ! "$LEARNING_COUNT" =~ ^[0-9]+$ ]]; then
  LEARNING_COUNT=0
fi
NEXT_ID=$((LEARNING_COUNT + 1))
PADDED_ID=$(printf "%03d" $NEXT_ID)

# Ensure learned directory exists
LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"
mkdir -p "$LEARNED_DIR"

# Create learning file
LEARNING_FILE="$LEARNED_DIR/${PADDED_ID}.md"

cat > "$LEARNING_FILE" << LEARNING_EOF
---
learning_id: $NEXT_ID
iteration: $ITERATION
timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
category: "discovery"
importance: "medium"
related_files: []
---

## Learning #$NEXT_ID (Iteration $ITERATION)

$LEARNING_TEXT
LEARNING_EOF

# Update learning count in state
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^learning_count: .*/learning_count: $NEXT_ID/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

echo "Learning #$NEXT_ID added to task '$TASK_ID'"
echo "File: $LEARNING_FILE"
echo ""
echo "This learning will be included in future iterations."
