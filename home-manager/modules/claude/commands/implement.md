
# Implementation phase

Write code, tests, handle linting/formatting, removing TODOs left during planning and scaffolding
phases.

* Make sure to come up with a good plan and note all TODOs before starting the implementation

* Write code iteratively following established patterns
  * Must be done iteratively, adding functions/structures/TODOs before implementation
  * Follow existing code patterns and use existing libraries/utilities

* Write tests first and alongside code development, making them pass as you go. When using compiled
  languages, you may need to comment out the code that doesn't compile yet.

* Check and fix diagnostics before running tests
  * Don't try to fix unrelated diagnostics, focus on current task

* Remove TODOs once implemented and add more if needed

* Failing implementation
  * Comment out failing code or tests instead of deleting if you cannot fix them by yourself
  * Notify me that the implementation is incomplete

* Before considering the task complete, *ALWAYS*:
  * Review your code with by diffing the current working changes
  * Run formatting, linting and tests
  * Fix any issues that aren't expected

* Update `PR.md` (if it exists, at root of repo)
