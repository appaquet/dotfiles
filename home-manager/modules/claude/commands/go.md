---
name: Go
description: Proceed to implementation of the plan or task at hand
---

# Go

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. Ensure crystal clear understanding of the task. If not, use `/ctx-improve` to clarify.
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.

   **Requirement check**: Read ALL requirements in project doc. Verify task aligns - clarify
   if it contradicts or overlaps with existing requirements.

2. Load internal TODO list with tasks
   Always include testing task if not already present
   Always include validation task that checks for the `development-completion-checklist`

3. Create new jj change for this implementation.

4. Implement tasks one by one, following best practices and coding standards:

   * Mark task `[~]` when starting, `[x]` when done
   * When all tasks under a phase are `[x]` → ask user via `AskUserQuestion` if phase should be ✅
   * When all tasks for a requirement are `[x]` → ask user via `AskUserQuestion` if requirement should be ✅
   * Add new tasks discovered, update Files section as needed
   * Create jj changes for significant milestones

   If deviating from plan, overcomplicating or keep doing same mistake, STOP and update user.

5. After all implementation: commit jj change with meaningful message.
