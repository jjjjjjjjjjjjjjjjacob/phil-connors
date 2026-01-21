#!/bin/bash

# Phil-Connors Status Dashboard
# Shows formatted overview of current loop state

set -euo pipefail

# Check for state file
STATE_FILE=".agent/phil-connors/state.md"

if [[ ! -f "$STATE_FILE" ]]; then
  echo "No active phil-connors loop found."
  echo ""
  echo "Start a loop with:"
  echo "  /phil-connors \"your task\" --completion-promise \"done criteria\""
  exit 0
fi

# Parse state frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")

ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
TASK_ID=$(echo "$FRONTMATTER" | grep '^task_id:' | sed 's/task_id: *//' | sed 's/^"\(.*\)"$/\1/')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
LEARNING_COUNT=$(echo "$FRONTMATTER" | grep '^learning_count:' | sed 's/learning_count: *//' || echo "0")
STARTED_AT=$(echo "$FRONTMATTER" | grep '^started_at:' | sed 's/started_at: *//' | sed 's/^"\(.*\)"$/\1/')
LAST_ITERATION_AT=$(echo "$FRONTMATTER" | grep '^last_iteration_at:' | sed 's/last_iteration_at: *//' | sed 's/^"\(.*\)"$/\1/')
CONTINUATION_COUNT=$(echo "$FRONTMATTER" | grep '^continuation_count:' | sed 's/continuation_count: *//' || echo "0")
MAX_CONTINUATIONS=$(echo "$FRONTMATTER" | grep '^max_continuations:' | sed 's/max_continuations: *//' || echo "0")
MIN_CONTINUATIONS=$(echo "$FRONTMATTER" | grep '^min_continuations:' | sed 's/min_continuations: *//' || echo "0")
SUMMARIZATION_THRESHOLD=$(echo "$FRONTMATTER" | grep '^summarization_threshold:' | sed 's/summarization_threshold: *//' || echo "10")
AUTO_CHECKPOINT=$(echo "$FRONTMATTER" | grep '^auto_checkpoint:' | sed 's/auto_checkpoint: *//' || echo "false")

# Calculate progress
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  PROGRESS_PCT=$((ITERATION * 100 / MAX_ITERATIONS))
  PROGRESS_BAR=""
  FILLED=$((PROGRESS_PCT / 5))
  EMPTY=$((20 - FILLED))
  for ((i=0; i<FILLED; i++)); do PROGRESS_BAR+="="; done
  for ((i=0; i<EMPTY; i++)); do PROGRESS_BAR+="-"; done
else
  PROGRESS_PCT=0
  PROGRESS_BAR="unlimited"
fi

# Status indicator
if [[ "$ACTIVE" == "true" ]]; then
  STATUS_ICON="ACTIVE"
else
  STATUS_ICON="PAUSED"
fi

# Print header
echo "================================================================================"
echo "                        PHIL-CONNORS STATUS DASHBOARD"
echo "================================================================================"
echo ""

# Task info
echo "TASK: $TASK_ID"
echo "STATUS: $STATUS_ICON"
echo ""

# Progress section
echo "--- PROGRESS ---"
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  echo "Iteration:    $ITERATION / $MAX_ITERATIONS [$PROGRESS_BAR] $PROGRESS_PCT%"
else
  echo "Iteration:    $ITERATION (no limit)"
fi

if [[ $MAX_CONTINUATIONS -gt 0 ]] || [[ $MIN_CONTINUATIONS -gt 0 ]]; then
  if [[ $MIN_CONTINUATIONS -gt 0 ]] && [[ $MAX_CONTINUATIONS -gt 0 ]]; then
    echo "Continuations: $CONTINUATION_COUNT (min: $MIN_CONTINUATIONS, max: $MAX_CONTINUATIONS)"
  elif [[ $MIN_CONTINUATIONS -gt 0 ]]; then
    echo "Continuations: $CONTINUATION_COUNT (min: $MIN_CONTINUATIONS)"
  else
    echo "Continuations: $CONTINUATION_COUNT / $MAX_CONTINUATIONS"
  fi
