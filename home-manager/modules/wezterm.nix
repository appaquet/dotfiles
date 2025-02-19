{ ... }:

let
  weztermConfig = ''
    local wezterm = require 'wezterm'

    function scheme_for_appearance(appearance)
      if appearance:find 'Dark' then
        return 'Catppuccin Mocha'
      else
        return 'Catppuccin Latte'
      end
    end

    wezterm.on('window-config-reloaded', function(window, pane)
      local overrides = window:get_config_overrides() or {}
      local appearance = window:get_appearance()
      local scheme = scheme_for_appearance(appearance)
      if overrides.color_scheme ~= scheme then
        overrides.color_scheme = scheme
        window:set_config_overrides(overrides)
      end
    end)

    return {
      color_scheme = 'Catppuccin Mocha',
      font = wezterm.font 'FiraCode Nerd Font Mono',
      window_decorations = "RESIZE", -- border less, but allow resizing
    }
  '';
in
{
  xdg.configFile."wezterm/wezterm.lua".text = weztermConfig;
}
