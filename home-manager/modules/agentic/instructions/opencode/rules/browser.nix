{
  nixantic.sources.harness-opencode.instructions."rules/browser" = {
    heading = "Web Browser";
    content = ''
      Do not use any web browser tool yourself. Always use the dedicated browser sub-agent for any web browsing tasks.
    '';
    harnesses = [ "opencode" ];
  };
}
