{
  config,
  lib,
  pkgs,
  inputs',
  ...
}:

let
  instructions = import ../instructions {
    inherit pkgs lib;
    postProcess = config.dotfiles.agentic.instructions.postProcess;
  };

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
        "claude-proj-docs *"
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
        // mkAllowCommands [ "ln -s * proj" ];

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
          ctx-load = "allow";
          ctx-save = "allow";
          mem-editing = "allow";
          proj-editing = "allow";
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
          "proj/**" = "allow";
          "docs/features/**" = "allow";
          "secrets/docs/features/**" = "allow";
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
      };
    };
  };

  baseConfig = {
    "$schema" = "https://opencode.ai/config.json";

    autoupdate = false;

    instructions =
      if config.dotfiles.agentic.instructions.mode == "legacy" then
        [ "~/.claude/rules/*.md" ]
      else
        [ "~/.config/opencode/rules/*.md" ];

    default_agent = "orchestrator";

    permission = permissions.agent.base;

    agent = {
      browser = {
        mode = "all";
        model = "openai/gpt-5.4-mini";
        description = "To be used by any tasks requiring web browser interaction. Shouldn't be used for websearch or webfetch skills, only for actually using the browser to interact with websites.";
        prompt = "You are an agent that can use a web browser to interact with websites. You should focus on that and not do any other work. If you are requested to do so, tell your manager agent that you should only be used for web browser related tasks.";
      };

      orchestrator = {
        mode = "primary";
        description = "Project manager agent that manages project documentation, code versioning and delegates work to sub-agents.";
        prompt = instructions.blocks.opencode."orchestrator-mode".body;
        permission = permissions.agent.planner;
      };

      plan = {
        mode = "primary";
        description = "Planning agent that creates project plans, break down tasks, and write to project docs.";
        prompt = "You are the planner of a project. Your role is to create project plans, break down tasks, and write to project docs. You must never engage in any code writing nor delegate such work, but can delegate plan/research to sub-agents. You should focus on high-level planning and project documentation. You actually don't even have access to running commands (other than jj), you only have access to writing project documentation.";
        permission = permissions.agent.planner;
      };
    };
  };

  mainConfig = lib.recursiveUpdate baseConfig {
    permission = permissions.agent.developer;
  };
  opencodeJson = pkgs.writers.writeJSON "opencode.json" mainConfig;

  nonoConfig = lib.recursiveUpdate baseConfig {
    permission = permissions.agent.sandbox;
  };
  nonoOpencodeJson = pkgs.writers.writeJSON "opencode-nono.json" nonoConfig;

  tuiJson = pkgs.writers.writeJSON "tui.json" {
    "$schema" = "https://opencode.ai/tui.json";
    theme = "tokyonight";
  };

  nono-opencode = pkgs.writeShellScriptBin "nono-opencode" ''
    export OPENCODE_ENABLE_EXA=1
    export OPENCODE_CONFIG=${nonoOpencodeJson}
    exec maybe --profile opencode -- ${pkgs.opencode}/bin/opencode "$@"
  '';

  opencode = pkgs.writeShellScriptBin "opencode" ''
    export OPENCODE_ENABLE_EXA=1
    exec ${pkgs.opencode}/bin/opencode "$@"
  '';

  mkOpencodeConfSymlinks =
    prefix: basePath: paths:
    lib.listToAttrs (
      map (path: {
        name = "${prefix}/${path}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/${basePath}/${path}";
        };
      }) paths
    );

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

  legacyPaths = [
    "commands"
    "agents"
  ];

  generatedPaths = [
    "commands"
    "agents"
    "rules"
    "skills"
    "AGENTS.md"
  ];

  commonSources = {
    ".config/opencode/opencode.json".source = opencodeJson;
    ".config/opencode/opencode-nono.json".source = nonoOpencodeJson;
    ".config/opencode/tui.json".source = tuiJson;
    ".config/opencode/plugins/ccmon.ts".source = "${inputs'.ccmon.packages.opencode-plugin}/ccmon.ts";
  };
in
{
  home.file =
    (
      if config.dotfiles.agentic.instructions.mode == "legacy" then
        mkOpencodeConfSymlinks ".config/opencode" "agentic/opencode" legacyPaths
      else
        mkOpencodeGeneratedSymlinks generatedPaths
    )
    // commonSources;

  home.packages = [
    nono-opencode
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
