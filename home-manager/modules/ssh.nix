{ ... }:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      "servapp.n3x.net" = {
        forwardAgent = true;
      };

      "deskapp.n3x.net" = {
        forwardAgent = true;
      };

      "nixos.n3x.net" = { # TODO: temp
        forwardAgent = true;
      };

      "exocore1.n3x.net" = {
        user = "root";
        port = 22943;
      };

      "pihole.n3x.net" = {
        user = "root";
      };

      "pikvm.n3x.net" = {
        user = "root";
      };

      "github.com" = {
        identityFile = "~/.ssh/github_id_rsa";
      };

      "*.n3x.net" = {
        user = "appaquet";
      };
    };
  };
}
