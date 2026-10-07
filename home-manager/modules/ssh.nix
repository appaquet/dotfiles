{ config, lib, ... }:

{
  sops.secrets = {
    "ssh/github_breakglass" = {
      sopsFile = config.sops.secretsFiles.common;
    };
    "ssh/ssh_breakglass" = {
      sopsFile = config.sops.secretsFiles.common;
    };
  };

  home.file.".ssh/github_1pw.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEGTenIFYqvhJQe8ibdZvvjvdPJVimkTmKe14MlZgMR7 github 1pw";
  home.file.".ssh/ssh_1pw.pub".text =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHNXBK1YpLeuIKx+tpVLpZOhKbMcqLeMx15SvcBG0jcR ssh 1pw";

  # Slot liveness probe for the fallback blocks below: exit 0 if the agent
  # at $1 is alive (answers a key list or "no identities"), 1 if dead.
  home.file.".ssh/agent-probe" = {
    text = ''
      #!/bin/sh
      slot=$1
      rc=1
      SSH_AUTH_SOCK="$slot" ssh-add -l >/dev/null 2>&1 && rc=0
      if [ $rc -eq 1 ]; then
        SSH_AUTH_SOCK="$slot" ssh-add -l 2>&1 | grep -q 'no identities' && rc=0
      fi
      exit $rc
    '';
    executable = true;
  };

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    settings = {
      # Mid-window fallback: slots are only re-pointed at shell start, so if
      # the primary's agent dies before the next shell, probe the live one.
      # Primary must render before backup (first match wins; entryAfter).
      # IdentityAgent picks the identity source only; ForwardAgent still
      # forwards the env slot socket.
      "agent-fallback-primary" = {
        header = "Match exec \"$HOME/.ssh/agent-probe $HOME/.ssh/ssh_auth_sock\"";
        IdentityAgent = "~/.ssh/ssh_auth_sock";
      };

      "agent-fallback-backup" = lib.hm.dag.entryAfter [ "agent-fallback-primary" ] {
        header = "Match exec \"$HOME/.ssh/agent-probe $HOME/.ssh/ssh_auth_sock_b\"";
        IdentityAgent = "~/.ssh/ssh_auth_sock_b";
      };

      "github.com" = {
        IdentityFile = [
          "~/.ssh/github_1pw.pub"
          config.sops.secrets."ssh/github_breakglass".path
        ];
      };

      "mbpapp.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "servapp.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "deskapp.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "exapp.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "piapp.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "vps.n3x.net" = {
        Port = 22222;
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "piups.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "piprint.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "utm.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "sparkbud1.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "sparkbud2.n3x.net" = {
        ForwardAgent = true;
        IdentityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "pihole.n3x.net" = {
        User = "root";
      };

      "pikvm.n3x.net" = {
        User = "root";
      };
    };
  };
}
