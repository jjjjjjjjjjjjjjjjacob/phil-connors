---
description: "List all phil-connors tasks"
allowed-tools: ["Bash", "Read"]
---

# List Phil-Connors Tasks

List all phil-connors tasks with their status.

## Steps

1. Check if tasks directory exists:
   ```bash
   test -d .agent/phil-connors/tasks && echo "EXISTS" || echo "NOT_FOUND"
   ```

2. **If NOT_FOUND**: Say "No phil-connors tasks found."

3. **If EXISTS**:
   - Get list of task directories:
     ```bash
     ls -1 .agent/phil-connors/tasks/
     ```

4. For each task, gather info and format as a table:
   - Read context.md to get created_at and original prompt (first line)
   - Count learnings in learned/ directory
   - Check if it's the active task from state.md

5. Check current active task:
   ```bash
   if [ -f .agent/phil-connors/state.md ]; then
     ACTIVE=$(grep '^active:' .agent/phil-connors/state.md | sed 's/active: *//')
     CURRENT_TASK=$(grep '^task_id:' .agent/phil-connors/state.md | sed 's/task_id: *//' | sed 's/^"\(.*\)"$/\1/')
     ITERATION=$(grep '^iteration:' .agent/phil-connors/state.md | sed 's/iteration: *//')
     echo "Active: $ACTIVE, Task: $CURRENT_TASK, Iteration: $ITERATION"
   fi
   ```

6. Output formatted list:
   ```
   === Phil-Connors Tasks ===

   Current: {current_task_id} (iteration {N}, {status})

   All Tasks:
   | Task ID                              | Learnings | Status  | Created    |
   |--------------------------------------|-----------|---------|------------|
   | my-task-20260121120000               | 5         | paused  | 2026-01-21 |
   | another-task-20260120150000          | 12        | done    | 2026-01-20 |
   ...

   To resume a task: /phil-connors-resume <task-id>
   ```

## Status Values

- **active** - Currently running loop
- **paused** - Stopped but can be resumed
- **done** - Completed (found completion promise in state)
