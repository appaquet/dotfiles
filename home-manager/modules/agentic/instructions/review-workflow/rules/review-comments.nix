{
  nixantic.sources.review-workflow.instructions."rules/review-comments" = {
    heading = "Review comments";
    content = ''
      REVIEW comments mark actionable feedback directly in code.

      They are communication tool (me<>agent, agent<>agent), not something that will live in code forever.

      User or agents write them to flag issues, ask questions, propose things.

      ## Format
      ```
      // REVIEW: <description>
      // REVIEW: <agent-name> - <description>
      // REVIEW: <description> >>
      // <more-multi-line-description>
      // <<
      ```

      ## Searching
      Using grep tool: `pattern="(//|#|--|/\\*|\\*)\\s*REVIEW:")`
      Ignore results in `proj/`
      If no grep tool, can use rg, but careful with glob exclusions failing silently.

      ## Addressing
      * Never delete unless addressed.
      * After fixed/addressed: remove.
      * Implement what comment describes. If names an abstraction or solution, build that. NOT OK to implement something else.
      * Never replace by other comment with explanation.
      * OK to pushback, but do it via comment under review comment.
    '';
  };
}
