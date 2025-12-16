# Claude Guide

## Workflows

- Actions
  - `/go`: Start implement the next task / work item / phase
  - `/continue`: Continue working on what you were doing before being interrupted
  - `/ask`: Think about a topic and provide feedback without acting

- Reviewing
  - `/review-launch`: Launch review agents for code style, architecture and correctness
  - `/review-search`: Search for REVIEW comments in the codebase
  - `/review-cat`: Categorize code review findings
  - `/review-fix`: Fix code review findings

- Context management
  - `/ctx-load`: Load repository and task context
  - `/ctx-save`: Save important context from conversation to PR.md and sub-files
  - `/ctx-plan`: Plan a high-level development plan for the task at hand
  - `/ctx-improve`: Improve context by asking clarifying questions to user

- Project/tasks management
  - `/pr-init`: Initialize a PR.md file for the current task
  - `/pr-split`: Split a phase from PR.md into a sub-file
  - `/pr-desc`: Generate PR description for current branch

- Instructions / Memory
  - `/mem-optimize`: Optimize instructions and memory usage

- Pull requests
  - `/pr-import-comments`: Import PR comments into codebase as REVIEW comments
  - `/pr-reply-comments`: Reply to PR comments based on code changes

## Agents

- `branch-diff-summarizer`: Analyzes branch changes and generates file-by-file summaries for PR.md
- `code-style-reviewer`: Reviews code for style, formatting, and syntax issues
- `code-correctness-reviewer`: Reviews code for logic errors, bugs, and runtime issues
- `architecture-reviewer`: Reviews code for architectural consistency and design patterns
