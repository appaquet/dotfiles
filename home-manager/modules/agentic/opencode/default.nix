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
      };
    };
  };

  baseConfig = {
    "$schema" = "https://opencode.ai/config.json";

    autoupdate = false;

    instructions = [ "~/.config/opencode/rules/*.md" ];

    default_agent = "orchestrator";

    permission = permissions.agent.base;

    agent = {
      browser = {
        mode = "subagent";
        model = "openai/gpt-5.6-luna";
        description = "Browser agent, to be used by any tasks requiring web browser interaction. Shouldn't be used for web search and web fetch, only for actually using the browser to interact with websites.";
        prompt = instructions.blocks.opencode."browser-agent-prompt".body;
        permission = permissions.agent.browser;
      };

      orchestrator = {
        mode = "primary";
        description = "Project manager agent that manages project documentation, version control and delegates work to sub-agents.";
        prompt = instructions.blocks.opencode."orchestration-prompt".body;
        permission = permissions.agent.planner;
      };

      plan = {
        mode = "primary";
        description = "Planning agent that creates project plans, break down tasks, and write to project docs.";
        prompt = "You are the planner of a project. Your role is to create project plans, break down tasks, and write to project docs. You must never engage in any code writing nor delegate such work, but can delegate plan/research to sub-agents. You should focus on high-level planning and project documentation. You actually don't even have access to running commands (other than jj), you only have access to writing project documentation.";
        permission = permissions.agent.planner;
      };

      explore = {
        model = "opencode-go/deepseek-v4-flash";
      };

      general = {
        disable = true; # Should use dev insteads. Don't have proper prompts for sub-agents work and keep recursively spawn.
      };
    };

    provider = {
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

  nono-opencode = pkgs.writeShellScriptBin "nono-opencode" ''
    export OPENCODE_ENABLE_EXA=1
    export OPENCODE_EXPERIMENTAL_PARALLEL=1 # parallel web search
    #export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=1 # non-blocking background sub-agents
    export OPENCODE_CONFIG=${yoloOpencodeJson}
    exec maybe --profile opencode -- ${pkgs.opencode}/bin/opencode "$@"
  '';

  yolo-opencode = pkgs.writeShellScriptBin "yolo-opencode" ''
    export OPENCODE_ENABLE_EXA=1
    export OPENCODE_EXPERIMENTAL_PARALLEL=1 # parallel web search
    #export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=1 # non-blocking background sub-agents
    export OPENCODE_ROOT="$(pwd)"
    export OPENCODE_CONFIG=${yoloOpencodeJson}
    exec ${pkgs.opencode}/bin/opencode "$@"
  '';

  opencode = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_ENABLE_EXA=1
    export OPENCODE_EXPERIMENTAL_PARALLEL=1 # parallel web search
    #export OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=1 # non-blocking background sub-agents
    export OPENCODE_ROOT="$(pwd)"
    exec ${pkgs.opencode}/bin/opencode "$@"
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
  };
in
{
  home.file = (mkOpencodeGeneratedSymlinks generatedPaths) // commonSources;

  home.packages = [
    nono-opencode
    yolo-opencode
    opencode
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
