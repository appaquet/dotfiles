---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

**Requires PLANNING mode.** Stop immediately if not in planning mode.

If context unclear, run `/ctx-load` first. Ultrathink throughout this task.

Task (may be empty):
```markdown
$ARGUMENTS
```

## Instructions

1. If the task above is empty and the context isn't clear about the task at hand from the rest of
   our conversation, ask me about the task to be worked on using the `AskUserQuestion` tool.

2. Make sure to read and understand the full context of the task, repository and relevant
   documentation files.

3. Analyze the task requirements and create a high-level development plan:
   * Break down the task into logical phases (scaffolding, testing, implementation, etc.)
   * Identify key files and components that will need modification
   * Consider dependencies and potential challenges
   * ultrathink each phase, step, how they can be tested and validated
   * Unless told otherwise, always insert validation tasks, asking for my feedback after each phase

4. Use `AskUserQuestion` tool if the requirements are unclear or incomplete. Use the Understanding
   Checklist to verify you have all necessary information. You need to have a 10/10 understanding
   and confidence level. If not, use `/ctx-improve` to clarify context before proceeding.

5. Update or create the `PR.md` file with:
   * Context section describing the task
   * Requirements section (if applicable)
   * TODO section with planned work items
   * Files section with relevant files identified

**Important**: NEVER jump to implementation after planning. Stop here and wait for explicit instruction to proceed to the next phase.
