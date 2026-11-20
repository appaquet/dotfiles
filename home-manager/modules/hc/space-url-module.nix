{ config, lib, ... }:

let
  cfg = config.dotfiles.hc.space-url;
in
{
  options.dotfiles.hc.space-url = {
    vars = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "MYAPP_FRONTEND_ORIGIN" ];
      description = ''
        Environment variables holding a workspace's URL, in priority order. Interactive fish shells
        label their Herdr terminal with the first non-empty one (`space.url=<url>`), and Herdr mods
        show it as a link on the space. Nothing is installed when empty.
      '';
    };
  };

  config = lib.mkIf (cfg.vars != [ ]) {
    programs.fish.interactiveShellInit = ''
      source ${./space-url.fish}
      hc_space_url_watch ${lib.escapeShellArgs cfg.vars}
    '';
  };
}
