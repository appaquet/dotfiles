---
name: instruction-writer
description: Write and optimize instructions for Claude Code (skills, slash commands, memory files, CLAUDE.md). Use when creating or editing instruction files, writing skill descriptions, or optimizing prompts for clarity and token efficiency. Triggers on phrases like "write a skill", "create a command", "optimize instructions", or "improve this prompt".
---

# Instruction Writer Skill

Expertise in writing effective instructions for Claude Code using latest prompt engineering best practices.

## When to Use This Skill

Automatically invoked when:

- Creating new skills, slash commands, or memory files
- Editing existing instruction files
- Optimizing prompts for clarity or token efficiency
- User mentions "write instructions", "create a skill/command", or "optimize this prompt"

## Core Principles

Apply all principles from @best-practices.md when writing or optimizing instructions. Key focus areas: clarity & specificity, token efficiency, canonical examples, and actionable steps.

## Workflow

### For New Instructions

1. Understand the purpose and trigger conditions
2. Draft clear, specific description (if skill) or title/purpose (if command)
3. Structure content with headers/XML tags
4. Add canonical examples
5. Review for token efficiency

### For Optimization

1. Read target file and any linked files (@docs references)
2. Identify issues: verbosity, unclear structure, weak examples, redundancy
3. Compare against @best-practices.md
4. Report findings with before/after examples
5. Wait for approval before applying changes
6. Apply optimizations preserving all salient information

## Supporting Files

- @best-practices.md: Comprehensive prompt engineering guidelines for Claude 4.x
