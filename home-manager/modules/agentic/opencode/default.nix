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

  planningAgentsPermissions = {
    "*" = "deny";
    webfetch = "ask";
    websearch = "allow";
    read = "allow";
    grep = "allow";
    task = "allow";
    edit = {
      "*" = "ask";
      "proj/**" = "allow";
      "docs/features/**" = "allow";
      "secrets/docs/features/**" = "allow";
    };
    bash = {
      "*" = "ask";
      "readlink proj" = "allow";
      "ln -s * proj" = "allow";
      "jj *" = "allow";
      "jj-current-branch" = "allow";
      "claude-proj-docs" = "allow";
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

    agent = {
      bigbrain = {
        mode = "subagent";
        model = "openai/gpt-5.5";
        description = "To be used for complex tasks (similar to opus)";
      };

      normal = {
        mode = "subagent";
        model = "opencode-go/deepseek-v4-pro";
        description = "To be used for general tasks (similar to sonnet)";
      };

      lightweight = {
        mode = "subagent";
        model = "opencode-go/deepseek-v4-flash";
        description = "To be used for lightweight tasks (similar to haiku)";
      };

      browser = {
        mode = "all";
        model = "openai/gpt-5.4-mini";
        description = "To be used by any tasks requiring web browser interaction. Shouldn't be used for websearch or webfetch skills, only for actually using the browser to interact with websites.";
        prompt = "You are an agent that can use a web browser to interact with websites. You should focus on that and not do any other work. If you are requested to do so, tell your manager agent that you should only be used for web browser related tasks.";
      };

      orchestrator = {
        mode = "primary";
        description = "Project manager agent that manages project documentation, code versioning and delegate work to sub-agents";
        prompt = "You are the orchestrator of a project. Your role is to manage the project documentation, code versioning, and delegate work to sub-agents. You should focus on high-level planning, project management, and jj (code versioning). Anything requiring reading, understanding and exploring code should be delegated to sub-agents. You actually don't even have access to writing files or running commands yourself, other than project documentation and jj commands.";
        permission = planningAgentsPermissions;
      };

      plan = {
        mode = "primary";
        description = "Planning agent that creates project plans, break down tasks, and write to project docs. Should never engage in any code writing nor delegate such work";
        prompt = "You are the planner of a project. Your role is to create project plans, break down tasks, and write to project docs. You should never engage in any code writing nor delegate such work. You should focus on high-level planning and project documentation. You actually don't even have access to running commands (other than jj), you only have access to writing project documentation.";
        permission = planningAgentsPermissions;
      };
    };

    permission = {
      external_directory = {
        "~/.claude/**" = "allow";
      };
      skill = {
        "*" = "ask";
        ctx-load = "allow";
        ctx-save = "allow";
        mem-editing = "allow";
        proj-editing = "allow";
      };
    };
  };

  mainConfig = lib.recursiveUpdate baseConfig {
    permission = {
      "*" = "ask";
      read = "allow";
      edit = "allow";
      grep = "allow";
      bash = {
        "*" = "ask";
        "notify *" = "allow";
        "lsof *" = "allow";
        "readlink *" = "allow";
        "echo *" = "allow";
        "grep *" = "allow";
        "rg *" = "allow";
        "sed *" = "allow";
        "cat *" = "allow";
        "ls *" = "allow";
        "tail *" = "allow";
        "ln -s * proj" = "allow";
        "claude-proj-docs *" = "allow";
        "jj log *" = "allow";
        "jj show *" = "allow";
        "jj diff *" = "allow";
        "jj status *" = "allow";
        "jj commit *" = "allow";
        "jj new *" = "allow";
        "jj squash *" = "allow";
        "jj ls" = "allow";
        "jj st" = "allow";
        "jj file show *" = "allow";
        "jj op log *" = "allow";
        "jj describe *" = "allow";
        "jj-main-branch *" = "allow";
        "jj-current-branch *" = "allow";
        "jj-prev-branch *" = "allow";
        "jj-stacked-branches *" = "allow";
        "jj-diff-working *" = "allow";
        "jj-diff-branch *" = "allow";
        "jj-stacked-stats *" = "allow";
        "gh pr list *" = "allow";
        "gh pr view *" = "allow";
        "gh pr checks *" = "allow";
        "gh pr diff *" = "allow";
        "gh pr review *" = "allow";
        "nix eval *" = "allow";
        "nix build *" = "allow";
        "nix flake *" = "allow";
        "nix develop *" = "allow";
        "nix run *" = "allow";
        "nix shell *" = "allow";
        "nix repl *" = "allow";
        "cargo test *" = "allow";
        "cargo check *" = "allow";
        "cargo clippy *" = "allow";
        "cargo fmt *" = "allow";
        "cargo build *" = "allow";
        "cargo tree *" = "allow";
        "go build *" = "allow";
        "go fmt *" = "allow";
        "go mod *" = "allow";
        "go test *" = "allow";
        "go doc *" = "allow";
        "go vet *" = "allow";
        "gofmt *" = "allow";
        "goimports *" = "allow";
        "staticcheck *" = "allow";
        "npm run build *" = "allow";
        "npm run lint *" = "allow";
        "npm run test *" = "allow";
        "npm run fmt *" = "allow";
      };
      webfetch = "ask";
      websearch = "allow";
    };
  };
  opencodeJson = pkgs.writers.writeJSON "opencode.json" mainConfig;

  # Inside nono, we allow everything as it's sandboxed.
  nonoConfig = lib.recursiveUpdate baseConfig {
    permission = {
      "*" = "allow";
      bash = "allow";
      webfetch = "allow";
      websearch = "allow";
    };
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
in
{
  home.file =
    if config.dotfiles.agentic.instructions.mode == "legacy" then
      (mkOpencodeConfSymlinks ".config/opencode" "agentic/opencode" [
        "commands"
        "agents"
      ])
      // {
        ".config/opencode/opencode.json".source = opencodeJson;
        ".config/opencode/opencode-nono.json".source = nonoOpencodeJson;
        ".config/opencode/tui.json".source = tuiJson;
        ".config/opencode/plugins/ccmon.ts".source = "${inputs'.ccmon.packages.opencode-plugin}/ccmon.ts";
      }
    else
      (mkOpencodeGeneratedSymlinks [
        "commands"
        "agents"
        "rules"
        "skills"
        "AGENTS.md"
      ])
      // {
        ".config/opencode/opencode.json".source = opencodeJson;
        ".config/opencode/opencode-nono.json".source = nonoOpencodeJson;
        ".config/opencode/tui.json".source = tuiJson;
        ".config/opencode/plugins/ccmon.ts".source = "${inputs'.ccmon.packages.opencode-plugin}/ccmon.ts";
      };

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
        "$HOME/.cache/opencode"
        "$HOME/.local/state/opencode"
        "$HOME/.local/state/ccmon" # ccmon plugin writes status there
      ];
    };
    network.block = false;
  };
}