fi
echo ""

# Completion promise
echo "--- COMPLETION ---"
echo "Promise: $COMPLETION_PROMISE"
echo ""

# Learnings section
echo "--- LEARNINGS ($LEARNING_COUNT total, summarize after $SUMMARIZATION_THRESHOLD) ---"

LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"
if [[ -d "$LEARNED_DIR" ]]; then
  # Count by category
  DISCOVERY=0; PATTERN=0; ANTI_PATTERN=0; FILE_LOC=0; CONSTRAINT=0; SOLUTION=0; BLOCKER=0; DEPRECATED=0

  for file in "$LEARNED_DIR"/*.md; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" == "_summary.md" ]] && continue

    CONTENT=$(cat "$file")
    CAT=$(echo "$CONTENT" | grep '^category:' | sed 's/category: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
    DEP=$(echo "$CONTENT" | grep '^deprecated:' | sed 's/deprecated: *//' | head -1 || echo "")

    if [[ "$DEP" == "true" ]]; then
      ((DEPRECATED++))
      continue
    fi

    case "$CAT" in
      discovery) ((DISCOVERY++)) ;;
      pattern) ((PATTERN++)) ;;
      anti-pattern) ((ANTI_PATTERN++)) ;;
      file-location) ((FILE_LOC++)) ;;
      constraint) ((CONSTRAINT++)) ;;
      solution) ((SOLUTION++)) ;;
      blocker) ((BLOCKER++)) ;;
    esac
  done

  printf "  %-15s %3d    %-15s %3d\n" "discovery:" "$DISCOVERY" "pattern:" "$PATTERN"
  printf "  %-15s %3d    %-15s %3d\n" "anti-pattern:" "$ANTI_PATTERN" "file-location:" "$FILE_LOC"
  printf "  %-15s %3d    %-15s %3d\n" "constraint:" "$CONSTRAINT" "solution:" "$SOLUTION"
  printf "  %-15s %3d    %-15s %3d\n" "blocker:" "$BLOCKER" "deprecated:" "$DEPRECATED"

  # Check for summary
  if [[ -f "$LEARNED_DIR/_summary.md" ]]; then
    echo ""
    echo "  [Summary file exists]"
  fi
else
  echo "  No learnings recorded yet"
fi
echo ""

# Checkpoints section
CHECKPOINT_DIR=".agent/phil-connors/tasks/$TASK_ID/checkpoints"
CHECKPOINT_INDEX="$CHECKPOINT_DIR/index.md"
echo "--- CHECKPOINTS ---"
if [[ -f "$CHECKPOINT_INDEX" ]]; then
  # Count checkpoints
  CP_COUNT=$(grep -c '^\| cp-' "$CHECKPOINT_INDEX" 2>/dev/null || echo "0")
  echo "Total: $CP_COUNT checkpoint(s)"

  # Show last 3
  if [[ $CP_COUNT -gt 0 ]]; then
    echo ""
    echo "Recent:"
    grep '^\| cp-' "$CHECKPOINT_INDEX" | tail -3 | while read -r line; do
      echo "  $line"
    done
  fi
else
  echo "  No checkpoints created"
fi
if [[ "$AUTO_CHECKPOINT" == "true" ]]; then
  echo "  [Auto-checkpoint: enabled]"
fi
echo ""

# Timeline
echo "--- TIMELINE ---"
echo "Started:        $STARTED_AT"
echo "Last iteration: $LAST_ITERATION_AT"
echo ""

# Recent activity (last 5 lines from session history)
echo "--- RECENT ACTIVITY ---"
HISTORY=$(awk '/^## Session History/,0' "$STATE_FILE" | tail -6 | head -5)
if [[ -n "$HISTORY" ]]; then
  echo "$HISTORY"
else
  echo "  No activity recorded"
fi
echo ""

echo "================================================================================"
echo "Commands: /phil-connors-learn | /phil-connors-checkpoint | /phil-connors-pause"
echo "================================================================================"
