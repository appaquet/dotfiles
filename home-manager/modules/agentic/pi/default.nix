{
  config,
  pkgs,
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;
in
{
  imports = [
    ./module.nix
    ./models.nix
    ./plugins
  ];

  dotfiles.pi = {
    enable = true;
    authFile = config.sops.secrets.pi_auth_json.path;
    environment.JJ_EDITOR.value = "false"; # fail loud if a jj command tries to open an editor

    settings = {
      doubleEscapeAction = "tree";
      enableInstallTelemetry = false;
      hideThinkingBlock = false;
      showCacheMissNotices = true;
      tuiMode = "fullscreen";
    };
  };

  home.file.".pi/agent/AGENTS.md".source = "${instructions.package}/pi/AGENTS.md";
  home.file.".pi/agent/prompts".source = "${instructions.package}/pi/prompts";
  home.file.".pi/agent/skills".source = "${instructions.package}/pi/skills";
  home.file.".pi/agent/agents".source = "${instructions.package}/pi/agents";

  # pi-rules skips symlinked entries during rule discovery, so materialize the rendered rule files as regular files.
  home.file.".pi/agent/rules".source = pkgs.runCommand "pi-rules-materialized" {
    preferLocalBuild = true;
  } "cp -rL ${instructions.package}/pi/rules $out";

  # pi secrets
  sops.secrets.pi_exa_api_key.sopsFile = config.sops.secretsFiles.work;
  sops.secrets.pi_exa_api_key.key = "pi/exa_api_key";
  sops.secrets.pi_auth_json.sopsFile = config.sops.secretsFiles.work;
  sops.secrets.pi_auth_json.key = "pi/auth_json";

  dotfiles.nono.profiles.pi = {
    meta.version = "1.0.0";

    extends = "coding-agent";

    filesystem.allow = [
      "$HOME/.pi"
      "$HOME/.local/share/pi"
    ];

    filesystem.read_file = [
      "$HOME/.config/sops-nix/secrets/pi_exa_api_key"
      "$HOME/.config/sops-nix/secrets/pi_auth_json"
    ];

    # pi-x-ide does a sig 0 on ide processes, which is blocked unfortunately...
    # i'd rather have that leak than have the ide not work
    security.signal_mode = "allow_all";

    network.block = false;
  };
}
