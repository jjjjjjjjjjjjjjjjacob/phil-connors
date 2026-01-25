#!/bin/bash

# Phil-Connors Stop Hook
# Prevents session exit when a phil-connors loop is active
# Injects THREE-TIER SKILL HIERARCHY into systemMessage every iteration

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Check for state file
STATE_FILE=".agent/phil-connors/state.md"

if [[ ! -f "$STATE_FILE" ]]; then
  # No active loop - allow exit
  exit 0
fi

# Source shared libraries
HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="$HOOK_DIR/../scripts"
source "$SCRIPTS_DIR/lib/parse-state.sh"
source "$SCRIPTS_DIR/lib/state-update.sh"
source "$SCRIPTS_DIR/lib/inject-learnings.sh"
source "$SCRIPTS_DIR/lib/stall-detection.sh"

# Parse state frontmatter using shared library
parse_state "$STATE_FILE"

ACTIVE="${PC_ACTIVE:-false}"
ITERATION="${PC_ITERATION:-1}"
MAX_ITERATIONS="${PC_MAX_ITERATIONS:-20}"
COMPLETION_PROMISE="${PC_COMPLETION_PROMISE:-}"
TASK_ID="${PC_TASK_ID:-}"
LEARNING_COUNT="${PC_LEARNING_COUNT:-0}"
SUMMARIZATION_THRESHOLD="${PC_SUMMARIZATION_THRESHOLD:-10}"
CONTINUATION_PROMPT="${PC_CONTINUATION_PROMPT:-}"
MAX_CONTINUATIONS="${PC_MAX_CONTINUATIONS:-0}"
MIN_CONTINUATIONS="${PC_MIN_CONTINUATIONS:-0}"
CONTINUATION_COUNT="${PC_CONTINUATION_COUNT:-0}"
AUTO_CHECKPOINT="${PC_AUTO_CHECKPOINT:-false}"
AUTO_CHECKPOINT_INTERVAL="${PC_AUTO_CHECKPOINT_INTERVAL:-0}"
LAST_SUMMARIZATION_AT="${PC_LAST_SUMMARIZATION_AT:-null}"

# Flag for continuation mode
CONTINUING=false

# Validate active state
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Phil-Connors loop: State file corrupted" >&2
  state_set_inactive "$STATE_FILE" 2>/dev/null || true
  exit 0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Phil-Connors loop: Max iterations ($MAX_ITERATIONS) reached." >&2
  state_set_inactive "$STATE_FILE"
  exit 0
fi

# Get transcript path
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

# === SESSION ISOLATION ===
# Prevent orphaned loops from triggering in unrelated sessions.
# Store transcript path on first iteration; validate it matches on subsequent iterations.
SESSION_TRANSCRIPT="${PC_SESSION_TRANSCRIPT:-}"

# Check if session_transcript field exists in state file (new loops have it, old ones don't)
HAS_SESSION_FIELD=$(grep -c '^session_transcript:' "$STATE_FILE" 2>/dev/null || echo "0")

if [[ "$HAS_SESSION_FIELD" -eq 0 ]]; then
  # Old loop created before session isolation was added - treat as orphaned
  echo "Phil-Connors: Legacy loop detected (no session tracking). Deactivating." >&2
  state_set_inactive "$STATE_FILE"
  exit 0
elif [[ -z "$SESSION_TRANSCRIPT" ]]; then
  # New loop, first iteration - store the transcript path for session isolation
  state_update "$STATE_FILE" "session_transcript" "\"$TRANSCRIPT_PATH\""
elif [[ "$SESSION_TRANSCRIPT" != "$TRANSCRIPT_PATH" ]]; then
  # Different session - orphaned loop detected
  echo "Phil-Connors: Orphaned loop detected (different session). Deactivating." >&2
  state_set_inactive "$STATE_FILE"
  exit 0
fi

