# Phil-Connors Plugin

Iterative development loops with **three-tier persistent skill hierarchy**. Named after the character from "Groundhog Day" who repeatedly lives the same day but learns and grows each iteration.

## Key Difference from Wiggum

Unlike Wiggum which loses context between iterations (only passing back the original prompt), Phil-Connors:

- **NEVER loses global skills** - `.agent/skills-lock.md` is injected into EVERY iteration
- **Preserves task context** - Task-specific constraints persist throughout
- **Accumulates learnings** - Individual insights are stored and auto-summarized
- **Prevents context bloat** - Learnings are condensed when threshold reached

## Three-Tier Skill Hierarchy

### Tier 1: Global Skills (IMMUTABLE)
- **File**: `.agent/skills-lock.md`
- Contains project-wide patterns, critical files, essential rules
- NEVER modified during a loop
- Injected into systemMessage every iteration

### Tier 2: Task-Specific Context (NON-EDITABLE)
- **File**: `.agent/phil-connors/tasks/{task-id}/context.md`
- Created at loop start
- Defines task constraints, priority files, success criteria
- Can include nested context schema for expansion

### Tier 3: Learned Skills (MALLEABLE)
- **Directory**: `.agent/phil-connors/tasks/{task-id}/learned/`
- Individual files for each learning (001.md, 002.md, etc.)
- **Categorized** by type: discovery, pattern, anti-pattern, file-location, constraint, solution, blocker
- **Importance levels**: low, medium, high, critical
- Auto-summarized when count reaches threshold (default: 10)
- Summary organized by category and importance for quick reference

## Commands

| Command | Description |
|---------|-------------|
| `/phil-connors "PROMPT" [OPTIONS]` | Start a loop with persistent context |
| `/phil-connors-learn [OPTIONS] "insight"` | Add a categorized learning during iteration |
| `/phil-connors-context-update [OPTIONS]` | Update task context (priority files, constraints, criteria) |
| `/phil-connors-pause` | Pause loop (state preserved for resume) |
| `/phil-connors-resume [TASK_ID]` | Resume a paused task |
| `/phil-connors-list` | List all tasks with status |
| `/cancel-phil-connors` | Cancel loop (alias for pause) |
| `/phil-connors-help` | Show detailed help |

### Options

- `--completion-promise '<text>'` - Promise to signal completion (REQUIRED)
- `--max-iterations <n>` - Max iterations (default: 20)
- `--continuation-prompt '<text>'` - Prompt to inject after completion for task chaining
- `--max-continuations <n>` - Max task continuations (default: 0 = no chaining)
- `--min-continuations <n>` - Force at least N continuations before checking promise (default: 0)
- `--task-id '<id>'` - Custom task identifier
- `--summarize-after <n>` - Summarize after N learnings (default: 10)
- `--skills-config '<text>'` - Initial content for `.agent/skills-lock.md` (overrides template)

## Example Session

```bash
# Start a loop with custom skills config
/phil-connors "Refactor auth to JWT" --completion-promise "All tests passing" --max-iterations 15 --skills-config "
## Project Rules
- Use TypeScript strict mode
- All auth code in src/auth/
- Never commit .env files
"

# During iteration, RECORD LEARNINGS with categories (critical!)
/phil-connors-learn "JWT library requires async operations"
/phil-connors-learn --category pattern "Always validate token before processing"
/phil-connors-learn -c anti-pattern -i high "Don't store tokens in localStorage"
/phil-connors-learn -c file-location -f src/auth/jwt.ts "JWT validation logic here"
/phil-connors-learn -c solution "Fixed by adding null check at line 42"

# When truly complete, you MUST output with promise tags:
<promise>All tests passing</promise>
```

**IMPORTANT**: Always use `/phil-connors-learn` to record discoveries. Learnings persist across context resets - without them, you'll rediscover the same things repeatedly.

### Learning Categories & Options

The `/phil-connors-learn` command supports categorization for better organization:

| Option | Short | Description |
|--------|-------|-------------|
| `--category <cat>` | `-c` | Category: discovery, pattern, anti-pattern, file-location, constraint, solution, blocker |
| `--importance <lvl>` | `-i` | Importance: low, medium, high, critical |
| `--file <path>` | `-f` | Related file path (can specify multiple) |
| `--update <id>` | `-u` | Update an existing learning by ID |
| `--deprecate <id>` | `-d` | Mark learning as deprecated (excluded from summaries) |
| `--list` | `-l` | List all learnings with IDs and status |

**Categories explained:**
- `discovery` - General findings about the codebase (default)
- `pattern` - Useful patterns to follow
- `anti-pattern` - Things NOT to do
- `file-location` - Important file locations
- `constraint` - Constraints or requirements discovered
- `solution` - Solutions that worked
- `blocker` - Issues blocking progress

