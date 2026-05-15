{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.nono;

  maymaybe-pre = pkgs.writeShellScriptBin "maymaybe-pre" ''
    if [ -f ".nono/pre.sh" ]; then
      . ".nono/pre.sh"
    fi
  '';

  maymaybe-in = pkgs.writeShellScriptBin "maymaybe-in" ''
    if [ -f ".nono/in.sh" ]; then
      . ".nono/in.sh"
    fi
    exec "$@"
  '';

  maymaybe-profile = pkgs.writeShellScriptBin "maymaybe-profile" ''
    DEFAULT="$1"
    if [ -f ".nono/profile.json" ]; then
      echo "$(pwd)/.nono/profile.json"
    else
      printf '%s' "$DEFAULT"
    fi
  '';
in
{
  options.dotfiles.nono = {
    profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything);
      default = { };
      description = "Nono profiles, keyed by profile name. Each value is rendered to ~/.config/nono/profiles/<name>.json. The attrset key is auto-injected as meta.name.";
    };
  };

  config = {
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

    home.packages = [
      pkgs.nono
      maymaybe-pre
      maymaybe-in
      maymaybe-profile
    ];

    dotfiles.nono.profiles.coding-agent = {
      meta.version = "1.0.0";
      workdir.access = "readwrite";
      filesystem = {
        read = [
          "/proc"
          "/nix"

          "$HOME/dotfiles"

          "$HOME/.config/git"
          "$HOME/.gitignore"

          "$HOME/.nix-profile/bin"
          "$HOME/.local/state/nix"
          "$HOME/.local/share/nix"
          "$HOME/.nix-defexpr"
        ];
        allow = [
          "$HOME/.config/jj"

          "$HOME/.config/fish"
          "$HOME/.local/share/fish"

          "$HOME/.cache/nix"

          "$HOME/.cache/go-build"
          "$HOME/.cache/golangci-lint"

          "$HOME/.npm"

          "/tmp"
        ];
        read_file = [ "$HOME/.profile" ];
        write_file = [ ];
      };
    };
  };
}
