{
  pkgs,
  config,
  lib,
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

  # Override claude with overridden config dir. This prevents it from writing its config to
  # ~/.claude.json so that we can keep all claude config in ~/.claude.
  claude-wrapped = pkgs.writeShellScriptBin "claude" ''
    # Warn if not in a git repo
    if [ ! -d ".git" ]; then
      echo -e "\e[31mWARNING: No .git, are you at the root of a project?\e[0m" >&2
      sleep 5
    fi

    export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.claude"
    export CLAUDE_ROOT="''${CLAUDE_PROJECT_DIR:-$(pwd)}"

    # Clear tmux indicator on start (in case previous session was killed) and exit
    ${claude-tmux-indicator}/bin/claude-tmux-indicator off
    trap '${claude-tmux-indicator}/bin/claude-tmux-indicator off' EXIT
    ${claude-code}/bin/claude "$@"
  '';

  # Utility to list project docs (avoids shell expansion issues in skill commands)
  claude-proj-docs = pkgs.writeShellScriptBin "claude-proj-docs" ''
    if [ -d "''${CLAUDE_ROOT:-$(pwd)}/proj" ]; then
      ls "''${CLAUDE_ROOT:-$(pwd)}/proj/"
    else
      echo "No project files"
    fi
  '';

  # Toggle tmux window indicator when Claude is working (used by hooks)
  claude-tmux-indicator = pkgs.writeShellScriptBin "claude-tmux-indicator" ''
    [ -z "$TMUX" ] && exit 0

    WORKING=" 🔄"
    PERMISSION=" 🔐"
    CURRENT=$(${pkgs.tmux}/bin/tmux display-message -p '#{window_name}')
    BASE="''${CURRENT%$WORKING}"
    BASE="''${BASE%$PERMISSION}"

    case "$1" in
      on)
        [[ "$CURRENT" != *"$WORKING" ]] && ${pkgs.tmux}/bin/tmux rename-window "$BASE$WORKING"
        ;;
      permission)
        ${pkgs.tmux}/bin/tmux rename-window "$BASE$PERMISSION"
        ;;
      off)
        ${pkgs.tmux}/bin/tmux rename-window "$BASE"
        ;;
    esac
  '';

  # Creates a sandboxed version of claude that we can use to skip permissions. This isn't protecting
  # it from the network, but we can at least be sure it doesn't wipe the system and home.
  sandboxed-version = "12";
  claude-sandboxed = pkgs.writeShellApplication {
    name = "claude-sandboxed";

    # Disable most of the checks since we may have unset vars
    bashOptions = [
      "errexit"
    ];
    checkPhase = "";

    runtimeInputs = with pkgs; [
      docker
      coreutils
    ];

    text = ''
      INIT_DIR=$(pwd)

      USER_UID=$(id -u)
      USER_GID=$(id -g)

      # Build an image with $PATH injected since it seems that claude from within the docker
      # container cannot correctly inherit the PATH from the env. Tried to debug launching claude
      # via fish manually and it couldn't do it. Also force rebuild if the derivation changes or
      # manually forced.
      CURRENT_PATH="$PATH"
      ENV_VARS_HASH="${builtins.hashString "sha256" (builtins.concatStringsSep "," passthrough-env-vars)}"
      PATH_HASH=$(echo "$CURRENT_PATH ${sandboxed-version} ${claude-wrapped}/bin/claude $ENV_VARS_HASH" | sha256sum | cut -c1-12)
      IMAGE_NAME="claude-alpine-$PATH_HASH"
      if ! docker images | grep -q "$IMAGE_NAME"; then
        echo "Building $IMAGE_NAME with current PATH..."
        cat << EOF > /tmp/Dockerfile.claude-"$PATH_HASH"
      FROM alpine:latest
      RUN apk add --no-cache bash fish

      ${mkDockerProfileExports passthrough-env-vars}

      EOF
        docker build -f /tmp/Dockerfile.claude-"$PATH_HASH" -t "$IMAGE_NAME" /tmp
        rm /tmp/Dockerfile.claude-"$PATH_HASH"
      fi

      # Use ENTRYPOINT if defined, otherwise default to wrapped claude
      if [ -n "''${ENTRYPOINT:-}" ]; then
        EXEC_CMD="$ENTRYPOINT"
        ARGS=("$@")
      else
        EXEC_CMD="${claude-wrapped}/bin/claude"
        ARGS=(--dangerously-skip-permissions --add-dir "${config.home.homeDirectory}" "$@")
      fi

      docker run --rm -it \
        --hostname "$(hostname)" \
        --user "$USER_UID:$USER_GID" \
        --workdir "$INIT_DIR" \
        --volume "$INIT_DIR:$INIT_DIR" \
        --volume "${config.home.homeDirectory}:${config.home.homeDirectory}:ro" \
        --volume "${config.home.homeDirectory}/.claude:${config.home.homeDirectory}/.claude:rw" \
        --volume "${config.home.homeDirectory}/.cache:${config.home.homeDirectory}/.cache:rw" \
        --volume "${config.home.homeDirectory}/.cargo:${config.home.homeDirectory}/.cargo:rw" \
        --volume "${config.home.homeDirectory}/.npm:${config.home.homeDirectory}/.npm:rw" \
        --volume "${config.home.homeDirectory}/go:${config.home.homeDirectory}/go:rw" \
        --volume "${config.home.homeDirectory}/dotfiles/home-manager/modules/claude:${config.home.homeDirectory}/dotfiles/home-manager/modules/claude:rw" \
        --volume "/etc/nix:/etc/nix:ro" \
        --volume "/etc/static/nix:/etc/static/nix:ro" \
        --volume "/nix:/nix:ro" \
        --volume "/run:/run:ro" \
        --env "CLAUDE_CONFIG_DIR" \
        --network host \
        --pid host \
        ${mkDockerEnvArgs passthrough-env-vars} \
        "$IMAGE_NAME" \
        "$EXEC_CMD" ''${ARGS[@]}
    '';
  };
  # Environment variables to pass through to the sandboxed container
  passthrough-env-vars = [
    "HOME"
    "PATH"
    "TERM"
    "COLORTERM"
    "SHELL"
    "GOROOT"
    "GOBIN"
    "MISE_SHELL"
    "NIX_PROFILES"
    "NIX_PATH"
    "LANG"
    "USER"
    "LOGNAME"
    "BACKEND_DIR"
    "DATA_DIR"
    "TMP_DATA_DIR"
    "HF_ENVIRONMENT"
    "AUTH_PROVIDER"
    "LOCAL_IP"
    "RUST_LOG"
    "RUST_BACKTRACE"
    "PYTHONPATH"
    "PYTHON_LD_LIBRARY_PATH"
    "LD_LIBRARY_PATH"
    "PKG_CONFIG_PATH"
    "CPATH"
    "LIBRARY_PATH"
  ];
  mkDockerProfileExports =
    vars:
    "RUN "
    + lib.concatMapStringsSep " && \\\n    " (
      var: "echo 'export ${var}=\"\$${var}\"' >> /etc/profile"
    ) vars;
  mkDockerEnvArgs = vars: lib.concatMapStringsSep " \\\n        " (var: "--env \"${var}\"") vars;

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
    claude-sandboxed
    claude-wrapped
    claude-proj-docs
    claude-tmux-indicator
    pkgs.socat # required for sandboxing
  ]
  ++ lib.optionals pkgs.stdenv.isLinux [
    pkgs.bubblewrap # required for sandboxing
  ];
}
