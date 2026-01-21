#!/bin/bash

# Phil-Connors Context Update Script
# Updates task context (Tier 2) during a phil-connors loop

set -euo pipefail

# Parse arguments
PRIORITY_FILES=()
CONSTRAINTS=()
SUCCESS_CRITERIA=()
NOTES=()

while [[ $# -gt 0 ]]; do
  case $1 in
    --priority-file|-p)
      [[ -z "${2:-}" ]] && { echo "Error: --priority-file requires a path" >&2; exit 1; }
      PRIORITY_FILES+=("$2")
      shift 2
      ;;
    --constraint|-c)
      [[ -z "${2:-}" ]] && { echo "Error: --constraint requires text" >&2; exit 1; }
      CONSTRAINTS+=("$2")
      shift 2
      ;;
    --success-criterion|-s)
      [[ -z "${2:-}" ]] && { echo "Error: --success-criterion requires text" >&2; exit 1; }
      SUCCESS_CRITERIA+=("$2")
      shift 2
      ;;
    --note|-n)
      [[ -z "${2:-}" ]] && { echo "Error: --note requires text" >&2; exit 1; }
      NOTES+=("$2")
      shift 2
      ;;
    --help|-h)
      cat << 'HELP_EOF'
Phil-Connors Context Update - Evolve task context during iteration

USAGE:
  /phil-connors-context-update [OPTIONS]

OPTIONS:
  --priority-file, -p <path>   Add a priority file (can specify multiple times)
  --constraint, -c <text>      Add a constraint discovered during iteration
  --success-criterion, -s <text> Add a success criterion
  --note, -n <text>            Add a task note
  --help, -h                   Show this help

EXAMPLES:
  /phil-connors-context-update --priority-file src/auth/jwt.ts
  /phil-connors-context-update -p src/auth.ts -c "No external deps" -s "Tests pass"
  /phil-connors-context-update --note "JWT library uses async patterns"

WHY USE THIS:
  Task context (Tier 2) is more permanent than learnings (Tier 3).
  Use this for discoveries that should always be visible, not summarized.
HELP_EOF
      exit 0
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      echo "Use --help to see available options" >&2
      exit 1
      ;;
  esac
done

