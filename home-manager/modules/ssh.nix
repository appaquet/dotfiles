{ ... }:

{
  programs.ssh = {
    enable = true;

    matchBlocks = {
      github = {
        hostname = "github.com";
        user = "git";
        identityFile = "~/.ssh/github_id_rsa";
      };

      servapp = {
        hostname = "servapp.n3x.net";
        user = "appaquet";
        forwardAgent = true;
      };

      deskapp = {
        hostname = "deskapp.n3x.net";
        user = "appaquet";
        forwardAgent = true;
      };

      nixos = { # TODO: temp
        hostname = "nixos.n3x.net";
        user = "appaquet";
        forwardAgent = true;
      };

      exocore1 = {
        hostname = "exocore1.n3x.net";
        user = "root";
        port = 22943;
      };

      pihole = {
        hostname = "pihole.n3x.net";
        user = "root";
      };

      pikvm = {
        hostname = "pikvm.n3x.net";
        user = "root";
      };
    };
  };
}