# === PASSTHROUGH COMMAND DETECTION ===
# These commands should NOT count as loop iterations or trigger continuation.
# Includes: read-only info commands, management commands, and aliases.
PASSTHROUGH_COMMANDS="phil-connors-help|phil-connors-status|phil-connors-search|phil-connors-checkpoints|list-phil-connors|cancel-phil-connors|pause-phil-connors|resume-phil-connors"

if [[ -f "$TRANSCRIPT_PATH" ]]; then
  # Extract last user message from transcript
  LAST_USER_MSG=$(grep '"role":"user"' "$TRANSCRIPT_PATH" | tail -1 | jq -r '.message.content[] | select(.type=="text") | .text' 2>/dev/null || echo "")

  # Check if this was a passthrough command - allow exit without affecting loop
  if echo "$LAST_USER_MSG" | grep -qiE "/(${PASSTHROUGH_COMMANDS})(\s|$)"; then
    exit 0
  fi
fi

# Get last assistant output for completion promise check
LAST_OUTPUT=""

if [[ -f "$TRANSCRIPT_PATH" ]]; then
  if grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
    LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
    LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
      .message.content |
      map(select(.type == "text")) |
      map(.text) |
      join("\n")
    ' 2>/dev/null || echo "")
  fi
fi

# === CHECK FOR COMPLETION PROMISE ===
# Continuation only triggers AFTER a completion promise is detected
PROMISE_DETECTED=false
PROMISE_TEXT=""

if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]] && [[ -n "$LAST_OUTPUT" ]]; then
  PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")
  if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
    PROMISE_DETECTED=true
  fi
fi

if [[ "$PROMISE_DETECTED" == "true" ]]; then
  # Completion promise detected - check if continuation should happen
  # Continuation triggers if: continuation_prompt is set AND
  #   (below min_continuations OR (max_continuations > 0 AND below max_continuations))
  SHOULD_CONTINUE=false

  if [[ -n "$CONTINUATION_PROMPT" ]] && [[ "$CONTINUATION_COUNT" =~ ^[0-9]+$ ]]; then
    # Check min_continuations (guarantees at least N continuations)
    if [[ "$MIN_CONTINUATIONS" =~ ^[0-9]+$ ]] && [[ $MIN_CONTINUATIONS -gt 0 ]] && \
       [[ $CONTINUATION_COUNT -lt $MIN_CONTINUATIONS ]]; then
      SHOULD_CONTINUE=true
    fi

    # Check max_continuations (allows up to N continuations if set)
    if [[ "$MAX_CONTINUATIONS" =~ ^[0-9]+$ ]] && [[ $MAX_CONTINUATIONS -gt 0 ]] && \
       [[ $CONTINUATION_COUNT -lt $MAX_CONTINUATIONS ]]; then
      SHOULD_CONTINUE=true
    fi
  fi

  if [[ "$SHOULD_CONTINUE" == "true" ]]; then
    # Continuation mode: reset iteration, increment continuation count
    NEXT_CONTINUATION=$((CONTINUATION_COUNT + 1))

    # Build appropriate message (stderr so it doesn't corrupt JSON output)
    if [[ $MIN_CONTINUATIONS -gt 0 ]] && [[ $MAX_CONTINUATIONS -gt 0 ]]; then
      echo "Phil-Connors: Task completed. Starting continuation $NEXT_CONTINUATION (min: $MIN_CONTINUATIONS, max: $MAX_CONTINUATIONS)" >&2
    elif [[ $MIN_CONTINUATIONS -gt 0 ]]; then
      echo "Phil-Connors: Task completed. Starting continuation $NEXT_CONTINUATION (min: $MIN_CONTINUATIONS)" >&2
    else
      echo "Phil-Connors: Task completed. Starting continuation $NEXT_CONTINUATION of $MAX_CONTINUATIONS" >&2
    fi

    # Update state file: reset iteration to 1, increment continuation_count
    state_batch_update "$STATE_FILE" \
      "iteration=1" \
      "continuation_count=$NEXT_CONTINUATION" \
      "last_iteration_at=\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""

    CONTINUING=true
    NEXT_ITERATION=1
  else
    # No continuations left or not configured - end loop normally
    echo "Phil-Connors loop: Detected <promise>$COMPLETION_PROMISE</promise>" >&2
    state_set_inactive "$STATE_FILE"
    exit 0
  fi
