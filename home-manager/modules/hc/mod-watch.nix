# herdr-mod-watch: reloads own herdr-app mods while their dotfiles copy is edited. herdr-app only watches its
# own home, and a linked mod's edits happen in dotfiles, so this touches the mod's link in the app home on
# every change, which reloads that one mod.
{ pkgs, ... }:

let
  herdrModWatch = pkgs.writeShellApplication {
    name = "herdr-mod-watch";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.fswatch
    ];
    text = ''
      # usage: herdr-mod-watch [app-src] [app-mods]
      src="''${1:-$HOME/dotfiles/home-manager/modules/hc/app}"
      mods="''${2:-$HOME/.config/herdr-app/mods}"
      src="$(realpath "$src")"

      fswatch -r -0 "$src" | while IFS= read -r -d "" file; do
        rel="''${file#"$src"/}"

        # Only <package>/mods/<mod>/... paths
        if [[ ! "$rel" =~ ^[^/]+/mods/([^/]+)/ ]]; then
          continue
        fi
        name="''${BASH_REMATCH[1]}"

        # Files the app writes on reload (would loop), hidden files and node_modules
        if [[ "/$rel" =~ /\.|/node_modules/|/gpui-kit\.d\.ts$|/jsconfig\.json$ ]]; then
          continue
        fi

        if [[ -L "$mods/$name" ]]; then
          touch -h "$mods/$name"
          echo "reloaded $name"
        fi
      done
    '';
  };
in
{
  home.packages = [ herdrModWatch ];
}
