---
name: proj-init
description: Initialize project folder and main doc by conversing with user to gather requirements
argument-hint: [task-description]
---

# Project Initialization

Create a project folder with `00-<project-name>.md` main doc by conversing with me. Use documented
structure from @docs/project-doc.md.

Task: $ARGUMENTS

## File Location

Unless project instructions specify otherwise:

1. Derive project name from `jj-current-branch`, use `AskUserQuestion` to confirm/adjust
2. Get current date via `date +%Y/%m/%d` and create directory: `docs/features/<date>-<project-name>/`
3. Create `00-<project-name>.md` in that directory
4. Commit docs in private change: `private: claude: docs - <project-name>`
5. Create folder symlink at repo root: `ln -s docs/features/<date>-<project-name> proj`
6. Commit symlink in private change: `private: project - <project-name>`

**Important**: Both changes stay private - never include in actual PRs

## Instructions

1. If task empty, ask about the task to be worked on.

2. Determine file location per above, create directory and symlink.

3. Use `/ctx-improve` to clarify requirements until crystal clear understanding.

4. Create `00-<project-name>.md` with appropriate sections. Do NOT create sub-docs unless
   explicitly requested via `/proj-split` or after asking user.

5. After each Q&A, update the project doc and think hard about next questions.

6. NEVER jump to implementation. **Use AskUserQuestion** to ask if user wants to proceed to planning or implementation.
