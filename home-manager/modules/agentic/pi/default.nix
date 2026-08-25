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
      defaultProvider = "scoped";
      defaultModel = "main";
      defaultThinkingLevel = "medium";

      theme = "catppuccin-mocha";

      powerline = {
        preset = "default";
        placement = "below";
        welcome = false;
        layout = {
          left = [
            "model"
            "thinking"
            "custom:scope"
            "path"
          ];
          right = [
            "subagents"
            "context_pct"
            "cache_read"
          ];
        };
        cache_read = {
          format = "percent";
        };
        customItems = [
          {
            id = "scope";
            statusKey = "scope";
            position = "right";
            color = "warning";
          }
        ];
      };

      scopeProvider = {
        local = {
          main = {
            model = "deskapp/qwen3.8-27b";
            thinking = "medium";
          };
          remap = {
            "scoped/junior" = {
              model = "deskapp/qwen3.8-27b";
              thinking = "off";
            };
            "scoped/mid" = {
              model = "deskapp/qwen3.8-27b";
              thinking = "low";
            };
            "scoped/senior" = {
              model = "deskapp/qwen3.8-27b";
              thinking = "medium";
            };
            "scoped/staff" = {
              model = "deskapp/qwen3.8-27b";
              thinking = "xhigh";
            };
            "scoped/principal" = {
              model = "deskapp/qwen3.8-27b";
              thinking = "xhigh";
            };
          };
        };
        codex = {
          main = {
            model = "openai-codex/gpt-5.6-sol";
            thinking = "medium";
          };
          remap = {
            "scoped/junior" = {
              model = "openai-codex/gpt-5.6-luna";
            };
            "scoped/mid" = {
              model = "openai-codex/gpt-5.6-luna";
            };
            "scoped/senior" = {
              model = "openai-codex/gpt-5.6-terra";
            };
            "scoped/staff" = {
              model = "openai-codex/gpt-5.6-sol";
            };
            "scoped/principal" = {
              model = "openai-codex/gpt-5.6-sol";
            };
          };
        };
      };

      packages = [
        "npm:@tigorhutasuhut/pi-rules@0.5.4" # https://github.com/tigorlazuardi/pi-rules
        "npm:@tintinweb/pi-subagents@0.17.1" # https://github.com/tintinweb/pi-subagents
        "npm:@tintinweb/pi-tasks@0.8.0" # https://github.com/tintinweb/pi-tasks
        "npm:@juicesharp/rpiv-ask-user-question@2.6.2" # https://github.com/juicesharp/rpiv-mono
        "npm:pi-web-access@0.24.0" # https://github.com/nicobailon/pi-web-access
        "npm:pi-mcp-adapter@2.26.1" # https://github.com/nicobailon/pi-mcp-adapter
        "npm:pi-x-ide@1.19.4" # https://github.com/balaenis/pi-x-ide
        "npm:pi-tool-display@0.5.0" # https://github.com/MasuRii/pi-tool-display
        "npm:@ifi/oh-pi-themes@0.5.1" # https://github.com/ifiokjr/oh-pi
        "npm:pi-powerline-footer@0.15.1" # https://github.com/nicobailon/pi-powerline-footer
      ];
    };

    environment = {
      EXA_API_KEY.file = config.sops.secrets.pi_exa_api_key.path;
      PI_X_IDE_AUTO_INSTALL.value = "0";
      JJ_EDITOR.value = "false"; # fail loud if a jj command tries to open an editor
    };
  };

  home.file.".pi/agent/AGENTS.md".source = "${instructions.package}/pi/AGENTS.md";
  home.file.".pi/agent/prompts".source = "${instructions.package}/pi/prompts";
  home.file.".pi/agent/skills".source = "${instructions.package}/pi/skills";
  home.file.".pi/agent/agents".source = "${instructions.package}/pi/agents";

  home.file.".pi/agent/models.json".source = ./models.json;
  home.file.".pi/agent/extensions/scope-provider.ts".source = ./scope-provider.ts;
  home.file.".pi/agent/extensions/rpiv-herdr-bridge.ts".source = ./rpiv-herdr-bridge.ts;

  # pi-rules skips symlinked entries during rule discovery, so materialize the rendered rule files as regular files.
  home.file.".pi/agent/rules".source = pkgs.runCommand "pi-rules-materialized" {
    preferLocalBuild = true;
  } "cp -rL ${instructions.package}/pi/rules $out";

  home.file.".pi/web-search.json".text = builtins.toJSON {
    provider = "exa";
    workflow = "none";
    autoOpenBrowser = false;
  };

  home.file.".pi/pi-x-ide/config.json".text = builtins.toJSON {
    status_display = "statusline";
  };

  home.file.".pi/agent/subagents.json".text = builtins.toJSON {
    disableDefaultAgents = true;
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
