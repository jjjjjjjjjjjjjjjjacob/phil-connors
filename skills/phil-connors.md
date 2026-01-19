---
description: "Start iterative development with persistent context. Use when user asks to 'groundhog this', 'phil-connors it', 'keep iterating with memory', or wants iterative development that remembers learnings."
---

# Phil-Connors Loop

The user wants to run a task with persistent context across iterations.

## When to use this

- User says "groundhog this", "phil-connors it", "groundhog day this"
- User wants iterative development with memory
- User asks for "keep trying but remember what you learned"
- User wants context preserved across iterations
- User mentions wanting learnings to persist
- User needs a loop that won't forget critical project rules

## How to start the loop

```
/phil-connors "<TASK DESCRIPTION>" --completion-promise "<SUCCESS_CRITERIA>" --max-iterations <N>
```

### Constructing the command

1. **Task description**: Convert user's request into clear task prompt
2. **Completion promise**: Define what "done" means (REQUIRED)
3. **Max iterations**: 15-20 for complex tasks, 10 for simpler (REQUIRED)

### Examples

User: "Groundhog this - fix the flaky tests"
```
/phil-connors "Fix all flaky tests. Identify root causes and apply fixes." --completion-promise "All tests stable" --max-iterations 15
```

User: "Phil-connors it until the auth works"
```
/phil-connors "Implement authentication with proper error handling and tests." --completion-promise "Auth complete and tested" --max-iterations 20
```

User: "Keep iterating on this refactor but don't forget the coding standards"
```
/phil-connors "Refactor the payment module following established patterns." --completion-promise "Refactor complete" --max-iterations 15
```

## Important notes

- Global skills from `.agent/skills-lock.md` are ALWAYS injected (never lost)
- Learnings persist and are auto-summarized after 10 entries
- Task context is preserved even after loop ends
- Use `/phil-connors-learn "insight"` to record discoveries during iteration
- Use `/cancel-phil-connors` to stop (state is preserved for resume)

## Three-tier skill hierarchy

Unlike wiggum, phil-connors maintains three levels of context:
1. **Global skills** (immutable): Project-wide rules that never change
2. **Task context** (fixed): Task-specific constraints set at loop start
3. **Learnings** (malleable): Accumulated insights, auto-summarized
