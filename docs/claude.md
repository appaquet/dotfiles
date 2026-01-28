# Claude Guide

## TODO

- [ ] Self-validation TODO items
- [x] `proj-split` -> should be `proj-edit` with crystal clear instructions on how project should be
      edited. (Done: created /proj-edit command + proj-editing skill)
- [x] Generalize all commands to force creation of tasks to gate things (Phase: Task Gating)
- [x] Mem edit -> instruction writer (consolidated into /mem-edit command + mem-editing skill)
- [ ] Generialize all commands that end up with an impletementation to use the same pattern
  - Perhaps build a <..> tag and refer to it for clear instructions
- [ ] Custom keybindings (see /keybindings)

## Workflows

- Actions
  - `/go`: Start implement the next task / work item / phase
  - `/continue`: Continue working on what you were doing before being interrupted
  - `/ask`: Think about a topic and provide feedback without acting
  - `/think`: Trigger deep thinking mode for complex problems

- Context management
  - `/ctx-load`: Load repository and task context
  - `/ctx-save`: Save important context from conversation to project docs
  - `/ctx-plan`: Plan a high-level development plan for the task at hand
  - `/ctx-improve`: Improve context by asking clarifying questions to user
  - `/ctx-check`: Check context understanding and output uncertainty disclosure

- Project/tasks management
  - `/proj-init`: Initialize project folder and main doc
  - `/proj-split`: Split a phase into a numbered sub-doc
  - `/proj-edit`: Edit project/phase docs with structure validation
  - `/proj-tidy`: Validate and fix project doc consistency
  - `/pr-desc`: Generate PR description for current branch

- Reviewing
  - `/review-launch`: Launch review agents for code style, architecture and correctness
  - `/review-search`: Search for REVIEW comments in the codebase
  - `/review-plan`: Research REVIEW comments, present plan, then fix after /go

- Instructions / Memory
  - `/mem-edit`: Edit instruction files with analysis and gate (user-facing)
  - `/introspect`: Reflect on errors to propose instruction improvements (suggests /mem-edit)

- Pull requests
  - `/pr-import-comments`: Import PR comments into codebase as REVIEW comments
  - `/pr-reply-comments`: Reply to PR comments based on code changes

- Internal Skills (called by commands, no gate)
  - `mem-editing`: Instruction file editing
  - `proj-editing`: Project/phase doc editing

## Agents

- `branch-diff-summarizer`: Analyzes branch changes and generates file-by-file summaries for project docs
- `code-style-reviewer`: Reviews code for style, formatting, and syntax issues
- `code-correctness-reviewer`: Reviews code for logic errors, bugs, and runtime issues
- `architecture-reviewer`: Reviews code for architectural consistency and design patterns
- `requirement-analyzer`: Analyzes project requirements and identifies potential gaps or ambiguities
