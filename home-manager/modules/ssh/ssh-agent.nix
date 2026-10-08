{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.ssh-agent;
  slotHelper = pkgs.writeShellApplication {
    name = "ssh-agent-slot";

    runtimeInputs = [
      pkgs.coreutils
      pkgs.openssh
    ];

    text = ''
      local_socket=${lib.escapeShellArg (if cfg.defaultSocket == null then "" else cfg.defaultSocket)}
      ${builtins.readFile ./ssh-agent-slot.sh}
    '';
  };
in
{
  options.dotfiles.ssh-agent = {
    enable = lib.mkEnableOption "shared SSH agent slots for persistent terminal sessions";

    defaultSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the local 1Password SSH agent socket; null on hosts using only forwarding";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ slotHelper ];

    programs.fish.shellInit = lib.mkAfter ''
      # Register incoming forwarding before normalizing persistent sessions.
      if ${lib.getExe slotHelper} init
        set -gx SSH_AUTH_SOCK "$HOME/.ssh/ssh_auth_sock"
      else
        set -e SSH_AUTH_SOCK
      end
    '';

    # Mid-window fallback: slots are only re-pointed at shell start, so if
    # the primary's agent dies before the next shell, probe the responsive
    # one. Primary must render before backup (first match wins; entryAfter).
    # IdentityAgent picks the identity source only; ForwardAgent still
    # forwards the env slot socket.
    programs.ssh.settings = {
      "agent-fallback-primary" = {
        header = "Match exec \"ssh-agent-slot probe $HOME/.ssh/ssh_auth_sock\"";
        IdentityAgent = "~/.ssh/ssh_auth_sock";
      };

      "agent-fallback-backup" = lib.hm.dag.entryAfter [ "agent-fallback-primary" ] {
        header = "Match exec \"ssh-agent-slot probe $HOME/.ssh/ssh_auth_sock_b\"";
        IdentityAgent = "~/.ssh/ssh_auth_sock_b";
      };
    };
  };
}
