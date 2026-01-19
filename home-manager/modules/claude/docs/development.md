
# Development Instructions

## Implementation Approach

* TODO-driven + TDD: Add TODOs → write tests (comment non-compiling) → implement
* Use project-specific TODO tags: `// TODO: PROJCODE - description`
* Never start implementation until explicitly told (even after plan)
* Verify understanding checklist before starting (see CLAUDE.md)
* Create `private: claude:` jj change before code changes (@docs/version-control.md)

## Coding

* Iterate: add functions/structures/TODOs before implementation
* Follow existing patterns, use existing libraries
* Write simple, non-overlapping tests (test golden path, not exhaustively)
* Comment out non-compiling code in compiled languages

## When Stuck

Comment out failing code/tests. Use `AskUserQuestion` for help.

## Before Completion

Verify:
* [ ] Initial plan/TODOs addressed
* [ ] Diff reviewed (`jj-diff-working --git`)
* [ ] Code style guidelines followed
* [ ] Formatting, linting, tests pass (including affected modules)
* [ ] Temporary debug files/code removed
* [ ] Project doc updated (if exists)

## When to Stop

CRITICAL: For fundamental design problems, stop immediately:
* Architectural mismatches (mutable vs immutable, incompatible structures)
* API incompatibilities requiring redesign
* Multiple failed workarounds
* No workarounds/reverts/continued coding - ask for help
* Never claim completion if incomplete
