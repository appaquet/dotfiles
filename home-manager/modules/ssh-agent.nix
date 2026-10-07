{
  lib,
  config,
  ...
}:

let
  cfg = config.dotfiles.ssh-agent;
  primarySlot = "$HOME/.ssh/ssh_auth_sock";
  backupSlot = "$HOME/.ssh/ssh_auth_sock_b";
  # Local default socket, empty on hosts without a local agent
  defaultSocket = lib.optionalString (cfg.defaultSocket != null) cfg.defaultSocket;
in
{
  options.dotfiles.ssh-agent = {
    enable = lib.mkEnableOption "SSH agent socket slot switching for tmux socket persistence";

    defaultSocket = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Absolute path to the local default SSH agent socket (e.g. 1Password); null on hosts without a local agent";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.fish.shellInit = lib.mkAfter ''
      # SSH agent socket slot switching
      # Two stable symlinks: the primary (always exported as SSH_AUTH_SOCK)
      # and the backup (previous primary, may be dead). Every shell start
      # probes candidates and re-points the primary:
      # incoming session socket -> backup -> local default.
      # Note: set -l is scoped to its enclosing block in fish, so state is
      # declared here and reassigned with plain set
      set -l D "${defaultSocket}"
      set -l P
      set -l B
      set -l I /dev/null
      set -l winner

      # live = the agent protocol answers (0: has keys, 1: live but empty).
      # A file check alone is insufficient: orphan socket files pass test -S
      function ssh_sock_live
        test -S $argv[1]; or return 1
        set -l out (SSH_AUTH_SOCK=$argv[1] ssh-add -l 2>&1)
        switch $status
          case 0
            return 0
          case 1
            string match -q '*no identities*' $out; and return 0
          end
          return 1
      end

      # Re-point a slot atomically: ln -sf is unlink+create
      function slot_set
        ln -sf $argv[2] "$argv[1].tmp"
        mv -f "$argv[1].tmp" $argv[1]
      end

      set -l primary "${primarySlot}"
      set -l backup "${backupSlot}"
      # Slots self-heal: absent or tampered slots are (re)created, absent target = /dev/null
      if not test -L $primary
        slot_set $primary /dev/null
      end
      if not test -L $backup
        slot_set $backup /dev/null
      end

      set P (readlink $primary)
      set B (readlink $backup)
      # I = the incoming session socket; /dev/null (a dead value) when absent
      if set -q SSH_AUTH_SOCK
        set I $SSH_AUTH_SOCK
      end

      # Slot paths are never candidates: a tmux server's env carries the slot
      # path, and treating it as a connection would self-link the slot
      if test $I = $primary; or test $I = $backup
        set I /dev/null
      end

      set winner $P
      if ssh_sock_live $I; and test $I != $P
        # New live connection wins (last action); old primary demoted to backup
        set winner $I
        if test -n $P; and test $P != /dev/null
          slot_set $backup $P
        end
      else if not ssh_sock_live $P
        # Primary dead: promote backup, then local default
        if ssh_sock_live $B
          set winner $B
        else if test -n $D; and ssh_sock_live $D
          set winner $D
        end
      end

      if test -n $winner; and test $winner != $P
        # Coming from the default: keep the displaced primary as backup
        if test $winner = $D
          if test -n $P; and test $P != /dev/null
            slot_set $backup $P
          end
        end
        slot_set $primary $winner
      end

      set -gx SSH_AUTH_SOCK $primary
    '';
  };
}
