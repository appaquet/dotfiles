{
  pkgs,
  config,
  lib,
  inputs',
  ...
}:

let
  instructions = config.nixantic.instructions.rendered;

  mkClaudeConfSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".claude/${path}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/agentic/claude/${path}";
        };
      }) paths
    );

  mkClaudeGeneratedSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".claude/${path}";
        value = {
          source = "${instructions.package}/claude/${path}";
        };
      }) paths
    );

  claude-code = pkgs.claude-code;

  claude-wrapped = pkgs.writeShellScriptBin "claude" ''
    if [ ! -d ".git" ]; then
      echo -e "\e[31mWARNING: No .git, are you at the root of a project?\e[0m" >&2
      sleep 5
    fi

    # Override claude with overridden config dir. This prevents it from writing its config to
    # ~/.claude.json so that we can keep all claude config in ~/.claude.
    export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.claude"
    export CLAUDE_ROOT="''${CLAUDE_PROJECT_DIR:-$(pwd)}"

    # Initialize the shared statusline once. It clears stale state and returns the
    # window ID that later hooks must keep targeting after the user switches windows.
    if CLAUDE_TMUX_WINDOW="$(tmux-statusline init)"; then
      if [ -n "$CLAUDE_TMUX_WINDOW" ]; then
        export CLAUDE_TMUX_WINDOW
      else
        unset CLAUDE_TMUX_WINDOW
      fi
    else
      unset CLAUDE_TMUX_WINDOW
      ${claude-tmux-indicator}/bin/claude-tmux-indicator startup-initialization-failed > /dev/null
    fi

    # Clear the pinned indicator when Claude exits.
    trap '${claude-tmux-indicator}/bin/claude-tmux-indicator off wrapper-exit-trap > /dev/null' EXIT

    # Enable telemetry and non-essential traffic since some features aren't enabled without
    # https://github.com/numtide/llm-agents.nix/issues/2811
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=""
    export DISABLE_NON_ESSENTIAL_MODEL_CALLS=""
    export DISABLE_TELEMETRY=""

    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
    export CLAUDE_CODE_NO_FLICKER=1 # alt-mode

    ${claude-code}/bin/claude --verbose "$@"
  '';

  nono-claude = pkgs.writeShellScriptBin "nono-claude" ''
    exec maybe --profile claude -- claude --allow-dangerously-skip-permissions "$@"
  '';

  # Toggle tmux window indicator when Claude is working (used by hooks).
  # Delegates title changes to the shared tmux-statusline utility.
  claude-tmux-indicator = pkgs.writeShellScriptBin "claude-tmux-indicator" ''
    CLAUDE_DIR="''${CLAUDE_ROOT:-.}"
    LOG_FILE="/tmp/claude-tmux-''${CLAUDE_DIR//\//-}.log"
    ACTION="$1"
    HOOK_NAME="''${2:-unknown}"

    # Log state change with timestamp
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') [$HOOK_NAME] $ACTION" >> "$LOG_FILE"

    run_statusline() {
      if ! TMUX_WINDOW_ID="$CLAUDE_TMUX_WINDOW" tmux-statusline "$@" > /dev/null 2>&1; then
        echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') [$HOOK_NAME] statusline-failed" >> "$LOG_FILE"
      fi
    }

    case "$ACTION" in
      on|permission|off)
        if [ -n "$TMUX" ] && [ -n "$CLAUDE_TMUX_WINDOW" ]; then
          case "$ACTION" in
            on)         run_statusline set '🔄';;
            permission) run_statusline set '🔐';;
            off)        run_statusline clear;;
          esac
        fi
        ;;
      *)
        # Unknown actions: log only, no title mutation
        ;;
    esac

    echo '{"continue":true,"suppressOutput":true}'
  '';

  generatedPaths = [
    "commands"
    "agents"
    "skills"
    "rules"
    "CLAUDE.md"
  ];

  localPaths = [
    "settings.json"
    "docs"
    "statusline.sh"
  ];

in
{
  home.file = (mkClaudeConfSymlinks localPaths) // (mkClaudeGeneratedSymlinks generatedPaths);

  home.packages = [
    claude-wrapped
    nono-claude

    claude-tmux-indicator

    pkgs.socat # required for sandboxing
    inputs'.ccmon.packages.default
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.bubblewrap # required for sandboxing
  ];

  dotfiles.nono.profiles.claude = {
    meta.version = "1.0.0";
    extends = "coding-agent";
    groups.include = [ "claude_code_macos" ];
    filesystem = {
      read = [ ];
      allow = [
        "$HOME/.claude"
        "$HOME/.claude.lock"
      ];
      read_file = [ ];
      write_file = [
      ];
    };
    network.block = false;
  };

  programs.fish.shellAbbrs = {
    cc = "claude";
  };
}
