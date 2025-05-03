{
  pkgs,
  unstablePkgs,
  config,
  secrets,
  ...
}:

let
  devMode = true; # Include files from dotfiles directly instead of via nix store

  pkgsChannel = unstablePkgs;

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

  includeSecrets = ''
    if filereadable("${secrets.common.nvimSecrets}")
      lua dofile("${secrets.common.nvimSecrets}")
    else
      lua print("nvim secrets not found!!")
    endif
  '';

  # Forked from https://github.com/mrded/nvim-lsp-notify
  nvim-lsp-notify = pkgs.vimUtils.buildVimPlugin {
    name = "lsp-notify";
    src = ./plugins/lsp-notify;
  };

  avante-nvim-override = pkgs.callPackage ./plugins/avante.nix {
    pkgs = pkgsChannel;
  };
in
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;

    package = pkgsChannel.neovim-unwrapped;

    plugins =
      (with pkgsChannel.vimPlugins; [
        # Theme
        catppuccin-nvim
        nvim-web-devicons

        # Layout
        nvim-tree-lua
        lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
        bufferline-nvim # https://github.com/akinsho/bufferline.nvim
        auto-session # automatically restore last session
        zen-mode-nvim

        # Tools
        fzf-lua
        delimitMate # auto close quotes, parens, etc
        which-key-nvim # show keymap hints
        todo-comments-nvim # highlight TODO, FIXME, etc
        multicursors-nvim
        mini-nvim # ton of modules (bufremove, etc.)

        # Notifications
        nvim-notify
        # nvim-notify-notify (see below)

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
        go-nvim
        neotest
        neotest-golang
        neotest-python
        rustaceanvim
        conform-nvim # formatting

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

        # AI
        avante-nvim-override
        copilot-lua # use `Copilot auth` to login
        render-markdown-nvim # optional dep

        # Debugging
        nvim-dap
        nvim-dap-ui
        nvim-dap-go
        nvim-dap-python
        nvim-dap-virtual-text

        # Syntax
        (nvim-treesitter.withPlugins (p: [
          # see https://github.com/nvim-treesitter/nvim-treesitter for available languages
          p.bash
          p.c
          p.comment
          p.css
          p.dockerfile
          p.dot
          p.fish
          p.go
          p.gomod
          p.gotmpl
          p.gowork
          p.html
          p.javascript
          p.json
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
          p.vimdoc
        ]))
        nvim-treesitter-textobjects # provider object manipulation
      ])
      # ++ (with pkgsChannel.vimPlugins; [
      # !Warning! Make sure that any plugin loaded here isn't loading treesitters. We can't have
      #])
      #++ (with pkgsChannel.vimPlugins; [
      # !Warning! Make sure that any plugin loaded here aren't loading treesitters. We can't have
      # it from both stable and unstable ( https://github.com/NixOS/nixpkgs/issues/282927 )
      # ])
      ++ [ nvim-lsp-notify ];

    extraConfig = (
      builtins.concatStringsSep "\n" [
        (includeLuaFile "base.lua")
        includeSecrets
        (includeLuaFile "keymap.lua")
        (includeLuaFile "theme.lua")
        (includeLuaFile "buffers.lua")
        (includeLuaFile "windows.lua")
        (includeLuaFile "statusline.lua")
        (includeLuaFile "tree.lua")
        (includeLuaFile "sessions.lua")
        (includeLuaFile "notify.lua")
        (includeLuaFile "fzf.lua")
        (includeLuaFile "treesitter.lua")
        (includeLuaFile "git.lua")
        (includeLuaFile "lang.lua")
        (includeLuaFile "formatting.lua")
        (includeLuaFile "ai.lua")
        (includeLuaFile "diag.lua")
        (includeLuaFile "testing.lua")
        (includeLuaFile "quickfix.lua")
        (includeLuaFile "debugging.lua")
      ]
    );

    extraPackages = with pkgs; [
      nixd # nix lsp
      marksman # markdown lsp
      nodejs # for copilot
      stylua # lua formatting
      lua-language-server # lua lsp
      bash-language-server # bash lsp
      shfmt # shell formatting
      shellcheck # shell linting
    ];
  };

  # In theory don't need this, see above
  # home.sessionVariables = {
  #   EDITOR = "nvim";
  #   VISUAL = "nvim";
  # };
}
