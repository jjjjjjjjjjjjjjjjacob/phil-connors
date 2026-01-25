#!/bin/bash

# Phil-Connors Status Dashboard
# Shows formatted overview of current loop state

set -euo pipefail

# Source the state parser library
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/parse-state.sh"

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
parse_state "$STATE_FILE"

ACTIVE="${PC_ACTIVE:-false}"
TASK_ID="${PC_TASK_ID:-}"
ITERATION="${PC_ITERATION:-1}"
MAX_ITERATIONS="${PC_MAX_ITERATIONS:-20}"
COMPLETION_PROMISE="${PC_COMPLETION_PROMISE:-}"
LEARNING_COUNT="${PC_LEARNING_COUNT:-0}"
STARTED_AT="${PC_STARTED_AT:-}"
LAST_ITERATION_AT="${PC_LAST_ITERATION_AT:-}"
CONTINUATION_COUNT="${PC_CONTINUATION_COUNT:-0}"
MAX_CONTINUATIONS="${PC_MAX_CONTINUATIONS:-0}"
MIN_CONTINUATIONS="${PC_MIN_CONTINUATIONS:-0}"
SUMMARIZATION_THRESHOLD="${PC_SUMMARIZATION_THRESHOLD:-10}"
AUTO_CHECKPOINT="${PC_AUTO_CHECKPOINT:-false}"

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
