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
- Auto-summarized when count reaches threshold (default: 10)
- Condensed summary injected into systemMessage

## Commands

| Command | Description |
|---------|-------------|
| `/phil-connors "PROMPT" [OPTIONS]` | Start a loop with persistent context |
| `/cancel-phil-connors` | Cancel loop (state preserved) |
| `/phil-connors-learn "insight"` | Add a learning during iteration |
| `/phil-connors-help` | Show detailed help |

### Options

- `--completion-promise '<text>'` - Promise to signal completion (REQUIRED)
- `--max-iterations <n>` - Max iterations (default: 20)
- `--continuation-prompt '<text>'` - Prompt to inject after completion for task chaining
- `--max-continuations <n>` - Max task continuations (default: 0 = no chaining)
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

# During iteration, RECORD LEARNINGS (critical!)
/phil-connors-learn "JWT library requires async operations"
/phil-connors-learn "Token expiry must be checked before validation"

# When truly complete, you MUST output with promise tags:
<promise>All tests passing</promise>
```

**IMPORTANT**: Always use `/phil-connors-learn` to record discoveries. Learnings persist across context resets - without them, you'll rediscover the same things repeatedly.

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

## File Structure Created

```
.agent/
├── skills-lock.md                     # Tier 1: IMMUTABLE (created if missing)
└── phil-connors/
    ├── state.md                       # Loop state
    └── tasks/
        └── {task-id}/
            ├── context.md             # Tier 2: Task context
            └── learned/
                ├── 001.md             # Individual learnings
                ├── 002.md
                └── _summary.md        # Auto-generated summary
```

## How It Works

1. **Setup**: Creates state file and task directory structure
2. **Each Iteration**: Stop hook injects all three tiers into systemMessage
3. **Learning**: `/phil-connors-learn` adds numbered files to learned directory
4. **Summarization**: When learning count hits threshold, creates condensed summary
5. **Completion**: Detects `<promise>` tags and deactivates loop (state preserved)

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
