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

# Parse state frontmatter
FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE")
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')
MAX_ITERATIONS=$(echo "$FRONTMATTER" | grep '^max_iterations:' | sed 's/max_iterations: *//')
COMPLETION_PROMISE=$(echo "$FRONTMATTER" | grep '^completion_promise:' | sed 's/completion_promise: *//' | sed 's/^"\(.*\)"$/\1/')
TASK_ID=$(echo "$FRONTMATTER" | grep '^task_id:' | sed 's/task_id: *//' | sed 's/^"\(.*\)"$/\1/')
LEARNING_COUNT=$(echo "$FRONTMATTER" | grep '^learning_count:' | sed 's/learning_count: *//' || echo "0")
SUMMARIZATION_THRESHOLD=$(echo "$FRONTMATTER" | grep '^summarization_threshold:' | sed 's/summarization_threshold: *//' || echo "10")

# Validate active state
if [[ "$ACTIVE" != "true" ]]; then
  exit 0
fi

# Validate numeric fields
if [[ ! "$ITERATION" =~ ^[0-9]+$ ]] || [[ ! "$MAX_ITERATIONS" =~ ^[0-9]+$ ]]; then
  echo "Warning: Phil-Connors loop: State file corrupted" >&2
  sed -i.bak 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || \
    sed -i '' 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || true
  exit 0
fi

# Check max iterations
if [[ $MAX_ITERATIONS -gt 0 ]] && [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "Phil-Connors loop: Max iterations ($MAX_ITERATIONS) reached."
  sed -i.bak 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || \
    sed -i '' 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || true
  exit 0
fi

# Get transcript and check for completion promise
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path')

if [[ -f "$TRANSCRIPT_PATH" ]]; then
  if grep -q '"role":"assistant"' "$TRANSCRIPT_PATH"; then
    LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
    LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
      .message.content |
      map(select(.type == "text")) |
      map(.text) |
      join("\n")
    ' 2>/dev/null || echo "")

    # Check completion promise
    if [[ "$COMPLETION_PROMISE" != "null" ]] && [[ -n "$COMPLETION_PROMISE" ]]; then
      PROMISE_TEXT=$(echo "$LAST_OUTPUT" | perl -0777 -pe 's/.*?<promise>(.*?)<\/promise>.*/$1/s; s/^\s+|\s+$//g; s/\s+/ /g' 2>/dev/null || echo "")

      if [[ -n "$PROMISE_TEXT" ]] && [[ "$PROMISE_TEXT" = "$COMPLETION_PROMISE" ]]; then
        echo "Phil-Connors loop: Detected <promise>$COMPLETION_PROMISE</promise>"
        sed -i.bak 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || \
          sed -i '' 's/^active: true/active: false/' "$STATE_FILE" 2>/dev/null || true
        exit 0
      fi
    fi
  fi
fi

# === AUTO-SUMMARIZATION CHECK ===
if [[ "$LEARNING_COUNT" =~ ^[0-9]+$ ]] && [[ "$SUMMARIZATION_THRESHOLD" =~ ^[0-9]+$ ]]; then
  if [[ $LEARNING_COUNT -ge $SUMMARIZATION_THRESHOLD ]]; then
    SCRIPT_DIR="$(dirname "$0")/../scripts"
    if [[ -x "$SCRIPT_DIR/summarize-learnings.sh" ]]; then
      "$SCRIPT_DIR/summarize-learnings.sh" "$TASK_ID" 2>/dev/null || true
    fi
  fi
fi

# Update iteration
NEXT_ITERATION=$((ITERATION + 1))
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^iteration: .*/iteration: $NEXT_ITERATION/" "$STATE_FILE" | \
  sed "s/^last_iteration_at: .*/last_iteration_at: \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"/" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

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

# === TIER 3: SUMMARIZED LEARNINGS ===
LEARNINGS=""
SUMMARY_FILE=".agent/phil-connors/tasks/$TASK_ID/learned/_summary.md"
LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"

if [[ -f "$SUMMARY_FILE" ]]; then
  LEARNINGS=$(cat "$SUMMARY_FILE")
elif [[ -d "$LEARNED_DIR" ]]; then
  # If no summary, include recent individual learnings (last 5)
  RECENT_FILES=$(ls -1 "$LEARNED_DIR"/*.md 2>/dev/null | grep -v '_summary.md' | tail -5 || echo "")
  if [[ -n "$RECENT_FILES" ]]; then
    LEARNINGS="## Recent Learnings (Last 5)"$'\n\n'
    while IFS= read -r file; do
      if [[ -f "$file" ]]; then
        LEARNINGS+="$(cat "$file")"$'\n\n---\n\n'
      fi
    done <<< "$RECENT_FILES"
  fi
fi

if [[ -z "$LEARNINGS" ]]; then
  LEARNINGS="[No learnings recorded yet - use /phil-connors-learn to add insights]"
fi

# Extract original prompt
ORIGINAL_PROMPT=$(awk '/^original_prompt:/{flag=1; next} flag && /^[a-z_]+:/{flag=0} flag' "$STATE_FILE" | sed 's/^  //')
if [[ -z "$ORIGINAL_PROMPT" ]]; then
  ORIGINAL_PROMPT=$(awk '/^---$/{i++; next} i>=2' "$STATE_FILE")
fi

# === BUILD COMPREHENSIVE SYSTEM MESSAGE ===
ITER_INFO="Iteration: $NEXT_ITERATION"
if [[ $MAX_ITERATIONS -gt 0 ]]; then
  ITER_INFO="$ITER_INFO of $MAX_ITERATIONS"
fi

SYSTEM_MSG="================================================================================
>>> HOW TO COMPLETE THIS LOOP - READ THIS FIRST <<<
================================================================================
When the task is TRULY complete, you MUST output EXACTLY this text:

<promise>$COMPLETION_PROMISE</promise>

CRITICAL:
- The <promise> tags are REQUIRED - without them, the loop continues forever
- The text inside must match EXACTLY: $COMPLETION_PROMISE
- Only output this when the statement is genuinely TRUE
- Do NOT just say \"done\" or \"complete\" - you MUST use the <promise> tags

================================================================================
>>> RECORD LEARNINGS - THIS IS IMPORTANT <<<
================================================================================
After EACH significant discovery or insight, you MUST run:

/phil-connors-learn \"your insight here\"

What to record:
- Discoveries about the codebase structure or patterns
- Solutions that worked (or didn't work)
- Important file locations or dependencies found
- Constraints or requirements discovered during iteration
- Anti-patterns to avoid

WHY: Learnings persist across context resets. Without them, you will
rediscover the same things repeatedly. Record insights as you find them!

================================================================================

=== PHIL-CONNORS ITERATION $NEXT_ITERATION ===

$ITER_INFO
Task ID: $TASK_ID
Learnings recorded: $LEARNING_COUNT

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
