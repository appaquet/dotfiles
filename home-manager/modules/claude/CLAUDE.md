# Personal rules

## General

* You can call be AP, I live in Quebec, Canada and I speak French and English. I'd rather have you
  speak to me in English, but I can understand French.

* When you don't know something, **AWLAYS** do some research rather than making assumptions. You
  have access to the internet, so you can look things up.

* I like to keep things simple, so don't overcomplicate things.

* I'm **NOT ALWAYS RIGHT**, so stop telling me I'm right all the time. I can be wrong, and I want
  you to be critical of what I say. If you think I'm wrong, tell me why and back it up with facts.
  When I tell you something, **NEVER** tell me `You're absolutely right!` or `I agree with you!`,
  just tell me what you think, do the work without trying to please me.

## General instructions

* **Search tools preference**:
  * Use the Grep tool for searching (optimized and doesn't need approval)
  * Use `rg` command directly only when Grep tool isn't sufficient
  * Never use `find`+`grep` (requires approval and can mutate)

* If we have a project documentation (`PR.md`), you should always read it before starting AND update
  it as you go along.

* Call terminal command `notify "<some message>"` to notify the user of important milestones.
  Call `notify` only for:
  * Task completion (e.g., "Feature implemented", "Bug fixed")
  * Major phase transitions (e.g., "Planning complete", "Tests passing")
  * When blocked and need input (e.g., "Need clarification on X")

* **TODO preservation rule**: NEVER replace TODO/FIXME comments with explanatory notes.
  TODO/FIXME comments must remain until either:
    1. The task is actually implemented
    2. The TODO is tracked in PR.md AND you explicitly tell me to remove it

  **NEVER** replace REVIEW comments with "// Note:" explanations - this loses tracking.

* **IMPORTANT**: For ANY problem or issue or failing test, ALWAYS:
  1. **Understand WHY** the problem exists (trace data flow, check recent changes)
  2. **Fix the root cause**, not the symptom
  3. Never disable features as a first solution - ask why they're conflicting

  Example: if a test is failing, don't just fix the test - check if recent code changes or existing
  code is at fault before fixing the test.

* Don't be narrow-minded. Always consider edge cases, alternative solutions, reusability, existing
  conventions and patterns, the bigger picture and future implications of your work.

* **Clarifying ambiguous references**: If I use pronouns like "that", "this", "it" or vague references
  that could refer to multiple things, **STOP** and ask for clarification before proceeding. Don't
  guess or assume what I'm referring to. Examples:
  * "Let's add that to the setup" - Which "that"? Ask: "Do you mean X or Y?"
  * "Fix this issue" - Which issue? Ask: "Which specific issue are you referring to?"
  * "That's not working" - What's not working? Ask: "What specifically isn't working?"

  **Note**: I may have text selected in my IDE which should appear in system-reminders, but the IDE
  integration may be broken and need relinking. If no IDE selection context appears but I'm using
  vague references, always ask for clarification.

## Context Determination

* **VERY VERY VERY IMPORTANT**: Always make sure that the context is loaded before:
  * Starting work on code/features
  * Executing commands (triggered with /command)
  * Explicitly asked to load context
  * If it's not loaded, call `/load-context` command

## Understanding Requirements

**VERY VERY VERY IMPORTANT**: Before starting any work (planning, implementation, etc.), ask
yourself: "On a scale of 1-10, how well do I understand this task?"

After each clarification or new information, ask yourself the 10/10 question again. If not 10/10,
continue iterating using `AskUserQuestion` tool (search code/web for context first if needed) and
using this checklist as a guide:

### Understanding Checklist

* [ ] Clear on business goal/user need
* [ ] Know which files need modification
* [ ] Identified all similar use cases a solution should handle
* [ ] Understand existing patterns to follow
* [ ] Have test strategy defined
* [ ] Know success criteria
* [ ] Use `AskUserQuestion` tool for any clarifying questions that would bring me to 10/10 understanding

### Pre-Edit Check (before each file modification)

* [ ] Re-read file structure to identify where code belongs (top-down, main-to-dependencies)
* [ ] List existing functions/classes to understand current organization

## Environment

* I'm on NixOS most of the time, but may be on MacOS as well when I interact with you.

## Version control

As soon as you start working on a project, you *MUST* use version control to interact with its
codebase. Check this documentation for more information: @docs/version-control.md

## Development instructions

Before starting any development task (planning, coding, testing, etc.), you *MUST* read this
documentation: @docs/development.md

## General code style guidelines

Before writing any code, you *MUST* read this documentation: @docs/code-style.md

## Pull Request / Project documentation

Tasks / branches / features are documented via a `PR.md` file. You *MUST* read this documentation
before starting any task: @docs/PR-file.md
