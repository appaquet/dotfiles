---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

Task: $ARGUMENTS

## Instructions

Ultrathink throughout this task.

1. Call `EnterPlanMode` tool. Do not proceed without entering plan mode.

2. Run `/ctx-load` to load project context.

3. If task is empty and context isn't clear, use `AskUserQuestion` to clarify.

4. Read and understand full context: task, repository, relevant documentation.

5. Use `AskUserQuestion` if requirements unclear. Need 10/10 understanding before proceeding.

6. Create high-level development plan:
   * Break down into logical phases
   * Identify key files and components
   * Consider dependencies and challenges
   * Insert validation tasks after each phase

7. Write plan to project doc (per @docs/project-doc.md structure):
   * Context section describing the task
   * TODO section with planned work items
   * Files section with relevant files

8. Call `ExitPlanMode` when plan is ready for user approval.
