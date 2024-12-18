{ pkgs, ... }:

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
      base16-nvim
      nvim-web-devicons

      # Layout
      nvim-tree-lua
      lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
      lualine-lsp-progress
      bufferline-nvim # https://github.com/akinsho/bufferline.nvim

      # Tools
      fzf-vim # :Files (ctrl-p), :Rg (ctrl-f), :History (ctrl-l)
      Rename # :Rename <new name>
      vim-multiple-cursors # ctrl-n multi cursors
      nvim-bufdel # :BufDel, :BufDelOthers (properly close buffers)
      delimitMate # auto close quotes, parens, etc
      nerdcommenter # block comment (<leader>cc, <leader>cu)

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
        (builtins.readFile ./conf/keymap.vim)
        (builtins.readFile ./conf/theme.vim)
        (builtins.readFile ./conf/plugin.nvimtree.vim)
        (builtins.readFile ./conf/plugin.bufferline.vim)
        (builtins.readFile ./conf/plugin.lualine.vim)
        (builtins.readFile ./conf/plugin.treesitter.vim)
        (builtins.readFile ./conf/plugin.fzf.vim)
        (builtins.readFile ./conf/plugin.lsp.vim)
        (builtins.readFile ./conf/plugin.copilot.vim)
      ]
    );
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
