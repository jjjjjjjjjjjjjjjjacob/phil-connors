#!/bin/bash

# Phil-Connors Summarize Learnings Script
# Creates a condensed summary of accumulated learnings
# Called by stop-hook when learning_count >= summarization_threshold

set -euo pipefail

TASK_ID="${1:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Error: Task ID required" >&2
  exit 1
fi

LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"
SUMMARY_FILE="$LEARNED_DIR/_summary.md"
STATE_FILE=".agent/phil-connors/state.md"

if [[ ! -d "$LEARNED_DIR" ]]; then
  exit 0
fi

# Get all learning files (excluding summary)
LEARNING_FILES=$(ls -1 "$LEARNED_DIR"/*.md 2>/dev/null | grep -v '_summary.md' | sort || echo "")

if [[ -z "$LEARNING_FILES" ]]; then
  exit 0
fi

# Count learnings
LEARNING_COUNT=$(echo "$LEARNING_FILES" | wc -l | tr -d ' ')

# Build concatenated content
LEARNINGS_CONTENT=""
LEARNING_IDS=()
while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    LEARNINGS_CONTENT+="$(cat "$file")"
    LEARNINGS_CONTENT+=$'\n\n---\n\n'
    # Extract ID from filename
    ID=$(basename "$file" .md)
    LEARNING_IDS+=("$ID")
  fi
done <<< "$LEARNING_FILES"

# Determine next learning ID
LAST_ID="${LEARNING_IDS[${#LEARNING_IDS[@]}-1]}"
NEXT_ID=$((10#$LAST_ID + 1))

# Create summary file
cat > "$SUMMARY_FILE" << SUMMARY_EOF
---
task_id: "$TASK_ID"
last_updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
learning_count: $LEARNING_COUNT
summarized_from: [$(IFS=,; echo "${LEARNING_IDS[*]}")]
next_learning_id: $NEXT_ID
---

## Condensed Learnings Summary

The following learnings have been accumulated during this task.
Review and condense them into actionable categories.

### All Learnings

$LEARNINGS_CONTENT

---

## Summary Categories

### High Priority (Apply Every Iteration)
<!-- Most critical learnings that should always be considered -->
1. [Pending summarization - review learnings above]

### Medium Priority (Reference When Relevant)
<!-- Important but situational learnings -->
1. [Pending summarization]

### Patterns Discovered
<!-- Useful patterns identified during work -->
- [Pending summarization]

### Anti-Patterns Avoided
<!-- Things NOT to do -->
- [Pending summarization]

---

*Note: This summary was auto-generated when learning count reached threshold.*
*You may condense the "All Learnings" section into the summary categories above.*
SUMMARY_EOF

# Update state to record summarization
if [[ -f "$STATE_FILE" ]]; then
  TEMP_FILE="${STATE_FILE}.tmp.$$"
  sed "s/^last_summarization_at: .*/last_summarization_at: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$STATE_FILE"
fi

echo "Summarization triggered for task '$TASK_ID' ($LEARNING_COUNT learnings)"
echo "Summary file: $SUMMARY_FILE"
