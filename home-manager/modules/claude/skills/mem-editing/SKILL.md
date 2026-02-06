---
name: mem-editing
description: Instructions to be used as soon as any instruction, CLAUDE.md, command, skill or agent file needs to be changed.
argument-hint: [files or description]
---

# Modify Instructions

Edit instruction files with full analysis workflow. Use for any instruction change: optimization,
bug fixes, adding rules, refactoring.

Target: `$ARGUMENTS`

## Instructions

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Ensure scope identified
   - If target is a file path → that's the primary file
   - If target is description → identify which file(s) need changes

3. 🔳 Gather context
   - Read primary file(s) and all @-linked files
   - Grep for key concepts in other instruction files
   - Check commands/skills/docs referencing same concepts

4. 🔳 Analyze thoroughly
   - Use the <deep-thinking> procedure
   - Check for redundancy and conflicts across files
   - Use `AskUserQuestion` for ambiguities
   - Apply principles from supporting docs

5. 🔳 Report findings
   - Files affected
   - Before/after for each change
   - Rationale

6. 🔳 Ensure jj change
   - If working copy clean → `jj new`
   - If uncommitted changes → use current change

7. 🔳 Apply changes
   - Preserve all salient information
   - Verify consistency across affected files

8. 🔳 Commit with descriptive message

## What to Check

- Ambiguity - what could a fresh agent misinterpret?
- Cross-file conflicts - do related files have contradicting rules?
- Redundancy - is this duplicated elsewhere?
- Missing context - does this assume knowledge not provided?

## Supporting Files

- @core.md: Core principles (self-verification, minimal info, writing style)
- @commands-skills.md: Slash command and skill structure
- @instructions.md: CLAUDE.md, memory files, structured prompting
- @agents.md: Agent structure and patterns
