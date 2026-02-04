# Commands and Skills Structure

Guidelines for writing slash commands and skills for Claude Code.

## Skills (SKILL.md)

```yaml
---
name: skill-name-here
description: Specific capability with trigger phrases. Include file types, concrete capabilities, and natural phrases users would say. Keep under 1024 chars.
---

# Skill Title

Brief purpose statement.

## When to Use

Specific triggers and scenarios.

## Core Principles

Key guidelines (reference supporting docs with @filename.md).

## Workflow

Clear steps for different scenarios.

## Supporting Files

* @referenced-file.md: Purpose
```

### Description Guidelines

* Make specific and discoverable
* Include file types/formats (PDF, .xlsx, etc.)
* List concrete capabilities
* Specify trigger phrases users would naturally say
* Bad: "Helps with documents"
* Good: "Extract text and tables from PDF files, fill forms, merge documents. Use when working with PDFs or mentioning document extraction."

### SKILL.md vs Supporting Files

Claude Code uses **progressive disclosure** - SKILL.md loads on activation, supporting files load only when referenced.

**SKILL.md should contain**:
* Quick-start guidance Claude needs immediately
* Essential instructions and workflow steps
* Concrete usage examples
* References to supporting files with @filename.md

**Supporting files handle**:
* Extended documentation (best-practices.md, reference.md)
* Additional examples (examples.md)
* Detailed API specifications
* Utility scripts and templates

**Avoiding Duplication**:
* Keep detailed principles in supporting files
* SKILL.md provides brief overview with cross-references
* Example: "Apply principles from @best-practices.md" instead of repeating them
* Pattern: "For detailed X, see @reference.md"

## Slash Commands

```markdown
---
name: command-name
description: Brief one-line purpose
argument-hint: [optional-arg]
---

# Command Title

Clear purpose statement.

Target: `$ARGUMENTS`

## Instructions

1. 🔳 Ensure X loaded
   - Skip if already done

2. 🔳 Do main work
   - Details...

3. **STOP AND WAIT** - Await `/proceed` confirmation
```

Note: Per CLAUDE.md, steps with 🔳 automatically become TaskCreate items.

### Command Guidelines

* Front-load critical rules (STOP points, approval gates)
* Use phases for multi-step workflows
* Single emphasis level (CRITICAL or Important, not both)
* Imperative mood throughout

## Optimization Workflow

When optimizing existing instructions:

1. **Analysis Phase**
   * Read target file and all linked files (@docs references)
   * Identify issues: verbosity, unclear structure, weak examples, cross-file redundancy
   * Compare against best practices
   * List specific issues with examples
   * Show before/after for key changes
   * Estimate token savings

2. **Wait for Approval**

3. **Implementation Phase**
   * Apply optimizations systematically
   * Remove meta-commentary
   * Consolidate redundant examples
   * Convert prose to lists/tables where clearer
   * Use imperative mood
   * Front-load critical rules
   * Single emphasis level
   * **Preserve all salient information**
