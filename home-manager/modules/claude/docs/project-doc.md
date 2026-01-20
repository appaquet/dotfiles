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

### Checkpoint (optional)

Brief 1-2 paragraph summary for resuming work. References phase (if applicable), tasks worked on, and next step if decided/obvious. Updated by `/ctx-save`, preserved until next save overwrites.

### Requirements (optional)

**Source of Truth:** Before creating/modifying requirements:
1. Read ALL existing requirements in main doc
2. Update existing rather than create parallel ones

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
* When phase completes, update all linked requirements to ✅
* When requirements have logical groupings (e.g., "API Operations", "Data Model"), add new
  requirements to the appropriate group rather than creating standalone entries elsewhere
* When promoting a Could Have item to active work, relocate it to the appropriate Must Have/Should
  Have section based on its type (e.g., an API endpoint moves to "API Operations")

**Sub-doc / phase requirements:**

Sub-docs may expand requirements with phase-specific details:

* **Numbering**: Derive from parent R-number: `R5.A`, `R5.B` (never new top-level `R1`, `R2`)
* **Main doc reference**: `R5: ⬜ Feature X (Phase: Auth, see R5.A-C in sub-doc)`
* **No Requirements section needed**: If only implementing main doc requirements, reference in tasks
  directly (e.g., `[ ] Implement X (R5)`)
* **Alternative**: Keep all R-numbers in main doc; sub-docs only for phase-specific tasks

### Questions (optional)

Checklist of questions/answers to resolve

### Tasks

Flat checkmark list of work items.

**Task indicators:**

* `[ ]` incomplete
* `[~]` in progress
* `[x]` complete
* `[x]` complete (R1, R2.1)

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
* Phase status is authoritative: report phases using their marker (⬜/🔄/✅), not inferred from tasks
  - If all tasks `[x]` but phase still 🔄 → ask user if phase should be marked ✅

**Management:**

* Update after starting/completing; detail sufficient for pickup
* If split into sub-doc, update both main and sub-doc
* Each item = discrete, independent work unit
* Never remove useful info from completed tasks
* Propose `/proj-split` at 15+ items or completed phase with 5+ items

### Files

Modified or important context files. Update after modifications.

* Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), project docs
* Include: crucial files even if unmodified
* Format: `- **path/file.ext**: Purpose. Changes (if any).`
* With sub-docs: use shorter descriptions, reference sub-doc for details
* Never replace files list with redirects like "See [sub-doc] for details"

