{
  lib,
  config,
  ...
}:

let
  cfg = config.dotfiles.ssh-agent;
  stableSocketPath = "$HOME/.ssh/ssh_auth_sock";
in
{
  options.dotfiles.ssh-agent = {
    enable = lib.mkEnableOption "SSH agent socket persistence for tmux";

    defaultSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to SSH agent socket (e.g., 1Password)";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fish.shellInit = lib.mkAfter ''
      # SSH agent socket persistence for tmux sessions
      # Creates a stable symlink to the configured socket
      set -l stable_socket "${stableSocketPath}"

      ${lib.optionalString (cfg.defaultSocket != null) ''
        set -l default_socket "${cfg.defaultSocket}"
        if test -S "$default_socket"
            mkdir -p (dirname "$stable_socket")
            ln -sf "$default_socket" "$stable_socket"
        end
      ''}

      ${lib.optionalString (cfg.defaultSocket == null) ''
        if set -q SSH_AUTH_SOCK; and test "$SSH_AUTH_SOCK" != "$stable_socket"; and test -S "$SSH_AUTH_SOCK"
            mkdir -p (dirname "$stable_socket")
            ln -sf "$SSH_AUTH_SOCK" "$stable_socket"
        end
      ''}

      if test -S "$stable_socket"
          set -gx SSH_AUTH_SOCK "$stable_socket"
      end
    '';
  };
}
