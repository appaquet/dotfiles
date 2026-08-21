{
  nixantic.sources.harnesses.instructions."pi-questionnaire" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Interactive questions";
      content = ''
        Use `${scope.harness.tools.askUserQuestion}`.
      '';
    };
}
