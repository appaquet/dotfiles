---
name: ctx-plan
description: Load repository context and create high-level development plans
argument-hint: [task-description]
---

# Plan

Build a full plan for the task at hand: $ARGUMENTS

Project files: !`ls "$PROJECT_ROOT/proj/" 2>/dev/null || echo "No project files"`

## Instructions

1. Run `/ctx-load` if context not sufficiently loaded.

2. Clarify task if empty or unclear via `AskUserQuestion`.

3. Research full context: task, repository, documentation.
   * Consider launching sub-agents (Task tool) to explore codebase, find patterns
   * Search web for external dependencies or unfamiliar concepts if needed
   * ultrathink about requirements, constraints, edge cases

4. Use `AskUserQuestion` to clarify requirements.
   Research and ask until 10/10 understanding.
   * Clarification ≠ approval—continue to steps 5-7 after answers

5. Create high-level development plan:
   * Break down into logical phases
   * Identify key files and components
   * Consider dependencies and challenges
   * Insert validation tasks after each phase

6. Write plan to project doc (per @docs/project-doc.md structure):
   * Context section describing the task
   * Requirements section using MoSCoW format with numbered items (R1, R2, R1.1)
   * TODO section with planned work items referencing requirements (e.g., "Implement X (R1, R2.1)")
   * Files section with relevant files

7. Tell me your understanding of the task on a 10/10 scale.
   If still not 10/10, propose /ctx-improve to reach full understanding.
   Use `AskUserQuestion` to confirm any choices, uncertainties and assumptions made.

8. **STOP** - The user will decide when to proceed to implementation.
