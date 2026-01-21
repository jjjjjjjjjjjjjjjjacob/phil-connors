#!/bin/bash

# Phil-Connors Loop Setup Script
# Creates three-tier skill hierarchy state for persistent context loops

set -euo pipefail

# Parse arguments
PROMPT_PARTS=()
MAX_ITERATIONS=20
COMPLETION_PROMISE="null"
TASK_ID=""
SUMMARIZATION_THRESHOLD=10
SKILLS_CONFIG=""
CONTINUATION_PROMPT=""
MAX_CONTINUATIONS=0

while [[ $# -gt 0 ]]; do
  case $1 in
    -h|--help)
      cat << 'HELP_EOF'
Phil-Connors Loop - Iterative development with persistent context

USAGE:
  /phil-connors "PROMPT" [OPTIONS]

ARGUMENTS:
  PROMPT    Initial prompt/task description

OPTIONS:
  --completion-promise '<text>'  Promise phrase to signal completion (REQUIRED)
  --max-iterations <n>           Max iterations (default: 20)
  --task-id '<id>'              Custom task identifier (default: auto-generated)
  --summarize-after <n>         Summarize learnings after N entries (default: 10)
  --skills-config '<text>'      Initial content for .agent/skills-lock.md (overrides template)
  --continuation-prompt '<text>' Prompt to inject after completion for chaining tasks
  --max-continuations <n>        Max task continuations (default: 0 = no chaining)
  -h, --help                    Show this help

DESCRIPTION:
  Phil-Connors creates a self-referential loop with THREE-TIER skill hierarchy:

  Tier 1 - Global Skills (.agent/skills-lock.md): NEVER modified during loop
  Tier 2 - Task Context: Created at loop start, defines constraints
  Tier 3 - Learnings: Accumulated insights, auto-summarized

  Unlike wiggum, global skills are injected EVERY iteration via systemMessage,
  ensuring critical context is never lost.

EXAMPLES:
  /phil-connors "Implement user auth" --completion-promise "Auth complete" --max-iterations 15
  /phil-connors "Fix flaky tests" --task-id "flaky-tests-fix" --completion-promise "Tests stable"

STOPPING:
  - Output <promise>COMPLETION_PROMISE</promise> when done
  - Reach max iterations
  - Use /cancel-phil-connors

ADDING LEARNINGS:
  During any iteration: /phil-connors-learn "insight about the code"
HELP_EOF
      exit 0
      ;;
    --max-iterations)
      [[ -z "${2:-}" ]] && { echo "Error: --max-iterations requires a number" >&2; exit 1; }
      [[ ! "$2" =~ ^[0-9]+$ ]] && { echo "Error: --max-iterations must be a positive integer" >&2; exit 1; }
      MAX_ITERATIONS="$2"
      shift 2
      ;;
    --completion-promise)
      [[ -z "${2:-}" ]] && { echo "Error: --completion-promise requires text" >&2; exit 1; }
      COMPLETION_PROMISE="$2"
      shift 2
      ;;
    --task-id)
      [[ -z "${2:-}" ]] && { echo "Error: --task-id requires text" >&2; exit 1; }
      TASK_ID="$2"
      shift 2
      ;;
    --summarize-after)
      [[ -z "${2:-}" ]] && { echo "Error: --summarize-after requires a number" >&2; exit 1; }
      [[ ! "$2" =~ ^[0-9]+$ ]] && { echo "Error: --summarize-after must be a positive integer" >&2; exit 1; }
      SUMMARIZATION_THRESHOLD="$2"
      shift 2
      ;;
    --skills-config)
      [[ -z "${2:-}" ]] && { echo "Error: --skills-config requires text" >&2; exit 1; }
      SKILLS_CONFIG="$2"
      shift 2
      ;;
    --continuation-prompt)
      [[ -z "${2:-}" ]] && { echo "Error: --continuation-prompt requires text" >&2; exit 1; }
      CONTINUATION_PROMPT="$2"
      shift 2
      ;;
    --max-continuations)
      [[ -z "${2:-}" ]] && { echo "Error: --max-continuations requires a number" >&2; exit 1; }
      [[ ! "$2" =~ ^[0-9]+$ ]] && { echo "Error: --max-continuations must be a positive integer" >&2; exit 1; }
      MAX_CONTINUATIONS="$2"
      shift 2
      ;;
    *)
      PROMPT_PARTS+=("$1")
      shift
      ;;
  esac
done

PROMPT="${PROMPT_PARTS[*]}"

[[ -z "$PROMPT" ]] && { echo "Error: No prompt provided" >&2; exit 1; }

# Generate task ID if not provided
if [[ -z "$TASK_ID" ]]; then
  SLUG=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | cut -c1-30 | sed 's/-$//')
  TASK_ID="${SLUG}-$(date +%Y%m%d%H%M%S)"
