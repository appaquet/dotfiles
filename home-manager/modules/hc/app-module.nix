{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.herdr-app;
  jsonFormat = pkgs.formats.json { };

  # Names the app ships and rewrites on start (non-layout keys of installed.json, herdr-app 0.1.15).
  # A managed entry with one of these names would be renamed or overwritten by the app. Refresh
  # when a new herdr-app version ships more mods, layouts or themes.
  shippedMods = [
    "agents"
    "changes"
    "confirm"
    "files"
    "help"
    "machine-add"
    "menu"
    "new-menu"
    "pane"
    "peek"
    "picker"
    "prompt"
    "spaces"
    "tabs"
    "terminals-bar"
    "terminals-pane"
    "toast"
    "win98"
    "workspace-chrome"
    "workspace-status"
    "worktree"
  ];
  shippedLayouts = [
    "main"
    "terminals"
    "win98"
  ];
  shippedThemes = [
    "atom-one-dark"
    "win98"
  ];

  clashes = shipped: managed: lib.filter (name: lib.elem name shipped) (lib.attrNames managed);
  assertNoShipped = kind: shipped: managed: {
    assertion = clashes shipped managed == [ ];
    message = "dotfiles.herdr-app.${kind}: names ${lib.concatStringsSep ", " (clashes shipped managed)} are shipped by herdr-app and rewritten on start. Pick another name.";
  };
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

    mods = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
      default = { };
      description = ''
        Mods linked into herdr-app/mods, name to mod directory. Each is one whole-directory symlink, never
        per-file links, which break relative imports. A mutable target (mkOutOfStoreSymlink) receives the
        typings the app writes into a mod folder; a store target is read-only, so the typings write fails
        quietly and the mod still loads. Names shipped by herdr-app are rejected.
      '';
    };

    layouts = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
      default = { };
      description = ''
        Layouts linked into herdr-app/layouts, name to JSON file, one link per file. Clicks (sizes, active
        panel) persist in layouts/.state either way. A store target is read-only: docking a new mod,
        layout.set and layout.reset fail, and a layout without node ids logs a keep_ids warning at each load.
        Clone it into an own layout to customize. Names shipped by herdr-app are rejected.
      '';
    };

    themes = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.path lib.types.str);
      default = { };
      description = ''
        Themes linked into herdr-app/themes, name to JSON file, one link per file. A shared layout that names
        a theme it ships does not apply without it. Names shipped by herdr-app are rejected.
      '';
    };
  };

  config = {
    assertions = [
      (assertNoShipped "mods" shippedMods cfg.mods)
      (assertNoShipped "layouts" shippedLayouts cfg.layouts)
      (assertNoShipped "themes" shippedThemes cfg.themes)
    ];

    xdg.configFile = {
      "herdr-app/keys.json" = lib.mkIf (cfg.keys != { }) {
        source = jsonFormat.generate "herdr-app-keys.json" cfg.keys;
      };
    }
    // lib.mapAttrs' (
      name: source: lib.nameValuePair "herdr-app/mods/${name}" { inherit source; }
    ) cfg.mods
    // lib.mapAttrs' (
      name: source: lib.nameValuePair "herdr-app/layouts/${name}.json" { inherit source; }
    ) cfg.layouts
    // lib.mapAttrs' (
      name: source: lib.nameValuePair "herdr-app/themes/${name}.json" { inherit source; }
    ) cfg.themes;

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
