{ inputs, ... }:
{
  imports =
    (with inputs.self.modules.darwin; [
      base
    ])
    ++ [
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
