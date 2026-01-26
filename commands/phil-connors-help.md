---
description: "Explain phil-connors plugin and commands"
allowed-tools: []
---

This is informational help text. Simply display this content to the user and do nothing else.

# Phil-Connors Plugin Help

**Version: 1.5.4**

## What is Phil-Connors?

Phil-Connors extends the Ralph Wiggum technique with **persistent context management**. Named after the character from "Groundhog Day," it ensures you never lose critical context while learning from each iteration.

## Three-Tier Skill Hierarchy

### Tier 1: Global Skills (IMMUTABLE)
- **File**: `.agent/skills-lock.md`
- **Behavior**: NEVER modified during loop
- **Contents**: Project-wide patterns, critical files, essential rules
- **Injection**: Included in systemMessage EVERY iteration

### Tier 2: Task-Specific Context (NON-EDITABLE)
- **File**: `.agent/phil-connors/tasks/{task-id}/context.md`
- **Behavior**: Created at loop start, defines task constraints
- **Contents**: Priority files, constraints, success criteria
- **Injection**: Included in systemMessage every iteration

### Tier 3: Learned Skills (MALLEABLE)
- **Directory**: `.agent/phil-connors/tasks/{task-id}/learned/`
- **Behavior**: Individual files for each learning, categorized
- **Contents**: Discoveries, patterns, anti-patterns, solutions, blockers
- **Injection**: Smart context-aware injection (critical always, fresh always, relevant by file match, high as summaries, rest omitted with search hint)

## Commands

| Command | Description |
|---------|-------------|
| `/phil-connors "PROMPT" [OPTIONS]` | Start a loop with persistent context |
| `/phil-connors-learn [OPTIONS] "insight"` | Add a categorized learning |
| `/phil-connors-context-update [OPTIONS]` | Add priority files, constraints, or notes to Tier 2 |
| `/phil-connors-checkpoint "desc"` | Create a state snapshot for rollback |
| `/phil-connors-rollback <id>` | Restore to a previous checkpoint |
| `/phil-connors-checkpoints` | List all checkpoints |
| `/phil-connors-search [OPTIONS] "query"` | Search learnings by keyword/category/importance |
| `/phil-connors-status` | Show formatted status dashboard |
| `/phil-connors-pause` | Pause loop (state preserved for resume) |
| `/phil-connors-resume [TASK_ID]` | Resume a paused task |
| `/list-phil-connors` | List all tasks with status |
| `/cancel-phil-connors` | Cancel loop (alias for pause) |

### /phil-connors Options

- `--completion-promise '<text>'` - Promise to signal completion (REQUIRED)
- `--max-iterations <n>` - Max iterations (default: 20)
- `--continuation-prompt '<text>'` - Prompt for task chaining
- `--max-continuations <n>` - Max task continuations (default: 0)
- `--min-continuations <n>` - Force minimum continuations (default: 0)
- `--task-id '<id>'` - Custom task identifier
- `--summarize-after <n>` - Summarize after N learnings (default: 10)
- `--skills-config '<text>'` - Initial content for skills-lock.md
- `--auto-checkpoint` - Enable automatic checkpoints (on continuation, summarization)
- `--auto-checkpoint-interval <n>` - Create checkpoint every N iterations

### /phil-connors-learn Options

- `--category <cat>` or `-c` - Category: discovery, pattern, anti-pattern, file-location, constraint, solution, blocker
- `--importance <lvl>` or `-i` - Importance: low, medium, high, critical
- `--file <path>` or `-f` - Related file path (can specify multiple)
- `--update <id>` or `-u` - Update an existing learning by ID
- `--deprecate <id>` or `-d` - Mark a learning as deprecated
- `--list` or `-l` - List all learnings with IDs and status

## Example Session

```bash
# Start a loop
/phil-connors "Refactor auth to JWT" --completion-promise "All tests passing" --max-iterations 15

# Add learnings with categories
/phil-connors-learn "JWT library requires async operations"
/phil-connors-learn -c pattern "Always validate token before processing"
/phil-connors-learn -c anti-pattern -i high "Don't store tokens in localStorage"
/phil-connors-learn -c file-location -f src/auth/jwt.ts "JWT validation logic here"

# When complete
<promise>All tests passing</promise>
```

## Task Chaining

Chain multiple tasks together with `--continuation-prompt`:

```bash
/phil-connors "Build the MVP" --completion-promise "Feature complete" \
  --continuation-prompt "What's the next priority? Implement it." \
  --max-continuations 5
```

## Pause & Resume

```bash
/phil-connors-pause              # Pause current loop
/phil-connors-list               # List all tasks
/phil-connors-resume my-task-id  # Resume specific task
/phil-connors-resume             # Resume most recent
```

## Key Differences from Wiggum

| Feature | Wiggum | Phil-Connors |
|---------|--------|--------------|
| Global skills | None | Injected every iteration |
| Task context | None | Preserved and expanded |
| Learnings | Lost between iterations | Accumulated, categorized, smart-injected |
| State persistence | Session only | Preserved after loop ends |
| Context injection | Original prompt only | All three tiers (priority-filtered) |
| Task chaining | None | Continuation prompts |
| Pause/Resume | None | Full support |
| Checkpoints | None | Snapshot & rollback |
| Stall detection | None | Auto-warns on zero-progress loops |

## Built-in Safeguards

- **Stall detection**: Warns after 3+ iterations with zero edits or persistent errors
- **Iteration limit warning**: Alerts at 80% of max_iterations to prioritize completion
- **Adaptive instructions**: Full instructions on iterations 1-2, compact single-line after
- **Smart summarization**: Only re-summarizes when new learnings exist since last summary
- **Atomic state updates**: All state mutations use backup + validation to prevent corruption

## File Structure

```
.agent/
├── skills-lock.md                     # Tier 1: IMMUTABLE
└── phil-connors/
    ├── state.md                       # Loop state
    └── tasks/
        └── {task-id}/
            ├── context.md             # Tier 2: Task context
            ├── learned/
            │   ├── 001.md             # Individual learnings
            │   ├── 002.md
            │   └── _summary.md        # Auto-generated summary
            └── checkpoints/
                ├── index.md           # Checkpoint registry
                └── cp-001/            # Snapshot of state at checkpoint
```
