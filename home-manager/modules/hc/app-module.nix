{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.herdr-app;
  jsonFormat = pkgs.formats.json { };
in
{
  options.dotfiles.herdr-app = {
    settings = lib.mkOption {
      type = lib.types.submodule {
        freeformType = jsonFormat.type;
      };
      default = { };
      description = "herdr-app settings declared in nix. They are merged into the live settings.json at activation: declared values win, keys the app or a person wrote survive.";
    };

    keys = lib.mkOption {
      type = lib.types.submodule {
        freeformType = jsonFormat.type;
      };
      default = { };
      description = "Complete herdr-app keymap, rendered to keys.json. A partial map silently unbinds every key it omits.";
    };
  };

  config = {
    xdg.configFile."herdr-app/keys.json" = lib.mkIf (cfg.keys != { }) {
      source = jsonFormat.generate "herdr-app-keys.json" cfg.keys;
    };

    # Merged rather than linked: herdr-app writes settings.json itself (Settings UI, zoom keys) and
    # applies it live, so a store symlink would be rewritten into the store.
    home.activation.herdrAppSettings = lib.mkIf (cfg.settings != { }) (
      lib.hm.dag.entryAfter [ "linkGeneration" ] (
        lib.hm.generators.mkImpureConfigMerger {
          inherit pkgs;
          format = "json";
          empty = "{}";
          jqOperation = "$dynamic * $static";
          path = "${config.xdg.configHome}/herdr-app/settings.json";
          staticSettings = jsonFormat.generate "herdr-app-settings.json" cfg.settings;
        }
      )
    );
  };
}
