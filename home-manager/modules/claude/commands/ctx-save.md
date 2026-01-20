---
name: ctx-save
description: Update project doc with current state, files, and Tasks progress
---

# Save Context

Save current project context into project docs while respecting established structure to allow easy
resumption later by you or by another agent.

Project files: !`claude-proj-docs`

## Instructions

1. Find project docs (check `proj/` symlink → find `00-*.md` main doc).
   Also identify any sub-docs (`01-*.md`, `02-*.md`, ..., in same directory).

2. Update the "Files" section:
   * Launch the `branch-diff-summarizer` agent to analyze changed files
   * Update project doc with agent's output (format per @docs/project-doc.md)

3. Update the Tasks section (format per @docs/project-doc.md):
   * Mark completed tasks as `[x]` (no approval needed)
   * Mark phases ✅ ONLY after `AskUserQuestion` confirms with user
   * Add any new tasks discovered during development
   * When marking a phase complete, update all linked requirements to ✅
   * Make sure to reference requirements by their Rn numbers

4. Update context and requirements sections if needed based on new discoveries
   * **Before modifying requirements**: Read ALL existing requirements first. If a new discovery
     relates to an existing requirement, update that requirement rather than creating a new one.
   * Maintain MoSCoW structure and Rn numbering in requirements
   * Add new requirements with next available number only if truly new scope, maintain requirement
     uniqueness and main/phase docs consistency

5. Update the "Checkpoint" section:
   * Write 1-2 paragraph summary of work just completed
   * Reference phase (if applicable) and specific tasks worked on
   * Include next step if decided or obvious
   * This helps resume work quickly in future sessions
