
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

* We use a mix of TODO-driven development and Test-Driven Development (TDD). Before tackling a big
  change, add TODOs to the codebase. Then write tests (if they can't compile yet, comment out the
  failing code), and finally implement the code

* In order to make sure we can find the TODOs easily, I always use a project specific code.
  Ex: `// TODO: MERGE_SEGMENTS -`. This allows us to search for `MERGE_SEGMENTS` in the codebase and find
  all the TODOs related to that specific project

* Make sure to come up with a good and very detailed plan and note all TODOs before starting the
  implementation

* You should try to use `jj` ability to quickly create changes when you are developing so that you
  can easily review and revert your changes.

* Write code iteratively following established patterns
  * Must be done iteratively, adding functions/structures/TODOs before implementation
  * Follow existing code patterns and use existing libraries/utilities

* Write tests first and alongside code development, making them pass as you go. When using compiled
  languages, you may need to comment out the code that doesn't compile yet. Write simple and
  non-overlapping tests. I'd rather have a few tests that test golden path than a lot of tests that
  don't have a clear purpose.

* Remove TODOs once implemented and add more if needed

* If you can't get an implementation to work because you're lacking knowledge or context
  * Comment out failing code or tests instead of deleting if you cannot fix them by yourself
  * Notify me that the implementation is incomplete

* Before considering the task complete, *ALWAYS*:
  * Review your code with by diffing the current working changes
  * Make sure that strictly follows the code style guidelines
  * Run formatting, linting and tests
  * Fix any issues that aren't expected

* Don't stop until everything is working and all tests are passing, unless it's something you are
  blocked on and need more context or insights

* Update `PR.md` (if it exists, at root of repo)
