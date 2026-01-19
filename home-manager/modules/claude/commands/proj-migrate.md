---
name: proj-migrate
description: Migrate existing PR.md project to new proj/ folder structure
---

# Project Migration

Migrate an existing `PR.md` symlink-based project to the new `proj/` folder symlink structure.

## Instructions

1. **Locate existing project**:
   * Check if `PR.md` exists at repo root
   * If symlink, follow it to get the actual directory path
   * If not a symlink, inform user this command is for symlink-based projects

2. **Understand current structure**:
   * Read `PR.md` to understand the project
   * List all files in the project directory
   * Identify sub-files (`PR-<phase-name>.md`)
   * Use `AskUserQuestion` to confirm understanding with user

3. **Plan the migration**:
   * Main doc: `PR.md` → `00-<project-name>.md`
   * Sub-docs: `PR-<phase>.md` → `01-<phase>.md`, `02-<phase>.md`, etc.
   * Symlink: `PR.md` (file) → `proj/` (folder)
   * Present migration plan to user for confirmation

4. **Execute migration** (after user confirms):
   * Rename main doc to `00-<project-name>.md`
   * Rename sub-docs to numbered format, preserving order
   * Update all internal references (links between docs)
   * Remove old `PR.md` symlink
   * Create new `proj/` folder symlink

5. **Update references in all docs**:
   * Replace `PR.md` references with `00-<project-name>.md`
   * Replace `PR-<phase>.md` references with new numbered names
   * Update relative links to use new filenames

6. **Report changes**:
   * List all renamed docs
   * List all updated references
   * Confirm migration complete