fi
# If no promise detected, continue normal iteration (handled below)

# === AUTO-SUMMARIZATION CHECK ===
# Only re-summarize if learning_count crossed the threshold since last summarization.
# If last_summarization_at is set, check whether new learnings have been added since.
if [[ "$LEARNING_COUNT" =~ ^[0-9]+$ ]] && [[ "$SUMMARIZATION_THRESHOLD" =~ ^[0-9]+$ ]]; then
  if [[ $LEARNING_COUNT -ge $SUMMARIZATION_THRESHOLD ]]; then
    SHOULD_SUMMARIZE=false
    SUMMARY_FILE=".agent/phil-connors/tasks/$TASK_ID/learned/_summary.md"

    if [[ "$LAST_SUMMARIZATION_AT" == "null" ]] || [[ -z "$LAST_SUMMARIZATION_AT" ]]; then
      # Never summarized - do it
      SHOULD_SUMMARIZE=true
    elif [[ -f "$SUMMARY_FILE" ]]; then
      # Check if the summary's total_learning_count is less than current
      SUMMARIZED_COUNT=$(grep '^total_learning_count:' "$SUMMARY_FILE" 2>/dev/null | sed 's/total_learning_count: *//' | head -1 || echo "0")
      if [[ "$SUMMARIZED_COUNT" =~ ^[0-9]+$ ]] && [[ $LEARNING_COUNT -gt $SUMMARIZED_COUNT ]]; then
        SHOULD_SUMMARIZE=true
      fi
    else
      # Summary file doesn't exist despite timestamp - re-summarize
      SHOULD_SUMMARIZE=true
    fi

    if [[ "$SHOULD_SUMMARIZE" == "true" ]]; then
      if [[ -x "$SCRIPTS_DIR/summarize-learnings.sh" ]]; then
        "$SCRIPTS_DIR/summarize-learnings.sh" "$TASK_ID" 2>/dev/null || true
        # Auto-checkpoint after summarization if enabled
        if [[ "$AUTO_CHECKPOINT" == "true" ]] && [[ -x "$SCRIPTS_DIR/create-checkpoint.sh" ]]; then
          "$SCRIPTS_DIR/create-checkpoint.sh" --auto "Auto-checkpoint after summarization (iteration $ITERATION)" 2>/dev/null || true
        fi
      fi
    fi
  fi
fi

# === AUTO-CHECKPOINT CHECK ===
# Trigger auto-checkpoint on continuation or at interval
if [[ "$AUTO_CHECKPOINT" == "true" ]]; then
  # Auto-checkpoint on continuation
  if [[ "$CONTINUING" == "true" ]] && [[ -x "$SCRIPTS_DIR/create-checkpoint.sh" ]]; then
    "$SCRIPTS_DIR/create-checkpoint.sh" --auto "Auto-checkpoint before continuation $NEXT_CONTINUATION" 2>/dev/null || true
  fi

  # Auto-checkpoint at interval
  if [[ "$AUTO_CHECKPOINT_INTERVAL" =~ ^[0-9]+$ ]] && [[ $AUTO_CHECKPOINT_INTERVAL -gt 0 ]]; then
    if [[ $((ITERATION % AUTO_CHECKPOINT_INTERVAL)) -eq 0 ]] && [[ -x "$SCRIPTS_DIR/create-checkpoint.sh" ]]; then
      "$SCRIPTS_DIR/create-checkpoint.sh" --auto "Auto-checkpoint at iteration $ITERATION (interval: $AUTO_CHECKPOINT_INTERVAL)" 2>/dev/null || true
    fi
  fi
fi

# Update iteration (skip if we just handled continuation)
if [[ "$CONTINUING" != "true" ]]; then
  NEXT_ITERATION=$((ITERATION + 1))
  state_batch_update "$STATE_FILE" \
    "iteration=$NEXT_ITERATION" \
    "last_iteration_at=\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
