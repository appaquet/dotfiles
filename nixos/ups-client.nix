{ pkgs, secrets, ... }:

{
  power.ups = {
    enable = true;
    mode = "netclient";

    users.monuser = {
      upsmon = "primary";
      passwordFile = secrets.upsPw;
    };

    upsmon = {
      settings = {
        MINSUPPLIES = 1;
        SHUTDOWNCMD = "${pkgs.systemd}/bin/shutdown now";

        # Don't spam WALL
        NOTIFYFLAG = [
          [
            "COMMOK"
            "SYSLOG"
          ]
          [
            "COMMBAD"
            "SYSLOG"
          ]
          [
            "NOCOMM"
            "SYSLOG"
          ]
          [
            "NOPARENT"
            "SYSLOG"
          ]
        ];
      };

      monitor.main = {
        system = "ups@192.168.0.20";
        user = "monuser";
        passwordFile = secrets.upsPw;
      };
    };
  };
}
