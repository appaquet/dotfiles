{
  config,
  inputs,
  inputs',
  pkgs,
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;
  piPackage = config.programs.pi.coding-agent.finalPackage;

  nono-pi = pkgs.writeShellScriptBin "nono-pi" ''
    export HERDR_AGENT=pi
    exec maybe --profile pi -- ${piPackage}/bin/pi "$@"
  '';
in
{
  imports = [
    inputs.pi.homeManagerModules.default
    ./models.nix
    ./plugins
  ];

  sops.secrets.pi_exa_api_key.sopsFile = config.sops.secretsFiles.common;
  sops.secrets.pi_opencode_api_key.sopsFile = config.sops.secretsFiles.common;

  programs.pi.coding-agent = {
    enable = true;
    package = inputs'.pi.packages.coding-agent.override {
      nodejs = pkgs.nodejs_26;
    };

    environment.OPENCODE_API_KEY.file = config.sops.secrets.pi_opencode_api_key.path;
    environment.JJ_EDITOR.value = "false"; # fail loud if a jj command tries to open an editor
  };

  home.file.".pi/agent/AGENTS.md".source = "${instructions.package}/pi/AGENTS.md";
  home.file.".pi/agent/prompts".source = "${instructions.package}/pi/prompts";
  home.file.".pi/agent/skills".source = "${instructions.package}/pi/skills";
  home.file.".pi/agent/agents".source = "${instructions.package}/pi/agents";

  # pi-rules skips symlinked entries during rule discovery, so materialize the rendered rule files as regular files.
  home.file.".pi/agent/rules".source = pkgs.runCommand "pi-rules-materialized" {
    preferLocalBuild = true;
  } "cp -rL ${instructions.package}/pi/rules $out";

  home.packages = [ nono-pi ];

  dotfiles.nono.profiles.pi = {
    meta.version = "1.0.0";

    extends = "coding-agent";

    filesystem.allow = [
      "$HOME/.pi"
      "$HOME/.local/share/pi"
    ];

    filesystem.read_file = [
      "$HOME/.config/sops-nix/secrets/pi_exa_api_key"
      "$HOME/.config/sops-nix/secrets/pi_opencode_api_key"
    ];

    # pi-x-ide does a sig 0 on ide processes, which is blocked unfortunately...
    # i'd rather have that leak than have the ide not work
    security.signal_mode = "allow_all";

    network.block = false;
  };
}
