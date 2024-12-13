{ pkgs, ... }:
{
  home.packages = with pkgs; [
    exo
  ];

  systemd.user.services.exocore = {
    Unit = {
      Description = "Exocore daemon";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
    Service = {
      ExecStart = "${pkgs.writeShellScript "watch-store" ''
        #!/run/current-system/sw/bin/bash
        cd /home/appaquet/Projects/exomind/exocore
        ${pkgs.exo}/bin/exo -d local_conf daemon
      ''}";
      WorkingDirectory = "/home/appaquet/Projects/exomind/exocore";
      Restart = "on-failure";
      RestartSec = "5s";
    };
  };
}
