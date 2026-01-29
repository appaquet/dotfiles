# Project Doc Structure

Project/feature documentation spanning multiple PRs. Docs kept throughout development.

## File Location

Unless project instructions specify otherwise:

* **Default**: `docs/features/<date>-<project-name>/` (date via `date +%Y/%m/%d`)
* **Main doc**: `00-<project-name>.md` inside the folder
* **Phase docs**: `01-<phase-name>.md`, `02-<phase-name>.md`, etc. (numbered for ordering)
* **Symlink**: `proj/` at repo root pointing to the project folder
* **Private change**: Symlink in `private: proj - <project-name>` jj change - never committed

### Finding Project Docs

1. Check if `proj/` symlink exists at repo root → follow it
2. Look for `00-*.md` as project doc, `01-*.md`, `02-*.md`, etc. as phase docs
3. If project instructions specify different location → use that

## When to Create

* **Create**: Only via `/proj-init`
* **Update**: After file modifications if exists
* **Phase docs**: Created with project doc (first phase) or via `/proj-split` (additional phases)
* **Never**: Create phase docs proactively without asking

## Sections

Keep sections in order described below. Never reorder, rename or create more sections.

**Project doc** (`00-*.md`): Overview and navigation. Requirements live here. Tasks do NOT live here.
**Phase doc** (`01-*.md`, `02-*.md`, ...): Where work happens. All tasks live here.

<project-doc-sections>
* Context - Purpose and scope
* Checkpoint (optional) - Resume point, updated by /ctx-save
* Requirements (optional) - MoSCoW prioritized, R-numbered
* Questions (optional) - Resolved Q&A
* Phases - List of phase references (NOT task items)
* Files - All modified files across all phases
</project-doc-sections>

<phase-doc-sections>
* Context - Brief, references project doc
* Requirements (optional) - Only if expanding parent R-numbers (R5.A, R5.B)
* Questions (optional) - Phase-specific Q&A
* Tasks - All `[ ]`, `[~]`, `[x]` items live here
* Files - Files relevant to this phase
</phase-doc-sections>

### Context

Purpose and scope of changes

### Checkpoint (optional)

Brief 1-2 paragraph summary for resuming work. References phase (if applicable), tasks worked on, and next step if decided/obvious. Updated by `/ctx-save`, preserved until next save overwrites. Checkpoint should remain in the main doc only.

### Requirements (optional)

**Source of Truth:** Before creating/modifying requirements:

1. Read ALL existing requirements in main doc
2. Update existing rather than create parallel ones
3. All requirements go in ONE Requirements section (never create separate scope sections)

Use MoSCoW prioritization with numbered requirements for traceability.

**Format:**

```markdown
#### Must Have
* R1: ⬜ Core feature description (Phase 1)
  * R1.1: Sub-requirement if hierarchical
* R2: 🔄 Another essential feature (Phase 2)

#### Should Have
* R3: ✅ Important but not blocking (Phase 1)

#### Could Have
* R4: ⬜ Nice to have

#### Won't Have (this scope)
* R5: Explicitly out of scope
```

**Requirement status markers:**

* `⬜` - Not started
* `🔄` - In progress
* `✅` - Complete

**Rules:**

* Number requirements sequentially (R1, R2, R3...) with sub-levels (R1.1, R1.2) when needed
* Status marker follows requirement number: `R1: ⬜ Description`
* Phase annotation by name: `(Phase: Auth)`, not number (phases may reorder)
* Tasks reference requirements they address: `* [ ] Implement X (R1, R2.1)`
* "Won't Have" items don't need status markers
* When requirements have logical groupings (e.g., "API Operations", "Data Model"), add new
  requirements to the appropriate group rather than creating standalone entries elsewhere
* When promoting a Could Have item to active work, relocate it to the appropriate Must Have/Should
  Have section based on its type (e.g., an API endpoint moves to "API Operations")

**Phase doc requirements:**

Phase docs may expand requirements with phase-specific details:

* **Numbering**: Derive from parent R-number: `R5.A`, `R5.B` (never new top-level `R1`, `R2`)
* **Project doc reference**: `R5: ⬜ Feature X (Phase: Auth, see R5.A-C in phase doc)`
* **No Requirements section needed**: If only implementing project doc requirements, reference in tasks
  directly (e.g., `[ ] Implement X (R5)`)
* **Alternative**: Keep all R-numbers in project doc; phase docs only for phase-specific tasks

### Questions (optional)

Checklist of questions/answers to resolve

### Phases (in project doc)

List of phase references. **No task items here** - all tasks live in phase docs.

<phase-reference-format>
### 🔄 01 Phase: Auth
[01-auth.md](01-auth.md)

Implement OAuth2 flow with JWT tokens. Adds login/logout endpoints and session management.
</phase-reference-format>

**Phase status indicators:**

* `### ⬜ NN Phase: Name` - To Do (NN = file number like 01, 02)
* `### 🔄 NN Phase: Name` - In Progress
* `### ✅ NN Phase: Name` - Done

**Rules:**

* Every phase gets a phase doc - no exceptions
* Always include 2-3 sentence summary after link
* Update summary when scope changes significantly
* Claude NEVER marks phases ✅ → use `AskUserQuestion` (user decides acceptance)
* When resuming: if multiple phases 🔄, ask user which to focus on

### Tasks (in phase doc)

Flat checkmark list of work items. **All tasks live in phase docs, never in project doc.**

<task-format>
* `[ ]` incomplete
* `[~]` in progress
* `[x]` complete
* `[ ] Implement X (R1, R2.1)` - reference requirements
</task-format>

**Progress Tracking Rules:**

* When starting work on a task → mark it `[~]` immediately
* When starting work on a phase → mark it 🔄 immediately (in project doc)
* Claude can mark tasks `[x]` after completing them
* Claude NEVER marks requirements ✅ → use `AskUserQuestion` (user decides acceptance)
* Each item = discrete, independent work unit
* Never remove useful info from completed tasks

### Files

Modified or important context files. Update after modifications.

* Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), project docs
* Include: crucial files even if unmodified
* Format: `- **path/file.ext**: Purpose. Changes (if any).`
* With phase docs: use shorter descriptions, reference phase doc for details
* Never replace files list with redirects like "See [phase doc] for details"
