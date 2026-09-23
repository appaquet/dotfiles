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

      vcsContext = import ./tools/vcs-context.nix { inherit pkgs; };
      vcsContextCheck = import ./checks/vcs-context.nix { inherit pkgs vcsContext; };
      piSessionQuery = import ./tools/pi-session-query.nix { inherit pkgs; };
      piSessionQueryCheck = import ./checks/pi-session-query.nix { inherit pkgs piSessionQuery; };
      piSessionQueryUnitCheck = import ./checks/pi-session-query-unit.nix { inherit pkgs; };
      showMeServeCheck = import ./checks/show-me-serve.nix { inherit pkgs; };

      llmAgentPackages = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system};
      piModuleCheck = import ./pi/checks/module.nix {
        inherit lib pkgs;
        home-manager = inputs.home-manager;
        upstreamPi = llmAgentPackages.pi;
      };

      piRuntimeChecks = import ./pi/checks/runtime.nix {
        inherit lib pkgs;
        home-manager = inputs.home-manager;
        nono = llmAgentPackages.nono;
        upstreamPi = llmAgentPackages.pi;
      };

      piPluginsUnitCheck = import ./pi/checks/tests.nix {
        inherit pkgs;
        piNode = llmAgentPackages.pi.override { useBun = false; };
      };

      # Keep one public flake check while retaining separate internal failures
      # for the wrapper contract and real Node runtime seam.
      piCheck = pkgs.runCommand "pi-check" {
        nativeBuildInputs = [
          piModuleCheck
          piRuntimeChecks.runtimeSmoke
          piRuntimeChecks.authMergeSmoke
        ];
      } "touch $out";

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
          ;
      };

      validatedPackage =
        name: instructions: acceptanceCheck:
        pkgs.runCommand name { } ''
          : ${instructions.check}
          : ${acceptanceCheck}
          : ${vcsContextCheck}
          ln -s ${instructions.package} "$out"
        '';
    in
    {
      packages = {
        agent-instructions = validatedPackage "agent-instructions" jjInstructions acceptanceChecks.jj;

        pi-nono-smoke = piRuntimeChecks.nonoSmoke;
      };
      checks = {
        agentic-show-me-serve = showMeServeCheck;
        agentic-vcs-context = vcsContextCheck;
        agentic-version-control-default = versionControlDefaultCheck;
        pi-session-query = piSessionQueryCheck;
        pi-session-query-unit = piSessionQueryUnitCheck;
        pi-plugins-unit = piPluginsUnitCheck;

        pi = piCheck;

        agent-instructions = acceptanceChecks.jj;
      };
    };
}
