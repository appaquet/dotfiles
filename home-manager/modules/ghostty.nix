{ ... }:

let
  ghosttyConfig = ''
    # See: https://ghostty.org/docs/config/reference
    # and: ghostty +list-themes
    theme = dark:catppuccin-mocha,light:catppuccin-latte

    font-family = FiraCode Nerd Font Mono
    font-size = 12
    font-thicken = true

    # Disabling ligature since it's pretty annoyingly making mono non-mono sized
    font-feature = -calt
    font-feature = -liga
    font-feature = -dlig

    # Parses URLs to allow click
    # Doesn't work at the moment: https://github.com/ghostty-org/ghostty/issues/1972#issuecomment-2240048536
    link-url = true

    # Fixes ctrl-alt keybindings (for fish)
    macos-option-as-alt = true

    # Because ghostty isn't well known
    term = xterm
  '';
in
{
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