fi

# === TIER 1: GLOBAL SKILLS (IMMUTABLE) ===
SKILLS_LOCK=""
if [[ -f ".agent/skills-lock.md" ]]; then
  SKILLS_LOCK=$(cat ".agent/skills-lock.md")
else
  SKILLS_LOCK="[No global skills file found at .agent/skills-lock.md]"
fi

# === TIER 2: TASK-SPECIFIC CONTEXT ===
TASK_CONTEXT=""
TASK_CONTEXT_FILE=".agent/phil-connors/tasks/$TASK_ID/context.md"
if [[ -f "$TASK_CONTEXT_FILE" ]]; then
  TASK_CONTEXT=$(cat "$TASK_CONTEXT_FILE")
else
  TASK_CONTEXT="[No task context found]"
fi

# === TIER 3: SMART LEARNING INJECTION (Context-Aware) ===
LEARNINGS=$(build_learning_injection "$TASK_ID" "$NEXT_ITERATION" "$TRANSCRIPT_PATH")

# Extract original prompt
ORIGINAL_PROMPT=$(awk '/^original_prompt:/{flag=1; next} flag && /^[a-z_]+:/{flag=0} flag' "$STATE_FILE" | sed 's/^  //')
if [[ -z "$ORIGINAL_PROMPT" ]]; then
  ORIGINAL_PROMPT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")
fi

# === ITERATION PROGRESS TRACKING ===
# Extract metrics from transcript using JSON-aware parsing
TOOL_CALLS=0
FILES_READ=0
FILES_EDITED=0
ERRORS_FOUND=0
LEARNINGS_ADDED=0
ITERATION_SUMMARY=""

