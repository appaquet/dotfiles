{ pkgs, secrets, ... }:

{
  #MONITOR ups@192.168.2.90 1 monuser secret slave # not so secrets... default for synology
  #MINSUPPLIES 1 # Minimum number of power supplies
  #SHUTDOWNCMD "/sbin/shutdown -h +0"
  #POLLFREQ 5 # Poll every 5 seconds
  #POLLFREQALERT 5 # Same as POLLFREQ
  #HOSTSYNC 15 # Sync with UPS every 15 minutes
  #DEADTIME 15 # UPS is dead after 15 minutes
  #POWERDOWNFLAG /etc/killpower # File to touch to shutdown the system
  #NOTIFYFLAG COMMOK       SYSLOG # Don't notify when we go back to power
  #NOTIFYFLAG COMMBAD      SYSLOG
  #NOTIFYFLAG NOCOMM       SYSLOG # Notify when we lose communications
  #NOTIFYFLAG NOPARENT     SYSLOG
  #RBWARNTIME 43200
  #NOCOMMWARNTIME 300
  #FINALDELAY 5

  power.ups = {
    enable = true;
    mode = "netclient";

    users.monuser = {
      upsmon = "primary";
      passwordFile = secrets.deskapp.nasappUpsPw;
    };

    upsmon = {
      settings = {
        MINSUPPLIES = 1; # Minimum number of power supplies
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
        passwordFile = secrets.deskapp.nasappUpsPw;
      };
    };
  };
}
