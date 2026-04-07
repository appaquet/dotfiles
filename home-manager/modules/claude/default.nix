{
  pkgs,
  config,
  lib,
  inputs',
  ...
}:

let
  # We symlink here since it may be change by claude and I want to iterate
  mkClaudeConfSymlinks =
    paths:
    lib.listToAttrs (
      map (path: {
        name = ".claude/${path}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/home-manager/modules/claude/${path}";
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

    # Capture tmux window ID so indicator targets correct window even if user switches
    if [ -n "$TMUX" ]; then
      export CLAUDE_TMUX_WINDOW=$(${pkgs.tmux}/bin/tmux display-message -p '#{window_id}')
    fi

    # Clear tmux indicator on start (in case previous session was killed) and exit
    ${claude-tmux-indicator}/bin/claude-tmux-indicator off wrapper-start > /dev/null
    trap '${claude-tmux-indicator}/bin/claude-tmux-indicator off wrapper-exit-trap > /dev/null' EXIT

    # Enable telemetry and non-essential traffic since some features aren't enabled without
    # https://github.com/numtide/llm-agents.nix/issues/2811
    export CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=""
    export DISABLE_NON_ESSENTIAL_MODEL_CALLS=""
    export DISABLE_TELEMETRY=""

    export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1
    export CLAUDE_CODE_NO_FLICKER=1 # alt-mode
    #export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1

    ${claude-code}/bin/claude "$@"
  '';

  # Utility to list project docs (avoids shell expansion issues in skill commands)
  claude-proj-docs = pkgs.writeShellScriptBin "claude-proj-docs" ''
    proj="''${CLAUDE_ROOT:-$(pwd)}/proj"
    if [ -d "$proj" ]; then
      abs=$(readlink -f "$proj")
      echo "proj/ ($abs) files:"
      ls "$proj/"
    else
      echo "No project files"
    fi
  '';

  # Toggle tmux window indicator when Claude is working (used by hooks)
  claude-tmux-indicator = pkgs.writeShellScriptBin "claude-tmux-indicator" ''
    CLAUDE_DIR="''${CLAUDE_ROOT:-.}"
    LOG_FILE="/tmp/claude-tmux-''${CLAUDE_DIR//\//-}.log"
    ACTION="$1"
    HOOK_NAME="''${2:-unknown}"

    # Log state change with timestamp
    echo "$(date '+%Y-%m-%d %H:%M:%S.%3N') [$HOOK_NAME] $ACTION" >> "$LOG_FILE"

    if [ -z "$TMUX" ] || [ -z "$CLAUDE_TMUX_WINDOW" ]; then
      echo '{"continue":true,"suppressOutput":true}'
      exit 0
    fi

    WORKING=" 🔄"
    PERMISSION=" 🔐"
    CURRENT=$(${pkgs.tmux}/bin/tmux display-message -t "$CLAUDE_TMUX_WINDOW" -p '#{window_name}')
    BASE="''${CURRENT%$WORKING}"
    BASE="''${BASE%$PERMISSION}"

    case "$ACTION" in
      on)
        [[ "$CURRENT" != *"$WORKING" ]] && ${pkgs.tmux}/bin/tmux rename-window -t "$CLAUDE_TMUX_WINDOW" "$BASE$WORKING"
        ;;
      permission)
        ${pkgs.tmux}/bin/tmux rename-window -t "$CLAUDE_TMUX_WINDOW" "$BASE$PERMISSION"
        ;;
      off)
        ${pkgs.tmux}/bin/tmux rename-window -t "$CLAUDE_TMUX_WINDOW" "$BASE"
        ;;
    esac

    echo '{"continue":true,"suppressOutput":true}'
  '';

in
{
  home.file = mkClaudeConfSymlinks [
    "settings.json"
    "commands"
    "docs"
    "agents"
    "skills"
    "CLAUDE.md"
    "statusline.sh"
  ];

  home.packages = [
    claude-wrapped
    claude-proj-docs
    claude-tmux-indicator
    pkgs.socat # required for sandboxing
    inputs'.ccmon.packages.default
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.bubblewrap # required for sandboxing
  ];
}