fi

# Create directory structure
mkdir -p ".agent/phil-connors/tasks/$TASK_ID/learned"

# Create or update skills-lock.md
if [[ -n "$SKILLS_CONFIG" ]]; then
  # User provided skills config - use it (even if file exists)
  mkdir -p ".agent"
  echo "$SKILLS_CONFIG" > ".agent/skills-lock.md"
  echo "Created .agent/skills-lock.md from --skills-config"
elif [[ ! -f ".agent/skills-lock.md" ]]; then
  # No file exists and no config provided - create template
  mkdir -p ".agent"
  cat > ".agent/skills-lock.md" << 'SKILLS_EOF'
# Global Skills (Tier 1 - IMMUTABLE)

This file is NEVER modified during a phil-connors loop.
Add project-wide patterns, critical files, and essential rules here.

These skills are injected into EVERY iteration via systemMessage,
ensuring you never lose critical context.

## Project Patterns
<!-- Add your project's coding patterns here -->
<!-- Example: Use snake_case for variables, PascalCase for classes -->

## Critical Files
<!-- List files that should never be modified without explicit permission -->
<!-- Example: src/core/engine.ts - core logic, requires careful review -->

## Essential Rules
<!-- Add rules that must always be followed -->
<!-- Example: All database queries must use parameterized statements -->

## Important Context
<!-- Add any context that should persist across all iterations -->
SKILLS_EOF
  echo "Created .agent/skills-lock.md template - populate with project-specific rules"
fi

# Create state file
cat > ".agent/phil-connors/state.md" << STATE_EOF
---
active: true
task_id: "$TASK_ID"
iteration: 1
max_iterations: $MAX_ITERATIONS
completion_promise: "$(echo "$COMPLETION_PROMISE" | sed 's/"/\\"/g')"
continuation_prompt: "$(echo "$CONTINUATION_PROMPT" | sed 's/"/\\"/g')"
max_continuations: $MAX_CONTINUATIONS
continuation_count: 0
original_prompt: |
  $PROMPT
started_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
last_iteration_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
learning_count: 0
last_summarization_at: null
summarization_threshold: $SUMMARIZATION_THRESHOLD
---

## Current Task
$TASK_ID

## Session History
- Iteration 1: Starting task
STATE_EOF

# Create task context file
cat > ".agent/phil-connors/tasks/$TASK_ID/context.md" << CONTEXT_EOF
---
task_id: "$TASK_ID"
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
priority_files: []
constraints: []
success_criteria: []
nested_context: []
---

## Task: $TASK_ID

### Original Prompt
$PROMPT

### Completion Criteria
$(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "- $COMPLETION_PROMISE"; else echo "- (none specified)"; fi)

### Priority Files
<!-- Files critical to this task - add as discovered -->

### Constraints
<!-- Add constraints discovered during iteration -->

### Notes
<!-- Task-specific notes -->
CONTEXT_EOF

# Output setup message
cat << MSG_EOF
=== Phil-Connors Loop Activated ===

Task ID: $TASK_ID
Iteration: 1
Max iterations: $(if [[ $MAX_ITERATIONS -gt 0 ]]; then echo $MAX_ITERATIONS; else echo "unlimited"; fi)
Completion promise: $(if [[ "$COMPLETION_PROMISE" != "null" ]]; then echo "$COMPLETION_PROMISE"; else echo "(none - runs until max iterations)"; fi)
$(if [[ -n "$CONTINUATION_PROMPT" ]] && [[ $MAX_CONTINUATIONS -gt 0 ]]; then echo "Continuation: enabled ($MAX_CONTINUATIONS max)"; fi)
Summarize after: $SUMMARIZATION_THRESHOLD learnings

Files created:
- .agent/phil-connors/state.md
- .agent/phil-connors/tasks/$TASK_ID/context.md

Three-Tier Skill Hierarchy Active:
- Tier 1 (IMMUTABLE): .agent/skills-lock.md
- Tier 2 (Task-specific): .agent/phil-connors/tasks/$TASK_ID/context.md
- Tier 3 (Learnings): .agent/phil-connors/tasks/$TASK_ID/learned/

IMPORTANT: Global skills from .agent/skills-lock.md are injected into EVERY
iteration via systemMessage. You will NEVER lose this context.

To add learnings: /phil-connors-learn "your insight"
To cancel: /cancel-phil-connors

MSG_EOF

echo ""
echo "$PROMPT"

if [[ "$COMPLETION_PROMISE" != "null" ]]; then
  echo ""
  echo "======================================================="
  echo "COMPLETION PROMISE: $COMPLETION_PROMISE"
  echo "Output <promise>$COMPLETION_PROMISE</promise> when TRUE"
  echo "======================================================="
fi
