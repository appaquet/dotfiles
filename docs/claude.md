# Claude Guide

## TODO

- [x] Uncertainty disclosure

## Workflows

- Actions
  - `/go`: Start implement the next task / work item / phase
  - `/continue`: Continue working on what you were doing before being interrupted
  - `/ask`: Think about a topic and provide feedback without acting

- Context management
  - `/ctx-load`: Load repository and task context
  - `/ctx-save`: Save important context from conversation to project docs
  - `/ctx-plan`: Plan a high-level development plan for the task at hand
  - `/ctx-improve`: Improve context by asking clarifying questions to user
  - `/ctx-check`: Check context understanding and output uncertainty disclosure

- Project/tasks management
  - `/proj-init`: Initialize project folder and main doc
  - `/proj-split`: Split a phase into a numbered sub-doc
  - `/proj-tidy`: Validate and fix project doc consistency
  - `/pr-desc`: Generate PR description for current branch

- Reviewing
  - `/review-launch`: Launch review agents for code style, architecture and correctness
  - `/review-search`: Search for REVIEW comments in the codebase
  - `/review-plan`: Create a review plan based on code changes
  - `/review-fix`: Fix code review findings

- Instructions / Memory
  - `/mem-edit`: Entry point for instruction file changes (edits, fixes, optimization)
  - `/introspect`: Reflect on errors to propose instruction improvements (suggests /mem-edit)

- Thinking
  - `/think`: Trigger deep thinking mode for complex problems

- Pull requests
  - `/pr-import-comments`: Import PR comments into codebase as REVIEW comments
  - `/pr-reply-comments`: Reply to PR comments based on code changes

## Agents

- `branch-diff-summarizer`: Analyzes branch changes and generates file-by-file summaries for project docs
- `code-style-reviewer`: Reviews code for style, formatting, and syntax issues
- `code-correctness-reviewer`: Reviews code for logic errors, bugs, and runtime issues
- `architecture-reviewer`: Reviews code for architectural consistency and design patterns
- `requirement-analyzer`: Analyzes project requirements and identifies potential gaps or ambiguities
