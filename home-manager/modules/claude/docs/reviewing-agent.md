# Code Review Agent Guidelines

Shared infrastructure for code review agents. All review agents follow this workflow

## Reviewer Workflow

1. 🔳 Load context
   - Run `/ctx-load` for project context, branch state, project docs
   - 🚀 Engage thrusters - As sub-agent, proceed immediately after loading

2. 🔳 Gather guidelines (merge in priority order)
   - Project guidelines: Find via Scope patterns (highest salience)
   - User guidelines: Only if explicitly referenced in agent's Scope section
   - General Guidelines: Agent's built-in criteria (in agent file)

3. 🔳 Load changed files
   - Run `jj-diff-branch --stat` to list modified files
   - For each code file (skip docs, generated files like *.pb.go):
     - Load diff: `jj-diff-branch --git <file>`
     - Load surrounding context as needed

4. 🔳 Create rule tasks
   - From merged guidelines (project > user > general), for EACH rule create `TaskCreate`:
     - Subject: "Check: [rule name]"
     - Description: What to look for + good/bad examples

5. 🔳 Execute rule checks
   - For EACH Check task:
     - Mark in-progress
     - Examine ALL changed files for this issue
     - Apply `<deep-thinking>` procedure
     - If violation(s) found
       - INSERT review comment(s) using the exact `<agent-review-comment>` format
         - The format is CRUCIAL for automated extraction
     - Mark complete before next rule

6. 🔳 Cross-file synthesis
   - Look back at all files, add comments for missed issues
   - Find patterns spanning multiple files

7. 🔳 Return summary
   - List all issues (even if already commented)
   - If no issues: explain what was examined
   - Ensure all issues have comments inserted

## Sub-agent Rules

- NEVER notify user directly - return results to parent agent
  - Results returned via comprehensive summary message
  - Parent agent handles aggregation and user communication

- NEVER modify the code directly for fixes
  - Only insert REVIEW comments
  - User will decide on actual code changes

- NEVER create `jj` changes since multiple reviewers run in parallel
  - Parent agent manages `jj` operations after collecting all reviews

- Other reviewer agents may run in parallel
  - It's normal for code to change, and you may have to-read for latest changes
  - Ensure that you are inserting comments on the correct version of the code
