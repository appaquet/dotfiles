# Workflows

## Expectations

- Always `/ctx-load` first
- Plan before implementing (`/ctx-plan`)
- Wait at STOP points - don't ask to continue
- Track work in project docs

## Commands

### Development Flow
- `/ctx-load`: Load project context
- `/ctx-plan`: Create development plan
- `/implement`: Execute tasks from phase doc
- `/ctx-save`: Save progress to project docs
- `/proceed`: Continue from STOP points

### Context
- `/ctx-improve`: Clarify understanding via questions
- `/ctx-check`: Output uncertainty disclosure
- `/continue`: Resume interrupted work

### Thinking
- `/ask`: Analyze without acting
- `/think`: Deep thinking for complex problems

### Project
- `/proj-init`: Initialize project folder
- `/proj-edit`: Edit project/phase docs
- `/proj-tidy`: Validate doc consistency

### Review
- `/review-launch`: Launch review agents
- `/review-search`: Find REVIEW comments
- `/review-plan`: Plan fixes for REVIEW comments

### Pull Requests
- `/pr-desc`: Generate PR description
- `/pr-import-comments`: Import PR comments
- `/pr-reply-comments`: Reply to PR comments

### Instructions
- `/mem-edit`: Edit instruction files
- `/introspect`: Reflect on errors

### Parallel
- `/forked <skill>`: Fork to sub-agents

## Internal Skills

Called by commands, no user gate:
- `mem-editing`: Instruction editing
- `proj-editing`: Project doc editing

## Agents

- `branch-diff-summarizer`: File-by-file change summaries
- `code-style-reviewer`: Style, formatting, syntax
- `code-correctness-reviewer`: Logic, bugs, runtime issues
- `architecture-reviewer`: Architecture, patterns
- `requirement-analyzer`: Requirement gaps
