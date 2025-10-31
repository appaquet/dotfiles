
# PR.md Structure

Project documentation at repo root. Documents current task/feature (may span multiple PRs).

## When to Create

* **Create**: Only when explicitly requested ("create PR.md", "document in PR.md")
* **Update**: Always after file modifications if exists
* **Never**: Create proactively

## Sections (exact order)

### Context (mandatory)
Context of changes

### Requirements (optional)
Requirements of changes

### Questions (optional)
Checklist of questions (and answers) to resolve during development

### Files (mandatory)
Modified OR important context files

MANDATORY: Update after file modifications. Exclude generated files (`*.pb.go`, `*.pb.gw.go`, `*_grpc.pb.go`, wire, etc.) and PR docs (`PR.md`). Include crucial files even if unmodified.

Format: `- **path/to/file.ext**: 1-2 sentences on purpose. 1-2 sentences on changes (if any).`

### TODO (mandatory)
Checkmark list of work items

MANDATORY: Update after starting/completing work.
- `[ ]` incomplete | `[~]` in progress | `[x]` complete
- Detail sufficient for developer to pick up later
- Each item = discrete, independent work unit

### Pull Requests (optional)
PR descriptions

Summary only: Start "In this PR, I implemented..." then high-level technical overview.
Focus: what was built (capability), not how (implementation details).
High-level: use system/component terms; avoid function names, algorithms, parameters.
Omit: test plans, generated attribution.
