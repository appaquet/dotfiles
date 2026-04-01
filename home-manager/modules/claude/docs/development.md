
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
* Write simple, non-overlapping tests (see <testing-principles>)
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

## Testing principles

<testing-principles>
* Tests must verify outcomes (state changes, return values), not just that code runs without error.
  A test that only checks "no exception thrown" is incomplete — assert expected state
* For data-changing operations, verify before/after state deltas
* Unit tests verify isolated logic. Integration tests verify components work together.
  Both are needed — passing unit tests alone does not guarantee the system works end-to-end
* Test at least one cross-feature interaction or integration seam per feature. Bugs cluster
  at boundaries between components
* Never modify an existing test to make it pass — fix the code. If the test is genuinely wrong,
  explain why before changing it
* Never write helper scripts that bypass the actual system under test
* Include at least one test with intentionally invalid input to verify error handling rejects it
* After writing tests, ask: would these tests catch the bug if the implementation were subtly
  wrong? Tests that mirror the implementation's assumptions don't add safety
</testing-principles>

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
* Multiple consecutive test failures without progress toward a fix
* Generating work beyond the planned scope (all tasks complete, inventing new ones)
</development-stop-triggers>

## Before marking as completed

Before marking the development as completed, ensure to follow this checklist:

<development-completion-checklist>
* [ ] Initial plan/requirements/ACs/TODOs addressed
* [ ] Tests are added/updated and passing, using <testing-principles>
* [ ] All task ACs verified passing
* [ ] Diff reviewed (`jj-diff-working --git`)
* [ ] Temporary debug files/code removed
* [ ] Code style guidelines followed
* [ ] Strictly follow ordering in `file-organization-order`
* [ ] Formatting, linting (including type checking if applicable), tests pass (only affected modules)
* [ ] No unexpected file deletions in diff (check --stat)
* [ ] Full project test suite passes (not just tests for changed code)
* [ ] Dependent code is still compiling & testing
* [ ] After completing changes, consider: do changes affect other features or paths not covered by the task's tests?
* [ ] Project doc updated (if exists)
</development-completion-checklist>
