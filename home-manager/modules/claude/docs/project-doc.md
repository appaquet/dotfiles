# Project Doc Structure

Project/feature documentation spanning potentially multiple PRs. Docs kept throughout development

## File Location

Unless project instructions specify otherwise:

* **Default**: `docs/features/<yyyy>/<mm>/<dd>-<project-name>/` (if date unavailable, use `date +%Y/%m/%d`)
* **Main doc**: `00-<project-name>.md` inside the folder
* **Phase docs**: `01-<phase-name>.md`, `02-<phase-name>.md`, etc. (numbered for ordering)
* **Symlink**: `proj/` at repo root pointing to the project folder

### Finding Project Docs

1. Check if `proj/` symlink exists at repo root → follow it
2. Look for `00-*.md` as project doc, `01-*.md`, `02-*.md`, etc. as phase docs
3. If project instructions specify different location → use that
4. Never start looking for project docs elsewhere, if symlink not found and docs needed → inform user

### Version control (jj)

* The symlink should be in a `private: proj - <project-name>` jj change
  * Contains the symlink file and **nothing else** — never mix doc changes into it
  * Don't prefix with `claude:`
* Doc file changes (00-*.md, 01-*.md, etc.)
  * Use `private: claude: docs -` like any other Claude commit
  * Should only contain doc file changes, never mix code changes into it
  * You can use jj fileset to only commit/squash the doc files if needed
  * Use `readlink ./proj` to get the path of project docs to commit
    Always execute as separate command to avoid permission issues with `$(readlink ./proj)`

## When Created & Updated

* **Create**: Only via `/proj-init`
* **Update**: After file modifications if exists
* **Phase docs**:
  * Created with project doc (first phase) or via `/proj-split` (additional phases)
  * Propose creation via `AskUserQuestion` when phase scope justifies it

* Persist decisions immediately: any decision, insight, or user clarification captured in docs on
  discovery — never rely on conversation as durable storage. Follow a SR&ED style of documentation

## Project Doc (00-XYZ.md)

Overview and navigation. Requirements live here. Tasks do NOT

### Sections

Keep in order. Never reorder, rename, or create more sections

* Context - Purpose and scope
* Checkpoint - Resume point, updated by /ctx-save
* Requirements - R-numbered, behavior-focused (WHAT not HOW)
* Questions & Investigations (optional) - Decisions, uncertainties, investigation records
* Inbox (optional) - Unprocessed feedback, bugs, ideas
* Phases - List of phase references (NOT task items)
* Files - All modified files across all phases

### Context

Purpose and scope of changes

### Checkpoint

Brief 1-2 paragraph summary for resuming work. References phase (if applicable), tasks worked on,
and next step if decided/obvious. Updated by `/ctx-save`, preserved until next save overwrites

### Requirements

Requirements describe WHAT (observable behavior), not HOW (implementation):

* Good: "Tasks only run on workers with matching library versions"
* Bad: "Workers report versions at registration time" (implementation detail)
* Test: Can this be verified without reading the code?

Requirements define WHAT to build. Acceptance criteria (ACs) on tasks define DONE — specific verifiable conditions per task

**Format:**

* R-numbered with status markers: `R1: ⬜ Description`
* Sub-levels when needed: R1.1, R1.2
* Phase annotation: `(Phase: Auth)` - by name, not number
* Tasks reference requirements: `[ ] Implement X (R1, R2.1)`

```markdown
* R1: ⬜ Core feature description (Phase: Setup)
  * R1.1: Sub-requirement if hierarchical
* R2: 🔄 Another essential feature (Phase: Auth)
* R3: ✅ Important supplementary feature (Phase: Setup)

#### Out of Scope (optional)
* Explicitly out of scope items (no status needed)
```

**Status markers:** `⬜` Not started | `🔄` In progress | `✅` Complete

**Rules:**

* Read ALL existing requirements before creating/modifying
* Update existing rather than create parallel ones
* All requirements go in ONE section (never create separate scope sections)
* Group related requirements logically when helpful (e.g., "API Operations", "Data Model")

