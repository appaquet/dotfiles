{ ... }:

{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    matchBlocks = {
      "servapp.n3x.net" = {
        forwardAgent = true;
      };

      "deskapp.n3x.net" = {
        forwardAgent = true;
      };

      "pihole.n3x.net" = {
        user = "root";
      };

      "pikvm.n3x.net" = {
        user = "root";
      };

      "vps.n3x.net" = {
        port = 22222;
        forwardAgent = true;
      };

      "github.com" = {
        identityFile = "~/.ssh/github_id_rsa";
      };
    };
  };
}
