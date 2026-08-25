{
  nixantic.sources.harnesses.instructions."pi-questionnaire" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Interactive questions";
      content = ''
        Use `${scope.harness.tools.askUserQuestion}`.

        Give user enough context to answer every question. Keep simple, self-contained questions direct; when one or two short sentences suffice, include that context in the question. 

        When more explanation is needed, give a brief bullet outline immediately before the tool call, then keep the questionnaire concise and focused on the decision and its choices.
      '';
    };
}
