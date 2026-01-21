#!/bin/bash

# Phil-Connors Summarize Learnings Script
# Creates a condensed summary of accumulated learnings organized by category
# Called by stop-hook when learning_count >= summarization_threshold
# Compatible with bash 3.x (macOS default)
#
# Features:
# - Skips deprecated learnings (deprecated: true in frontmatter)
# - Optionally archives learnings after summarization (--archive flag)
# - Organizes by importance (critical/high first) and category

set -euo pipefail

TASK_ID="${1:-}"
ARCHIVE_MODE="${2:-}"

if [[ -z "$TASK_ID" ]]; then
  echo "Error: Task ID required" >&2
  exit 1
fi

LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"
ARCHIVE_DIR=".agent/phil-connors/tasks/$TASK_ID/learned-archive"
SUMMARY_FILE="$LEARNED_DIR/_summary.md"
STATE_FILE=".agent/phil-connors/state.md"

if [[ ! -d "$LEARNED_DIR" ]]; then
  exit 0
fi

# Get all learning files (excluding summary and archived)
LEARNING_FILES=$(ls -1 "$LEARNED_DIR"/*.md 2>/dev/null | grep -v '_summary.md' | sort || echo "")

if [[ -z "$LEARNING_FILES" ]]; then
  exit 0
fi

# Count learnings
LEARNING_COUNT=$(echo "$LEARNING_FILES" | wc -l | tr -d ' ')

# Create temp directory for category files
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Initialize category temp files and counters
touch "$TEMP_DIR/pattern.md"
touch "$TEMP_DIR/anti-pattern.md"
touch "$TEMP_DIR/solution.md"
touch "$TEMP_DIR/file-location.md"
touch "$TEMP_DIR/constraint.md"
touch "$TEMP_DIR/discovery.md"
touch "$TEMP_DIR/blocker.md"
touch "$TEMP_DIR/critical.md"
touch "$TEMP_DIR/high.md"

# Initialize counters
echo "0" > "$TEMP_DIR/pattern.count"
echo "0" > "$TEMP_DIR/anti-pattern.count"
echo "0" > "$TEMP_DIR/solution.count"
echo "0" > "$TEMP_DIR/file-location.count"
echo "0" > "$TEMP_DIR/constraint.count"
echo "0" > "$TEMP_DIR/discovery.count"
echo "0" > "$TEMP_DIR/blocker.count"
echo "0" > "$TEMP_DIR/critical.count"
echo "0" > "$TEMP_DIR/high.count"

LEARNING_IDS=""
DEPRECATED_IDS=""
TOTAL_CRITICAL=0
TOTAL_HIGH=0
TOTAL_DEPRECATED=0
ACTIVE_COUNT=0

while IFS= read -r file; do
  if [[ -f "$file" ]]; then
    # Extract ID from filename
    ID=$(basename "$file" .md)
    if [[ -z "$LEARNING_IDS" ]]; then
      LEARNING_IDS="$ID"
    else
      LEARNING_IDS="$LEARNING_IDS,$ID"
    fi

    CONTENT=$(cat "$file")

    # Check if deprecated
    IS_DEPRECATED=$(echo "$CONTENT" | grep '^deprecated: true' || echo "")
    if [[ -n "$IS_DEPRECATED" ]]; then
      TOTAL_DEPRECATED=$((TOTAL_DEPRECATED + 1))
      if [[ -z "$DEPRECATED_IDS" ]]; then
        DEPRECATED_IDS="$ID"
      else
        DEPRECATED_IDS="$DEPRECATED_IDS,$ID"
      fi
      continue  # Skip deprecated learnings
    fi

    ACTIVE_COUNT=$((ACTIVE_COUNT + 1))

    # Extract category from frontmatter
    CATEGORY=$(echo "$CONTENT" | grep '^category:' | sed 's/category: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
    [[ -z "$CATEGORY" ]] && CATEGORY="discovery"

    # Extract importance from frontmatter
    IMPORTANCE=$(echo "$CONTENT" | grep '^importance:' | sed 's/importance: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
    [[ -z "$IMPORTANCE" ]] && IMPORTANCE="medium"

    # Extract just the learning text (after frontmatter)
    LEARNING_TEXT=$(echo "$CONTENT" | awk '/^---$/{i++; next} i>=2')

    # Append to category file
    if [[ -f "$TEMP_DIR/$CATEGORY.md" ]]; then
      echo "$LEARNING_TEXT" >> "$TEMP_DIR/$CATEGORY.md"
      echo "" >> "$TEMP_DIR/$CATEGORY.md"
      COUNT=$(cat "$TEMP_DIR/$CATEGORY.count")
      echo $((COUNT + 1)) > "$TEMP_DIR/$CATEGORY.count"
    fi

    # Track importance
    if [[ "$IMPORTANCE" == "critical" ]]; then
      TOTAL_CRITICAL=$((TOTAL_CRITICAL + 1))
      echo "$LEARNING_TEXT" >> "$TEMP_DIR/critical.md"
      echo "" >> "$TEMP_DIR/critical.md"
    elif [[ "$IMPORTANCE" == "high" ]]; then
      TOTAL_HIGH=$((TOTAL_HIGH + 1))
      echo "$LEARNING_TEXT" >> "$TEMP_DIR/high.md"
      echo "" >> "$TEMP_DIR/high.md"
    fi
  fi
done <<< "$LEARNING_FILES"

# Determine next learning ID
LAST_ID=$(echo "$LEARNING_IDS" | tr ',' '\n' | tail -1)
NEXT_ID=$((10#$LAST_ID + 1))

# Read category counts
PATTERN_COUNT=$(cat "$TEMP_DIR/pattern.count")
ANTIPATTERN_COUNT=$(cat "$TEMP_DIR/anti-pattern.count")
SOLUTION_COUNT=$(cat "$TEMP_DIR/solution.count")
FILELOC_COUNT=$(cat "$TEMP_DIR/file-location.count")
CONSTRAINT_COUNT=$(cat "$TEMP_DIR/constraint.count")
DISCOVERY_COUNT=$(cat "$TEMP_DIR/discovery.count")
BLOCKER_COUNT=$(cat "$TEMP_DIR/blocker.count")

# Create summary file
cat > "$SUMMARY_FILE" << SUMMARY_EOF
---
task_id: "$TASK_ID"
last_updated: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
total_learning_count: $LEARNING_COUNT
active_learning_count: $ACTIVE_COUNT
deprecated_count: $TOTAL_DEPRECATED
critical_count: $TOTAL_CRITICAL
high_importance_count: $TOTAL_HIGH
summarized_from: [$LEARNING_IDS]
deprecated_ids: [$DEPRECATED_IDS]
next_learning_id: $NEXT_ID
categories:
  patterns: $PATTERN_COUNT
  anti_patterns: $ANTIPATTERN_COUNT
  solutions: $SOLUTION_COUNT
  file_locations: $FILELOC_COUNT
  constraints: $CONSTRAINT_COUNT
  discoveries: $DISCOVERY_COUNT
  blockers: $BLOCKER_COUNT
---

## Learnings Summary (Organized by Category)

Active: $ACTIVE_COUNT learnings | Deprecated: $TOTAL_DEPRECATED | Critical: $TOTAL_CRITICAL | High: $TOTAL_HIGH

SUMMARY_EOF

# Add high-importance section first if any exist
if [[ -s "$TEMP_DIR/critical.md" ]]; then
  cat >> "$SUMMARY_FILE" << 'CRITICAL_HEAD'
---

## CRITICAL IMPORTANCE (Apply Every Iteration)

CRITICAL_HEAD
  cat "$TEMP_DIR/critical.md" >> "$SUMMARY_FILE"
fi

if [[ -s "$TEMP_DIR/high.md" ]]; then
  cat >> "$SUMMARY_FILE" << 'HIGH_HEAD'
---

## HIGH IMPORTANCE

HIGH_HEAD
  cat "$TEMP_DIR/high.md" >> "$SUMMARY_FILE"
fi

# Add category sections header
cat >> "$SUMMARY_FILE" << 'DIVIDER'
---

## By Category

DIVIDER

# Patterns
if [[ $PATTERN_COUNT -gt 0 ]]; then
  echo "### Patterns ($PATTERN_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/pattern.md" >> "$SUMMARY_FILE"
fi

# Anti-patterns
if [[ $ANTIPATTERN_COUNT -gt 0 ]]; then
  echo "### Anti-Patterns ($ANTIPATTERN_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/anti-pattern.md" >> "$SUMMARY_FILE"
fi

# Solutions
if [[ $SOLUTION_COUNT -gt 0 ]]; then
  echo "### Solutions ($SOLUTION_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/solution.md" >> "$SUMMARY_FILE"
fi

# File Locations
if [[ $FILELOC_COUNT -gt 0 ]]; then
  echo "### File Locations ($FILELOC_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/file-location.md" >> "$SUMMARY_FILE"
fi

# Constraints
if [[ $CONSTRAINT_COUNT -gt 0 ]]; then
  echo "### Constraints ($CONSTRAINT_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/constraint.md" >> "$SUMMARY_FILE"
fi

# Blockers
if [[ $BLOCKER_COUNT -gt 0 ]]; then
  echo "### Blockers ($BLOCKER_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/blocker.md" >> "$SUMMARY_FILE"
fi

# Discoveries (general)
if [[ $DISCOVERY_COUNT -gt 0 ]]; then
  echo "### Discoveries ($DISCOVERY_COUNT)" >> "$SUMMARY_FILE"
  echo "" >> "$SUMMARY_FILE"
  cat "$TEMP_DIR/discovery.md" >> "$SUMMARY_FILE"
fi

cat >> "$SUMMARY_FILE" << 'FOOTER'
---

*Auto-generated summary organized by category and importance.*
*Critical/high importance learnings appear first for quick reference.*
*Deprecated learnings are excluded from this summary.*
FOOTER

# Update state to record summarization
if [[ -f "$STATE_FILE" ]]; then
  TEMP_FILE="${STATE_FILE}.tmp.$$"
  sed "s/^last_summarization_at: .*/last_summarization_at: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" "$STATE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$STATE_FILE"
fi

# === ARCHIVE MODE ===
if [[ "$ARCHIVE_MODE" == "--archive" ]]; then
  mkdir -p "$ARCHIVE_DIR"

  ARCHIVED_COUNT=0
  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      BASENAME=$(basename "$file")
      # Don't archive the summary file
      if [[ "$BASENAME" != "_summary.md" ]]; then
        mv "$file" "$ARCHIVE_DIR/$BASENAME"
        ARCHIVED_COUNT=$((ARCHIVED_COUNT + 1))
      fi
    fi
  done <<< "$LEARNING_FILES"

  echo "Archived $ARCHIVED_COUNT learnings to $ARCHIVE_DIR"
fi

echo "Summarization triggered for task '$TASK_ID' ($ACTIVE_COUNT active, $TOTAL_DEPRECATED deprecated)"
echo "Summary file: $SUMMARY_FILE"
