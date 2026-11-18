{ pkgs }:

# Builds every jj-utils check the same way: jj-test-lib.sh goes in front of the suite body,
# the packaged commands are on PATH, and JJ_CONFIG holds the test identity plus the real
# aliases from jujutsu.nix, so suites never copy them.
let
  inherit (pkgs) lib;

  jjUtils = import ../jj-utils.nix { inherit pkgs; };
  inherit ((import ../jujutsu.nix { inherit pkgs; }).programs.jujutsu) settings;

  jjConfig = (pkgs.formats.toml { }).generate "jj-test-config.toml" {
    user = {
      name = "Test User";
      email = "test@example.com";
    };
    inherit (settings) revset-aliases aliases;
  };

  suites = [
    "jj-promote-unit"
    "jj-proj-tug-unit"
    "jj-stack-unit"
    "jj-workspace-branch-unit"
    "jj-workspace-herdr-unit"
    "jj-workspace-utils-unit"
  ];

  # Inputs a suite needs beyond git, jj and jj-utils.
  extraInputs = {
    jj-workspace-herdr-unit = [ pkgs.jq ];
  };

  check =
    name:
    let
      script = pkgs.writeText "${name}.sh" (
        builtins.readFile ./jj-test-lib.sh + builtins.readFile (./. + "/${name}.sh")
      );
    in
    pkgs.runCommand "${name}-check"
      {
        nativeBuildInputs = [
          pkgs.git
          pkgs.jujutsu
          jjUtils
        ]
        ++ extraInputs.${name} or [ ];
      }
      ''
        JJ_CONFIG=${jjConfig} bash ${script}
        touch "$out"
      '';
in
lib.genAttrs suites check
