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

  # Override claude with overridden config dir. This prevents it to write its config to
  # ~/.claude.json so that we can mount ~/.claude as a volume in the container. We cannot mount the
  # config itself since it's swapped (probably to prevent corruption across instances).
  claude-wrapped = pkgs.writeShellScriptBin "claude" ''
    export CLAUDE_CONFIG_DIR="${config.home.homeDirectory}/.claude"
    exec ${pkgs.claude-code}/bin/claude "$@"
  '';

  # Creates a sandboxed version of claude that we can use to skip permissions. This isn't protecting
  # it from the network, but we can at least be sure it doesn't wipe the system and home.
  sandboxed-version = "5";
  claude-sandboxed = pkgs.writeShellApplication {
    name = "claude-sandboxed";

    bashOptions = [
      "errexit"
      "nounset"
    ]; # by default it adds pipefail, which is a pain

    runtimeInputs = with pkgs; [
      docker
      coreutils
    ];

    text = ''
      INIT_DIR=$(pwd)

      USER_UID=$(id -u)
      USER_GID=$(id -g)

      # Capture current PATH and create hash for image caching
      CURRENT_PATH="$PATH"
      PATH_HASH=$(echo "$CURRENT_PATH ${sandboxed-version}" | sha256sum | cut -c1-12)
      IMAGE_NAME="claude-alpine-$PATH_HASH"

      # Build an image with $PATH injected since it seems that claude from within the docker
      # container cannot correctly inherit the PATH from the env. Tried to debug launching claude
      # via fish manually and it couldn't do it.
      if ! docker images | grep -q "$IMAGE_NAME"; then
        echo "Building $IMAGE_NAME with current PATH..."
        cat << EOF > /tmp/Dockerfile.claude-"$PATH_HASH"
      FROM alpine:3.20
      RUN apk add --no-cache bash fish

      RUN echo 'export PATH="$CURRENT_PATH"' >> /etc/profile
      RUN echo 'export TERM="screen-256color"' >> /etc/profile
      RUN echo 'export COLORTERM="truecolor"' >> /etc/profile
      RUN echo 'export SHELL="${config.home.homeDirectory}/.nix-profile/bin/fish"' >> /etc/profile

      EOF
        docker build -f /tmp/Dockerfile.claude-"$PATH_HASH" -t "$IMAGE_NAME" /tmp
        rm /tmp/Dockerfile.claude-"$PATH_HASH"
      fi

      # Use ENTRYPOINT if defined, otherwise default to wrapped claude
      if [ -n "''${ENTRYPOINT:-}" ]; then
        EXEC_CMD="$ENTRYPOINT"
      else
        EXEC_CMD="${claude-wrapped}/bin/claude"
      fi

      docker run --rm -it \
        --hostname "$(hostname)" \
        --user "$USER_UID:$USER_GID" \
        --workdir "$INIT_DIR" \
        --volume "$INIT_DIR:$INIT_DIR" \
        --volume "${config.home.homeDirectory}:${config.home.homeDirectory}:ro" \
        --volume "${config.home.homeDirectory}/.claude:${config.home.homeDirectory}/.claude:rw" \
        --volume "${config.home.homeDirectory}/.cache:${config.home.homeDirectory}/.cache:rw" \
        --volume "/nix:/nix:ro" \
        --volume "/run:/run:ro" \
        --env "PATH=$CURRENT_PATH" \
        --env "HOME=${config.home.homeDirectory}" \
        --env "SHELL=${config.home.homeDirectory}/.nix-profile/bin/fish" \
        --env "TERM=screen-256color" \
        --env "COLORTERM=truecolor" \
        --env "CLAUDE_CONFIG_DIR" \
        "$IMAGE_NAME" \
        "$EXEC_CMD" "$@"
    '';
  };
in
{
  home.file = mkClaudeConfSymlinks [
    "settings.json"
    "commands"
    "docs"
    "CLAUDE.md"
  ];

  home.packages = [
    claude-wrapped
    claude-sandboxed
  ];
}
