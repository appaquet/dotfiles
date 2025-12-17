# PR.md Structure

Project/feature documentation spanning multiple PRs. File and sub-files kept throughout development.

## File Location

Unless project instructions specify otherwise:

* **Default**: `docs/feats/<date>-<project-name>/PR.md` (date via `date +%Y/%m/%d`)
* **Symlink**: At repo root pointing to actual file
* **Private change**: Symlink in `private: PR.md` jj change - never committed
* **Sub-files**: Same directory, named `PR-<phase-name>.md`

### Finding PR.md

1. Check if root `PR.md` is symlink → follow it
2. If project instructions specify location → use that
3. Otherwise assume repo root

## When to Create

* **Create**: Only via `/pr-init`
* **Update**: After file modifications if exists
* **Never**: Proactively

## Sections

Order: Context ★, Requirements, Questions, Files ★, TODO ★, Pull Requests (★ = mandatory)

### Context

Purpose and scope of changes

### Requirements

Requirements of changes

### Questions

Checklist of questions/answers to resolve during development

### Files

Modified or important context files. Update after modifications.

* Exclude: generated files (`*.pb.go`, `*_grpc.pb.go`, wire), PR docs
* Include: crucial files even if unmodified
* Format: `- **path/file.ext**: Purpose. Changes (if any).`
* If many files + sub-files: abbreviate, mention sub-file

### TODO

Checkmark list of work items. Split phases into `PR-<phase-name>.md` if too big.

**Phase indicators** (prefix):
* `### ⬜ Phase Name` - To Do
* `### 🔄 Phase Name` - In Progress
* `### ✅ Phase Name` - Done

Sub-file link under header:
```
### 🔄 Phase: Auth
[PR-auth.md](PR-auth.md)
```

**Management:**
* Task indicators: `[ ]` incomplete | `[~]` in progress | `[x]` complete
* Update after starting/completing; detail sufficient for pickup
* If split into sub file, update both
* Each item = discrete, independent work unit
* Never remove useful info from completed TODOs
* Propose `/pr-split` at 15+ items or completed phase with 5+ items

### Pull Requests

* Start "In this PR, I implemented..." + high-level technical overview
* Focus on capability, not implementation details
* Use system/component terms; avoid function names/algorithms
* Omit test plans and generated attribution
