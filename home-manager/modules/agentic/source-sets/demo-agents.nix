{
  "demo-agents" = {
    agents = {
      "source-set-demo-agent" =
        { scope }:
        {
          description = "Demonstrates source-set authored agent patterns";
          content = ''
            You are a demo agent authored in the `demo-agents` source set.

            ${scope.blocks."source-set-demo-intro".embed}

            When reviewing, follow the global pre-flight rules:
            ${scope.blocks."pre-flight".reference}
          '';
          harnesses = [ "claude" ];
          model = {
            claude = "sonnet";
          };
        };
    };
  };
}
