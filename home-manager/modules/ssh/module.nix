{
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.ssh.agent;
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
  options.dotfiles.ssh.agent = {
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
      # Non-interactive sessions (ssh host cmd) never take over the agent, except
      # herdr-core bridges: they are a connection from another machine, like a
      # login. fish -c keeps its command in its own args, so the bridge is
      # recognized there: its bootstrap, then "exec $p connect".
      set -l slot_incoming "$SSH_AUTH_SOCK"
      set -l slot_init init
      if not status is-interactive
        set -l slot_args (ps -o args= -p $fish_pid 2>/dev/null | string collect)
        set -q SSH_CONNECTION
        and string match -qr '(?s)herdr-core.*\bconnect\b' -- "$slot_args"
        or set -a slot_init --non-interactive
      end
      if ${lib.getExe slotHelper} $slot_init
        set -gx SSH_AUTH_SOCK "$HOME/.ssh/ssh_auth_sock"
      else
        set -e SSH_AUTH_SOCK
      end

      # A non-interactive ssh session keeps its own raw forwarded socket: a
      # command run over ssh uses the agent forwarded to it, and the shared slot
      # may not exist on hosts without a local agent. Nested shells inherit the
      # slot symlink and keep it.
      if not status is-interactive; and set -q SSH_CONNECTION; and test -S "$slot_incoming"; and not test -L "$slot_incoming"
        set -gx SSH_AUTH_SOCK "$slot_incoming"
      end

      # Release a registered forwarded agent from the stack when its shell ends:
      # a bridge's shell ends with its connection, an interactive login's on
      # exit (SIGHUP is fish's job, best effort). Only raw sshd sockets: a
      # symlink inherited from a parent shell is shared and must survive this exit.
      if not contains -- --non-interactive $slot_init; and set -q SSH_CONNECTION; and test -S "$slot_incoming"; and not test -L "$slot_incoming"
        set -g __ssh_agent_slot_incoming "$slot_incoming"
        function __ssh_agent_slot_release --on-event fish_exit
          ${lib.getExe slotHelper} release "$__ssh_agent_slot_incoming" >/dev/null 2>&1
        end
      end
    '';
  };
}
