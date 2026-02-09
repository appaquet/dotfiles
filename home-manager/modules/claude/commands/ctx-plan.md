---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

Build a full plan for the task at hand: $ARGUMENTS

Project files: !`claude-proj-docs`

ALL implementations require completing this planning workflow and waiting for `/implement`. No
exceptions, no matter how trivial. There is no such thing as "quick fix not requiring planning"
since I explicitly called this command

NEVER engage the native plan mode `EnterPlanMode`

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Ensure context loaded - run `/ctx-load` if not sufficient

3. 🔳 Ensure task defined - clarify via `AskUserQuestion` if empty or unclear

4. 🔳 Research and clarify
   - Use sub-agents to explore codebase, find patterns
   - Using the <deep-thinking> procedure
   - Search web for unfamiliar concepts if needed
   - For each unknown, add sub-task to investigate
   - Use `AskUserQuestion` to clarify as you discover uncertainties

5. 🔳 Report 10/10 understanding via `full-understanding-checklist`
   - If not 10/10, suggest `/ctx-improve` to improve further more

6. 🔳 Create development plan
   - Break into logical phases
   - Identify key files and components
   - Develop one component at the time, writing its test right after and make sure to pass it before
     moving on
   - Consider dependencies and challenges

7. 🔳 Write plan to docs via `proj-editing` skill

8. **STOP**: User will decide next steps
