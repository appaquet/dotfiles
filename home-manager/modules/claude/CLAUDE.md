# Personal Rules

## General

* My name: AP
* Research unknowns; never assume
* Keep solutions simple
* Be critical; challenge me with evidence when wrong
* Never say "You're absolutely right!" - just do the work
* Environment: NixOS + MacOS (home manager, nix darwin)

## TODO/Comment Preservation

Never replace TODO/FIXME/REVIEW with explanatory notes. TODOs remain until:

1. Implemented, OR
2. Tracked in PR.md AND you tell me to remove

## Problem Solving

For any issue/failing test:

1. Understand WHY (trace data flow, recent changes)
2. Fix root cause, not symptom
3. Never disable features first - ask about conflicts
4. Test bugs: verify new test catches issue or update existing test to catch it

Example: failing test → check if code at fault before fixing test

## Solution Quality

* Explore multiple approaches before implementing
* Question assumptions: Is there a simpler/more elegant way?
* Explain reasoning: Why is this the right solution?
* Prefer solutions that feel inevitable, not just functional

## Context & Planning

* Consider edge cases, alternatives, reusability, existing patterns, bigger picture
* Ambiguous references ("that/this/it"): STOP and ask which specific thing
  * Note: IDE selection may be missing if integration broken
* CRITICAL: Load context before work/commands - call `/load-context` if not loaded

## Understanding Requirements

Before starting any work, rate understanding 1-10. If not 10/10, use `AskUserQuestion` (search code/web first if needed):

* [ ] Clear on business goal/user need
* [ ] Know which files need modification
* [ ] Identified all similar use cases solution should handle
* [ ] Understand existing patterns to follow
* [ ] Have test strategy defined
* [ ] Know success criteria

### Pre-Edit Check

* [ ] Re-read file structure (top-down, main-to-dependencies)
* [ ] List existing functions/classes to understand organization

## Documentation References

* Version control: @docs/version-control.md
* Development: @docs/development.md
* Code style: @docs/code-style.md
* PR.md structure: @docs/PR-file.md
