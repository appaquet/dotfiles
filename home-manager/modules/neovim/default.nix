{ config, lib, pkgs, unstablePkgs, ... }:

{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # TODO: Inspire configs from:
    # - https://github.com/AstroNvim/AstroNvim
    # - https://github.com/rockerBOO/awesome-neovim#preconfigured-configuration (meta list of configs)
    # - https://astronvim.com/#-features
    # - https://www.lunarvim.org/docs/plugins/core-plugins-list
    plugins = with pkgs.vimPlugins; [
      # Theme
      nvim-base16
      nvim-web-devicons

      # Layout
      nvim-tree-lua
      lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
      lualine-lsp-progress
      bufferline-nvim # https://github.com/akinsho/bufferline.nvim

      # LSP
      nvim-lspconfig # https://github.com/neovim/nvim-lspconfig/

      # Autocomplete (w/ LSP)
      luasnip
      nvim-cmp # https://github.com/hrsh7th/nvim-cmp
      cmp-cmdline
      cmp_luasnip
      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-nvim-lsp-document-symbol

      # Syntax
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

      # Tools
      fzf-vim # :Files (ctrl-p), :Rg (ctrl-f)
      Rename # :Rename <new name>
      vim-multiple-cursors # ctrl-n multi cursors
      bclose-vim # close buffer cleanly via <leader>w
      delimitMate # auto close quotes, parens, etc
      nerdcommenter # block comment (<leader>cc, <leader>cu)
    ];

    extraConfig = (builtins.concatStringsSep "\n" [
      (builtins.readFile ./conf/base.vim)
      (builtins.readFile ./conf/keymap.vim)
      (builtins.readFile ./conf/theme.vim)
      (builtins.readFile ./conf/plugin.nvimtree.vim)
      (builtins.readFile ./conf/plugin.bufferline.vim)
      (builtins.readFile ./conf/plugin.lualine.vim)
      (builtins.readFile ./conf/plugin.treesitter.vim)
      (builtins.readFile ./conf/plugin.fzf.vim)
      (builtins.readFile ./conf/plugin.lsp.vim)
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
