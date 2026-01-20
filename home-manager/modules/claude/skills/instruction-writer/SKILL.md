---
name: instruction-writer
description: Knowledge for writing effective Claude Code instructions. Auto-triggers for CLAUDE.md, SKILL.md, command files.
---

# Instruction Writer Skill

Load this skill to enter instruction-writing mode. Provides knowledge and principles for writing
effective Claude Code instructions.

## When Loaded

**Auto-triggers when:**
* Creating or modifying CLAUDE.md, SKILL.md, or command files
* Optimizing prompts for clarity or token efficiency
* User mentions "write instructions", "create a skill/command", "optimize this prompt"

## Core Principles

Apply all principles from @best-practices.md. Key focus areas:
* Clarity & specificity over vagueness
* Token efficiency - every token depletes attention budget
* Canonical examples over exhaustive edge cases
* Actionable steps in imperative mood

## What to Check

When reviewing instructions, look for:
* Ambiguity - what could a fresh agent misinterpret?
* Cross-file conflicts - do related files have contradicting rules?
* Redundancy - is this duplicated elsewhere?
* Missing context - does this assume knowledge not provided?

## Supporting Files

* @best-practices.md: Comprehensive prompt engineering guidelines for Claude 4.x
