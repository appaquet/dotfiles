{
  nixantic.sources.review-workflow.instructions."reviewer-usage" =
    { scope }:
    {
      role = "rule";
      heading = "Reviewer usage";
      content = ''
        ${scope.blocks."reviewer-budget".embed}
      '';
    };

  nixantic.sources.review-workflow.blocks."reviewer-budget" =
    { scope }:
    {
      content = ''
        When to spend a reviewer sub-agent: `code-style-reviewer`, `code-correctness-reviewer`, `architecture-reviewer`, `requirements-reviewer`.
      '';

      tag = "reviewer-budget";
      taggedContent = ''
        * Default to trusting the evidence the implementing agent returned. It already owes you proof of correct work.
        * Launch at most 2 unprompted reviewer passes per implementation session, once the work is complete and tests pass, not after each task.
        * None of these are reviewer triggers: finishing a task, a planned task named "Verify X", re-reviewing after applying a previous reviewer's findings, or mid-task uncertainty.
        * A risky or genuinely uncertain step is still a valid trigger. Name the exact files or changes to review.
        * Weigh the findings critically and act on real issues only; reviewers can be overzealous, so hold the line on the plan.
        * If the findings would trigger another review round, stop and update the user instead of re-launching.
      '';
    };
}
