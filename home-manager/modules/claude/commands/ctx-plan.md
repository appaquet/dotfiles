---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

Task: $ARGUMENTS

Ultrathink. Use sub-agents (Task tool) for codebase exploration if needed.

## Instructions

1. Run `/ctx-load` if context not sufficiently loaded.

2. Clarify task if empty or unclear via `AskUserQuestion`.

3. Research full context: task, repository, documentation.
   * Consider launching sub-agents (Task tool) to explore codebase, find patterns
   * Search web for external dependencies or unfamiliar concepts if needed

4. Use `AskUserQuestion` to clarify requirements.
   Research and ask until 10/10 understanding.

5. Create high-level development plan:
   * Break down into logical phases
   * Identify key files and components
   * Consider dependencies and challenges
   * Insert validation tasks after each phase

6. Write plan to project doc:
   * Context section describing the task
   * TODO section with planned work items
   * Files section with relevant files

7. **STOP** - Use `AskUserQuestion` to ask if user wants to proceed to implementation.
