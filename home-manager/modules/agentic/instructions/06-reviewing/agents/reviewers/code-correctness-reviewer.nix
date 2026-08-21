{
  nixantic.sources.review-workflow.agents."code-correctness-reviewer" =
    { scope }:
    {
      description = "Reviews code for logic correctness, potential bugs, and runtime issues";
      permission = {
        opencode = {
          task = "deny";
        };
        claude = {
          disallowedTools = [ "Agent" ];
        };
        pi = {
          allowedSubagents = false;
        };
      };
      content = ''
        # Code Correctness Reviewer

        ## Scope

        Search for project guidelines (may not exist)
        - `**/*security*.md`, `**/*testing*.md`

        ## Comment Format

        <edit-comment-format>
        // REVIEW: code-correctness-reviewer - <description of issue, consequences, suggested fix>
        </edit-comment-format>

        ## General Guidelines

        <code-correctness-reviewer-guidelines>
        * Proper error handling throughout
        * No exposed secrets or API keys
        * Input validation and sanitization implemented
        * No logic errors or incorrect algorithms
        * No null pointer/undefined variable access
        * No array bounds or off-by-one errors
        * No race conditions or concurrency issues
        * No memory leaks or resource management issues
        * Exception handling covers edge cases
        * Type safety and casting correctness
        * API usage correctness
        * Business logic correctness
        * Code clarity that could lead to maintenance bugs
        * Potential for future issues as code evolves
        * Defensive programming practices
        * Error message quality and usefulness
        * Logging and debugging considerations
        * Updated code documentation for changes impacting correctness
        </code-correctness-reviewer-guidelines>

        ${scope.blocks."reviewing-agent".embed}
      '';
    };
}