# Validate at least one update is provided
if [[ ${#PRIORITY_FILES[@]} -eq 0 ]] && [[ ${#CONSTRAINTS[@]} -eq 0 ]] && \
   [[ ${#SUCCESS_CRITERIA[@]} -eq 0 ]] && [[ ${#NOTES[@]} -eq 0 ]]; then
  echo "Error: No updates provided" >&2
  echo "" >&2
  echo "Usage: /phil-connors-context-update [OPTIONS]" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --priority-file, -p <path>   Add a priority file" >&2
  echo "  --constraint, -c <text>      Add a constraint" >&2
  echo "  --success-criterion, -s <text> Add a success criterion" >&2
  echo "  --note, -n <text>            Add a note" >&2
  echo "" >&2
  echo "Example:" >&2
  echo "  /phil-connors-context-update -p src/auth.ts -c \"Must be backwards compatible\"" >&2
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
ACTIVE=$(echo "$FRONTMATTER" | grep '^active:' | sed 's/active: *//')
ITERATION=$(echo "$FRONTMATTER" | grep '^iteration:' | sed 's/iteration: *//')

if [[ "$ACTIVE" != "true" ]]; then
  echo "Error: Phil-connors loop is not active" >&2
  exit 1
fi

# Read context file
CONTEXT_FILE=".agent/phil-connors/tasks/$TASK_ID/context.md"

if [[ ! -f "$CONTEXT_FILE" ]]; then
  echo "Error: Task context file not found: $CONTEXT_FILE" >&2
  exit 1
fi

# Parse existing YAML arrays from frontmatter
CONTEXT_FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$CONTEXT_FILE")

# Extract existing arrays (handle YAML array format)
EXISTING_PRIORITY_FILES=$(echo "$CONTEXT_FRONTMATTER" | grep '^priority_files:' | sed 's/priority_files: *//')
EXISTING_CONSTRAINTS=$(echo "$CONTEXT_FRONTMATTER" | grep '^constraints:' | sed 's/constraints: *//')
EXISTING_SUCCESS_CRITERIA=$(echo "$CONTEXT_FRONTMATTER" | grep '^success_criteria:' | sed 's/success_criteria: *//')

# Function to update YAML array
update_yaml_array() {
  local current="$1"
  shift
  local new_items=("$@")

  # Start with current (strip brackets)
  local result="${current#[}"
  result="${result%]}"

  # Add new items
  for item in "${new_items[@]}"; do
    if [[ -n "$result" ]]; then
      result="$result, \"$item\""
    else
      result="\"$item\""
    fi
  done

  echo "[$result]"
}

# Update priority_files
if [[ ${#PRIORITY_FILES[@]} -gt 0 ]]; then
  NEW_PRIORITY_FILES=$(update_yaml_array "$EXISTING_PRIORITY_FILES" "${PRIORITY_FILES[@]}")
  TEMP_FILE="${CONTEXT_FILE}.tmp.$$"
  sed "s|^priority_files:.*|priority_files: $NEW_PRIORITY_FILES|" "$CONTEXT_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$CONTEXT_FILE"
fi

# Update constraints
if [[ ${#CONSTRAINTS[@]} -gt 0 ]]; then
  NEW_CONSTRAINTS=$(update_yaml_array "$EXISTING_CONSTRAINTS" "${CONSTRAINTS[@]}")
  TEMP_FILE="${CONTEXT_FILE}.tmp.$$"
  sed "s|^constraints:.*|constraints: $NEW_CONSTRAINTS|" "$CONTEXT_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$CONTEXT_FILE"
fi

# Update success_criteria
if [[ ${#SUCCESS_CRITERIA[@]} -gt 0 ]]; then
  NEW_SUCCESS_CRITERIA=$(update_yaml_array "$EXISTING_SUCCESS_CRITERIA" "${SUCCESS_CRITERIA[@]}")
  TEMP_FILE="${CONTEXT_FILE}.tmp.$$"
  sed "s|^success_criteria:.*|success_criteria: $NEW_SUCCESS_CRITERIA|" "$CONTEXT_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$CONTEXT_FILE"
fi

# Append notes to Notes section (not in frontmatter)
if [[ ${#NOTES[@]} -gt 0 ]]; then
  # Find the Notes section and append
  TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  for note in "${NOTES[@]}"; do
    echo "- [Iteration $ITERATION, $TIMESTAMP] $note" >> "$CONTEXT_FILE"
  done
fi

# Append priority files to Priority Files section
if [[ ${#PRIORITY_FILES[@]} -gt 0 ]]; then
  # Check if Priority Files section marker exists, append there
  if grep -q "### Priority Files" "$CONTEXT_FILE"; then
    # Append after the marker (find line number, append after)
    LINE_NUM=$(grep -n "### Priority Files" "$CONTEXT_FILE" | head -1 | cut -d: -f1)
    if [[ -n "$LINE_NUM" ]]; then
      TEMP_FILE="${CONTEXT_FILE}.tmp.$$"
      head -n "$LINE_NUM" "$CONTEXT_FILE" > "$TEMP_FILE"
      for pf in "${PRIORITY_FILES[@]}"; do
        echo "- \`$pf\` (added iteration $ITERATION)" >> "$TEMP_FILE"
      done
      tail -n +$((LINE_NUM + 1)) "$CONTEXT_FILE" >> "$TEMP_FILE"
      mv "$TEMP_FILE" "$CONTEXT_FILE"
    fi
  fi
fi

# Append constraints to Constraints section
if [[ ${#CONSTRAINTS[@]} -gt 0 ]]; then
  if grep -q "### Constraints" "$CONTEXT_FILE"; then
    LINE_NUM=$(grep -n "### Constraints" "$CONTEXT_FILE" | head -1 | cut -d: -f1)
    if [[ -n "$LINE_NUM" ]]; then
      TEMP_FILE="${CONTEXT_FILE}.tmp.$$"
      head -n "$LINE_NUM" "$CONTEXT_FILE" > "$TEMP_FILE"
      for c in "${CONSTRAINTS[@]}"; do
        echo "- $c (added iteration $ITERATION)" >> "$TEMP_FILE"
      done
      tail -n +$((LINE_NUM + 1)) "$CONTEXT_FILE" >> "$TEMP_FILE"
      mv "$TEMP_FILE" "$CONTEXT_FILE"
    fi
  fi
fi

# Output summary
echo "=== Task Context Updated ==="
echo ""
echo "Task ID: $TASK_ID"
echo "Iteration: $ITERATION"
echo ""

if [[ ${#PRIORITY_FILES[@]} -gt 0 ]]; then
  echo "Priority files added:"
  for pf in "${PRIORITY_FILES[@]}"; do
    echo "  - $pf"
  done
fi

if [[ ${#CONSTRAINTS[@]} -gt 0 ]]; then
  echo "Constraints added:"
  for c in "${CONSTRAINTS[@]}"; do
    echo "  - $c"
  done
fi

if [[ ${#SUCCESS_CRITERIA[@]} -gt 0 ]]; then
  echo "Success criteria added:"
  for s in "${SUCCESS_CRITERIA[@]}"; do
    echo "  - $s"
  done
fi

if [[ ${#NOTES[@]} -gt 0 ]]; then
  echo "Notes added:"
  for n in "${NOTES[@]}"; do
    echo "  - $n"
  done
fi

echo ""
echo "Context file updated: $CONTEXT_FILE"
echo "These updates will be visible in all future iterations (Tier 2)."
