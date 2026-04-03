{ ... }:
{
  imports = [
    ../modules/common.nix
    ./apps.nix
  ];

  system = {
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    defaults = {
      screencapture = {
        location = "~/documents_app/Screenshots/";
        type = "png";
      };
    };
  };

  networking.localHostName = "mbpapp";
}
