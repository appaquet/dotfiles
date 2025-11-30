{ secrets, ... }:
{
  power.ups = {
    enable = true;
    mode = "netserver"; # "netserver" exposes UPS data to network clients

    ups = {
      # Servers UPS
      # "ups" is expected by Synology
      ups = {
        description = "CyberPower CP1500 AVR UPS";
        driver = "usbhid-ups";
        port = "auto";

        directives = [
          "vendorid = 0764"
          "productid = 0501"
          "serial = CTHLQ2000774"

          # Override low bat thresholds to 30% or 10m left.
          # Check `upsc ups` to see all values
          "override.battery.charge.low = 10" # default 10%
          "override.battery.charge.warning = 50" # default 20%
          "override.battery.runtime.low = 300" # default 300, but it stops if desktop draws too much
          "ignorelb" # ignore ups own low battery signal
        ];
      };

      # Network UPS
      network = {
        description = "CyberPower CP1500 AVR UPS";
        driver = "usbhid-ups";
        port = "auto";

        directives = [
          "vendorid = 0764"
          "productid = 0501"
          "serial = CTHGP2001888"
        ];
      };
    };

    upsd.listen = [
      {
        address = "0.0.0.0";
        port = 3493;
      }
    ];

    users.monuser = {
      upsmon = "primary";
      passwordFile = secrets.upsPw;
    };

    upsmon = {
      monitor = {
        servers = {
          system = "ups";
          type = "primary";
          user = "monuser";
          passwordFile = secrets.upsPw;
        };

        network = {
          system = "network";
          type = "primary";
          user = "monuser";
          passwordFile = secrets.upsPw;
        };
      };

      settings = {
        MINSUPPLIES = 1;
        RUN_AS_USER = "root";
        SHUTDOWNCMD = "systemctl restart upsd"; # don't restart pi, just upsd
      };
    };
  };
}
