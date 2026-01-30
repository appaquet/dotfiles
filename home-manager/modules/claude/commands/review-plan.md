---
name: review-plan
description: Research REVIEW comments, present plan, then fix after /go
---

# Plan and Fix Review Comments

Research REVIEW comments in the codebase, present prioritized plan, then execute fixes after /go.

Consider these REVIEW comments as created by me as a way to communicate potential issues,
improvements, or questions in the code to act on right away. They aren't left for future
consideration nor to be ignored.

Important: any modifications to project or phase docs need to be done via `proj-editing` skill.

## Task Tracking

**FIRST**: Create one `TaskCreate` per row below BEFORE any other work. Mark in-progress/completed as you proceed:

| # | Subject | Description |
| --- | --- | --- |
| 1 | Ensure REVIEW comments found | Skip if just searched, else run /review-search |
| 2 | Research each comment | For each comment, add sub-task "Research: [file:line]" to understand context, read surrounding code, check related files |
| 3 | Categorize and prioritize | Group by priority (High/Medium/Low), effort (Quick/Moderate/Extensive), note dependencies |
| 4 | Check requirements | Read ALL requirements in project doc. Verify fixes don't contradict - update existing requirement if needed |
| 5 | Update project doc | Add identified fixes to Tasks section with priorities |
| 6 | Present plan | Show prioritized list with research findings |
| 7 | Await /go to proceed | Plan complete, await user confirmation |
| 8 | Create jj change | New change for fixes |
| 9 | Execute fixes | **FIRST**: Create one `TaskCreate` per REVIEW comment with subject "Fix: [file:line]" BEFORE implementing. **THEN**: For each Fix task, implement, remove REVIEW, mark complete. Never skip without asking user. |
| 10 | Verify no orphaned removals | Search for removed REVIEW comments that weren't addressed |
| 11 | Final verification | Search again for remaining comments, run tests |
| 12 | Commit | Summarize fixes in message |

## Instructions

STOP rushing. Invest thinking tokens now to save iteration tokens later.

### Phase 1: Plan (tasks 1-7)

1. **Ensure REVIEW comments found** - Call `/review-search` unless we just searched.

2. **Research each comment** - For each comment found:
   * Analyze thoroughly (ultra, deeply, freakingly, super ultrathink!)
   * Speak your mind LOUDLY. Don't just use a thinking block, but tell me everything you have in mind.
   * Read surrounding code to understand the issue
   * Check related files if the change has broader impact
   * Identify dependencies between review items
   * Add sub-task "Research: [file:line]" for each comment

3. **Categorize and prioritize** each finding:
   * **Priority**: High (critical/security/functionality), Medium (important but non-critical), Low (minor/stylistic)
   * **Effort**: Quick Win, Moderate, Extensive
   * **Dependencies**: Note if items must be addressed in a specific order

4. **Check requirements** - Read ALL requirements in project doc. Verify fixes don't contradict
   existing requirements - if a fix requires changing a requirement, update the existing one
   rather than creating a new one.

5. **Update project doc** - Add identified fixes to Tasks section with priorities.

6. **Present plan** - Show prioritized list with research findings.

7. **STOP** - Wait for user to respond (e.g., with `/go`).

### Phase 2: Execute (tasks 8-12)

8. **Create jj change** - New change for fixes.

9. **Execute fixes**:
   * **FIRST**: Create one `TaskCreate` per REVIEW comment with subject "Fix: [file:line]" - do NOT implement anything until all Fix tasks exist
   * **THEN**: For each Fix task:
     * Mark task in-progress
     * Implement the change
     * Remove associated REVIEW comment
     * Mark task complete
     * Update project doc Tasks section

10. **Verify no orphaned removals** - Search for any REVIEW comments that were removed without being addressed.

11. **Final verification**:
    * Search again for any remaining review comments
    * Run tests, formatting, and linting
    * Ensure project doc reflects all completed work

12. **Commit** - Commit the jj change with a clear message summarizing the fixes.

## Important Rules

* **NEVER** replace REVIEW comments with "// Note:" explanations or similar. Report to user if you
  believe they are unnecessary, and keep the REVIEW comment in the code. Remember, these comments
  are my way of communicating potential issues or improvements that I want you to act on right away.

* **NEVER** skip a comment on the premise that it's not needed. If you want to pushback, communicate
  with the user. Fix other comments, then clearly state which you didn't address and why. User decides.
