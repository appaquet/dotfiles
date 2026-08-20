{
  config,
  inputs,
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;
in
{
  imports = [
    inputs.pi.homeManagerModules.default
  ];

  sops.secrets.pi_exa_api_key.sopsFile = config.sops.secretsFiles.common;

  programs.pi.coding-agent = {
    enable = true;

    #models = ./models.json; # This is not used here so that we use a symlinked version

    settings = {
      defaultProvider = "deskapp";
      defaultModel = "qwen3.8-27b";
      defaultThinkingLevel = "medium";
      packages = [
        "npm:@tintinweb/pi-subagents@0.14.3"
        "npm:@tintinweb/pi-tasks@0.7.2"
        "npm:@juicesharp/rpiv-ask-user-question@2.4.0"
        "npm:pi-web-access@0.22.0"
      ];
    };

    environment.EXA_API_KEY.file = config.sops.secrets.pi_exa_api_key.path;
  };

  home.file.".pi/agent/AGENTS.md".source = "${instructions.package}/pi/AGENTS.md";
  home.file.".pi/agent/prompts".source = "${instructions.package}/pi/prompts";
  home.file.".pi/agent/skills".source = "${instructions.package}/pi/skills";
  home.file.".pi/agent/agents".source = "${instructions.package}/pi/agents";
  home.file.".pi/agent/models.json".source = ./models.json;

  home.file.".pi/web-search.json".text = builtins.toJSON {
    provider = "exa";
    workflow = "none";
    autoOpenBrowser = false;
  };
}
