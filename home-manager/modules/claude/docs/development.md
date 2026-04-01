
# Development Instructions

## General principles

* Never implement until you see exact phrase "🚀 Engage thrusters" (from /proceed or /implement). No variations.
* Scope discipline: during `/implement`, execute ONLY tasks from the approved plan
  * Boy-scout fixes in code you're already touching are fine (small cleanup, typo fix)
  * New tasks, inbox items, discovered issues beyond current scope: inform user, don't act
  * Mental model: would a new developer start this work without team agreement?
* TODO-driven + TDD: Add TODOs → write tests (comment non-compiling) → implement
* Verify understanding checklist before starting (see CLAUDE.md)
* Iterate: add functions/structures/TODOs before implementation
* Follow existing patterns, use existing libraries
* Follow a SR&ED documentation style. Persist new uncertainties, hypothesis, decisions, insights,
  failed approaches to phase doc Questions & Investigations immediately — docs are the single source
  of truth, not conversation context
* Optimize for the target codebase, not minimal diff. When told to build X, build X — don't
  build a half-measure Y because it's smaller or safer. Half-measures cost more total effort
* Write simple, non-overlapping tests (test golden path, not exhaustively)
* Always leave existing TODO/FIXME/REVIEW comments intact, unless we implemented them or tracked
  them in project doc.

## Before inserting any code

Before adding/modifying code, ensure to follow this checklist:

<code-insert-checklist>
* [ ] Make sure that code is being inserted following the ordering of methods as per code style guidelines (ex: `file-organization-order`)
* [ ] Make sure your comments/docs aren't excessive & describes why, not what
* [ ] Make sure reuse code and find existing utils before writing new code
* [ ] Make sure code strictly follows personal & project code style guidelines
      (@~/.claude/docs/code-style.md)
</code-insert-checklist>

## When to Stop

STEP IMPLEMENTATION as soon as any of these triggers occur:

<development-stop-triggers>
* Architectural mismatches (mutable vs immutable, incompatible structures)
* API incompatibilities requiring redesign
* Multiple failed workarounds
* No workarounds/reverts/continued coding - ask for help
* Never claim completion if incomplete
* Keep executing a command which never succeeds
* Version control state confusing or operations had unexpected effects
</development-stop-triggers>

## Before marking as completed

Before marking the development as completed, ensure to follow this checklist:

<development-completion-checklist>
* [ ] Initial plan/requirements/ACs/TODOs addressed
* [ ] Tests are added/updated and passing
* [ ] All task ACs verified passing
* [ ] Diff reviewed (`jj-diff-working --git`)
* [ ] Temporary debug files/code removed
* [ ] Code style guidelines followed
* [ ] Strictly follow ordering in `file-organization-order`
* [ ] Formatting, linting (including type checking if applicable), tests pass (only affected modules)
* [ ] Dependent code is still compiling & testing
* [ ] Project doc updated (if exists)
</development-completion-checklist>
