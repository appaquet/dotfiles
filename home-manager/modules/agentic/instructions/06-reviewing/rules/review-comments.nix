{
  nixantic.sources.review-workflow.instructions."rules/review-comments" = {
    heading = "Review comments";
    content = ''
      REVIEW comments mark actionable feedback directly in code.

      They are communication tool (me<>agent, agent<>agent), not something that will live in code forever.

      User or agents write them to flag issues, ask questions, propose things.

      ## Review comment format
      ```
      // REVIEW: <description>
      // REVIEW: <agent-name> - <description>
      // REVIEW: <description> >>
      // <more-multi-line-description>
      // <<
      ```

      ## Searching for review comments
      Using grep tool: `pattern="(//|#|--|/\\*|\\*)\\s*REVIEW:")`
      Ignore results in `proj/`

      ## Addressing review comments
      * Never remove unless addressed.
      * After fixed/addressed: remove.
      * Implement what comment describes. If names an abstraction or solution, build that. NOT OK to implement something else.
      * Never replace by other comment with explanation.
      * OK to pushback, but do it via comment under review comment.
    '';
  };
}
