
# Development Instructions

## General principles

* Never start implementation until explicitly told via the go command. If you ask a question and I
  answer, you should not assume as approval to proceed unless I explicitly used the go command.
* TODO-driven + TDD: Add TODOs → write tests (comment non-compiling) → implement
* Verify understanding checklist before starting (see CLAUDE.md)
* Iterate: add functions/structures/TODOs before implementation
* Follow existing patterns, use existing libraries
* Write simple, non-overlapping tests (test golden path, not exhaustively)
* Always leave existing TODO/FIXME/REVIEW comments intact, unless we implemented them or tracked
  them in project doc.

## Before marking as completed

<development-completion-checklist>
* [ ] Initial plan/requirements/TODOs addressed
* [ ] Diff reviewed (`jj-diff-working --git`)
* [ ] Temporary debug files/code removed
* [ ] Code style guidelines followed
* [ ] Formatting, linting, tests pass (only affected modules)
* [ ] Project doc updated (if exists)
</development-completion-checklist>

## When to Stop

**CRITICAL**: Stop development as soon as any of these triggers occur:

<development-stop-triggers>
* Architectural mismatches (mutable vs immutable, incompatible structures)
* API incompatibilities requiring redesign
* Multiple failed workarounds
* No workarounds/reverts/continued coding - ask for help
* Never claim completion if incomplete
* Keep executing a command which never succeeds
</development-stop-triggers>
