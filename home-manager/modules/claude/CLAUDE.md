# General

* Name: AP
* Shell: fish
* Research unknowns; never assume. Verify claims before stating - check docs/code first
* Keep solutions simple
* No superlatives or excessive praise - wastes tokens, users prefer directness
* Optimize for TOTAL tokens (including future fixes), not current tokens - deep thinking upfront is
  cheaper than iterations
* Environment: NixOS + MacOS (home manager, nix darwin)

## Top-level instructions

* If `/ctx-load` has never been called, always call it first
* Plan and track work using project & phase docs: @docs/project-doc.md
* When summarizing, ALWAYS include the reference to project doc and phase (@proj/..., where
  prefix path with `@` very important to make sure we automatically reference the file)
* Never implement until you see exact phrase "🚀 Engage thrusters". Never ask via `AskUserQuestion`
  if you can proceed - wait for signal
* You should always use `AskUserQuestion` to ask me questions. Never ask me directly in response
* In any command/skill/agent, create a `TaskCreate` for each instruction step that has 🔳 annotation
  before proceeding with any of the requested work. Mark in-progress/completed as you proceed

## Sub-instructions files

* Workflows: @docs/workflows.md
* Project doc structure: @docs/project-doc.md
* Version control: @docs/version-control.md
* Development: @docs/development.md
* Code style: @docs/code-style.md

## Context understanding

Always ensure 10/10 understanding checklist: explore code + web search + `AskUserQuestion`
Always report on understanding at any decision point - verbalize WHAT you understand for each item, not just that you checked it. User validates your understanding

<full-understanding-checklist>
* [ ] Clear on goal/user need: [state the goal]
* [ ] Identified similar use cases: [list them]
* [ ] Understand existing patterns: [describe patterns]
* [ ] Re-read file structure: [list key files]
* [ ] List existing functions/classes: [name them]
* [ ] Have test strategy: [describe approach]
* [ ] Know which files to modify: [list files]
* [ ] Know success criteria: [state criteria]
</full-understanding-checklist>

## Destructive Operations

Before deleting files/content: confirm preserved elsewhere OR explicitly disposable
Before rewriting/refactoring files: diff old vs new to verify no content lost
Always assume you are not alone working on the same code. Multiple agents or myself may be working concurrently.

## Problem Solving

For problems/issues/failing tests:

<problem-solving-checklist>
1. Understand WHY (trace data flow, logging, changes)
2. Fix root cause, not symptom. Generic solution over specific case and bespoke fixes
3. Ask user before destructive changes
4. Test bugs: verify new test catches issue or update existing test to catch it
</problem-solving-checklist>

When agreed plan fails: STOP, explain failure, ask before changing approach
User-specified approaches are constraints - a working workaround is still a failure if it deviates

## Deep Thinking

When a command/skill/agent requires thorough analysis, apply these steps:

<deep-thinking>
1. STOP rushing - invest thinking tokens now to save iteration tokens later
2. Re-read all relevant context - don't rely on memory
3. Analyze thoroughly (ultra think, be pedantic)
4. Externalize your thinking - speak your mind LOUDLY, don't just use thinking blocks
5. Think as a fresh agent - what could be misinterpreted? What's ambiguous?
6. Question assumptions - what haven't you verified?
</deep-thinking>
