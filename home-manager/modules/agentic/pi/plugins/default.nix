{
  config,
  lib,
  ...
}:

let
  plugins = [
    # https://github.com/tigorlazuardi/pi-rules
    {
      package = "npm:@tigorhutasuhut/pi-rules@0.6.0";
      files = {
        # See https://github.com/tigorlazuardi/pi-rules#configure-source-priority
        # Drop global user rules, other than pi
        # But include repo rules for pi, agents, and claude.
        ".pi/agent/rules.json".text = builtins.toJSON {
          enabled = true;
          sources = [
            {
              scope = "repo";
              kind = "pi";
            }
            {
              scope = "repo";
              kind = "agents";
            }
            {
              scope = "repo";
              kind = "claude";
            }
            {
              scope = "user";
              kind = "pi";
            }
          ];
        };
      };
    }

    # https://github.com/Quartermaster-Labs/pi-on-demand-context
    {
      package = "npm:@quartermaster-labs/pi-on-demand-context@0.3.1";
    }

    # https://github.com/tintinweb/pi-subagents
    {
      package = "npm:@tintinweb/pi-subagents@0.18.2";
      files = {
        ".pi/agent/subagents.json".text = builtins.toJSON {
          disableDefaultAgents = true;
        };
      };
    }

    # https://github.com/tintinweb/pi-tasks
    {
      package = "npm:@tintinweb/pi-tasks@0.9.0";
    }

    # https://github.com/juicesharp/rpiv-mono
    {
      package = "npm:@juicesharp/rpiv-ask-user-question@2.7.1";
    }

    # https://github.com/nicobailon/pi-web-access
    {
      package = "npm:pi-web-access@0.24.2";
      environment = {
        EXA_API_KEY.file = config.sops.secrets.pi_exa_api_key.path;
      };
      files = {
        ".pi/web-search.json".text = builtins.toJSON {
          provider = "exa";
          workflow = "none";
          autoOpenBrowser = false;
        };
      };
    }

    # https://github.com/nicobailon/pi-mcp-adapter
    {
      package = "npm:pi-mcp-adapter@2.27.0";
      files = {
        ".pi/agent/mcp.json".text = builtins.toJSON {
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
      };
    }

    # https://github.com/balaenis/pi-x-ide
    {
      package = "npm:pi-x-ide@1.19.5";
      environment = {
        PI_X_IDE_AUTO_INSTALL.value = "0";
      };
      files = {
        ".pi/pi-x-ide/config.json".text = builtins.toJSON {
          status_display = "statusline";
        };
      };
    }

    # https://github.com/MasuRii/pi-tool-display
    {
      package = "npm:pi-tool-display@0.5.0";
    }

    # https://github.com/ifiokjr/oh-pi
    {
      package = "npm:@ifi/oh-pi-themes@0.5.1";
      settings = {
        theme = "catppuccin-mocha";
      };
    }

    # https://github.com/nicobailon/pi-powerline-footer
    {
      package = "npm:pi-powerline-footer@0.15.1";
      settings = {
        powerline = {
          preset = "default";
          placement = "below";
          welcome = false;
          layout = {
            left = [
              "custom:mode"
              "custom:scope"
              "model"
              "thinking"
            ];
            right = [
              "path"
              "subagents"
              "context_pct"
              "cache_read"
              "custom:tps"
            ];
          };
          cache_read = {
            format = "percent";
          };
          customItems = [
            {
              id = "mode";
              statusKey = "mode";
              position = "left";
              excludeFromExtensionStatuses = true;
            }
            {
              id = "scope";
              statusKey = "scope";
              position = "right";
              color = "warning";
            }
            {
              id = "tps";
              statusKey = "tps";
              position = "right";
              selfColorize = true; # preserve extension color
            }
          ];
        };
      };
    }

    # https://github.com/arhen/pi-extensions
    {
      package = "npm:@arhen/pi-core-tps-stats@1.3.1";
    }

    {
      files = {
        ".pi/agent/extensions/scope-provider.ts".source = ./scope-provider.ts;
      };
    }

    {
      files = {
        ".pi/agent/extensions/herdr-agent-state.ts" = {
          source = ./herdr-agent-state.ts;
          force = true; # rewrite the file on activation instead of failing
        };
      };
    }

    {
      files = {
        ".pi/agent/extensions/rpiv-herdr-bridge.ts".source = ./rpiv-herdr-bridge.ts;
      };
    }

    {
      files = {
        ".pi/agent/extensions/mode-switch.ts".source = ./mode-switch.ts;
      };
    }

    {
      files = {
        ".pi/agent/extensions/bash-timeout.ts".source = ./bash-timeout.ts;
        ".pi/agent/bash-timeout.json".text = builtins.toJSON {
          defaultTimeoutSeconds = 300; # 5m default
          maxTimeoutSeconds = 1200; # 20m max explicit by agent
        };
      };
    }
  ];

  # npm packages feed settings.packages; local extension entries have no package.
  npmPlugins = lib.filter (p: p ? "package") plugins;

  # Merge one optional attribute out of every plugin entry, dropping entries
  # that don't define it. Each key is owned by at most one plugin.
  merge =
    key: lib.foldl (acc: p: if builtins.hasAttr key p then acc // p.${key} else acc) { } plugins;
in
{
  programs.pi.coding-agent.settings = (merge "settings") // {
    packages = lib.map (p: p.package) npmPlugins;
  };

  programs.pi.coding-agent.environment = merge "environment";

  home.file = merge "files";
}
