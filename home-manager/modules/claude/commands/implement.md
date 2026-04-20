---
name: Implement
description: Proceed to implementation of the plan
effort: xhigh
---

# Implement

Goal is to proceed to implementation of the plan or task at hand.

After instructions & tasks loaded, you are free to 🚀 Engage thrusters

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Clear any "Await /implement" tasks from previous command

3. 🔳 Verify 10/10 understanding. If unclear, use `/ctx-improve`
   - Read ALL requirements in project doc
   - Clarify if task contradicts or overlaps

4. 🔳 Load tasks from project/phase doc/context
   - For each task, create 1..n `TaskCreate`
     - Segment for better tracking
   - Create tasks for verification/testing each implementation step
     If user validation needed, task description should be clear about waiting for user input

5. Create `jj` change for this implementation
   - Run `jj ls` to check state
   - If `@` is empty: `jj describe -m "private: claude: description"`
   - If `@` has changes: `jj new -m "private: claude: description"`
   - After task complete: `jj ls` then `jj commit -m "..."`

6. 🔳 Implement tasks one by one:
   - Follow `code-insert-checklist` before modifying code
   - Update documentation if existing:
     - Mark phase doc task `[~]` when starting, `[x]` when done
       Like `task-format` dictates. Done = all ACs pass and tested working
     - Add new tasks discovered to phase doc
     - Note critical decisions
     - Before marking task done: verify each AC sub-item passes
   - If deviating or overcomplicating, STOP and update user
   - If any decisions or discoveries, update project/phase doc

7. 🔳 Validate via `development-completion-checklist`
   - State each item aloud, confirm compliance

8. 🔳 Validate formatting, linting and tests

9. 🔳 Run `/ctx-save` to update project and phase docs

10. 🔳 Commit / squash `jj` change with meaningful message if not already done
       After checking state with `jj ls`
