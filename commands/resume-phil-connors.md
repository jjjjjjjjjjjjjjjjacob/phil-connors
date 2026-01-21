---
description: "Resume a paused phil-connors task"
argument-hint: "[TASK_ID]"
allowed-tools: ["Bash", "Read"]
---

# Resume Phil-Connors

Resume a previously paused phil-connors task.

## Steps

1. **If TASK_ID provided**: Use it directly
   **If no TASK_ID**: Check for most recent task in `.agent/phil-connors/state.md`

2. Validate the task exists:
   ```bash
   # If using state.md task_id
   TASK_ID=$(grep '^task_id:' .agent/phil-connors/state.md | sed 's/task_id: *//' | sed 's/^"\(.*\)"$/\1/')

   # Or use provided task_id from arguments: $ARGUMENTS
   ```

3. Check task directory exists:
   ```bash
   test -d ".agent/phil-connors/tasks/$TASK_ID" && echo "FOUND" || echo "NOT_FOUND"
   ```

4. **If NOT_FOUND**:
   - List available tasks: `ls -1 .agent/phil-connors/tasks/`
   - Say "Task '{TASK_ID}' not found. Available tasks: ..."

5. **If FOUND**:
   - Set active to true:
     ```bash
     sed -i '' 's/^active: false/active: true/' .agent/phil-connors/state.md 2>/dev/null || sed -i 's/^active: false/active: true/' .agent/phil-connors/state.md
     ```
   - Read current state (iteration, learning_count, completion_promise)
   - Read the task context from `.agent/phil-connors/tasks/$TASK_ID/context.md`

6. Output message:
   ```
   === Phil-Connors Loop Resumed ===

   Task ID: {task_id}
   Resuming at iteration: {iteration}
   Learnings available: {learning_count}
   Completion promise: {completion_promise}

   Context loaded from: .agent/phil-connors/tasks/{task_id}/

   Continue working on the task. When complete, output:
   <promise>{completion_promise}</promise>
   ```

7. **Then read and output the original prompt** from state.md so you know what to continue working on.

## Examples

```
/phil-connors-resume                          # Resume most recent task
/phil-connors-resume my-task-20260121120000   # Resume specific task
```
