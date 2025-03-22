{ secrets, ... }:
let
  # Heavily adapted from: https://github.com/bercribe/nixos/blob/71c3fe9b382f6827e905f26702b90e78d1489517/modules/systems/hardware/ups/server.nix#L21
  vendorId = "0764";
  productId = "0501";
in
{
  power.ups = {
    enable = true;
    mode = "netserver";

    ups.ups = {
      # ups name "ups" expect by synology
      description = "CyberPower CP1500 AVR UPS";
      driver = "usbhid-ups";
      port = "auto";

      directives = [
        "vendorid = ${vendorId}"
        "productid = ${productId}"

        # Override low bat thresholds to 30% or 10m left.
        # Check `upsc ups` to see all values
        "override.battery.charge.low = 10" # default 10%
        "override.battery.charge.warning = 50" # default 20%
        "override.battery.runtime.low = 240" # default 300, but it stops if desktop draws too much
        "ignorelb"
      ];
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
      monitor.cyberpower = {
        system = "ups";
        type = "primary";
        user = "monuser"; # expected by synology
        passwordFile = secrets.upsPw;
      };

      settings = {
        MINSUPPLIES = 1;
        RUN_AS_USER = "root";
        SHUTDOWNCMD = "systemctl restart upsd";
      };
    };
  };
}
