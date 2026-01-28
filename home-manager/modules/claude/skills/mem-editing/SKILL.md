---
name: mem-editing
description: Internal skill for instruction file changes. Called by /mem-edit command or other commands needing instruction edits. No gate - flows with caller.
argument-hint: [files or description]
---

# Modify Instructions

Edit instruction files with full analysis workflow. Use for any instruction change: optimization,
bug fixes, adding rules, refactoring.

Target: `$ARGUMENTS` (files or description of change)

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure scope identified | Skip if $ARGUMENTS is file path, else ask |
| 2 | Gather context | Read primary files, linked files, grep for related. For each related file, add sub-task "Read: [file]" |
| 3 | Analyze and clarify | Check conflicts, redundancy. For each ambiguity about user intent, use AskUserQuestion to clarify. |
| 4 | Report findings | Files affected, before/after, rationale. If multiple valid approaches, use AskUserQuestion to get direction. |
| 5 | Ensure jj change | Create new change if working copy clean, skip if already have uncommitted changes |
| 6 | Apply changes | Edit files, verify consistency across all affected |
| 7 | Commit | Message describing changes |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

1. **Ensure scope identified**:
   * If target is a file path → that's the primary file
   * If target is a description → identify which file(s) need changes

2. **Gather context** - Read primary file(s) and all linked files (@docs references):
   * Search for related files
   * Grep for key concepts/terms in other instruction files
   * Check commands, skills, docs that reference the same concepts
   * For each related file found, add sub-task "Read: [file]"

3. **Analyze and clarify** thoroughly (ultra, deeply, freakingly, super ultrathink!):
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Think through each instruction as a fresh agent - what could be misinterpreted?
   * Check for redundancy and conflicts ACROSS files
   * For each ambiguity about user intent, use `AskUserQuestion` to clarify
   * Identify all changes needed (may span multiple files)
   * Apply best practices from supporting docs

4. **Report findings**:
   * Files affected
   * Before/after for each change
   * Rationale

5. **Ensure jj change** - Check `jj status`. If working copy is clean, create new change. If already have uncommitted changes, use current change.

6. **Apply changes** - Preserve all salient information, verify consistency across all affected files.

7. **Commit** - Commit changes with descriptive message.

## What to Check

When reviewing instructions, look for:
* Ambiguity - what could a fresh agent misinterpret?
* Cross-file conflicts - do related files have contradicting rules?
* Redundancy - is this duplicated elsewhere?
* Missing context - does this assume knowledge not provided?

## Supporting Files

* @core.md: Core principles - self-verification, minimal info, writing style, examples, anti-patterns
* @commands-skills.md: Slash command and skill structure, task tracking guidelines
* @instructions.md: CLAUDE.md, memory files, structured prompting (XML tags)
* @agents.md: Agent structure and patterns
