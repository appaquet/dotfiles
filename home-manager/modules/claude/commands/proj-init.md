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

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure task defined | Skip if $ARGUMENTS provided, else ask |
| 2 | Set up project folder | Derive name from branch (confirm with user), create docs/features/\<date\>-\<name\>/, proj symlink, private commits |
| 3 | Create initial project doc | Read project-doc.md structure first. Create 00-\<name\>.md with Context section and empty Requirements/Tasks/Files |
| 4 | Clarify and update doc | Ask questions, update doc after each answer. For each gap, add sub-task "Clarify: [question]". Continue until 10/10. |
| 5 | Await /go to proceed | Project doc ready, await user confirmation |

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

1. **Ensure task defined** - If task empty, ask about the task to be worked on.

2. **Set up project folder** - Determine file location per above, create directory and symlink.

3. **Create initial project doc** - Create `00-<project-name>.md`:
   * Read @~/.claude/docs/project-doc.md "## Sections" completely first
   * Match every format detail: status markers, emoji prefixes, bullet styles, R-numbers
   * Do NOT create sub-docs unless explicitly requested via `/proj-split` or after asking user

4. **Clarify and update doc** - Use `/ctx-improve` to clarify requirements until crystal clear understanding.
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * After each Q&A, update the project doc and think hard about next questions
   * For each gap discovered, add sub-task "Clarify: [question]"
   * Continue until 10/10 understanding

5. **STOP** - Never jump to implementation. Tell user to use `/go` when ready to proceed.
