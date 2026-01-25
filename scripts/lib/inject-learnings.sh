#!/bin/bash

# Phil-Connors Smart Learning Injection Library
# Source this file to get build_learning_injection() for context-aware Tier 3 content.
# Compatible with bash 3.x (macOS default).
#
# Strategy:
#   1. ALWAYS include: critical importance learnings (full text)
#   2. ALWAYS include: learnings from last 2 iterations (freshness)
#   3. INCLUDE if relevant: learnings whose related_files match transcript files
#   4. SUMMARIZE: high importance learnings (one-line each)
#   5. OMIT: medium/low learnings not matching relevance criteria
#   6. APPEND: count of omitted learnings prompting /phil-connors-search
#
# Usage:
#   source "$(dirname "$0")/lib/inject-learnings.sh"
#   LEARNINGS=$(build_learning_injection "$TASK_ID" "$ITERATION" "$TRANSCRIPT_PATH")

# build_learning_injection <task_id> <current_iteration> [transcript_path]
# Outputs filtered learning content to stdout.
build_learning_injection() {
  local task_id="$1"
  local current_iteration="$2"
  local transcript_path="${3:-}"

  local learned_dir=".agent/phil-connors/tasks/$task_id/learned"

  if [[ ! -d "$learned_dir" ]]; then
    echo "[No learnings recorded yet - use /phil-connors-learn to add insights]"
    return
  fi

  # Get learning files (excluding summary)
  local learning_files
  learning_files=$(ls -1 "$learned_dir"/*.md 2>/dev/null | grep -v '_summary.md' | sort || echo "")

  if [[ -z "$learning_files" ]]; then
    echo "[No learnings recorded yet - use /phil-connors-learn to add insights]"
    return
  fi

  # Collect file paths mentioned in transcript (for relevance matching)
  local transcript_files=""
  if [[ -n "$transcript_path" ]] && [[ -f "$transcript_path" ]]; then
    transcript_files=$(grep -oE '[a-zA-Z0-9_./-]+\.[a-zA-Z]{1,6}' "$transcript_path" 2>/dev/null | sort -u | head -50 || echo "")
  fi

  local critical_content=""
  local fresh_content=""
  local relevant_content=""
  local high_summaries=""
  local omitted_count=0
  local total_active=0

  # Freshness window: last 2 iterations
  local freshness_cutoff=$((current_iteration - 2))
  [[ $freshness_cutoff -lt 1 ]] && freshness_cutoff=1

  while IFS= read -r file; do
    [[ -f "$file" ]] || continue

    local content
    content=$(cat "$file")

    # Skip deprecated
    if echo "$content" | grep -q '^deprecated: true'; then
      continue
    fi

    total_active=$((total_active + 1))

    # Extract metadata from frontmatter
    local importance
    importance=$(echo "$content" | grep '^importance:' | sed 's/importance: *//' | sed 's/^"\(.*\)"$/\1/' | head -1)
    [[ -z "$importance" ]] && importance="medium"

    local iteration
    iteration=$(echo "$content" | grep '^iteration:' | sed 's/iteration: *//' | head -1)

    local related
    related=$(echo "$content" | grep '^related_files:' | sed 's/related_files: *//' | head -1)

    # Extract body text (after frontmatter)
    local body
    body=$(echo "$content" | awk 'BEGIN{i=0} /^---$/{i++; next} i>=2' | sed '/^$/d')

    local included=false

    # Rule 1: Critical importance - ALWAYS include full text
    if [[ "$importance" == "critical" ]]; then
      if [[ -n "$critical_content" ]]; then
        critical_content+=$'\n\n'
      fi
      critical_content+="$body"
      included=true
    fi

    # Rule 2: Freshness - include if from recent iterations
    if [[ "$included" != "true" ]] && [[ "$iteration" =~ ^[0-9]+$ ]] && \
       [[ $iteration -ge $freshness_cutoff ]]; then
      if [[ -n "$fresh_content" ]]; then
        fresh_content+=$'\n\n'
      fi
      fresh_content+="$body"
      included=true
    fi

    # Rule 3: Relevance - include if related_files match transcript
    if [[ "$included" != "true" ]] && [[ -n "$transcript_files" ]] && \
       [[ "$related" != "[]" ]] && [[ -n "$related" ]]; then
      local matched=false
      while IFS= read -r tf; do
        [[ -z "$tf" ]] && continue
        if echo "$related" | grep -qF "$tf" 2>/dev/null; then
          matched=true
          break
        fi
      done <<< "$transcript_files"

      if [[ "$matched" == "true" ]]; then
        if [[ -n "$relevant_content" ]]; then
          relevant_content+=$'\n\n'
        fi
        relevant_content+="$body"
        included=true
      fi
    fi

    # Rule 4: High importance - include as one-line summary
    if [[ "$included" != "true" ]] && [[ "$importance" == "high" ]]; then
      local one_line
      one_line=$(echo "$body" | grep -v '^##' | grep -v '^$' | head -1 | cut -c1-100)
      if [[ -n "$one_line" ]]; then
        high_summaries+="- $one_line"$'\n'
      fi
      included=true
    fi

    # Rule 5: Not included - count as omitted
    if [[ "$included" != "true" ]]; then
      omitted_count=$((omitted_count + 1))
    fi

  done <<< "$learning_files"

  # Build output
  local output=""

  if [[ -n "$critical_content" ]]; then
    output+="## CRITICAL Learnings (Always Apply)"$'\n\n'
    output+="$critical_content"$'\n\n'
  fi

  if [[ -n "$fresh_content" ]]; then
    output+="## Recent Learnings (Last 2 Iterations)"$'\n\n'
    output+="$fresh_content"$'\n\n'
  fi

  if [[ -n "$relevant_content" ]]; then
    output+="## Relevant Learnings (Matching Current Files)"$'\n\n'
    output+="$relevant_content"$'\n\n'
  fi

  if [[ -n "$high_summaries" ]]; then
    output+="## High Importance (Summaries)"$'\n\n'
    output+="$high_summaries"$'\n'
  fi

  if [[ $omitted_count -gt 0 ]]; then
    output+="---"$'\n'
    output+="*$omitted_count additional learnings available (total active: $total_active). Use /phil-connors-search to find specific learnings.*"$'\n'
  fi

  if [[ -z "$output" ]]; then
    output="[No learnings recorded yet - use /phil-connors-learn to add insights]"
  fi

  printf '%s' "$output"
}
