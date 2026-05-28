{
  "demo-skills" = {
    skills = {
      "source-set-demo-skill" = {
        kind = "directory";

        main =
          { scope }:
          {
            description = "Demonstrates source-set authored skill patterns";
            content = ''
              # Source Set Demo Skill

              This skill was authored in the `demo-skills` source set. It bundles a markdown
              reference file and demonstrates skill-to-command dual output.

              ${scope.blocks."source-set-demo-intro".embed}
            '';
            asCommand = true;
          };

        files = {
          "demo-data.md" = {
            kind = "md";
            content = builtins.readFile ./demo-data.md;
          };
        };
      };
    };
  };
}
