---
name: proj-init
description: Initialize project folder with project doc and first phase doc
argument-hint: [task-description]
---

# Project Initialization

Create project folder with project doc and phase doc(s). Structure from @/.claude/docs/project-doc.md.

Task: $ARGUMENTS
Current date: !`date +%Y/%m/%d`

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Load skill
   - Load the `proj-editing` skill right away. This will be needed for creating project and phase docs
   - Read @/.claude/docs/project-doc.md completely to ensure full understanding of structure of
     project and phase docs

3. 🔳 Ensure task defined
   - If empty, use `AskUserQuestion` to clarify

4. 🔳 Set up project folder
   - Derive name from `jj-current-branch`, confirm with `AskUserQuestion`
   - Create directory per `File Location` in @/.claude/docs/project-doc.md
   - Create symlink: `ln -s <project-folder> proj`
   - Commit symlink: `jj commit -m "private: proj - <project-name>"`

5. 🔳 Create project doc (00-<name>.md)
   - Follow project doc structure from @/.claude/docs/project-doc.md
   - Add phase references in Phases section

6. 🔳 Create phase doc(s) (01-<name>.md, etc.)
   - Follow phase doc structure from @/.claude/docs/project-doc.md
   - Confirm phase name(s) with `AskUserQuestion`
   - Commit docs: `jj commit -m "private: claude: docs - <project-name>"`

7. 🔳 Clarify requirements
   - Use `/ctx-improve` until 10/10 understanding per `full-understanding-checklist`
   - Update docs after each clarification

8. **STOP AND WAIT** - User decides when to `/implement`
