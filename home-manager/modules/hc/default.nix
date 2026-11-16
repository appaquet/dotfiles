{
  pkgs,
  inputs',
  ...
}:
let
  # JSON escape decoder: nix strings have no unicode escape, the JSON parser does.
  esc = code: builtins.fromJSON ''"${code}"'';
in
{
  imports = [ ./app-module.nix ];

  # Look: applied live by the app, and only to layouts that leave fonts unset.
  dotfiles.herdr-app.settings = {
    font = "FiraCode Nerd Font";
  };

  # Complete keymap: a partial keys.json silently unbinds every key it omits.
  # Pinned: new default bindings from later app versions need a manual refresh.
  dotfiles.herdr-app.keys = {
    global = {
      "cmd-q" = "app.quit";
      "cmd-h" = "app.hide";
      "cmd-alt-h" = "app.hide_others";
      "cmd-t" = "tab.new";
      "cmd-w" = "tab.close";
      "ctrl-tab" = "space.next";
      "ctrl-shift-tab" = "space.prev";
      "cmd-shift-]" = "tab.next";
      "cmd-shift-[" = "tab.prev";
      "cmd-alt-]" = "space.next";
      "cmd-alt-[" = "space.prev";
      "cmd-]" = "agent.next";
      "cmd-[" = "agent.prev";
      "cmd-shift-l" = "layout.switch";
      "cmd-n" = "space.new";
      "cmd-p" = "mod.open:picker";
      "cmd-shift-p" = "app.palette";
      "cmd-," = "app.settings";
      "cmd-d" = "pane.split:right";
      "cmd-shift-d" = "pane.split:down";
      "cmd-shift-w" = "pane.close";
      "cmd-shift-enter" = "pane.zoom";
      "cmd-alt-left" = "pane.go:left";
      "cmd-alt-right" = "pane.go:right";
      "cmd-alt-up" = "pane.go:up";
      "cmd-alt-down" = "pane.go:down";
      "cmd-alt-shift-left" = "pane.swap:left";
      "cmd-alt-shift-right" = "pane.swap:right";
      "cmd-alt-shift-up" = "pane.swap:up";
      "cmd-alt-shift-down" = "pane.swap:down";
      "f2" = "tab.rename";
      "shift-f2" = "space.rename";
      "cmd-/" = "app.help";
      "cmd-shift-/" = "app.help";
      "cmd-b" = "layout.toggle:sidebar";
      "cmd-=" = "app.zoom_in";
      "cmd-+" = "app.zoom_in";
      "cmd--" = "app.zoom_out";
      "cmd-0" = "app.zoom_reset";
      "cmd-1" = "tab.select:1";
      "cmd-2" = "tab.select:2";
      "cmd-3" = "tab.select:3";
      "cmd-4" = "tab.select:4";
      "cmd-5" = "tab.select:5";
      "cmd-6" = "tab.select:6";
      "cmd-7" = "tab.select:7";
      "cmd-8" = "tab.select:8";
      "cmd-9" = "tab.select:9";
      "ctrl-shift-1" = "space.select:1";
      "ctrl-shift-2" = "space.select:2";
      "ctrl-shift-3" = "space.select:3";
      "ctrl-shift-4" = "space.select:4";
      "ctrl-shift-5" = "space.select:5";
      "ctrl-shift-6" = "space.select:6";
      "ctrl-shift-7" = "space.select:7";
      "ctrl-shift-8" = "space.select:8";
      "ctrl-shift-9" = "space.select:9";
      "ctrl-a shift-n" = "space.new";
      "ctrl-a shift-w" = "space.rename";
      "ctrl-a shift-d" = "space.close";
      "ctrl-a g" = "mod.open:picker";
      "ctrl-a c" = "tab.new";
      "ctrl-a n" = "tab.next";
      "ctrl-a p" = "tab.prev";
      "ctrl-a shift-x" = "tab.close";
      "ctrl-a 1" = "tab.select:1";
      "ctrl-a 2" = "tab.select:2";
      "ctrl-a 3" = "tab.select:3";
      "ctrl-a 4" = "tab.select:4";
      "ctrl-a 5" = "tab.select:5";
      "ctrl-a 6" = "tab.select:6";
      "ctrl-a 7" = "tab.select:7";
      "ctrl-a 8" = "tab.select:8";
      "ctrl-a 9" = "tab.select:9";
      "ctrl-a v" = "pane.split:right";
      "ctrl-a -" = "pane.split:down";
      "ctrl-a h" = "pane.go:left";
      "ctrl-a j" = "pane.go:down";
      "ctrl-a k" = "pane.go:up";
      "ctrl-a l" = "pane.go:right";
      "ctrl-a shift-h" = "pane.swap:left";
      "ctrl-a shift-j" = "pane.swap:down";
      "ctrl-a shift-k" = "pane.swap:up";
      "ctrl-a shift-l" = "pane.swap:right";
      "ctrl-a x" = "pane.close";
      "ctrl-a b" = "layout.toggle:sidebar";
    };

    terminal = {
      "cmd-c" = "terminal.copy";
      "cmd-v" = "terminal.paste";
      "ctrl-v" = "terminal.paste_image";
      "alt-left" = "send:${esc "\\u001b"}b";
      "alt-right" = "send:${esc "\\u001b"}f";
      "alt-backspace" = "send:${esc "\\u0017"}";
      "cmd-left" = "send:${esc "\\u0001"}";
      "cmd-right" = "send:${esc "\\u0005"}";
      "cmd-backspace" = "send:${esc "\\u0015"}";
    };
  };

  home.packages = [
    pkgs.rodeo # TUI client for hc
    inputs'.llm-agents.packages.herdr-core
    inputs'.llm-agents.packages.herdr-app
  ];
}
