{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.nono;
in
{
  imports = [ ./maybe.nix ];

  options.dotfiles.nono = {
    enable = lib.mkEnableOption "nono sandbox, its profiles and the maybe launcher";

    package = lib.mkOption {
      type = lib.types.package;
      description = "nono package installed alongside the generated profiles.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "Nono profiles, keyed by profile name. Each value is rendered to ~/.config/nono/profiles/<name>.json. The attrset key is auto-injected as meta.name.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.file = lib.mapAttrs' (
      name: profile:
      lib.nameValuePair ".config/nono/profiles/${name}.json" {
        source = pkgs.writers.writeJSON "nono-profile-${name}.json" (
          profile
          // {
            meta = (profile.meta or { }) // {
              name = name;
            };
          }
        );
      }
    ) cfg.profiles;

    home.packages = [ cfg.package ];
  };
}
