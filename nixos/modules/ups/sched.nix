# Adapted from https://github.com/codgician/serenitea-pot/blob/3afbd8108779fb4983f80ffdd38dd319454fe334/modules/nixos/power/ups/default.nix

{
  config,
  pkgs,
  ...
}:

let
  cfg = config.power.myUps;

  upssched-cmd = pkgs.writeShellApplication {
    name = "upssched-cmd";

    runtimeInputs = with pkgs; [
      nut
      util-linux
    ];

    text = ''
      log_event () {
        logger -t upssched-cmd "$1"
        echo "$1" >> /tmp/upssched.log
      }

      case $1 in
        upsgone)
          log_event "UPS GONE"
          ;;
        replacebat)
          log_event "UPS REPLACE BAT"
          ;;
        lowbat)
          status=$(cat /tmp/upssched-status 2>/dev/null || echo "unknown")
          if [ "$status" = "onbatt" ]; then
            log_event "UPS LOW BAT, SHUTTING DOWN"
            upsmon -c fsd
          else
            log_event "UPS LOW BAT, BUT NOT ON BATTERY (status: $status), NOT SHUTTING DOWN"
          fi
          ;;
        onbatt)
          log_event "UPS ON BAT"
          echo "onbatt" > /tmp/upssched-status
          ;;
        online)
          log_event  "UPS ONLINE"
          echo "online" > /tmp/upssched-status
          ;;

        timeonbatt)
          log_event "UPS ON BAT FOR TOO LONG - SHUTTING DOWN"
          upsmon -c fsd
          ;;
        timeonline)
          log_event "UPS BACK ONLINE"
          ;;
        *)
          log_event "Unrecognized command: $1"
          ;;
      esac
    '';
  };
in
pkgs.writeText "upssched.conf" ''
  CMDSCRIPT ${upssched-cmd}/bin/upssched-cmd
  PIPEFN /var/lib/nut/upssched.pipe
  LOCKFN /var/lib/nut/upssched.lock
  AT ONBATT * EXECUTE onbatt
  AT ONLINE * EXECUTE online
  AT ONBATT * START-TIMER timeonbatt ${toString cfg.shutdownDelay}
  AT ONLINE * CANCEL-TIMER timeonbatt timeonline
  AT COMMBAD * EXECUTE upsgone
  AT COMMOK * EXECUTE online
  AT NOCOMM * EXECUTE upsgone
  AT REPLBATT * EXECUTE replacebat
  AT LOWBATT * EXECUTE lowbat
''
