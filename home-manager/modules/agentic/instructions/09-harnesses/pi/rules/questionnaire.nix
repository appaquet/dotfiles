{
  nixantic.sources.harnesses.instructions."pi-questionnaire" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Interactive questions";
      content = ''
        Use `${scope.harness.tools.askUserQuestion}`.

        Every question `header` MUST be 16 characters or fewer. Use a short label, not explanatory text.

        Always give user enough context to answer every question. Keep simple, self-contained questions direct; when one or two short sentences suffice, include that context in the question. 

        When more explanation is needed, give 1 page max bullet outline immediately before the tool call, then keep the questionnaire concise and focused on the decision and its choices.

        Always assume user is context switching and need proper briefing before each questionaire.
      '';
    };
}
