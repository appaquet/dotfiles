# Code Review Agent Guidelines

Shared infrastructure for code review agents. All review agents follow this workflow

## Reviewer Workflow

1. STOP, follow pre-flight instructions
   THEN, continue

2. 🔳 Load context
   - Run `/ctx-load` for project context, branch state, project docs
   - 🚀 Engage thrusters - As sub-agent, proceed immediately after loading

3. 🔳 Gather guidelines (merge in priority order)
   - Project guidelines: Find via Scope patterns (highest salience)
   - User guidelines: Only if explicitly referenced in agent's Scope section
   - General Guidelines: Agent's built-in criteria (in agent file)

4. 🔳 Create rule tasks
   - From merged guidelines (project > user > general), for EACH rule create `TaskCreate`:
     - Subject: "Check: [rule name]"
     - Description: What to look for + good/bad examples
   - 🔳 Create one task using `TaskCreate` for EACH rule

5. 🔳 Load changed files
   - Run `jj-diff-branch --stat` to list modified files
     - Exclude reviewing docs themselves and generated files (e.g., *.pb.go)
   - For each file to be reviewed:
     - Load diff: `jj-diff-branch --git <file>`
     - Load surrounding context if needed to understand changes

6. 🔳 Execute rule checks
   - For EACH check task:
     - Mark task in-progress
     - Examine changed hunks for this issue
       - Apply `<deep-thinking>` procedure
       - Don't report issues on unrelated changes, unless it's a blatant problem
     - If violation(s) found
       - INSERT IN THE CODE review comments using the format found in `<agent-review-comment>` block in agent file
         - The format is CRUCIAL for automated extraction
           - Don't include the actual XML block
           - `// REVIEW: [agent-name] - <description of issue, consequences, suggested fix>`
         - You should never just report an issue without inserting a comment in the code
         - Use the `Edit` tool to write it, no other means
         - If you can't edit, it may be that another agent inserted in parallel, and you NEED to
           read it back to insert
         - You should NEVER report on an issue without successfully inserting a comment
     - Mark complete before next rule

7. 🔳 Cross-file synthesis
   - Look back at all files and rules, add comments for issues that span multiple files that may
     have been missed

8. 🔳 Return summary, in one SINGLE LAST message
   - Give overall summary to parent agent
   - If issues found:
     - List all issues found to parent agent
     - Make sure you really inserted comments for each
       This is CRUCIAL for automated extraction
   - If no issues
     - Explain what was examined

## Sub-agent Rules

- NEVER notify user directly - return results to parent agent
  - Results returned via comprehensive summary message
  - Parent agent handles aggregation and user communication

- NEVER modify the code directly for fixes
  - Only insert REVIEW comments
  - User will decide on actual code changes

- NEVER create `jj` changes since multiple reviewers run in parallel
  - Parent agent manages `jj` operations after collecting all reviews

- You should NOT use externals tools (bash, formatter, linters, etc.)
  Your own is to solely rely on your training and guidelines provided and insert commentsw
  accordingly

- Other reviewer agents may run in parallel
  - It's normal for code to change, and you may have to-read for latest changes
  - Ensure that you are inserting comments on the correct version of the code
