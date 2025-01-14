{ pkgs, ... }:

let
  readLuaFile =
    path:
    builtins.concatStringsSep "\n" [
      "lua << END"
      (builtins.readFile path)
      "END"
    ];

in
{
  home.packages = with pkgs; [
    nixd # nix lsp
    marksman # markdown lsp
    nodejs # for copilot
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    # TODO: Inspire configs from:
    # - https://astronvim.com/#-features
    # - https://nvchad.com/docs/features
    # - https://github.com/rockerBOO/awesome-neovim#preconfigured-configuration (meta list of configs)
    # - https://www.lunarvim.org/docs/plugins/core-plugins-list
    plugins = with pkgs.vimPlugins; [
      # Theme
      night-owl-nvim
      nvim-web-devicons

      # Layout
      nvim-tree-lua
      lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
      lualine-lsp-progress
      bufferline-nvim # https://github.com/akinsho/bufferline.nvim
      auto-session # automatically restore last session

      # Tools
      fzf-lua # <leader>f*
      Rename # :Rename <new name>
      vim-multiple-cursors # ctrl-n multi cursors
      nvim-bufdel # :BufDel, :BufDelOthers (properly close buffers)
      delimitMate # auto close quotes, parens, etc
      nerdcommenter # block comment (<leader>cc, <leader>cu)
      which-key-nvim # show keymap hints

      # Git
      vim-fugitive # Git (diff|log|...) commands
      vim-gitgutter # Show diffs in gutter

      # LSP
      nvim-lspconfig # https://github.com/neovim/nvim-lspconfig

      # Autocomplete (w/ LSP)
      luasnip
      nvim-cmp # https://github.com/hrsh7th/nvim-cmp
      cmp-cmdline
      cmp_luasnip
      cmp-nvim-lsp
      cmp-nvim-lsp-signature-help
      cmp-nvim-lsp-document-symbol

      # Copilot (use Copilot auth)
      # See https://github.com/zbirenbaum/copilot.lua
      # and https://github.com/zbirenbaum/copilot-cmp
      copilot-lua
      copilot-cmp
      avante-nvim
      render-markdown-nvim # needed for avante

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
        p.lua
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
    ];

    extraConfig = (
      builtins.concatStringsSep "\n" [
        (builtins.readFile ./conf/base.vim)
        (readLuaFile ./conf/keymap.lua)
        (readLuaFile ./conf/theme.lua)
        (readLuaFile ./conf/plugin.autosession.lua)
        (readLuaFile ./conf/plugin.avante.lua)
        (readLuaFile ./conf/plugin.bufferline.lua)
        (readLuaFile ./conf/plugin.copilot.lua)
        (readLuaFile ./conf/plugin.fzf.lua)
        (readLuaFile ./conf/plugin.lsp.lua)
        (readLuaFile ./conf/plugin.lualine.lua)
        (readLuaFile ./conf/plugin.nvimtree.lua)
        (readLuaFile ./conf/plugin.treesitter.lua)
      ]
    );
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
