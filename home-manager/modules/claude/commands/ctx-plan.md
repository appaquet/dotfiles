---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

Build a full plan for the task at hand: $ARGUMENTS

Project files: !`claude-proj-docs`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure context loaded | Skip if sufficient, else run /ctx-load |
| 2 | Ensure task defined | Skip if $ARGUMENTS provided, else ask |
| 3 | Research and clarify | Explore files, ask questions. For each unknown, add sub-task to investigate. For each ambiguity, add sub-task to ask user. |
| 4 | Report 10/10 understanding | If not 10/10, add more research/clarify sub-tasks and continue. Only proceed when fully understood. |
| 5 | Create development plan | Break into phases, identify files, consider dependencies |
| 6 | Write plan to project doc | Context, Requirements (MoSCoW), Tasks, Files sections |
| 7 | Confirm choices with user | Surface assumptions and uncertainties via AskUserQuestion |
| 8 | Await /go to proceed | Plan complete, await user confirmation |


## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure context loaded** - Run `/ctx-load` if context not sufficiently loaded.

2. **Ensure task defined** - Clarify task if empty or unclear via `AskUserQuestion`.

3. **Research and clarify** - Research full context: files, task, repository, documentation.
   * Consider launching sub-agents (Task tool) to explore codebase, find patterns
   * Search web for external dependencies or unfamiliar concepts if needed
   * Think about requirements, constraints, edge cases
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.
   * For each unknown discovered, add sub-task to investigate
   * For each ambiguity, add sub-task to ask user

4. **Report 10/10 understanding** - Research and ask until 10/10 on `full-understanding-checklist`.
   If not 10/10, add more research/clarify sub-tasks and continue. Only proceed when fully understood.

5. **Create development plan**:
   * Break down into logical phases
   * Identify key files and components
   * Consider dependencies and challenges
   * Insert validation tasks after each phase

6. **Write plan to project doc** (per @~/.claude/docs/project-doc.md structure):
   * Context section describing the task
   * Requirements section using MoSCoW format with numbered items (R1, R2, R1.1)
   * Tasks section with planned work items referencing requirements (e.g., "Implement X (R1, R2.1)")
   * Files section with relevant files

7. **Confirm choices with user** - Think very hard about your plan and tell me your understanding
   of the task on a 10/10 scale. If still not 10/10, propose /ctx-improve to reach full understanding.
   Use `AskUserQuestion` to confirm any choices, uncertainties and assumptions made.

8. **STOP** - The user will decide when to proceed to implementation.
   * Do NOT use `EnterPlanMode` or `ExitPlanMode` tools - this skill writes to project docs directly
   * Simply stop generating and wait for user to respond (e.g., with `/go`)
