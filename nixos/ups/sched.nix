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
        #echo "$1" >> /tmp/upssched-cmd.log
      }

      case $1 in
        upsgone)
          log_event "The UPS has been gone for a while"
          ;;
        replacebat)
          log_event "The UPS needs its battery replaced"
          ;;
        lowbat)
          log_event "The UPS has LOW BAT"
          upsmon -c fsd
          ;;
        onbatt)
          log_event "The UPS is ON BATT"
          ;;
        online)
          log_event  "The UPS is ONLINE"
          ;;
        timeonbatt)
          log_event "The UPS is ON BAT for a while"
          upsmon -c fsd
          ;;
        timeonline)
          log_event "The UPS is back ONLINE"
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
