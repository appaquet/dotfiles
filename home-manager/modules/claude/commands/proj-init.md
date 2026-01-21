---
name: proj-init
description: Initialize project folder and main doc by conversing with user to gather requirements
argument-hint: [task-description]
---

# Project Initialization

Create a project folder with `00-<project-name>.md` main doc by conversing with me. Use documented
structure from @~/.claude/docs/project-doc.md.

Current date: !`date +%Y/%m/%d`

Task: $ARGUMENTS

## File Location

Unless project instructions specify otherwise:

1. Derive project name from `jj-current-branch`, use `AskUserQuestion` to confirm/adjust
2. Using current date, create directory: `docs/features/<year>/<month>/<day>-<project-name>/`
3. Create `00-<project-name>.md` in that directory
4. Commit docs in private change: `private: claude: docs - <project-name>`
5. Create folder symlink at repo root: `ln -s docs/features/<date>-<project-name> proj`
6. Commit symlink in private change: `private: project - <project-name>`

**Important**: Both changes stay private - never include in actual PRs

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. If task empty, ask about the task to be worked on.

2. Determine file location per above, create directory and symlink.

3. Use `/ctx-improve` to clarify requirements until crystal clear understanding.
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in
     mind.

4. Create `00-<project-name>.md`:
   * Read @~/.claude/docs/project-doc.md "## Sections" completely first
   * Match every format detail: status markers, emoji prefixes, bullet styles, R-numbers
   * Do NOT create sub-docs unless explicitly requested via `/proj-split` or after asking user

5. After each Q&A, update the project doc and think hard about next questions.

6. NEVER jump to implementation. **Use AskUserQuestion** to ask if user wants to proceed to planning or implementation.
