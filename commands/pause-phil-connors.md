---
description: "Pause active phil-connors loop (can resume later)"
allowed-tools: ["Bash", "Read"]
---

# Pause Phil-Connors

To pause the phil-connors loop (preserving state for later resume):

1. Check if `.agent/phil-connors/state.md` exists:
   ```bash
   test -f .agent/phil-connors/state.md && echo "EXISTS" || echo "NOT_FOUND"
   ```

2. **If NOT_FOUND**: Say "No active Phil-Connors loop found."

3. **If EXISTS**:
   - Read `.agent/phil-connors/state.md` to get the current iteration and task_id
   - Set active to false:
     ```bash
     sed -i '' 's/^active: true/active: false/' .agent/phil-connors/state.md 2>/dev/null || sed -i 's/^active: true/active: false/' .agent/phil-connors/state.md
     ```
   - Report the pause status with resume instructions

4. Output message:
   ```
   Paused Phil-Connors loop for task '{task_id}' at iteration {N}.

   State preserved:
   - Learnings: {learning_count} recorded
   - Context: .agent/phil-connors/tasks/{task_id}/

   To resume this task later, run:
     /phil-connors-resume {task_id}

   To list all paused tasks:
     /phil-connors-list
   ```

**Note:** All state is preserved including learnings, context, and iteration count. Use `/phil-connors-resume` to continue where you left off.
