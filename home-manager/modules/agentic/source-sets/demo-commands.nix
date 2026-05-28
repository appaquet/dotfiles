{
  "demo-commands" = {
    commands = {
      "source-set-demo" =
        { scope }:
        {
          description = "Demonstrate source-set authored commands";
          content = ''
            # Source Set Demo Command

            This command was authored in the `demo-commands` source set and demonstrates
            cross-source-set block references and directory/global block references.

            ${scope.blocks."deep-thinking".reference}

            ${scope.blocks."source-set-demo-intro".embed}
          '';
          asSkill = true;
        };
    };
  };
}
