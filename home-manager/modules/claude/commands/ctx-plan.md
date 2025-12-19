---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

**Requires PLANNING mode.** Stop immediately if not in planning mode.

If context unclear, run `/ctx-load` first. Ultrathink throughout this task.

Task: $ARGUMENTS

## Instructions

1. If the task is empty and the context isn't clear about the task at hand from the rest of our
   conversation, ask me about the task to be worked on using the `AskUserQuestion` tool.

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

5. Update or create project doc (following `@docs/project-doc.md` structure).
   Include:
   * Context section describing the task
   * TODO section with planned work items (flat list, no phases unless asked)
   * Files section with relevant files identified

**Important**: NEVER jump to implementation after planning. **Use AskUserQuestion** to ask if user wants to proceed to implementation.
