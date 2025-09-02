---
name: plan
description: Load repository context and create high-level development plans
---

Load repository context, current task context, and create high-level plans for the task at hand:

Task (may be empty):

```markdown
$ARGUMENTS
```

1. If the task above is empty and the context isn't clear about the task at hand from the rest of
   our conversation, ask me about the task to be worked on

2. Make sure to read and understand the full context of the task, repository and relevant
   documentation files

3. Analyze the task requirements and create a high-level development plan:
   * Break down the task into logical phases (scaffolding, implementation, testing, etc.)
   * Identify key files and components that will need modification
   * Consider dependencies and potential challenges

4. Ask clarification questions if the requirements are unclear or incomplete. Use the Understanding
   Checklist from to verify you have all necessary information

5. Update or create the `PR.md` file with:
   * Context section describing the task
   * Requirements section (if applicable)
   * TODO section with planned work items
   * Files section with relevant files identified

**Important**: NEVER jump to implementation after planning. Stop here and wait for explicit instruction to proceed to the next phase.
