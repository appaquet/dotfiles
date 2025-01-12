{ secrets, ... }:
let
  vendorId = "0764";
  productId = "0501";
in
{
  power.ups = {
    enable = true;
    mode = "netserver";

    # Adapted from: https://github.com/bercribe/nixos/blob/71c3fe9b382f6827e905f26702b90e78d1489517/modules/systems/hardware/ups/server.nix#L21
    ups.ups = {
      # ups name "ups" expect by synology
      description = "CyberPower CP1500 AVR UPS";
      driver = "usbhid-ups";
      port = "auto";

      directives = [
        "vendorid = ${vendorId}"
        "productid = ${productId}"

        # Override low bat thresholds to 50% or 300s left.
        #"override.battery.charge.low = 50"
        #"override.battery.runtime.low = 300"
        #"ignorelb"
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
