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
  ];

  sops.secrets.pi_exa_api_key.sopsFile = config.sops.secretsFiles.common;

  programs.pi.coding-agent = {
    enable = true;
    package = inputs'.pi.packages.coding-agent.override {
      nodejs = pkgs.nodejs_26;
    };

    #models = ./models.json; # This is not used here so that we use a symlinked version

    settings = {
      defaultProvider = "deskapp";
      defaultModel = "qwen3.8-27b";
      defaultThinkingLevel = "medium";
      theme = "catppuccin-mocha";
      packages = [
        "npm:@tigorhutasuhut/pi-rules@0.5.4"
        "npm:@tintinweb/pi-subagents@0.14.3"
        "npm:@tintinweb/pi-tasks@0.7.2"
        "npm:@juicesharp/rpiv-ask-user-question@2.4.0"
        "npm:pi-web-access@0.22.0"
        "npm:pi-mcp-adapter@2.25.0"
        "npm:pi-x-ide@1.19.4"
        "npm:@ifi/oh-pi-themes@0.5.1"
      ];
    };

    environment.EXA_API_KEY.file = config.sops.secrets.pi_exa_api_key.path;
    environment.PI_X_IDE_AUTO_INSTALL.value = "0";
  };

  home.file.".pi/agent/AGENTS.md".source = "${instructions.package}/pi/AGENTS.md";
  home.file.".pi/agent/prompts".source = "${instructions.package}/pi/prompts";
  home.file.".pi/agent/skills".source = "${instructions.package}/pi/skills";
  home.file.".pi/agent/agents".source = "${instructions.package}/pi/agents";
  home.file.".pi/agent/models.json".source = ./models.json;

  # pi-rules skips symlinked entries during rule discovery, so materialize
  # the rendered rule files as regular files.
  home.file.".pi/agent/rules".source = pkgs.runCommand "pi-rules-materialized" {
    preferLocalBuild = true;
  } "cp -rL ${instructions.package}/pi/rules $out";

  home.file.".pi/web-search.json".text = builtins.toJSON {
    provider = "exa";
    workflow = "none";
    autoOpenBrowser = false;
  };

  home.file.".pi/agent/mcp.json".text = builtins.toJSON {
    scriptMode = false;
    settings.mcpFooterStatus = "off";
    mcpServers.chrome = {
      command = "mcp-npx";
      args = [
        "-y"
        "chrome-devtools-mcp@latest"
        "--browser-url=http://127.0.0.1:9222"
        "--experimentalPageIdRouting"
      ];
    };
  };

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
    ];

    network.block = false;
  };
}
