{ inputs, ... }:

{
  perSystem =
    { pkgs, lib, ... }:
    let
      evalInstructions =
        modules:
        lib.evalModules {
          specialArgs = { inherit pkgs; };
          modules = [
            inputs.nixantic.nixanticModules.core
            ./nixantic.nix
          ]
          ++ modules;
        };
      sharedDefault = (evalInstructions [ ]).config.nixantic;
      jjInstructions =
        (evalInstructions [ { nixantic.versionControl.mode = "jj"; } ]).config.nixantic.instructions;
      gitInstructions =
        (evalInstructions [ { nixantic.versionControl.mode = "git"; } ]).config.nixantic.instructions;
      homeManagerDefault =
        (inputs.home-manager.lib.homeManagerConfiguration {
          inherit pkgs;
          modules = [
            inputs.nixantic.homeManagerModules.default
            ./nixantic.nix
            {
              home = {
                username = "nixantic";
                homeDirectory = "/home/nixantic";
                stateVersion = "24.11";
              };
            }
          ];
        }).config.nixantic;
      versionControlDefaultCheck = pkgs.runCommand "agentic-version-control-default-check" { } ''
        test "${sharedDefault.versionControl.mode}" = jj
        test "${homeManagerDefault.versionControl.mode}" = jj
        test "${sharedDefault.instructions.package}" = "${jjInstructions.package}"
        test "${homeManagerDefault.instructions.package}" = "${jjInstructions.package}"
        touch $out
      '';
      acceptanceChecks = import ./checks/corpus.nix {
        inherit
          pkgs
          jjInstructions
          gitInstructions
          ;
      };
      validatedPackage =
        name: instructions: acceptanceCheck:
        pkgs.runCommand name { } ''
          : ${instructions.check}
          : ${acceptanceCheck}
          ln -s ${instructions.package} "$out"
        '';
    in
    {
      packages = {
        agent-instructions = validatedPackage "agent-instructions" jjInstructions acceptanceChecks.jj;
        agent-instructions-git =
          validatedPackage "agent-instructions-git" gitInstructions
            acceptanceChecks.git;
      };
      checks = {
        agentic-version-control-default = versionControlDefaultCheck;
        agent-instructions = acceptanceChecks.jj;
        agent-instructions-git = acceptanceChecks.git;
      };
    };
}
