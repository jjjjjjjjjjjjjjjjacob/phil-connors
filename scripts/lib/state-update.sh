#!/bin/bash

# Phil-Connors Atomic State Update Library
# Source this file to get state_update(), state_batch_update(), and state_recover().
# Compatible with bash 3.x (macOS default).
#
# All updates create a .bak backup before writing and validate the result.
#
# Usage:
#   source "$(dirname "$0")/lib/state-update.sh"
#   state_update ".agent/phil-connors/state.md" "iteration" "5"
#   state_batch_update ".agent/phil-connors/state.md" "iteration=5" "last_iteration_at=\"2025-01-01T00:00:00Z\""

# state_update <file> <field> <value>
# Atomically updates a single frontmatter field.
# Creates .bak backup before writing. Validates write succeeded.
state_update() {
  local file="$1"
  local field="$2"
  local value="$3"

  if [[ ! -f "$file" ]]; then
    echo "Error: state_update: file not found: $file" >&2
    return 1
  fi

  # Create backup
  cp "$file" "${file}.bak"

  # Create temp file with safe naming
  local temp_file
  temp_file=$(mktemp "${file}.XXXXXX") || {
    echo "Error: state_update: cannot create temp file" >&2
    return 1
  }

  # Use awk for robust field replacement (handles colons in values)
  awk -v field="$field" -v value="$value" '
    BEGIN { in_fm = 0; done_fm = 0 }
    /^---$/ {
      if (in_fm == 0) { in_fm = 1 }
      else { done_fm = 1 }
      print; next
    }
    in_fm == 1 && done_fm == 0 {
      split($0, parts, ": ")
      if (parts[1] == field) {
        print field ": " value
        next
      }
    }
    { print }
  ' "$file" > "$temp_file"

  # Verify temp file is non-empty
  if [[ ! -s "$temp_file" ]]; then
    echo "Error: state_update: write produced empty file, aborting" >&2
    rm -f "$temp_file"
    return 1
  fi

  # Verify frontmatter structure preserved (has two --- lines)
  local fence_count
  fence_count=$(grep -c '^---$' "$temp_file" || echo "0")
  if [[ "$fence_count" -lt 2 ]]; then
    echo "Error: state_update: corrupted frontmatter structure, aborting" >&2
    rm -f "$temp_file"
    return 1
  fi

  # Atomic move
  mv "$temp_file" "$file"
  return 0
}

# state_batch_update <file> <field1=value1> [field2=value2] ...
# Atomically updates multiple frontmatter fields in a single write pass.
# Creates .bak backup before writing.
# Uses a pairs file to pass field/value data safely to awk (no injection risk).
state_batch_update() {
  local file="$1"
  shift

  if [[ ! -f "$file" ]]; then
    echo "Error: state_batch_update: file not found: $file" >&2
    return 1
  fi

  if [[ $# -eq 0 ]]; then
    echo "Error: state_batch_update: no field=value pairs provided" >&2
    return 1
  fi

  # Create backup
  cp "$file" "${file}.bak"

  # Write field=value pairs to a temp file for safe awk consumption
  local pairs_file
  pairs_file=$(mktemp) || {
    echo "Error: state_batch_update: cannot create pairs file" >&2
    return 1
  }

  for pair in "$@"; do
    echo "$pair" >> "$pairs_file"
  done

  local temp_file
  temp_file=$(mktemp "${file}.XXXXXX") || {
    echo "Error: state_batch_update: cannot create temp file" >&2
    rm -f "$pairs_file"
    return 1
  }

  # Single pass awk: reads pairs file first, then processes input
  awk '
    BEGIN { in_fm = 0; done_fm = 0 }
    NR == FNR {
      # First file: read field=value pairs
      idx = index($0, "=")
      if (idx > 0) {
        field = substr($0, 1, idx - 1)
        value = substr($0, idx + 1)
        replacements[field] = value
      }
      next
    }
    /^---$/ {
      if (in_fm == 0) { in_fm = 1 }
      else { done_fm = 1 }
      print; next
    }
    in_fm == 1 && done_fm == 0 {
      idx = index($0, ": ")
      if (idx > 0) {
        key = substr($0, 1, idx - 1)
        if (key in replacements) {
          print key ": " replacements[key]
          next
        }
      }
    }
    { print }
  ' "$pairs_file" "$file" > "$temp_file"

  rm -f "$pairs_file"

  # Verify temp file is non-empty
  if [[ ! -s "$temp_file" ]]; then
    echo "Error: state_batch_update: write produced empty file, aborting" >&2
    rm -f "$temp_file"
    return 1
  fi

  # Verify frontmatter structure preserved
  local fence_count
  fence_count=$(grep -c '^---$' "$temp_file" || echo "0")
  if [[ "$fence_count" -lt 2 ]]; then
    echo "Error: state_batch_update: corrupted frontmatter, aborting" >&2
    rm -f "$temp_file"
    return 1
  fi

  mv "$temp_file" "$file"
  return 0
}

# state_recover <file>
# Restores state from .bak file if main file is corrupted or missing.
state_recover() {
  local file="$1"
  local bak_file="${file}.bak"

  if [[ ! -f "$bak_file" ]]; then
    echo "Error: state_recover: no backup found at $bak_file" >&2
    return 1
  fi

  # Validate backup has proper frontmatter
  local fence_count
  fence_count=$(grep -c '^---$' "$bak_file" || echo "0")
  if [[ "$fence_count" -lt 2 ]]; then
    echo "Error: state_recover: backup file also corrupted" >&2
    return 1
  fi

  cp "$bak_file" "$file"
  echo "State recovered from backup: $bak_file" >&2
  return 0
}

# state_set_inactive [file]
# Convenience: atomically sets active: false.
state_set_inactive() {
  local file="${1:-.agent/phil-connors/state.md}"
  state_update "$file" "active" "false"
}
