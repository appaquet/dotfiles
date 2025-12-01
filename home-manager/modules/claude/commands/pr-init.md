---
name: pr-init
description: Initialize PR.md file by conversing with user to gather requirements
argument-hint: [task-description]
---

# PR Initialization

Create a `PR.md` file with appropriate sections by conversing with me. Use documented structure from
@docs/PR-file.md. If too big, propose splitting into phases and sub-files (`PR-<phase-name>.md`).

Task (may be empty, ask me if so):
```markdown
$ARGUMENTS
```

## File Location

Unless project instructions specify otherwise:

1. Derive project name from `jj-current-branch`, use `AskUserQuestion` to confirm/adjust
2. Get current date via `date +%Y/%m/%d` and create directory: `docs/feats/<date>-<project-name>/`
3. Create `PR.md` in that directory
4. Commit docs in private jj change: `jj new -m "private: claude: docs - <project-name>"`
5. Create symlink at repo root: `ln -s docs/feats/.../PR.md PR.md`
6. Commit symlink in private jj change: `jj new -m "private: PR.md - <project-name>"`

**Important**: Both changes stay private - never include in actual PRs

## Instructions

1. If task empty, ask about the task to be worked on.

2. Determine file location per above, create directory and symlink.

3. Use `/ctx-improve` to clarify requirements until crystal clear understanding.

4. Create `PR.md` with appropriate sections. If too big, propose splitting into phases with
   sub-files (`PR-<phase-name>.md` in same directory).

5. After each Q&A, update `PR.md` and think hard about next questions.

6. NEVER jump to implementation. Stop after file creation.
