{ ... }:

let
  ghosttyConfig = ''
    # See: https://ghostty.org/docs/config/reference
    # and: ghostty +list-themes
    theme = dark:Catppuccin Mocha,light:Catppuccin Latte

    font-family = FiraCode Nerd Font Mono
    font-size = 16
    font-thicken = false

    # Scroll on macos with external mouse is way too fast
    mouse-scroll-multiplier = 0.25

    # Parses URLs to allow click
    # Doesn't work at the moment: https://github.com/ghostty-org/ghostty/issues/1972#issuecomment-2240048536
    link-url = true

    # Fixes ctrl-alt keybindings (for fish)
    macos-option-as-alt = true

    # Unbding alt-left/right to make it work with fish
    keybind = alt+left=unbind
    keybind = alt+right=unbind

    # Don't show qui confirmation dialog on close
    confirm-close-surface = false

    # Because ghostty isn't well known and causes color issues
    term = xterm-256color
  '';
in
{
  xdg.configFile."ghostty/config".text = ghosttyConfig;
}
