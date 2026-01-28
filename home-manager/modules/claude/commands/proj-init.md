---
name: proj-init
description: Initialize project folder with project doc and first phase doc
argument-hint: [task-description]
---

# Project Initialization

Create a project folder with `00-<project-name>.md` (project doc) and `01-<phase-name>.md` (first phase doc).
Use structure from @~/.claude/docs/project-doc.md.

Current date: !`date +%Y/%m/%d`

Task: $ARGUMENTS

Important: any modifications to project or phase docs need to be done via `proj-editing` skill.

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure task defined | Skip if $ARGUMENTS provided, else ask |
| 2 | Set up project folder | Derive name from branch (confirm with user), create docs/features/\<date\>-\<name\>/, proj symlink, private commits |
| 3 | Create project doc | Read project-doc.md structure. Create 00-\<name\>.md with Context, empty Requirements, Phases (link to first phase), Files |
| 4 | Create first phase doc | Create 01-\<phase-name\>.md with Context, Tasks, Files. All task items go here. |
| 5 | Clarify and update docs | Ask questions, update docs after each answer. For each gap, add sub-task "Clarify: [question]". Continue until 10/10. |
| 6 | Await /go to proceed | Docs ready, await user confirmation |

## File Location

Unless project instructions specify otherwise:

1. Derive project name from `jj-current-branch`, use `AskUserQuestion` to confirm/adjust
2. Using current date, create directory: `docs/features/<year>/<month>/<day>-<project-name>/`
3. Create `00-<project-name>.md` (project doc) in that directory
4. Create `01-<phase-name>.md` (first phase doc) in that directory
5. Commit docs in private change: `private: claude: docs - <project-name>`
6. Create folder symlink at repo root: `ln -s docs/features/<date>-<project-name> proj`
7. Commit symlink in private change: `private: project - <project-name>`

**Important**: Both changes stay private - never include in actual PRs

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure task defined** - If task empty, ask about the task to be worked on.

2. **Set up project folder** - Determine file location per above, create directory and symlink.

3. **Create project doc** - Create `00-<project-name>.md`:
   * Read @~/.claude/docs/project-doc.md completely first
   * Follow `<project-doc-sections>` structure
   * Phases section references first phase doc (NO task items here)
   * Match format details: status markers, emoji prefixes, R-numbers

4. **Create first phase doc** - Create `01-<phase-name>.md`:
   * Follow `<phase-doc-sections>` structure
   * Context references project doc
   * All task items `[ ]` go here
   * Use `AskUserQuestion` to confirm phase name

5. **Clarify and update docs** - Use `/ctx-improve` to clarify requirements until crystal clear understanding.
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * After each Q&A, update the docs and think hard about next questions
   * For each gap discovered, add sub-task "Clarify: [question]"
   * Continue until 10/10 understanding on the `full-understanding-checklist`

6. **STOP** - Never jump to implementation. Tell user to use `/go` when ready to proceed.
