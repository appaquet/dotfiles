
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

* I use a mix of TODO-driven development and Test-Driven Development (TDD). Before tackling a big
  change, add TODOs to the codebase. Then write tests (if they can't compile yet, comment out the
  failing code), and finally implement the code

* In order to make sure we can find the TODOs easily, I always use a project specific code.
  Ex: `// TODO: MERGE_SEGMENTS -`. This allows us to search for `MERGE_SEGMENTS` in the codebase and find
  all the TODOs related to that specific project

* Make sure to come up with a good and very detailed plan and note all TODOs before starting the
  implementation

* Before doing any changes to the code, always make sure you are working on a `private: claude:`
  `jj` change so that I can revert after. **IMPORTANT** Create a new one every time you start
  working on a new task that could span multiple files, OR, that you aren't confident about an
  implementation so that you can easily revert it if needed.

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

* If a file is too big for your context, ask me if you can split it to optimize your context use

* Remove TODOs once implemented and add more if needed

* Before considering the task complete, *ALWAYS*:
  * Review the initial plan, TODOs and instructions
  * Review your code with by diffing the current working changes (`fish -c "jj-diff-working"`)
  * Make sure that strictly follows the code style guidelines
  * Run formatting, linting and tests
  * Fix any issues that aren't expected
  * If you create temporary files for debugging purpose (ex: temporary tests, binaries, etc.), make
    you to **always** remove them when you are done debugging. Temporary files should not be committed
    to the codebase

* **NEVER** stop until everything is working and all tests are passing, unless it's something you
  are blocked on and need more context or insights

* **ALWAYS** tell me if an implementation is incomplete at the end of the process. Never tell me
  that the feature is complete unless it is 100% finished, follows the plan exactly, and all
  lints/tests are passing.

* Update `PR.md` (if it exists, at root of repo)
