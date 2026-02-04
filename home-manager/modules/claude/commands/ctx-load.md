---
name: ctx-load
description: Load comprehensive project context including docs, project info, and branch status
---

# Load Context

Load context about the project and task at hand

## State

* Current branch: !`jj-current-branch`
* Project files: !`claude-proj-docs`

## Instructions

1. 🔳 Read project docs (use State above - don't re-discover)
   * If project files found:  
     * Read main project doc for context, requirements, progress
     * Read & summarize checkpoint section if exists
   * If "No project files", may be uninitialized
     * STOP, inform user about missing context

2. 🔳 Load current phase docs if referenced in checkpoint or you think relevant for current work
      But be mindful of context length limits

3. 🔳 Resolve ambiguity
   * If multiple phases or tasks in progress, use `AskUserQuestion` to clarify focus unless the
     checkpoint is clear on next steps

4. 🔳 Synthesize context
   * Summarize current project state
