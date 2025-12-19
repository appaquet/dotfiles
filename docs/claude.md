# Claude Guide

## TODO

- [x] Better project docs. Rename from PR to 00-project.md and then have sub-docs sequenced.
  - `proj/` symlink at root → `docs/features/<date>-<project-name>/`
  - Main doc: `00-<project-name>.md`, sub-docs: `01-phase.md`, `02-phase.md`, etc.
- [x] Make clear that project folder at root is always a symlink to actual folder

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

- Project/tasks management
  - `/proj-init`: Initialize project folder and main doc
  - `/proj-split`: Split a phase into a numbered sub-doc
  - `/proj-desc`: Generate PR description for current branch
  - `/proj-migrate`: Migrate existing PR.md project to new structure

- Reviewing
  - `/review-launch`: Launch review agents for code style, architecture and correctness
  - `/review-search`: Search for REVIEW comments in the codebase
  - `/review-cat`: Categorize code review findings
  - `/review-fix`: Fix code review findings

- Instructions / Memory
  - `/mem-optimize`: Optimize instructions and memory usage
  - `/introspect`: Reflect on errors to propose instruction improvements

- Pull requests
  - `/pr-import-comments`: Import PR comments into codebase as REVIEW comments
  - `/pr-reply-comments`: Reply to PR comments based on code changes

## Agents

- `branch-diff-summarizer`: Analyzes branch changes and generates file-by-file summaries for project docs
- `code-style-reviewer`: Reviews code for style, formatting, and syntax issues
- `code-correctness-reviewer`: Reviews code for logic errors, bugs, and runtime issues
- `architecture-reviewer`: Reviews code for architectural consistency and design patterns
