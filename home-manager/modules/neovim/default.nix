{
  pkgs,
  unstablePkgs,
  config,
  ...
}:

let
  devMode = true; # Include files from dotfiles directly instead of via nix store

  confDir = "${config.home.homeDirectory}/dotfiles/home-manager/modules/neovim/conf";

  includeLuaFile =
    path:
    if devMode then
      ''
        lua dofile("${confDir}/${path}")
      ''
    else
      ''
        lua << END
        ${builtins.readFile ./conf/${path}}
        END
      '';

  includeVimFile =
    path:
    if devMode then
      ''
        source ${confDir}/${path}
      ''
    else
      builtins.readFile ./conf/${path};

in
{
  home.packages = with pkgs; [
    nixd # nix lsp
    marksman # markdown lsp
    nodejs # for copilot
    stylua # lua formatting
    bash-language-server # bash lsp
    shfmt # shell formatting
    shellcheck # shell linting
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;

    plugins =
      (with pkgs.vimPlugins; [
        # Theme
        catppuccin-nvim
        nvim-web-devicons

        # Layout
        nvim-tree-lua
        lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
        lualine-lsp-progress
        bufferline-nvim # https://github.com/akinsho/bufferline.nvim
        auto-session # automatically restore last session
        nvim-notify

        # Tools
        fzf-lua # <leader>f*
        Rename # :Rename <new name>
        vim-multiple-cursors # ctrl-n multi cursors
        nvim-bufdel # :BufDel, :BufDelOthers (properly close buffers)
        delimitMate # auto close quotes, parens, etc
        nerdcommenter # block comment (<leader>cc, <leader>cu)
        which-key-nvim # show keymap hints
        todo-comments-nvim # highlight TODO, FIXME, etc

        # Diagnostics
        trouble-nvim

        # Git
        vim-fugitive # Git (diff|log|...) commands
        gitsigns-nvim # Show git signs in gutter
        diffview-nvim # :DiffviewOpen, :DiffviewClose
        octo-nvim
        gitlinker-nvim

        # LSP / Languages
        nvim-lspconfig # https://github.com/neovim/nvim-lspconfig
        #go-nvim (unstable)
        neotest
        neotest-golang
        neotest-python
        rustaceanvim
        conform-nvim # easy formatting

        # Autocomplete (w/ LSP)
        nvim-cmp # https://github.com/hrsh7th/nvim-cmp
        cmp-cmdline
        cmp-nvim-lsp
        cmp-nvim-lsp-signature-help
        cmp-nvim-lsp-document-symbol
        cmp-cmdline

        # Snippets
        luasnip
        cmp_luasnip
        friendly-snippets # easy load from vscode, languages, etc.

        # Copilot (use Copilot auth)
        copilot-lua

        # Avante and dependencies
        #avante-nvim (unstable)
        render-markdown-nvim
        nui-nvim
        dressing-nvim
        plenary-nvim
        img-clip-nvim

        # Debugging
        nvim-dap
        nvim-dap-ui
        nvim-dap-go

        # Syntax
        (nvim-treesitter.withPlugins (p: [
          # see https://github.com/nvim-treesitter/nvim-treesitter for available languages
          p.bash
          p.c
          p.css
          p.dockerfile
          p.dot
          p.fish
          p.go
          p.html
          p.javascript
          p.jsonnet
          p.lua
          p.markdown
          p.nix
          p.proto
          p.python
          p.rust
          p.sql
          p.toml
          p.typescript
          p.vim
        ]))
        nvim-treesitter-textobjects # provider object manipulation
      ])
      ++ (with unstablePkgs.vimPlugins; [
        avante-nvim
        go-nvim
      ]);

    extraConfig = (
      builtins.concatStringsSep "\n" [
        (includeVimFile "base.vim")
        (includeLuaFile "base.lua")
        (includeLuaFile "keymap.lua")
        (includeLuaFile "layout.lua")
        (includeLuaFile "theme.lua")
        (includeLuaFile "sessions.lua")
        (includeLuaFile "notify.lua")
        (includeLuaFile "fzf.lua")
        (includeLuaFile "ai.lua")
        (includeLuaFile "lsp.lua")
        (includeLuaFile "formatting.lua")
        (includeLuaFile "treesitter.lua")
        (includeLuaFile "diag.lua")
        (includeLuaFile "testing.lua")
        (includeLuaFile "git.lua")
        (includeLuaFile "quickfix.lua")
        (includeLuaFile "code.lua")
        (includeLuaFile "debugging.lua")
      ]
    );
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
