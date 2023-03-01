{ config, lib, pkgs, ... }:
let
  base16-vim = pkgs.vimPlugins.base16-vim.overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "chriskempson";
      repo = "base16-vim";
      rev = "3be3cd82cd31acfcab9a41bad853d9c68d30478d";
      sha256 = "uJvaYYDMXvoo0fhBZUhN8WBXeJ87SRgof6GEK2efFT0=";
    };
  });

  vim-airline = pkgs.vimPlugins.vim-airline.overrideAttrs (old: {
    src = pkgs.fetchFromGitHub {
      owner = "vim-airline";
      repo = "vim-airline";
      rev = "038e3a6ca59f11b3bb6a94087c1792322d1a1d5c";
      sha256 = "m6ENdxaWT/e6Acl2OblnfvKFAO9ysPgrexoNL2TUqVQ=";
    };
  });

in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    plugins = with pkgs.vimPlugins; [
      nvim-web-devicons
      nvim-tree-lua

      fzf-vim # :Files (ctrl-p), :Rg (ctrl-f)
      base16-vim # theme
      vim-airline # status / tab bar

      vim-multiple-cursors # ctrl-n multi cursors
      bclose-vim # close buffer cleanly via <leader>w
      delimitMate # auto close quotes, parens, etc
    ];

    extraConfig = (builtins.concatStringsSep "\n" [
      (builtins.readFile ./conf/base.vim)
      (builtins.readFile ./conf/keymap.vim)
      (builtins.readFile ./conf/theme.vim)
      (builtins.readFile ./conf/plugin.nvimtree.vim)
      (builtins.readFile ./conf/plugin.airline.vim)
    ]);
  };

  programs.fish = {
    interactiveShellInit = ''
      set -x EDITOR nvim
      set -x VISUAL nvim
      alias vi=nvim
      alias vim=nvim
    '';
  };
}
