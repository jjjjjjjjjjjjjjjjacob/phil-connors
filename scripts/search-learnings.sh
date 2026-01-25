#!/bin/bash

# Phil-Connors Search Learnings Script
# Searches through learnings by keyword, category, or importance

set -euo pipefail

# Parse arguments
QUERY=""
CATEGORY_FILTER=""
IMPORTANCE_FILTER=""
SEARCH_ALL=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --category|-c)
      [[ -z "${2:-}" ]] && { echo "Error: --category requires a value" >&2; exit 1; }
      CATEGORY_FILTER="$2"
      shift 2
      ;;
    --importance|-i)
      [[ -z "${2:-}" ]] && { echo "Error: --importance requires a value" >&2; exit 1; }
      IMPORTANCE_FILTER="$2"
      shift 2
      ;;
    --all|-a)
      SEARCH_ALL=true
      shift
      ;;
    --help|-h)
      cat << 'HELP_EOF'
Phil-Connors Search - Find learnings by keyword, category, or importance

USAGE:
  /phil-connors-search [OPTIONS] "query"

OPTIONS:
  --category, -c <cat>   Filter by category
  --importance, -i <lvl> Filter by importance (low, medium, high, critical)
  --all, -a              Search all tasks, not just current
  --help, -h             Show this help

EXAMPLES:
  /phil-connors-search "auth"                    # Find learnings mentioning "auth"
  /phil-connors-search -c pattern                # All pattern learnings
  /phil-connors-search -i critical               # All critical learnings
  /phil-connors-search "token" -c anti-pattern   # Anti-patterns about tokens
  /phil-connors-search --all "database"          # Search all tasks
HELP_EOF
      exit 0
      ;;
    *)
      if [[ -z "$QUERY" ]]; then
        QUERY="$1"
      else
        QUERY="$QUERY $1"
      fi
      shift
      ;;
  esac
done

# If no filters and no query, show help
if [[ -z "$QUERY" ]] && [[ -z "$CATEGORY_FILTER" ]] && [[ -z "$IMPORTANCE_FILTER" ]]; then
  echo "Usage: /phil-connors-search [OPTIONS] \"query\""
  echo ""
  echo "At least one of: query text, --category, or --importance is required."
  echo "Use --help for more options."
  exit 1
fi

# Determine search directories
SEARCH_DIRS=()

if [[ "$SEARCH_ALL" == "true" ]]; then
  # Search all tasks
  if [[ -d ".agent/phil-connors/tasks" ]]; then
    for task_dir in .agent/phil-connors/tasks/*/learned; do
      [[ -d "$task_dir" ]] && SEARCH_DIRS+=("$task_dir")
    done
  fi
else
  # Search current task only
  STATE_FILE=".agent/phil-connors/state.md"
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  source "$SCRIPT_DIR/lib/parse-state.sh"

  validate_state_exists "$STATE_FILE" || {
    echo "Use --all to search all tasks, or start a loop first." >&2
    exit 1
  }

  TASK_ID="${PC_TASK_ID:-}"
  LEARNED_DIR=".agent/phil-connors/tasks/$TASK_ID/learned"

  if [[ -d "$LEARNED_DIR" ]]; then
    SEARCH_DIRS+=("$LEARNED_DIR")
  fi
fi

if [[ ${#SEARCH_DIRS[@]} -eq 0 ]]; then
  echo "No learnings found to search."
  exit 0
fi

# Search function
RESULTS=()
MATCH_COUNT=0

for dir in "${SEARCH_DIRS[@]}"; do
  for file in "$dir"/*.md; do
    [[ -f "$file" ]] || continue
    [[ "$(basename "$file")" == "_summary.md" ]] && continue

    CONTENT=$(cat "$file")

    # Extract metadata
    FILE_CAT=$(echo "$CONTENT" | grep '^category:' | sed 's/category: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
    FILE_IMP=$(echo "$CONTENT" | grep '^importance:' | sed 's/importance: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
    FILE_DEP=$(echo "$CONTENT" | grep '^deprecated:' | sed 's/deprecated: *//' | head -1 || echo "")
    FILE_ID=$(echo "$CONTENT" | grep '^learning_id:' | sed 's/learning_id: *//' | head -1)
    FILE_ITER=$(echo "$CONTENT" | grep '^iteration:' | sed 's/iteration: *//' | head -1)

    # Skip deprecated unless explicitly searching for them
    if [[ "$FILE_DEP" == "true" ]]; then
      continue
    fi

    # Apply category filter
    if [[ -n "$CATEGORY_FILTER" ]] && [[ "$FILE_CAT" != "$CATEGORY_FILTER" ]]; then
      continue
    fi

    # Apply importance filter
    if [[ -n "$IMPORTANCE_FILTER" ]] && [[ "$FILE_IMP" != "$IMPORTANCE_FILTER" ]]; then
      continue
    fi

    # Apply text query (case-insensitive)
    if [[ -n "$QUERY" ]]; then
      if ! echo "$CONTENT" | grep -qi "$QUERY"; then
        continue
      fi
    fi

    # Match found - extract preview
    BODY=$(echo "$CONTENT" | awk 'BEGIN{i=0} /^---$/{i++; next} i>=2' | grep -v '^##' | head -3)
    PREVIEW=$(echo "$BODY" | tr '\n' ' ' | cut -c1-80)
    [[ ${#PREVIEW} -ge 79 ]] && PREVIEW="${PREVIEW}..."

    # Get task ID from path
    TASK_FROM_PATH=$(echo "$dir" | sed 's|.*/tasks/\([^/]*\)/learned|\1|')

    ((MATCH_COUNT++))

    # Print result
    echo "--- Match #$MATCH_COUNT ---"
    echo "ID: $FILE_ID | Category: $FILE_CAT | Importance: $FILE_IMP | Iteration: $FILE_ITER"
    if [[ "$SEARCH_ALL" == "true" ]]; then
      echo "Task: $TASK_FROM_PATH"
    fi
    echo "File: $file"
    echo ""
    echo "$PREVIEW"
    echo ""
  done
done

if [[ $MATCH_COUNT -eq 0 ]]; then
  echo "No learnings found matching your criteria."
  if [[ -n "$QUERY" ]]; then
    echo "  Query: \"$QUERY\""
  fi
  if [[ -n "$CATEGORY_FILTER" ]]; then
    echo "  Category: $CATEGORY_FILTER"
  fi
  if [[ -n "$IMPORTANCE_FILTER" ]]; then
    echo "  Importance: $IMPORTANCE_FILTER"
  fi
else
  echo "================================================================================"
  echo "Found $MATCH_COUNT matching learning(s)"
  echo "================================================================================"
fi
