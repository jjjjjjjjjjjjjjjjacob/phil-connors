#!/bin/bash

# Phil-Connors Add Learning Script
# Adds a learning to the current task's learned directory

set -euo pipefail

# Parse arguments
LEARNING_TEXT=""
CATEGORY="discovery"
IMPORTANCE="medium"
RELATED_FILES=()
UPDATE_ID=""
DEPRECATE_ID=""
LIST_MODE=false

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
    --update|-u)
      [[ -z "${2:-}" ]] && { echo "Error: --update requires a learning ID" >&2; exit 1; }
      UPDATE_ID="$2"
      shift 2
      ;;
    --deprecate|-d)
      [[ -z "${2:-}" ]] && { echo "Error: --deprecate requires a learning ID" >&2; exit 1; }
      DEPRECATE_ID="$2"
      shift 2
      ;;
    --list|-l)
      LIST_MODE=true
      shift
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
  --update, -u <id>      Update an existing learning by ID (e.g., --update 3)
  --deprecate, -d <id>   Mark a learning as deprecated (superseded or no longer relevant)
  --list, -l             List all learnings with their IDs and status
  --help, -h             Show this help

EXAMPLES:
  # Add a new learning
  /phil-connors-learn "JWT library requires async operations"
  /phil-connors-learn --category pattern "Always use parameterized queries"
  /phil-connors-learn -c anti-pattern -i high "Don't mutate state directly"
  /phil-connors-learn -c file-location -f src/auth/jwt.ts "Auth logic lives here"

  # Update an existing learning (change importance or add content)
  /phil-connors-learn --update 3 -i critical "Updated: This is even more important"
  /phil-connors-learn -u 5 --category anti-pattern "Changed category for this learning"

  # Mark a learning as deprecated (won't show in summaries)
  /phil-connors-learn --deprecate 2

  # List all learnings to see IDs
  /phil-connors-learn --list
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

# Source shared libraries
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/lib/parse-state.sh"
source "$SCRIPT_DIR/lib/state-update.sh"

# Read and validate state
STATE_FILE=".agent/phil-connors/state.md"
validate_state_exists "$STATE_FILE" || exit 1
validate_state_active || exit 1

TASK_ID="${PC_TASK_ID:-}"
ITERATION="${PC_ITERATION:-1}"
LEARNING_COUNT="${PC_LEARNING_COUNT:-0}"

# Ensure learned directory exists
LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"
mkdir -p "$LEARNED_DIR"

