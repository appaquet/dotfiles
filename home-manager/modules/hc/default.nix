{
  config,
  lib,
  pkgs,
  inputs',
  ...
}:
let
  appDir = ./app;
  appLink = sub: "${config.home.homeDirectory}/dotfiles/home-manager/modules/hc/app/${sub}";

  # Entries of an app/ subfolder (missing folder means none), filtered by file type.
  entries =
    sub:
    if builtins.pathExists (appDir + "/${sub}") then builtins.readDir (appDir + "/${sub}") else { };
  jsonNames =
    sub:
    lib.mapAttrsToList (file: _: lib.removeSuffix ".json" file) (
      lib.filterAttrs (file: type: type == "regular" && lib.hasSuffix ".json" file) (entries sub)
    );
  dirNames = sub: lib.attrNames (lib.filterAttrs (_: type: type == "directory") (entries sub));
  packages = dirNames "";

  # Links every item of `kind` across all packages. A name found in two packages fails evaluation.
  linkAll =
    kind: suffix: names:
    let
      owners = lib.foldl' (
        acc: pkg:
        acc
        // lib.genAttrs (names "${pkg}/${kind}") (
          name:
          if acc ? ${name} then
            throw "hc: ${kind} '${name}' exists in both packages '${acc.${name}}' and '${pkg}' under app/"
          else
            pkg
        )
      ) { } packages;
    in
    lib.mapAttrs (
      name: pkg: config.lib.file.mkOutOfStoreSymlink (appLink "${pkg}/${kind}/${name}${suffix}")
    ) owners;

  # Catppuccin themes only (not the repo's layout/mods), linked read-only from the store; named by the `ap` layout.
  catppuccin = pkgs.fetchFromGitHub {
    owner = "MarcozVD";
    repo = "herdr-layout-catppuccin";
    rev = "b58f43478fbf874c8be989b3336793f7c98b6d10";
    hash = "sha256-bWlOzSpHZHvmje2CiqACqg10j5b/RxRs+TQ8MZsDm+k=";
  };
  catppuccinThemes = {
    herdr-catppuccin = "${catppuccin}/themes/herdr-catppuccin.json";
    herdr-catppuccin-latte = "${catppuccin}/themes/herdr-catppuccin-latte.json";
  };

  # JSON escape decoder: nix strings have no unicode escape, the JSON parser does.
  esc = code: builtins.fromJSON ''"${code}"'';
in
{
  imports = [
    ./app-module.nix
    ./mod-watch.nix
    ./skills.nix
    ./space-url-module.nix
  ];

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
      "cmd-p" = "mod.open:goto";
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
      "ctrl-a g" = "mod.open:goto";
      "ctrl-a w" = "mod.open:goto";
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
      "ctrl-a z" = "pane.zoom";
      "ctrl-a b" = "layout.toggle:sidebar";
      "ctrl-a t" = "mod.open:sysmon";
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

  # Own content is grouped by package: app/<package>/{mods/<mod>/, layouts/*.json, themes/*.json}.
  # Every item of every package is linked to the live checkout, so edits by AP or the app show up
  # as dotfiles diffs. Names must be unique across packages. Adding one needs a snapshot (any jj
  # command) and a home switch.
  dotfiles.herdr-app.mods = linkAll "mods" "" dirNames;
  dotfiles.herdr-app.layouts = linkAll "layouts" ".json" jsonNames;
  dotfiles.herdr-app.themes = lib.mkMerge [
    (linkAll "themes" ".json" jsonNames)
    catppuccinThemes
  ];

  home.packages = [
    pkgs.rodeo # TUI client for hc
    inputs'.llm-agents.packages.herdr-core
    inputs'.llm-agents.packages.herdr-app
    inputs'.llm-agents.packages.herdr # keep until we fully transitioned
  ];
}
