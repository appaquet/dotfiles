---
name: ctx-load
description: Load comprehensive project context including docs, project info, and branch status
---

# Load Context

Load as much context as possible about the project and task at hand.

## State

* Current branch: !`jj-current-branch`
* List of changes in current branch and stacked branches: !`jj-stacked-stats`
* Project files: !`claude-proj-docs`

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Read project docs | Use State section. Read `00-*.md` project doc. Present Checkpoint if exists. |
| 2 | Load phase docs if needed | Load phase docs (`01-*.md`, etc.) if referenced in checkpoint or planning to work on them |
| 3 | Resolve ambiguity | If multiple tasks `[~]` or phases 🔄, use AskUserQuestion to clarify focus |
| 4 | Synthesize context | Analyze thoroughly. Summarize current project state. |
| 5 | Propose next steps | Based on Tasks section or ask user via AskUserQuestion if unclear |
| 6 | Await /go to proceed | Context loaded, await user confirmation |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Read project docs** (use State above - don't re-discover):
   * If "No project files" shown, check if project instructions specify a different location
   * May not exist if no task started yet - that's fine for new features
   * If files exist, read `00-*.md` project doc to understand context, requirements, progress
   * If "Checkpoint" section exists, present it to help resume where work left off

2. **Load phase docs if needed**:
   * Load phase docs (`01-*.md`, `02-*.md`, ...) if referenced in checkpoint or planning to work on them

3. **Resolve ambiguity** if multiple items in-progress:
   * If multiple tasks `[~]` or phases 🔄, use `AskUserQuestion` to clarify which to focus on
   * Mark the chosen task/phase as in-progress per @~/.claude/docs/project-doc.md rules

4. **Synthesize context**:
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Provide summary of current project state and context

5. **Propose next steps**:
   * If project doc exists, propose next tasks based on Tasks section in phase doc
   * Propose project doc updates if missing information
   * If no clear direction, use `AskUserQuestion` tool for clarification on goals

6. **STOP** - Don't consider any answer on what to work next as an approval to start.
   Await `/go` confirmation before proceeding with any work.
