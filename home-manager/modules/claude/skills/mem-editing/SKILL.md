---
name: mem-editing
description: Instructions to be used as soon as any instruction, CLAUDE.md, command, skill or agent file needs to be changed.
argument-hint: [files or description]
---

# Instruction Editing Guidelines

Guidelines for editing Claude Code instruction files (CLAUDE.md, commands, skills, agents, docs).
Load supporting files as needed for the specific component type being edited.

## When to Use

Any time instruction files are created or modified: optimization, bug fixes, adding rules,
refactoring, new commands/skills/agents.

## Editing Principles

* Preserve all salient information - never silently drop content
* Check for redundancy and conflicts across files before editing
* Apply principles from supporting docs below (match the component type)
* Consider surrounding style: load neighboring commands/skills/agents to match patterns
* Use `AskUserQuestion` for ambiguities

## What to Check

* Ambiguity - what could a fresh agent misinterpret?
* Cross-file conflicts - do related files have contradicting rules?
* Redundancy - is this duplicated elsewhere?
* Missing context - does this assume knowledge not provided?

## Supporting Files

* @core.md: Core principles (self-verification, minimal info, writing style)
* @commands-skills.md: Slash command and skill structure
* @instructions.md: CLAUDE.md, memory files, structured prompting
* @agents.md: Agent structure and patterns
