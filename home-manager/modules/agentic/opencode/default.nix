{
  config,
  lib,
  pkgs,
  inputs',
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;

  permissions = rec {
    mkAllowCommands = commands: lib.genAttrs commands (_: "allow");

    bash = {
      shellRead = mkAllowCommands [
        "notify *"
        "lsof *"
        "readlink *"
        "echo *"
        "grep *"
        "rg *"
        "sed *"
        "cat *"
        "ls *"
        "tail *"
      ];

      projectDocs = mkAllowCommands [
        "agentic-proj-docs *"
      ];

      dev = {
        nix = mkAllowCommands [
          "nix eval *"
          "nix build *"
          "nix flake *"
          "nix develop *"
          "nix run *"
          "nix shell *"
          "nix repl *"
        ];

        rust = mkAllowCommands [
          "cargo test *"
          "cargo check *"
          "cargo clippy *"
          "cargo fmt *"
          "cargo build *"
          "cargo tree *"
        ];

        go = mkAllowCommands [
          "go build *"
          "go fmt *"
          "go mod *"
          "go test *"
          "go doc *"
          "go vet *"
          "gofmt *"
          "goimports *"
          "staticcheck *"
        ];

        node = mkAllowCommands [
          "npm run build *"
          "npm run lint *"
          "npm run test *"
          "npm run fmt *"
        ];
      };

      vcs = {
        jjRead = mkAllowCommands [
          "jj log *"
          "jj show *"
          "jj diff *"
          "jj status *"
          "jj ls"
          "jj st"
          "jj file show *"
          "jj op log *"
          "jj describe *"
          "jj-main-branch *"
          "jj-current-branch *"
          "jj-prev-branch *"
          "jj-stacked-branches *"
          "jj-diff-working *"
          "jj-diff-branch *"
          "jj-stacked-stats *"
        ];

        jjWrite = mkAllowCommands [
          "jj commit *"
          "jj new *"
          "jj squash *"
          "jj workspace update"
        ];

        ghRead = mkAllowCommands [
          "gh pr list *"
          "gh pr view *"
          "gh pr checks *"
          "gh pr diff *"
        ];

        ghWrite = mkAllowCommands [
          "gh pr review *"
        ];
      };

      planner =
        bash.shellRead
        // bash.projectDocs
        // bash.vcs.jjRead
        // bash.vcs.jjWrite
        // bash.vcs.ghRead
        // mkAllowCommands [
          "agentic-proj-create-adhoc *"
          "ln * proj"
          "ln * proj-adhoc"
          "rm proj"
          "rm proj-adhoc"
        ];

      developer =
        bash.shellRead
        // bash.projectDocs
        // bash.dev.nix
        // bash.dev.rust
        // bash.dev.go
        // bash.dev.node
        // bash.vcs.jjRead
        // bash.vcs.jjWrite
        // bash.vcs.ghRead
        // bash.vcs.ghWrite;
    };

    agent = {
      base = {
        read = "allow";
        grep = "allow";
        websearch = "allow";
        webfetch = "ask";

        external_directory = {
          "~/.claude/**" = "allow";
          "~/dotfiles/**" = "allow";
        };

        skill = {
          "*" = "ask";
          proj-load = "allow";
          proj-save = "allow";
          mem-writing = "allow";
          proj-writing = "allow";
          human-writer = "allow";
          customize-opencode = "allow";
        };
      };

      planner = {
        "*" = "deny";

        websearch = "allow";
        read = "allow";
        grep = "allow";
        task = "allow";
        glob = "allow";
        todowrite = "allow";
        question = "allow";

        edit = {
          "*" = "deny";
          "*.md" = "allow";
          "proj/**" = "allow";
          "docs/features/**" = "allow";
          "dev/features/**" = "allow";
          "secrets/docs/features/**" = "allow";
        };

        skill = {
          "*" = "ask";
          proj-load = "allow";
          proj-save = "allow";
          mem-writing = "allow";
          proj-writing = "allow";
          human-writer = "allow";
          customize-opencode = "allow";
        };

        bash = (
          {
            "*" = "deny";
          }
          // bash.planner
        );
      };

      developer = {
        "*" = "ask";
        edit = "allow";
        task = "allow";

        bash =
          bash.shellRead
          // bash.projectDocs
          // bash.dev.nix
          // bash.dev.rust
          // bash.dev.go
          // bash.dev.node
          // bash.vcs.jjRead
          // bash.vcs.jjWrite
          // bash.vcs.ghRead
          // bash.vcs.ghWrite;
      };

      sandbox = {
        "*" = "allow";
        bash = "allow";
        webfetch = "allow";
        task = "allow";
      };

      browser = {
        task = "deny";
        "chrome*" = "allow";
      };
    };
  };

  baseConfig = {
    "$schema" = "https://opencode.ai/config.json";

    autoupdate = false;

    experimental = {
      disable_paste_summary = true;
    };

    instructions = [
      # Main instruction is written to AGENTS.md, which will be loaded as well
      "~/.config/opencode/rules/*.md"
    ];

    default_agent = "orchestrator";

    permission = permissions.agent.base;

    mcp = {
      chrome = {
        type = "local";
        command = [
          "mcp-npx"
          "-y"
          "chrome-devtools-mcp@latest"
          "--browser-url=http://127.0.0.1:9222"
          "--experimentalPageIdRouting"
        ];
        enabled = true;
      };
    };

    agent = {
      orchestrator = {
        mode = "primary";
        color = "#fdba74";
        description = "Project manager agent that manages project documentation, version control and delegates work to sub-agents.";
        prompt = instructions.blocks.opencode."orchestration-prompt".body;
        permission = permissions.agent.planner;
      };

      # Built-in plan agents doesn't allow any edits even if we pass permission overrides.
      # Redefine as `planner` instead
      plan = {
        disable = true;
      };
      planner = {
        mode = "primary";
        color = "#93c5fd";
        description = "Planning agent that creates project plans, break down tasks, and write to project docs.";
        prompt = "You are the planner of a project. Your role is to create project plans, break down tasks, and write to project docs. You must never engage in any code writing nor delegate such work, but can delegate exploration/search to sub-agents. You actually don't even have access to running commands (other than jj), you only have access to writing to project documentation.";
        permission = permissions.agent.planner;
      };

      explore = {
        model = "opencode-go/deepseek-v4-flash";
      };

      build = {
        color = "#f87171";
        prompt = "You are in direct build mode, with orchestration off. You should not use sub-agents to do any development work. You can only use the explore agent for code exploration and research.";
        permission = {
          task = {
            "*" = "deny";
            explore = "allow";
            general = "allow";
          };
        };
      };
    };

    provider = {
      sparkbud1 = {
        npm = "@ai-sdk/openai-compatible";
        name = "Sparkbud1";
        options = {
          baseURL = "http://sparkbud1.n3x.net:8080/v1";
        };
        models = {
          "bottlecapai/ThinkingCap-Qwen3.6-27B-NVFP4" = {
            name = "bottlecapai/ThinkingCap-Qwen3.6-27B-NVFP4";
          };
          "unsloth/Qwen3.6-27B-NVFP4" = {
            name = "unsloth/Qwen3.6-27B-NVFP4";
          };
          "deepseek-v4-flash-dspark" = {
            name = "deepseek-v4-flash-dspark";
          };
        };
      };

      sparkbud2 = {
        npm = "@ai-sdk/openai-compatible";
        name = "Sparkbud2";
        options = {
          baseURL = "http://sparkbud2.n3x.net:8080/v1";
        };
        models = {
          "unsloth/Qwen3.6-27B-NVFP4" = {
            name = "unsloth/Qwen3.6-27B-NVFP4";
          };
          laguna = {
            name = "laguna";
          };
          "deepreinforce-ai/Ornith-1.0-35B" = {
            name = "deepreinforce-ai/Ornith-1.0-35B";
          };
        };
      };

      deskapp = {
        npm = "@ai-sdk/openai-compatible";
        name = "deskapp";
        options = {
          baseURL = "http://deskapp.n3x.net:15000/v1";
        };
        models = {
          "unsloth/gemma-4-12B-it-qat-GGUF" = {
            name = "unsloth/gemma-4-12B-it-qat-GGUF";
          };
          "unsloth/Qwen3.6-27B-MTP-GGUF" = {
            name = "unsloth/Qwen3.6-27B-MTP-GGU";
          };
          "unsloth/Qwen3.6-27B-NVFP4" = {
            name = "unsloth/Qwen3.6-27B-NVFP4";
            limit = {
              context = 150000;
              output = 12000;
            };
            options = {
              chat_template_kwargs.enable_thinking = true;
              temperature = 0.6;
              top_p = 0.95;
              top_k = 20;
            };
            variants = {
              thinking = {
                chat_template_kwargs.enable_thinking = true;
                temperature = 0.6;
                top_p = 0.95;
                top_k = 20;
              };
              non-thinking = {
                chat_template_kwargs.enable_thinking = false;
                temperature = 0.7;
                top_p = 0.8;
                top_k = 20;
                presence_penalty = 1.5;
              };
            };
          };
        };
      };
    };
  };

  mainConfig = lib.recursiveUpdate baseConfig {
    permission = permissions.agent.developer;
  };
  opencodeJson = pkgs.writers.writeJSON "opencode.json" mainConfig;

  yoloConfig = lib.recursiveUpdate baseConfig {
    permission = permissions.agent.sandbox;
  };
  yoloOpencodeJson = pkgs.writers.writeJSON "opencode-yolo.json" yoloConfig;

  tuiJson = pkgs.writers.writeJSON "tui.json" {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "tokyonight";
  };

  tmuxStatuslinePlugin = pkgs.writeText "tmux-statusline.ts" (
    builtins.readFile ./plugins/tmux-statusline.ts
  );

  direnvPlugin = pkgs.writeText "direnv.ts" (builtins.readFile ./plugins/direnv.ts);

  notifyPlugin = pkgs.writeText "notify.ts" (builtins.readFile ./plugins/notify.ts);

  commonExports = ''
    export OPENCODE_ENABLE_EXA=1
    export OPENCODE_EXPERIMENTAL_PARALLEL=1 # parallel web search
    export OPENCODE_EXPERIMENTAL_FILEWATCHER=1 # reload direnv after devshell file changes
    export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=1 # non-blocking background sub-agents
    export OPENCODE_ROOT="$(pwd)"
  '';

  opencode = pkgs.writeShellScriptBin "opencode" ''
    ${commonExports}
    exec ${pkgs.opencode}/bin/opencode "$@"
  '';

  nono-opencode = pkgs.writeShellScriptBin "nono-opencode" ''
    export OPENCODE_CONFIG=${yoloOpencodeJson}
    exec maybe --profile opencode -- ${opencode}/bin/opencode "$@"
  '';

  yolo-opencode = pkgs.writeShellScriptBin "yolo-opencode" ''
    export OPENCODE_CONFIG=${yoloOpencodeJson}
    exec ${opencode}/bin/opencode "$@"
  '';

  closecode = pkgs.writeShellScriptBin "closecode" ''
    SANDBOX=$(mktemp -d /tmp/closecode-XXXXXX)
    trap "rm -rf "$SANDBOX"" EXIT
    export XDG_DATA_HOME="$SANDBOX/data"
    export XDG_CACHE_HOME="$SANDBOX/cache"
    export XDG_STATE_HOME="$SANDBOX/state"

    exec ${opencode}/bin/opencode "$@"
  '';

  nono-closecode = pkgs.writeShellScriptBin "nono-closecode" ''
    export OPENCODE_CONFIG=${yoloOpencodeJson}
    exec maybe --profile opencode -- ${closecode}/bin/closecode "$@"
  '';

  yolo-closecode = pkgs.writeShellScriptBin "yolo-closecode" ''
    export OPENCODE_CONFIG=${yoloOpencodeJson}
    exec ${closecode}/bin/closecode "$@"
  '';

  mkOpencodeGeneratedSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".config/opencode/${path}";
        value = {
          source = "${instructions.package}/opencode/${path}";
        };
      }) paths
    );

  generatedPaths = [
    "commands"
    "agents"
    "rules"
    "skills"
    "AGENTS.md"
  ];

  commonSources = {
    ".config/opencode/opencode.json".source = opencodeJson;
    ".config/opencode/opencode-yolo.json".source = yoloOpencodeJson;
    ".config/opencode/tui.json".source = tuiJson;
    ".config/opencode/plugins/ccmon.ts".source = "${inputs'.ccmon.packages.opencode-plugin}/ccmon.ts";
    ".config/opencode/plugins/tmux-statusline.ts".source = tmuxStatuslinePlugin;
    ".config/opencode/plugins/direnv.ts".source = direnvPlugin;
    #".config/opencode/plugins/notify.ts".source = notifyPlugin; # FIXME: doesn't work because ssh key unavailable in sandbox
  };
in
{
  home.file = (mkOpencodeGeneratedSymlinks generatedPaths) // commonSources;

  home.packages = [
    opencode
    nono-opencode
    yolo-opencode
    closecode
    nono-closecode
    yolo-closecode
  ];

  dotfiles.nono.profiles.opencode = {
    meta.version = "1.0.0";
    extends = "coding-agent";
    filesystem = {
      read = [ "$HOME/.claude" ];
      allow = [
        "$HOME/.config/opencode"
        "$HOME/.local/share/opencode"
        "$HOME/.local/share/opentui"
        "$HOME/.cache/opencode"
        "$HOME/.local/state/opencode"
        "$HOME/.local/state/ccmon" # ccmon plugin writes status there
      ];
    };
    network.block = false;
  };
}
