{
  pkgs,
  config,
  lib,
  inputs',
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;

  codexDir = "${instructions.package}/codex";

  # Codex's discovery drops symlinked files; dereference the rendered folders.
  materialize =
    subdir:
    pkgs.runCommand "codex-${subdir}-materialized" { } ''
      mkdir -p $out
      cp -rL "${codexDir}/${subdir}/." $out/
    '';
  agentsMaterialized = materialize "agents";
  skillsMaterialized = materialize "skills";

  # Read from the rendered output paths: readDir on the built tree would make evaluation
  # build the instructions package for the target platform.
  skillNames = lib.pipe instructions.codex [
    builtins.attrValues
    (builtins.map (instruction: instruction.outputPath))
    (builtins.filter (path: lib.hasPrefix "skills/" path))
    (builtins.map (path: lib.head (lib.splitString "/" (lib.removePrefix "skills/" path))))
    lib.unique
  ];

  # Codex's own skill root, not the shared ~/.agents/skills that Pi also reads. It stays a real
  # directory so Codex can install its bundled .system skills, hence one entry per skill.
  skillFiles =
    assert skillNames != [ ] || throw "nixantic rendered no codex skill directories";
    lib.listToAttrs (
      lib.map (name: {
        name = ".codex/skills/${name}";
        value.source = "${skillsMaterialized}/${name}";
      }) skillNames
    );
in
{
  # Only AGENTS.md stays a symlink; its loader follows symlinks.
  home.file = {
    ".codex/AGENTS.md".source = "${codexDir}/AGENTS.md";
    ".codex/agents".source = agentsMaterialized;
  }
  // skillFiles;

  home.packages = [
    inputs'.llm-agents.packages.codex
  ];
}