# === LIST MODE ===
if [[ "$LIST_MODE" == "true" ]]; then
  echo "=== Learnings for Task: $TASK_ID ==="
  echo ""

  LEARNING_FILES=$(ls -1 "$LEARNED_DIR"/*.md 2>/dev/null | grep -v '_summary.md' | sort || echo "")

  if [[ -z "$LEARNING_FILES" ]]; then
    echo "No learnings recorded yet."
    exit 0
  fi

  printf "%-4s %-12s %-10s %-10s %s\n" "ID" "Category" "Importance" "Status" "Preview"
  printf "%-4s %-12s %-10s %-10s %s\n" "---" "------------" "----------" "----------" "-------"

  while IFS= read -r file; do
    if [[ -f "$file" ]]; then
      ID=$(basename "$file" .md)
      CONTENT=$(cat "$file")
      CAT=$(echo "$CONTENT" | grep '^category:' | sed 's/category: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
      IMP=$(echo "$CONTENT" | grep '^importance:' | sed 's/importance: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
      DEP=$(echo "$CONTENT" | grep '^deprecated:' | sed 's/deprecated: *//' | head -1 || echo "")

      # Get first line of learning text (after frontmatter, skip ## header)
      PREVIEW=$(echo "$CONTENT" | awk 'BEGIN{i=0} /^---$/{i++; next} i>=2 && NF' | grep -v '^##' | head -1 | cut -c1-40)
      if [[ ${#PREVIEW} -gt 39 ]]; then
        PREVIEW="${PREVIEW}..."
      fi
      [[ -z "$PREVIEW" ]] && PREVIEW="(no preview)"

      STATUS="active"
      if [[ "$DEP" == "true" ]]; then
        STATUS="deprecated"
      fi

      printf "%-4s %-12s %-10s %-10s %s\n" "$ID" "$CAT" "$IMP" "$STATUS" "$PREVIEW"
    fi
  done <<< "$LEARNING_FILES"

  echo ""
  echo "Total: $(echo "$LEARNING_FILES" | wc -l | tr -d ' ') learnings"
  exit 0
fi

# === DEPRECATE MODE ===
if [[ -n "$DEPRECATE_ID" ]]; then
  PADDED_DEP_ID=$(printf "%03d" "$DEPRECATE_ID")
  DEP_FILE="$LEARNED_DIR/${PADDED_DEP_ID}.md"

  if [[ ! -f "$DEP_FILE" ]]; then
    echo "Error: Learning #$DEPRECATE_ID not found" >&2
    echo "Use /phil-connors-learn --list to see available learnings" >&2
    exit 1
  fi

  # Check if already deprecated
  if grep -q '^deprecated: true' "$DEP_FILE"; then
    echo "Learning #$DEPRECATE_ID is already deprecated"
    exit 0
  fi

  # Add deprecated field to frontmatter
  TEMP_FILE="${DEP_FILE}.tmp.$$"
  sed '/^---$/,/^---$/{
    /^importance:/a\
deprecated: true\
deprecated_at: "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"\
deprecated_in_iteration: '"$ITERATION"'
  }' "$DEP_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$DEP_FILE"

  echo "Learning #$DEPRECATE_ID marked as deprecated"
  echo "  It will no longer appear in summaries"
  echo "  Use --update to modify, or delete the file to remove completely"
  exit 0
fi

# === UPDATE MODE ===
if [[ -n "$UPDATE_ID" ]]; then
  PADDED_UPD_ID=$(printf "%03d" "$UPDATE_ID")
  UPD_FILE="$LEARNED_DIR/${PADDED_UPD_ID}.md"

  if [[ ! -f "$UPD_FILE" ]]; then
    echo "Error: Learning #$UPDATE_ID not found" >&2
    echo "Use /phil-connors-learn --list to see available learnings" >&2
    exit 1
  fi

  # Read existing content
  EXISTING_CONTENT=$(cat "$UPD_FILE")
  EXISTING_CAT=$(echo "$EXISTING_CONTENT" | grep '^category:' | sed 's/category: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
  EXISTING_IMP=$(echo "$EXISTING_CONTENT" | grep '^importance:' | sed 's/importance: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
  EXISTING_ITER=$(echo "$EXISTING_CONTENT" | grep '^iteration:' | sed 's/iteration: *//' | head -1)
  EXISTING_FILES=$(echo "$EXISTING_CONTENT" | grep '^related_files:' | sed 's/related_files: *//' | head -1)

  # Use existing values as defaults if not provided
  [[ "$CATEGORY" == "discovery" ]] && CATEGORY="$EXISTING_CAT"
  [[ "$IMPORTANCE" == "medium" ]] && IMPORTANCE="$EXISTING_IMP"
  [[ ${#RELATED_FILES[@]} -eq 0 ]] && FILES_YAML="$EXISTING_FILES"

  # If no new text, keep existing text
  if [[ -z "$LEARNING_TEXT" ]]; then
    LEARNING_TEXT=$(echo "$EXISTING_CONTENT" | awk '/^---$/{i++; next} i>=2')
    # Remove the header line (## Learning #N...)
    LEARNING_TEXT=$(echo "$LEARNING_TEXT" | tail -n +3)
  fi

  # Format related files if provided
  if [[ ${#RELATED_FILES[@]} -gt 0 ]]; then
    FILES_YAML="["
    for f in "${RELATED_FILES[@]}"; do
      FILES_YAML+="\"$f\", "
    done
    FILES_YAML="${FILES_YAML%, }]"
  fi

  CATEGORY_DISPLAY=$(echo "$CATEGORY" | tr '-' ' ' | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)} 1')

  cat > "$UPD_FILE" << LEARNING_EOF
---
learning_id: $UPDATE_ID
iteration: $EXISTING_ITER
timestamp: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
category: "$CATEGORY"
importance: "$IMPORTANCE"
related_files: $FILES_YAML
updated_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
updated_in_iteration: $ITERATION
---

## Learning #$UPDATE_ID (Iteration $EXISTING_ITER, Updated Iteration $ITERATION) [$CATEGORY_DISPLAY]

$LEARNING_TEXT
LEARNING_EOF

  echo "Learning #$UPDATE_ID updated"
  echo "  Category: $CATEGORY"
  echo "  Importance: $IMPORTANCE"
  echo "  File: $UPD_FILE"
  exit 0
fi

# === NORMAL ADD MODE - Require learning text ===
if [[ -z "$LEARNING_TEXT" ]]; then
  echo "Error: No learning text provided" >&2
  echo "" >&2
  echo "Usage: /phil-connors-learn [OPTIONS] \"your insight or discovery\"" >&2
  echo "" >&2
  echo "Options:" >&2
  echo "  --category, -c <cat>   Category: discovery, pattern, anti-pattern, file-location, constraint, solution, blocker" >&2
  echo "  --importance, -i <lvl> Importance: low, medium, high, critical" >&2
  echo "  --file, -f <path>      Related file (can specify multiple)" >&2
  echo "  --update, -u <id>      Update existing learning by ID" >&2
  echo "  --deprecate, -d <id>   Mark learning as deprecated" >&2
  echo "  --list, -l             List all learnings" >&2
  echo "" >&2
  echo "Examples:" >&2
  echo "  /phil-connors-learn \"JWT library requires async operations\"" >&2
  echo "  /phil-connors-learn --category pattern \"Always validate inputs\"" >&2
  echo "  /phil-connors-learn -c anti-pattern -i high \"Don't mutate state directly\"" >&2
  exit 1
fi

# Calculate next learning ID
if [[ ! "$LEARNING_COUNT" =~ ^[0-9]+$ ]]; then
  LEARNING_COUNT=0
fi
NEXT_ID=$((LEARNING_COUNT + 1))
PADDED_ID=$(printf "%03d" $NEXT_ID)

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
state_update "$STATE_FILE" "learning_count" "$NEXT_ID"

echo "Learning #$NEXT_ID added to task '$TASK_ID'"
echo "  Category: $CATEGORY"
echo "  Importance: $IMPORTANCE"
if [[ ${#RELATED_FILES[@]} -gt 0 ]]; then
  echo "  Related files: ${RELATED_FILES[*]}"
fi
echo "  File: $LEARNING_FILE"
echo ""
echo "This learning will be included in future iterations."