**Learning lifecycle management:**
```bash
# List all learnings to see their IDs
/phil-connors-learn --list

# Update an existing learning (change importance/category)
/phil-connors-learn --update 3 -i critical "This is now critical"

# Mark a learning as deprecated (no longer relevant)
/phil-connors-learn --deprecate 2
```

**When summarization triggers**, learnings are auto-organized by:
1. Critical/high importance items first (always apply these)
2. Then grouped by category for easy lookup
3. Deprecated learnings are excluded from summaries

### Updating Task Context

Use `/phil-connors-context-update` to evolve task context as requirements emerge:

```bash
# Add priority files discovered during work
/phil-connors-context-update --priority-file src/auth/jwt.ts

# Add constraints discovered during iteration
/phil-connors-context-update --constraint "Must maintain v2 API compatibility"

# Add success criteria as scope becomes clearer
/phil-connors-context-update --success-criterion "All auth tests pass"

# Combine multiple updates
/phil-connors-context-update -p src/auth.ts -c "No external deps" -s "Tests pass"
```

**Why use context updates instead of learnings?**
- Task context (Tier 2) is always visible in every iteration
- Learnings (Tier 3) may be summarized/archived
- Use context for things that must ALWAYS be visible

## Task Chaining (Continuations)

Chain multiple tasks together automatically with `--continuation-prompt` and `--max-continuations`:

```bash
/phil-connors "Build the MVP" --completion-promise "Feature complete" \
  --continuation-prompt "What's the next priority feature? Pick one and implement it." \
  --max-continuations 5 --max-iterations 15
```

**How it works:**
1. When you output `<promise>Feature complete</promise>`, the loop doesn't end
2. Instead, iteration resets to 1 and the continuation prompt is injected
3. You pick the next task and work on it
4. Repeat until `max_continuations` is reached, then the loop ends

This is useful for open-ended development sessions where you want the assistant to autonomously work through multiple features or tasks.

## Pause & Resume

Pause a loop to continue later in a new session:

```bash
# Pause the current loop
/phil-connors-pause

# List all tasks (active, paused, done)
/phil-connors-list

# Resume a specific task
/phil-connors-resume my-task-20260121120000

# Resume the most recent task
/phil-connors-resume
```

**How it works:**
- Pause sets `active: false` but preserves all state (learnings, context, iteration)
- Resume sets `active: true` and continues from where you left off
- All learnings persist and are re-injected on resume
- Task list shows status of all tasks for easy reference

## File Structure Created

```
.agent/
├── skills-lock.md                     # Tier 1: IMMUTABLE (created if missing)
└── phil-connors/
    ├── state.md                       # Loop state
    └── tasks/
        └── {task-id}/
            ├── context.md             # Tier 2: Task context (editable via context-update)
            ├── learned/
            │   ├── 001.md             # Individual learnings
            │   ├── 002.md
            │   └── _summary.md        # Auto-generated summary
            └── learned-archive/       # Archived learnings (optional)
```

## How It Works

1. **Setup**: Creates state file and task directory structure
2. **Each Iteration**: Stop hook injects all three tiers into systemMessage
3. **Learning**: `/phil-connors-learn` adds categorized files to learned directory
4. **Progress Tracking**: Each iteration's metrics are logged (tool calls, file ops, errors)
5. **Summarization**: When learning count hits threshold, creates categorized summary
6. **Completion**: Detects `<promise>` tags and deactivates loop (state preserved)

## Iteration Progress Tracking

Each iteration automatically tracks and logs metrics to the state file:

- **Tool calls**: Total tools invoked
- **File reads**: Files read during iteration
- **File edits**: Files modified or written
- **Errors found**: Error mentions in output

This creates a progress history in `.agent/phil-connors/state.md`:

```
## Session History
- Iteration 1: Starting task
- Iteration 1 (14:32:05): tools=12, reads=4, edits=2, errors=0
- Iteration 2 (14:35:22): tools=8, reads=2, edits=3, errors=1
- Iteration 3 → Continuation 1 (14:40:15): Task completed, starting next
```

The current iteration's metrics are also shown in the systemMessage header for visibility.

## Technical Details

- Stop hook reads transcript to detect completion promise
- Skills-lock.md content is included verbatim in systemMessage
- Task context and summarized learnings are also included
- State file uses YAML frontmatter for structured data
- All scripts are portable (macOS/Linux compatible)

## Installation

This plugin is auto-installed in the Claude Code plugins cache at:
```
~/.claude/plugins/cache/phil-connors/phil-connors/1.0.0/
```

## License

MIT
