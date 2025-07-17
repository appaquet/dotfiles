
# Pull Request review phase

Review pull request, check for style/architecture issues

* Load the context of the pull request:
  * Read `PR.md` (if it exists, at root of repo)
    * If it doesn't exist, use `gh pr view` to get the context of the PR from GitHub
  * When checking diff of our branch, ALWAYS use `fish -c "jj-diff-branch"` to diff of changes, and
    `fish -c "jj-diff-branch --stat"` for a summary of changed files. If no changes present, use `gh
    pr diff`.
* Create multiple agents to conduct a thorough review of the pull request:
  * Agent 1 (in parallel): loads the code style guides, and reviews the code for style issues,
    typos/syntax errors, remaining debugging code or comments, and quality issues (code smells, long
    functions, etc.).
  * Agent 2 (in parallel): reviews the code for correctness, logic issues, and potential bugs. it
    loads any missing context from existing files (outside of the diff) if it is needed to
    understand the code.
  * Agent 3 (in parallel): thinks very deeply about the architecture of the changes and the code in
    which it is implemented and review for any architectural issues. it loads any missing context
    from existing files (outside of the diff) if it is needed to understand the code and
    architecture.
  * Agent 4 (after 1-3): collects feedback from the other agents and:
    * Add `// REVIEW:` comments for any issues found in the code
    * Update `PR.md` (if it exists, at root of repo)
      * Update "Files" with modified files (bold paths + descriptions)
      * Update "TODO" with checkmark lists with completed items
