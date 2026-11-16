{ lib, ... }:

{
  options.dotfiles.neovim = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable neovim configuration.";
    };

    full = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable full neovim configuration with LSP, autocomplete, etc.";
    };

    devMode = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable dev mode for neovim - loads Lua files via dofile() for live editing.";
    };
  };
}
