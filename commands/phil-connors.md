---
description: "Start phil-connors loop with persistent context"
argument-hint: "PROMPT --completion-promise TEXT [--max-iterations N] [--skills-config TEXT]"
allowed-tools: ["Bash"]
---

# Phil-Connors Loop Command

Run this command to initialize the Phil-Connors loop:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/setup-loop.sh" $ARGUMENTS
```

Execute the above command using Bash, then work on the task.

## Three-Tier Skill Hierarchy

Phil-Connors maintains persistent context via THREE TIERS:

1. **Tier 1 - Global Skills** (`.agent/skills-lock.md`): IMMUTABLE. Project-wide patterns, critical files, essential rules. Injected into EVERY iteration via systemMessage.

2. **Tier 2 - Task Context** (`.agent/phil-connors/tasks/{id}/context.md`): Non-editable during loop. Defines task constraints, priority files, success criteria.

3. **Tier 3 - Learnings** (`.agent/phil-connors/tasks/{id}/learned/`): Malleable. Individual insight files, auto-summarized when threshold reached.

## Key Difference from Wiggum

Unlike Wiggum which only passes back the original prompt, Phil-Connors injects ALL THREE TIERS into your systemMessage every iteration. You will NEVER lose:
- Global skills from skills-lock.md
- Task-specific context
- Summarized learnings from previous iterations

## During Each Iteration

The stop hook reads and injects all skills. Review the systemMessage for:
- TIER 1: Apply these rules ALWAYS
- TIER 2: Task-specific constraints
- TIER 3: Learnings from previous iterations

## Adding Learnings

Use `/phil-connors-learn "insight"` to record discoveries during iteration.

Learnings are CRITICAL - they persist across context resets. Record:
- Codebase structure discoveries
- Solutions that worked (or didn't)
- Important file locations
- Constraints or requirements found

## Options

- `--completion-promise '<text>'` - Required. Text that signals task completion
- `--max-iterations <n>` - Max iterations before auto-stop (default: 20)
- `--skills-config '<text>'` - Initial content for .agent/skills-lock.md (overrides template)
- `--task-id '<id>'` - Custom task identifier
- `--summarize-after <n>` - Auto-summarize learnings after N entries (default: 10)

## Example with Skills Config

```
/phil-connors "Fix auth bugs" --completion-promise "All auth tests pass" --skills-config "
## Project Rules
- Use TypeScript strict mode
- All functions need tests
- Auth code is in src/auth/
"
```

## Completion

Output `<promise>COMPLETION_PROMISE</promise>` only when the statement is TRUE.

**IMPORTANT:** Always specify `--completion-promise`. A reasonable default for `--max-iterations` is 15-20.
