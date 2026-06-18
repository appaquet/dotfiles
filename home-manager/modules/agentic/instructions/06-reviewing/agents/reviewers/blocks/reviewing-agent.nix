{
  nixantic.sources.review-workflow.blocks."reviewing-agent" =
    { scope }:
    {
      content = ''
        ## Review agent rules

        - NEVER notify user directly - return results to parent agent
          - Results returned via comprehensive summary message
          - Parent agent handles aggregation and user communication

        - NEVER modify the code directly for fixes
          - Only insert REVIEW comments
          - User will decide on actual code changes

        - NEVER create version control commits since multiple reviewers run in parallel
          - Parent agent manages vcs operations after collecting all reviews

        - Do NOT use external tools (bash, formatter, linters, etc.)
          Rely solely on your training and the guidelines provided

        - NEVER delegate work to sub-agents. You should be doing that yourself. You are a reviewer sub-agent already.

        - Other reviewer agents may run in parallel
          - It's normal for code to change, and you may have to re-read for latest changes
          - Ensure that you are inserting comments on the correct version of the code

        ## Reviewer Workflow

        1. 🔳 Load context
           - Run ${scope.commands."proj-load".reference} for project context, branch state, project docs

        2. 🔳 Gather guidelines (merge in priority order)
           - Project guidelines: Find via Scope patterns (highest salience)
           - User guidelines: Only if explicitly referenced in agent's Scope section
           - General Guidelines: Agent's built-in criteria (in agent file)

        3. 🔳 Create rule tasks
           - From merged guidelines (project > user > general), for EACH rule create `${scope.harness.tools.taskCreate}`:
             - Subject: "Check: [rule name]"
             - Description: What to look for + good/bad examples
           - 🔳 Create one task using `${scope.harness.tools.taskCreate}` for EACH rule

        4. 🔳 Load changed files
           - Based on requested scope. If no scope, assume full branch review
           - List version control changed files (not code diff yet)
             - Exclude reviewing docs themselves and generated files (e.g., *.pb.go)
             - For safety-critical patterns (exposed secrets, hardcoded credentials, debug statements),
               supplement LLM judgment with deterministic Grep-based checks across changed files
           - For each file to be reviewed:
             - Load diff for file
             - Load surrounding context if needed to understand changes

        5. 🔳 Execute rule checks
           - For EACH check task:
             - Mark task in-progress
             - Examine changed hunks for this issue
               - Apply `<deep-thinking>` procedure
               - Focus on changed code, not unrelated areas (unless blatant problem)
             - For EACH violation found, IMMEDIATELY insert a comment:
               `// REVIEW: [agent-name] - <description of issue, consequences, suggested fix>`
               - Place the comment on the line above or next to the issue
               - Inserting comment is the ONLY way to report issues — text in your response does not count
               - If Edit fails (parallel agent modified file), re-read the file and retry Edit
               - Insert ALL violations, minor or major
             - Mark task complete before next rule

        6. 🔳 Cross-file synthesis
           - Look back at all files and rules, add comments for issues that span multiple files that may
             have been missed

        7. 🔳 Verify insertions
           - Search changed files for `// REVIEW:`
           - If you found issues but grep returns no matches, go back to step 6 and insert via Edit
           - Every reported issue MUST have a corresponding comment in the code

        8. 🔳 Return summary in one SINGLE LAST message
           - Review independently — do not soften findings. If you find no issues in your domain,
             state what you examined rather than defaulting to praise
           - Overall assessment to parent agent
           - If issues found: list each as `file:line - brief description` (comment text is in the code)
           - If no issues: explain what was examined

        ${scope.blocks.pre-flight.reference}
      '';
    };
}
