{ ... }:

let
  weztermConfig = ''
  '';
in
{
  xdg.configFile."wezterm/wezterm.lua".text = weztermConfig;
}
