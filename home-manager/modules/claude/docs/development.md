
# Development Instructions

## Development Workflow

Here's my usual development workflow, which I'll detail through commands when starting them:

1. Planning phrase: load relevant docs and context, create high-level plan and potentially project
   documentation (ex: PR.md)
2. Scaffolding phase: add TODOs, scaffold structure (interfaces, structs, functions), write tests
   and comment out the code that doesn't compile yet
3. Implementation phase: implement code, make tests pass as code is being implemented, making sure
   it is properly formatted and linted as well
4. Implementation review phase: I'll review the implementation and leave `// REVIEW:` comments to
   be addresses
5. Pull request review phase: we review the overall pull request / branch changes and make sure
   everything is in order, including documentation, tests, formatting, etc.
6. Pull request opening phase: we describe our changes and get ready to open the pull request

## Implementation Guidelines

* Use a mix of TODO-driven development and Test-Driven Development (TDD). Before tackling a big
  change, add TODOs to the codebase. Then write tests (if they can't compile yet, comment out the
  failing code), and finally implement the code

* In order to make sure we can find the TODOs easily, always use a project specific code.
  Ex: `// TODO: MERGE_SEGMENTS -`. This allows us to search for `MERGE_SEGMENTS` in the codebase and
  find all the TODOs related to that specific project

* Make sure to come up with a good and very detailed plan and note all TODOs before starting the
  implementation. If I ask you to make a plan or write the plan to a PR.md without explicitly
  telling you to start the implementation after, you should **NEVER** start the implementation until
  I tell you to.

* Before jumping into the implementation, **ALWAYS** verify your understanding checklist. Never
  assume anything, **ALWAYS** use `AskUserQuestion` tool for any unclear requirements

* Before doing any changes to the code, create a `private: claude:` `jj` change following the
  guidelines in @docs/version-control.md.

* Write code iteratively following established patterns
  * Must be done iteratively, adding functions/structures/TODOs before implementation
  * Follow existing code patterns and use existing libraries/utilities

* Write tests first and alongside code development, making them pass as you go. When using compiled
  languages, you may need to comment out the code that doesn't compile yet. Write simple and
  non-overlapping tests. I'd rather have a few tests that test golden path than a lot of tests that
  don't have a clear purpose.

* If you can't get an implementation to work because you're lacking knowledge or context
  * Comment out failing code or tests instead of deleting if you cannot fix them by yourself
  * Notify me that the implementation is incomplete

* Before considering a task or ask complete, *ALWAYS*:
  * Review the initial plan, TODOs and instructions
  * Review your code with by diffing the current working changes (`jj-diff-working --git`)
  * Make sure that **strictly** follows the code style guidelines
  * **VERY IMPORTANT:** Run formatting, linting and tests. Don't only test your code, but modules
    that you may have affected as well (ex: packages, crates, etc.)
  * Fix any issues that aren't expected
  * If you create temporary files for debugging purpose (ex: temporary tests, binaries, etc.), make
    you to **always** remove them when you are done debugging. Temporary files should not be committed
    to the codebase

* **STOP IMMEDIATELY when you encounter a fundamental design problem you can't solve:**
  * Architectural mismatches (e.g., mutable vs immutable, different data structures)
  * API incompatibilities that require significant redesign
  * When you find yourself trying multiple failed workarounds
  * **Don't try workarounds, don't revert, don't keep coding blindly. ASK FOR HELP.**

* **NEVER** considerate a task complete and tell me so if it is not. Always be honest about the
  state of your work. This is **VERY VERY VERY IMPORTANT** for trust and collaboration.

* Update `PR.md` (if it exists, at root of repo)
