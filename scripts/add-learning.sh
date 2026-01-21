#!/bin/bash

# Phil-Connors Add Learning Script
# Adds a learning to the current task's learned directory

set -euo pipefail

# Parse arguments
LEARNING_TEXT=""
CATEGORY="discovery"
IMPORTANCE="medium"
RELATED_FILES=()

# Valid categories
VALID_CATEGORIES=("discovery" "pattern" "anti-pattern" "file-location" "constraint" "solution" "blocker")

while [[ $# -gt 0 ]]; do
  case $1 in
    --category|-c)
      [[ -z "${2:-}" ]] && { echo "Error: --category requires a value" >&2; exit 1; }
      CATEGORY="$2"
      # Validate category
      VALID=false
      for vc in "${VALID_CATEGORIES[@]}"; do
        if [[ "$vc" == "$CATEGORY" ]]; then
          VALID=true
          break
        fi
      done
      if [[ "$VALID" != "true" ]]; then
        echo "Error: Invalid category '$CATEGORY'" >&2
        echo "Valid categories: ${VALID_CATEGORIES[*]}" >&2
        exit 1
      fi
      shift 2
      ;;
    --importance|-i)
      [[ -z "${2:-}" ]] && { echo "Error: --importance requires a value" >&2; exit 1; }
      if [[ "$2" != "low" && "$2" != "medium" && "$2" != "high" && "$2" != "critical" ]]; then
        echo "Error: Invalid importance '$2'. Use: low, medium, high, critical" >&2
        exit 1
      fi
      IMPORTANCE="$2"
      shift 2
      ;;
    --file|-f)
      [[ -z "${2:-}" ]] && { echo "Error: --file requires a path" >&2; exit 1; }
      RELATED_FILES+=("$2")
      shift 2
      ;;
    --help|-h)
      cat << 'HELP_EOF'
Phil-Connors Learn - Record insights during iteration

USAGE:
  /phil-connors-learn [OPTIONS] "your insight"

OPTIONS:
  --category, -c <cat>   Category for the learning (default: discovery)
                         Valid: discovery, pattern, anti-pattern, file-location,
                                constraint, solution, blocker
  --importance, -i <lvl> Importance level: low, medium, high, critical (default: medium)
  --file, -f <path>      Related file (can specify multiple times)
  --help, -h             Show this help

EXAMPLES:
  /phil-connors-learn "JWT library requires async operations"
  /phil-connors-learn --category pattern "Always use parameterized queries"
  /phil-connors-learn -c anti-pattern -i high "Don't mutate state directly"
  /phil-connors-learn -c file-location -f src/auth/jwt.ts "Auth logic lives here"
  /phil-connors-learn -c solution "Fixed by adding null check at line 42"
HELP_EOF
      exit 0
      ;;
    *)
      if [[ -z "$LEARNING_TEXT" ]]; then
        LEARNING_TEXT="$1"
      else
        LEARNING_TEXT="$LEARNING_TEXT $1"
      fi
      shift
      ;;
  esac
done

if [[ -z "$LEARNING_TEXT" ]]; then
  echo "Error: No learning text provided" >&2
  echo "" >&2
  echo "Usage: /phil-connors-learn [OPTIONS] \"your insight or discovery\"" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --category, -c <cat>   Category: discovery, pattern, anti-pattern, file-location, constraint, solution, blocker" >&2
  echo "  --importance, -i <lvl> Importance: low, medium, high, critical" >&2
  echo "  --file, -f <path>      Related file (can specify multiple)" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /phil-connors-learn \"JWT library requires async operations\"" >&2
  echo "  /phil-connors-learn --category pattern \"Always validate inputs\"" >&2
  echo "  /phil-connors-learn -c anti-pattern -i high \"Don't mutate state directly\"" >&2
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

# Format related files as YAML array
if [[ ${#RELATED_FILES[@]} -gt 0 ]]; then
  FILES_YAML="["
  for f in "${RELATED_FILES[@]}"; do
    FILES_YAML+="\"$f\", "
  done
  FILES_YAML="${FILES_YAML%, }]"
else
  FILES_YAML="[]"
fi

# Format category display name for header (capitalize first letter of each word)
CATEGORY_DISPLAY=$(echo "$CATEGORY" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

cat > "$LEARNING_FILE" << LEARNING_EOF
---
learning_id: $NEXT_ID
iteration: $ITERATION
timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
category: "$CATEGORY"
importance: "$IMPORTANCE"
related_files: $FILES_YAML
---

## Learning #$NEXT_ID (Iteration $ITERATION) [$CATEGORY_DISPLAY]

$LEARNING_TEXT
LEARNING_EOF

# Update learning count in state
TEMP_FILE="${STATE_FILE}.tmp.$$"
sed "s/^learning_count: .*/learning_count: $NEXT_ID/" "$STATE_FILE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

echo "Learning #$NEXT_ID added to task '$TASK_ID'"
echo "  Category: $CATEGORY"
echo "  Importance: $IMPORTANCE"
if [[ ${#RELATED_FILES[@]} -gt 0 ]]; then
  echo "  Related files: ${RELATED_FILES[*]}"
fi
echo "  File: $LEARNING_FILE"
echo ""
echo "This learning will be included in future iterations."
