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

  # Codex's own skill root, not the shared ~/.agents/skills that Pi also reads.
  skillFiles = lib.listToAttrs (
    lib.map (name: {
      name = ".codex/skills/${name}";
      value = {
        source = "${skillsMaterialized}/${name}";
      };
    }) (lib.attrNames (builtins.readDir "${codexDir}/skills"))
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
