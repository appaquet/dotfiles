
# Development Instructions

* We use a mix of TODO-driven development and Test-Driven Development (TDD). Before tackling a big
  change, add TODOs to the codebase. Then write tests (if they can't compile yet, comment out the
  failing code), and finally implement the code

* In order to make sure we can find the TODOs easily, I always use a project specific code. Ex: `//
  TODO: MERGE_SEGMENTS - `. This allows us to search for `MERGE_SEGMENTS` in the codebase and find
  all the TODOs related to that specific project

* Here's my usual development workflow, which I'll details through commands when starting them:
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
