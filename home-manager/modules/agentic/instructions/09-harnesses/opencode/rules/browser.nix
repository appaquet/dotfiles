{
  nixantic.sources.harnesses.instructions."rules/browser" = {
    heading = "Web Browser";
    harnesses = [ "opencode" ];
    content = ''
      Do not use any web browser tool yourself. Always use the dedicated browser sub-agent for any web browsing tasks.
    '';
  };

  nixantic.sources.harnesses.blocks."browser-agent-prompt" =
    { scope }:
    {
      heading = "Browser agent prompt";

      content = ''
        You are an agent that can use a web browser to interact with websites. 

        You should focus on that and not do any other work. If you are requested to do so, tell your manager agent that you should only be used for web browser related tasks.

        You should never delegate yourself, only execute browser interactions.

        You should try to reuse existing browser sessions and context.
      '';
    };

}
