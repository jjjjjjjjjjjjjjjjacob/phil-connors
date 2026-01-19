---
description: "Cancel active phil-connors loop"
allowed-tools: ["Bash", "Read"]
hide-from-slash-command-tool: "true"
---

# Cancel Phil-Connors

To cancel the phil-connors loop:

1. Check if `.agent/phil-connors/state.md` exists:
   ```bash
   test -f .agent/phil-connors/state.md && echo "EXISTS" || echo "NOT_FOUND"
   ```

2. **If NOT_FOUND**: Say "No active Phil-Connors loop found."

3. **If EXISTS**:
   - Read `.agent/phil-connors/state.md` to get the current iteration and task_id
   - Set active to false (preserves state for potential resume):
     ```bash
     sed -i '' 's/^active: true/active: false/' .agent/phil-connors/state.md 2>/dev/null || sed -i 's/^active: true/active: false/' .agent/phil-connors/state.md
     ```
   - Report: "Cancelled Phil-Connors loop for task '{task_id}' (was at iteration N)"

**Note:** Unlike wiggum, state is preserved (not deleted) so task learnings remain in `.agent/phil-connors/tasks/`. You can manually resume by setting `active: true` in state.md.