### Questions & Investigations (optional)

Checklist of questions, decisions, and investigation records. Capture uncertainties when encountered, outcomes when discovered. Update continuously — conversation context is ephemeral, docs are durable

Format:
```markdown
* [x] Q: Can we use X for Y?
  * Uncertainty: Unknown if X supports concurrent Z
  * Tried: Prototype with X — hit limitation W
  * Result: Switched to V, handles concurrency natively
* [ ] Q: Will approach A scale to N?
```

### Inbox (optional)

Unprocessed items: feedback, bugs, ideas

### Phases

List of phase references. No task items here

<phase-title-format>

```markdown
* `### ⬜ NN Phase: Name` - To Do (NN = file number like 01, 02)
* `### 🔄 NN Phase: Name` - In Progress
* `### ✅ NN Phase: Name` - Done
```

</phase-title-format>

<phase-format>

```markdown
### 🔄 01 Phase: Auth
[01-auth](01-auth.md)

Implement OAuth2 flow with JWT tokens. Adds login/logout endpoints and session management
```

</phase-format>

<phase-progress-rules>
* Every phase gets a phase doc - no exceptions
* Always include 2-3 sentence summary after link
* Update summary when scope changes significantly
* Claude NEVER marks phases ✅ → use `AskUserQuestion` (user decides acceptance)
* When resuming: if multiple phases 🔄, ask user which to focus on
</phase-progress-rules>

### Files

Modified or important context files. Update after modifications

* Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), project docs
* Include: crucial files even if unmodified
* Format: `- **path/file.ext**: Purpose. Changes (if any).`
* Never replace files list with redirects like "See [phase doc] for details"
* Should mention phase in which got modified. Don't remove previous ones, always include all of them

## Phase Doc (01-XYZ.md, 02-XYZ.md, ...)

Where work happens. All tasks live here

### Sections

Keep in order. Never reorder, rename, or create more sections

* Context - Brief, references project doc
* Requirements (optional) - Only if expanding parent R-numbers (R5.A, R5.B)
* Questions & Investigations (optional) - Phase-specific questions, decisions, investigations
* Tasks - All `[ ]`, `[~]`, `[x]` items
* Files - Files relevant to this phase

### Context

Brief context referencing parent project doc. Example: "See [00-project](00-project.md)."

### Requirements (optional)

Only needed when expanding project doc requirements with phase-specific details:

* **Numbering**: Derive from parent R-number: `R5.A`, `R5.B` (never new top-level `R1`, `R2`)
* **Project doc reference**: `R5: ⬜ Feature X (Phase: Auth, see R5.A-C in phase doc)`
* **No section needed**: If only implementing project doc requirements, reference in tasks directly
  (e.g., `[ ] Implement X (R5)`)

### Questions & Investigations (optional)

Phase-specific questions, decisions, and investigation records. Same format as project doc Questions & Investigations

### Tasks

Flat checkmark list of work items

<task-format>
* `[ ]` incomplete
* `[~]` in progress
* `[x]` complete
* `[ ] Implement X (R1, R2.1)` - reference requirements
  - `AC: specific verifiable condition` - acceptance criteria sub-items
  - Each AC maps to a test assertion. Task done = all ACs pass
</task-format>

<task-progress-rules>
* When starting work on a task → mark it `[~]` immediately
* When starting work on a phase → mark it 🔄 immediately (in project doc)
* Claude can mark tasks `[x]` after completing them
* Claude NEVER marks requirements ✅ → use `AskUserQuestion` (user decides acceptance)
* Each item = discrete, independent work unit
* Never remove useful info from completed tasks
* A task without ACs is a task without a definition of done — add ACs during planning
</task-progress-rules>

### Files

Files relevant to this phase. Update after modifications

* Format: `- **path/file.ext**: Purpose. Changes (if any).`
* Use shorter descriptions, reference phase doc for details
