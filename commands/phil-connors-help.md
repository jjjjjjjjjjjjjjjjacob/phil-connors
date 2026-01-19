---
description: "Explain phil-connors plugin and commands"
---

# Phil-Connors Plugin Help

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
- **Behavior**: Individual files for each learning
- **Contents**: Discoveries, patterns, anti-patterns
- **Injection**: Summarized version included in systemMessage

## Commands

### /phil-connors "PROMPT" [OPTIONS]
Start a loop with persistent context.

**Options:**
- `--completion-promise '<text>'` - Promise to signal completion (REQUIRED)
- `--max-iterations <n>` - Max iterations (default: 20)
- `--task-id '<id>'` - Custom task identifier
- `--summarize-after <n>` - Summarize after N learnings (default: 10)

### /cancel-phil-connors
Cancel the active loop. State is preserved (not deleted) for potential resume.

### /phil-connors-learn "insight"
Add a learning during iteration. Learnings persist and are auto-summarized.

## Example Session

```
/phil-connors "Refactor auth to JWT" --completion-promise "All tests passing" --max-iterations 15
```

During iteration:
```
/phil-connors-learn "JWT library requires async operations for production"
/phil-connors-learn "Token expiry must be checked before validation"
```

When complete:
```
<promise>All tests passing</promise>
```

## Key Differences from Wiggum

| Feature | Wiggum | Phil-Connors |
|---------|--------|--------------|
| Global skills | None | Injected every iteration |
| Task context | None | Preserved and expanded |
| Learnings | Lost between iterations | Accumulated and summarized |
| State persistence | Session only | Preserved after loop ends |
| Context injection | Original prompt only | All three tiers |

## File Structure

```
.agent/
├── skills-lock.md                     # Tier 1: IMMUTABLE
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
