---
name: pr-init
description: Initialize PR.md file by conversing with user to gather requirements
argument-hint: [task-description]
---

# PR Initialization

Create a `PR.md` file at the root of the repository with the appropriate sections by conversing with
me. You should *ALWAYS* use the documented structure as defined in your rules. If file too big,
propose splitting into phases and sub-files (`PR-<subphase>.md`).

Task (may be empty, ask me if so):
```markdown
$ARGUMENTS
```

1. If the task above is empty, ask me about the task to be worked on.

2. Use the `/ctx-improve` command to improve the context of the task at hand by asking
   clarifying questions until you have a crystal clear understanding of the task.

3. Create a `PR.md` file at the root of the repository with the appropriate sections.
   If project too big, propose splitting into phases and sub-files (`PR-<subphase>.md`).

4. After each question / answer, update the `PR.md` file think hard about the next questions to ask
   to make sure you have all the information needed to proceed with the task.

5. NEVER jump to implementation after. Once we have the file created, let's stop there and leave me
   the task kick-off the next phase.
