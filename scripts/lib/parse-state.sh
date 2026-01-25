#!/bin/bash

# Phil-Connors State Parser Library
# Source this file to get parse_frontmatter(), parse_state(), and validation functions.
# Compatible with bash 3.x (macOS default).
#
# Usage:
#   source "$(dirname "$0")/lib/parse-state.sh"
#   parse_state   # or: validate_state_exists || exit 1
#   echo "$PC_TASK_ID"
#   echo "$PC_ITERATION"

# parse_frontmatter <file_path> [prefix]
# Reads YAML frontmatter from a .md file and exports fields as PREFIX_FIELD variables.
# Keys are uppercased and hyphens replaced with underscores.
# Default prefix: PC_FM
#
# Example: parse_frontmatter "context.md" "CTX"
#   Sets: CTX_TASK_ID, CTX_CREATED_AT, CTX_PRIORITY_FILES, etc.
parse_frontmatter() {
  local file="$1"
  local prefix="${2:-PC_FM}"

  if [[ ! -f "$file" ]]; then
    echo "Error: parse_frontmatter: file not found: $file" >&2
    return 1
  fi

  local in_frontmatter=false
  local in_multiline=false

  while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ "$line" == "---" ]]; then
      if [[ "$in_frontmatter" == "true" ]]; then
        break  # End of frontmatter
      else
        in_frontmatter=true
        continue
      fi
    fi

    [[ "$in_frontmatter" != "true" ]] && continue

    # Skip multiline continuation lines (indented or empty within multiline)
    if [[ "$in_multiline" == "true" ]]; then
      if [[ "$line" =~ ^[[:space:]] ]] || [[ -z "$line" ]]; then
        continue
      else
        in_multiline=false
      fi
    fi

    # Detect multiline value indicator (key: |)
    if [[ "$line" =~ ^[a-z_-]+:\ \|$ ]]; then
      in_multiline=true
      continue
    fi

    # Skip lines that don't look like key: value
    if [[ ! "$line" =~ ^[a-z_-]+: ]]; then
      continue
    fi

    # Extract key (everything before first colon)
    local key="${line%%:*}"

    # Extract value (everything after first ": ")
    local value="${line#*: }"

    # Handle bare "key:" with no value
    if [[ "$value" == "${line%%:*}:" ]] || [[ -z "$value" ]]; then
      value=""
    fi

    # Strip surrounding quotes from value
    if [[ "$value" =~ ^\"(.*)\"$ ]]; then
      value="${BASH_REMATCH[1]}"
    fi

    # Normalize key: replace hyphens with underscores, uppercase
    local var_name="${prefix}_$(echo "$key" | tr '-' '_' | tr '[:lower:]' '[:upper:]')"

    # Export the variable (using printf to avoid eval injection)
    printf -v "$var_name" '%s' "$value"
    export "$var_name"
  done < "$file"
}

# parse_state [state_file_path]
# Convenience wrapper that parses state.md into PC_* variables.
# Sets: PC_ACTIVE, PC_TASK_ID, PC_ITERATION, PC_MAX_ITERATIONS,
#       PC_COMPLETION_PROMISE, PC_CONTINUATION_PROMPT, PC_MAX_CONTINUATIONS,
#       PC_MIN_CONTINUATIONS, PC_CONTINUATION_COUNT, PC_AUTO_CHECKPOINT,
#       PC_AUTO_CHECKPOINT_INTERVAL, PC_LEARNING_COUNT, PC_SUMMARIZATION_THRESHOLD,
#       PC_STARTED_AT, PC_LAST_ITERATION_AT, PC_LAST_SUMMARIZATION_AT,
#       PC_LAST_CHECKPOINT_AT
parse_state() {
  local state_file="${1:-.agent/phil-connors/state.md}"
  parse_frontmatter "$state_file" "PC"
}

# validate_state_exists [state_file_path]
# Checks state file exists and parses it. Returns 1 with help message if not found.
validate_state_exists() {
  local state_file="${1:-.agent/phil-connors/state.md}"
  if [[ ! -f "$state_file" ]]; then
    echo "Error: No active phil-connors loop" >&2
    echo "" >&2
    echo "Start a loop first with:" >&2
    echo "  /phil-connors \"your task\" --completion-promise \"done criteria\"" >&2
    return 1
  fi
  parse_state "$state_file"
  return 0
}

# validate_state_active
# Returns 0 if loop is active, 1 if not (with error message).
# Must call parse_state() or validate_state_exists() first.
validate_state_active() {
  if [[ "${PC_ACTIVE:-}" != "true" ]]; then
    echo "Error: Phil-connors loop is not active" >&2
    return 1
  fi
  return 0
}
