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

      (nvim-treesitter.withPlugins (p: [
        # see https://github.com/nvim-treesitter/nvim-treesitter for available languages
        p.nix
        p.go
        p.gomod
        p.rust
        p.toml
        p.bash
        p.proto
        p.sql
        p.markdown
        p.c
        p.python
        p.dockerfile
        p.dot
        p.fish
        p.html
        p.css
        p.javascript
        p.typescript
        p.vim
      ]))
      nvim-treesitter-textobjects # provider object manipulation

      vim-multiple-cursors # ctrl-n multi cursors
      bclose-vim # close buffer cleanly via <leader>w
      delimitMate # auto close quotes, parens, etc
      nerdcommenter # block comment (<leader>cc)
    ];

    extraConfig = (builtins.concatStringsSep "\n" [
      (builtins.readFile ./conf/base.vim)
      (builtins.readFile ./conf/keymap.vim)
      (builtins.readFile ./conf/theme.vim)
      (builtins.readFile ./conf/plugin.nvimtree.vim)
      (builtins.readFile ./conf/plugin.airline.vim)
      (builtins.readFile ./conf/plugin.treesitter.vim)
      (builtins.readFile ./conf/plugin.fzf.vim)
    ]);
  };

  home.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
