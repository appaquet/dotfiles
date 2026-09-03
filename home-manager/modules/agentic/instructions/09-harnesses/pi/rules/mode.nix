{
  nixantic.sources.harnesses.instructions."pi-mode" =
    { scope }:
    {
      harnesses = [ "pi" ];
      role = "rule";
      heading = "Session mode";
      content = ''
        The PI_MODE env var (builder|orchestrator) selects the initial mode of a fresh pi session at launch, like PI_SCOPE selects the scope preset. A session's persisted mode entry wins on resume/fork; invalid values fall back to builder with a warning.
      '';
    };
}
