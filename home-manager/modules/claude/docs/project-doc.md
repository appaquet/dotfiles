# Project Doc Structure

Project/feature documentation spanning multiple PRs. Docs kept throughout development.

## File Location

Unless project instructions specify otherwise:

* **Default**: `docs/features/<date>-<project-name>/` (date via `date +%Y/%m/%d`)
* **Main doc**: `00-<project-name>.md` inside the folder
* **Sub-docs**: `01-<phase-name>.md`, `02-<phase-name>.md`, etc. (numbered for ordering)
* **Symlink**: `proj/` at repo root pointing to the project folder
* **Private change**: Symlink in `private: proj - <project-name>` jj change - never committed

### Finding Project Docs

1. Check if `proj/` symlink exists at repo root → follow it
2. Look for `00-*.md` as main doc, `01-*.md`, `02-*.md`, etc. as sub-docs
3. If project instructions specify different location → use that

## When to Create

* **Create**: Only via `/proj-init`
* **Update**: After file modifications if exists
* **Sub-docs**: Only via `/proj-split` OR after explicitly asking user
* **Never**: Create phases/sub-docs proactively without asking

## Sections

Keep sections in order described below.

### Context

Purpose and scope of changes

### Requirements (optional)

Specific requirements

### Questions (optional)

Checklist of questions/answers to resolve

### Files

Modified or important context files. Update after modifications.

* Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), project docs
* Include: crucial files even if unmodified
* Format: `- **path/file.ext**: Purpose. Changes (if any).`
* With sub-docs: use shorter descriptions, reference sub-doc for details
* Never replace files list with redirects like "See [sub-doc] for details"

### TODO

Flat checkmark list of work items.

**Task indicators:**

* `[ ]` incomplete
* `[~]` in progress
* `[x]` complete

**Phase indicators** (prefix for sub-doc references):

* `### ⬜ Phase Name` - To Do
* `### 🔄 Phase Name` - In Progress
* `### ✅ Phase Name` - Done

**Sub-doc reference** (when split via `/proj-split`):

```
### 🔄 Phase: Auth
[01-auth.md](01-auth.md)

Implement OAuth2 flow with JWT tokens. Adds login/logout endpoints and session management.
```

* Always include 2-3 sentence summary after link - provides context without opening sub-doc
* Maintain summary as phase progresses - update when scope changes significantly

**Progress Tracking Rules:**

* When starting work on a task → mark it `[~]` immediately
* When starting work in a phase → mark it 🔄 immediately
* Claude can mark tasks `[x]` after completing them
* Claude NEVER marks phases ✅ → use `AskUserQuestion` to ask user
* When resuming: if multiple items are `[~]` or 🔄, ask user which to focus on

**Management:**

* Update after starting/completing; detail sufficient for pickup
* If split into sub-doc, update both main and sub-doc
* Each item = discrete, independent work unit
* Never remove useful info from completed TODOs
* Propose `/proj-split` at 15+ items or completed phase with 5+ items

### Pull Requests (optional)

* Start "In this PR, I implemented..." + high-level technical overview
* Focus on capability, not implementation details
* Use system/component terms; avoid function names/algorithms
* Omit test plans and generated attribution
