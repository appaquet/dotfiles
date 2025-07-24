---
name: scaffold
description: Convert planning into code TODOs with clear prefixes and structure
---

Convert planning into code TODOs with clear prefixes and structure.

1. Read the `PR.md` file at the root of the repository to understand the current task and plan

2. Add TODOs with clear project prefixes throughout the codebase:
   * Use format: `// TODO: PROJECT_CODE - Description of what needs to be implemented`
   * Make TODOs specific and actionable
   * Place TODOs in relevant files where implementation will occur

3. Create code structure placeholders:
   * Add function signatures with TODO bodies
   * Add struct/interface definitions
   * Add test placeholders with commented-out failing code
   * Ensure code compiles by commenting out parts that don't work yet

4. Update `PR.md` TODO section with scaffolding tasks to be completed

5. Notify completion with `notify "Scaffolding complete"`

**Important**: Never jump into the implementation phase unless explicitly asked. Stop after scaffolding is complete.
