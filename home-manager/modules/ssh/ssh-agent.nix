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
    enable = lib.mkEnableOption "shared SSH agent session stack for persistent terminal sessions";

    defaultSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the local 1Password SSH agent socket; null on hosts using only forwarding";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ slotHelper ];

    programs.fish.shellInit = lib.mkAfter ''
      # Push incoming forwarding before normalizing persistent sessions.
      # Non-interactive sessions (ssh host cmd) never take over the agent.
      set -l slot_incoming "$SSH_AUTH_SOCK"
      set -l slot_init init
      status is-interactive; or set -a slot_init --non-interactive
      if ${lib.getExe slotHelper} $slot_init
        set -gx SSH_AUTH_SOCK "$HOME/.ssh/ssh_auth_sock"
      else
        set -e SSH_AUTH_SOCK
      end

      # Release this session's forwarded agent from the stack when it ends
      # (exit or SIGHUP on disconnect). Only raw sshd sockets: herdr's stable
      # agent symlink is shared by all panes and must survive a pane exit.
      if status is-interactive; and set -q SSH_CONNECTION; and test -S "$slot_incoming"; and not test -L "$slot_incoming"
        set -g __ssh_agent_slot_incoming "$slot_incoming"
        function __ssh_agent_slot_release --on-event fish_exit
          ${lib.getExe slotHelper} release "$__ssh_agent_slot_incoming" >/dev/null 2>&1
        end
      end
    '';
  };
}
