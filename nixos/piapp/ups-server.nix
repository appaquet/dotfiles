{ pkgs, secrets, ... }:
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

  # Send a WOL when we have enough runtime on UPS every 5m
  systemd.timers.ups-monitor = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5m";
      OnUnitActiveSec = "5m";
      Unit = "ups-monitor.service";
    };
  };
  systemd.services.ups-monitor = {
    serviceConfig = {
      Type = "oneshot";
      User = "root";
    };
    script = ''
      status=$(${pkgs.nut}/bin/upsc ups ups.status 2>&1) || true
      runtime=$(${pkgs.nut}/bin/upsc ups battery.runtime 2>&1) || true

      if [[ "$runtime" =~ ^[0-9]+$ ]] && [ "$runtime" -ge 1000 ]; then
        slug="ups-runtime"
        if [[ "$status" == "OL"* ]]; then
          echo "Waking up servers"
          ${pkgs.wol}/bin/wol 32:2F:E6:AB:B2:E7 # servapp
          ${pkgs.wol}/bin/wol 8C:AE:4C:DD:5F:D0 # nasapp (2.5G)
          ${pkgs.wol}/bin/wol 00:11:32:b4:d0:c7 # nasapp (1G)
        fi
      else
        echo "Not enough runtime left, skipping WOL"
      fi
    '';
>>>>>>> c076d6c (servapp: auto wol when ups is back)
  };
}
