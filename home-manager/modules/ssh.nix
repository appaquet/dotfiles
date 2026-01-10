{ config, ... }:

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

  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "github.com" = {
        identityFile = [
          "~/.ssh/github_1pw.pub"
          config.sops.secrets."ssh/github_breakglass".path
        ];
      };

      "servapp.n3x.net" = {
        forwardAgent = true;
        identityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "deskapp.n3x.net" = {
        forwardAgent = true;
        identityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "piapp.n3x.net" = {
        forwardAgent = true;
        identityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "vps.n3x.net" = {
        port = 22222;
        forwardAgent = true;
        identityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "piups.n3x.net" = {
        forwardAgent = true;
        identityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "piprint.n3x.net" = {
        forwardAgent = true;
        identityFile = [
          "~/.ssh/ssh_1pw.pub"
          config.sops.secrets."ssh/ssh_breakglass".path
        ];
      };

      "pihole.n3x.net" = {
        user = "root";
      };

      "pikvm.n3x.net" = {
        user = "root";
      };
    };
  };
}
