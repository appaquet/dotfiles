---
name: Go
description: Proceed to implementation of the plan or task at hand
---

# Go

Proceed to implementation of the plan or task at hand.

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Clear gate tasks | Check TaskList for "Await /go" tasks from previous command, mark complete |
| 2 | Verify understanding | Ensure 10/10 understanding of task. If unclear, use /ctx-improve. Read ALL requirements in project doc. |
| 3 | Load implementation tasks | **FIRST**: Read Tasks section from current phase doc (tasks live in phase docs, not project doc). For each `[ ]` item, create TaskCreate. **THEN**: List created tasks to verify before proceeding. |
| 4 | Create jj change | New change for implementation |
| 5 | Implement tasks | For each task: mark in-progress, implement following dev guidelines, mark complete, update project doc |
| 6 | Validate completion | State each item in development-completion-checklist aloud and confirm compliance |
| 7 | Commit | Commit jj change with meaningful message |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Clear gate tasks** - Check `TaskList` for any "Await /go" tasks from previous command.
   Mark them completed before proceeding.

2. **Verify understanding** - Ensure 10/10 understanding of the task. If not, use `/ctx-improve` to clarify.
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * **Requirement check**: Read ALL requirements in project doc. Verify task aligns - clarify if it contradicts or overlaps.

3. **Load implementation tasks**:
   * Identify current phase from project doc Checkpoint or ask user
   * **FIRST**: Read Tasks section from **phase doc** (tasks live in phase docs, NOT project doc).
                For each `[ ]` item, create `TaskCreate` with subject matching the doc task.
                You can create subtasks if needed for clarity.
   * **THEN**: List created tasks to verify all items captured before proceeding
   * Always include a verification/testing task if not already present

4. **Create jj change** - New change for this implementation.

5. **Implement tasks** one by one, following best practices and coding standards:
   * Mark task in-progress when starting, completed when done
   * Mark **phase doc** task `[~]` when starting, `[x]` when done
   * When all tasks in phase are `[x]` → ask user via `AskUserQuestion` if phase should be ✅ (in project doc)
   * When all tasks for a requirement are `[x]` → ask user via `AskUserQuestion` if requirement should be ✅
   * Add new tasks discovered (to phase doc), update Files section as needed
   * Create jj changes for significant milestones

   If deviating from plan, overcomplicating or keep doing same mistake, STOP and update user.

6. **Validate completion** - Before committing, verify each item in `development-completion-checklist`.
   State each item aloud and confirm compliance. If any item fails, fix before proceeding.

7. **Commit** - After validation passes, commit jj change with meaningful message.
