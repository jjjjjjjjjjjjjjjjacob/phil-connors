#!/bin/bash

# Phil-Connors Stall Detection Library
# Analyzes iteration history to detect lack of progress.
# Compatible with bash 3.x (macOS default).
#
# Usage:
#   source "$(dirname "$0")/../scripts/lib/stall-detection.sh"
#   STALL_WARNING=$(detect_stall "$STATE_FILE" "$ITERATION" "$FILES_EDITED" "$ERRORS_FOUND")

# detect_stall <state_file> <current_iteration> <files_edited> <errors_found>
# Analyzes the session history in the state file to detect stall patterns.
# Outputs a warning message to stdout if a stall is detected, empty string otherwise.
#
# Stall patterns detected:
#   1. Zero-edit streak: 3+ consecutive iterations with 0 file edits
#   2. Error loop: Same error count persisting for 3+ iterations with no edits
#   3. Low progress: 4+ iterations where edits < errors consistently
detect_stall() {
  local state_file="$1"
  local current_iteration="$2"
  local current_edits="${3:-0}"
  local current_errors="${4:-0}"

  # Need at least 3 iterations of history to detect stalls
  if [[ $current_iteration -lt 3 ]]; then
    return
  fi

  # Extract recent iteration history lines from state file
  # Format: "- Iteration N (HH:MM:SS): tools=X, reads=Y, edits=Z, errors=W"
  local history
  history=$(grep '^- Iteration [0-9]' "$state_file" 2>/dev/null | tail -5 || echo "")

  if [[ -z "$history" ]]; then
    return
  fi

  # Parse edit and error counts from recent history
  local zero_edit_streak=0
  local error_streak=0
  local low_progress_streak=0

  while IFS= read -r line; do
    local edits
    edits=$(echo "$line" | grep -o 'edits=[0-9]*' | sed 's/edits=//' || echo "0")
    local errors
    errors=$(echo "$line" | grep -o 'errors=[0-9]*' | sed 's/errors=//' || echo "0")

    [[ -z "$edits" ]] && edits=0
    [[ -z "$errors" ]] && errors=0

    # Count zero-edit streak
    if [[ $edits -eq 0 ]]; then
      zero_edit_streak=$((zero_edit_streak + 1))
    else
      zero_edit_streak=0
    fi

    # Count error-with-no-edits streak
    if [[ $errors -gt 0 ]] && [[ $edits -eq 0 ]]; then
      error_streak=$((error_streak + 1))
    else
      error_streak=0
    fi

    # Count low progress (more errors than edits)
    if [[ $errors -gt $edits ]] && [[ $edits -lt 2 ]]; then
      low_progress_streak=$((low_progress_streak + 1))
    else
      low_progress_streak=0
    fi
  done <<< "$history"

  # Include current iteration in streak analysis
  if [[ $current_edits -eq 0 ]]; then
    zero_edit_streak=$((zero_edit_streak + 1))
  fi
  if [[ $current_errors -gt 0 ]] && [[ $current_edits -eq 0 ]]; then
    error_streak=$((error_streak + 1))
  fi
  if [[ $current_errors -gt $current_edits ]] && [[ $current_edits -lt 2 ]]; then
    low_progress_streak=$((low_progress_streak + 1))
  fi

  # Determine if stalled
  local warning=""

  if [[ $zero_edit_streak -ge 3 ]]; then
    warning="[STALL DETECTED] $zero_edit_streak consecutive iterations with zero file edits."
    warning+=$'\n'"Consider: Try a different approach, create a checkpoint and experiment, or record a blocker learning."
  elif [[ $error_streak -ge 3 ]]; then
    warning="[STALL DETECTED] $error_streak consecutive iterations hitting errors without making edits."
    warning+=$'\n'"Consider: Record the error as a blocker (/phil-connors-learn -c blocker), rollback to last good checkpoint, or try a fundamentally different approach."
  elif [[ $low_progress_streak -ge 4 ]]; then
    warning="[LOW PROGRESS] $low_progress_streak iterations with more errors than edits."
    warning+=$'\n'"Consider: Step back and re-evaluate the approach. Use /phil-connors-checkpoint before trying something different."
  fi

  if [[ -n "$warning" ]]; then
    printf '%s' "$warning"
  fi
}