if [[ -f "$TRANSCRIPT_PATH" ]]; then
  # Count tool_use blocks in transcript (reliable JSON field)
  TOOL_CALLS=$(grep -c '"type":"tool_use"' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

  # Count file read/edit operations by tool name in JSON
  FILES_READ=$(grep -o '"name":"Read"' "$TRANSCRIPT_PATH" 2>/dev/null | wc -l | tr -d ' ' || echo "0")
  FILES_EDITED=$(grep -oE '"name":"(Edit|Write)"' "$TRANSCRIPT_PATH" 2>/dev/null | wc -l | tr -d ' ' || echo "0")

  # Count errors from tool_result blocks with is_error
  ERRORS_FOUND=$(grep -c '"is_error":true' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")

  # Count phil-connors-learn invocations (from Bash tool calls)
  LEARNINGS_ADDED=$(grep -c 'phil-connors-learn\|add-learning\.sh' "$TRANSCRIPT_PATH" 2>/dev/null || echo "0")
fi

# Build iteration summary line
TIMESTAMP=$(date +"%H:%M:%S")
if [[ "$CONTINUING" == "true" ]]; then
  ITERATION_SUMMARY="- Iteration $ITERATION → Continuation $NEXT_CONTINUATION ($TIMESTAMP): Task completed, starting next"
else
  ITERATION_SUMMARY="- Iteration $ITERATION ($TIMESTAMP): tools=$TOOL_CALLS, reads=$FILES_READ, edits=$FILES_EDITED, errors=$ERRORS_FOUND"
fi

# Append to progress history in state file (after the --- block)
if [[ -n "$ITERATION_SUMMARY" ]]; then
  echo "$ITERATION_SUMMARY" >> "$STATE_FILE"
fi

# === STALL DETECTION ===
STALL_WARNING=$(detect_stall "$STATE_FILE" "$NEXT_ITERATION" "$FILES_EDITED" "$ERRORS_FOUND")

# === ITERATION LIMIT WARNING ===
LIMIT_WARNING=""
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  REMAINING=$((MAX_ITERATIONS - NEXT_ITERATION))
  THRESHOLD=$(( (MAX_ITERATIONS * 80) / 100 ))
  if [[ $NEXT_ITERATION -ge $THRESHOLD ]] && [[ $REMAINING -gt 0 ]]; then
    LIMIT_WARNING="[ITERATION LIMIT] $REMAINING iterations remaining (${NEXT_ITERATION}/${MAX_ITERATIONS}). Prioritize completing the task or output your completion promise."
  fi
fi

# === BUILD COMPREHENSIVE SYSTEM MESSAGE ===
ITER_INFO="Iteration: $NEXT_ITERATION"
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  ITER_INFO="$ITER_INFO of $MAX_ITERATIONS"
fi

# Build continuation header if in continuation mode
CONTINUATION_HEADER=""
if [[ "$CONTINUING" == "true" ]]; then
  # Build header line based on what's configured
  if [[ $MIN_CONTINUATIONS -gt 0 ]] && [[ $MAX_CONTINUATIONS -gt 0 ]]; then
    CONT_HEADER_LINE=">>> CONTINUATION $NEXT_CONTINUATION (min: $MIN_CONTINUATIONS, max: $MAX_CONTINUATIONS) <<<"
  elif [[ $MIN_CONTINUATIONS -gt 0 ]]; then
    CONT_HEADER_LINE=">>> CONTINUATION $NEXT_CONTINUATION (min: $MIN_CONTINUATIONS) <<<"
  else
    CONT_HEADER_LINE=">>> CONTINUATION $NEXT_CONTINUATION of $MAX_CONTINUATIONS <<<"
  fi

  CONTINUATION_HEADER="================================================================================
$CONT_HEADER_LINE
================================================================================
PREVIOUS TASK COMPLETED! Now respond to this continuation prompt:

$CONTINUATION_PROMPT

Work on the next task. When THAT task is complete, output:
<promise>$COMPLETION_PROMISE</promise>

================================================================================

"
fi

# Build instruction block - full on first iteration, compact on subsequent
if [[ $NEXT_ITERATION -le 2 ]]; then
  INSTRUCTIONS="================================================================================
>>> HOW TO COMPLETE THIS LOOP <<<
================================================================================
When the task is TRULY complete, output: <promise>$COMPLETION_PROMISE</promise>
The <promise> tags are REQUIRED. The text inside must match EXACTLY.

Record learnings: /phil-connors-learn \"insight\" (persists across iterations)
Categories: -c discovery|pattern|anti-pattern|file-location|constraint|solution|blocker
Importance: -i low|medium|high|critical

================================================================================
"
else
  INSTRUCTIONS="Completion: <promise>$COMPLETION_PROMISE</promise> | Learnings: /phil-connors-learn \"insight\"
"
fi

SYSTEM_MSG="${CONTINUATION_HEADER}${INSTRUCTIONS}
=== PHIL-CONNORS ITERATION $NEXT_ITERATION ===

$ITER_INFO
Task ID: $TASK_ID
Learnings recorded: $LEARNING_COUNT
Last iteration: tools=$TOOL_CALLS, reads=$FILES_READ, edits=$FILES_EDITED, errors=$ERRORS_FOUND
$(if [[ -n "$STALL_WARNING" ]]; then echo ""; echo "$STALL_WARNING"; fi)$(if [[ -n "$LIMIT_WARNING" ]]; then echo ""; echo "$LIMIT_WARNING"; fi)
================================================================================
TIER 1: GLOBAL SKILLS (IMMUTABLE - ALWAYS APPLY THESE)
================================================================================
$SKILLS_LOCK

================================================================================
TIER 2: TASK CONTEXT (NON-EDITABLE IN LOOP)
================================================================================
$TASK_CONTEXT

================================================================================
TIER 3: ACCUMULATED LEARNINGS
================================================================================
$LEARNINGS

================================================================================
ORIGINAL PROMPT
================================================================================
$ORIGINAL_PROMPT"

# Output JSON to block stop and continue loop
jq -n \
  --arg prompt "$ORIGINAL_PROMPT" \
  --arg msg "$SYSTEM_MSG" \
  '{
    "decision": "block",
    "reason": $prompt,
    "systemMessage": $msg
  }'

exit 0
