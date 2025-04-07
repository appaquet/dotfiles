{
  pkgs,
  unstablePkgs,
  config,
  secrets,
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

in
{
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
        bufferline-nvim # https://github.com/akinsho/bufferline.nvim
        auto-session # automatically restore last session
        zen-mode-nvim # zen mode

        # Tools
        fzf-lua
        nvim-bufdel # :BufDel, :BufDelOthers (properly close buffers)
        delimitMate # auto close quotes, parens, etc
        which-key-nvim # show keymap hints
        todo-comments-nvim # highlight TODO, FIXME, etc
        multicursors-nvim

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
        #go-nvim (unstable)
        neotest
        neotest-golang
        neotest-python
        #rustaceanvim (unstable)
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
        #avante-nvim # (unstable)
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
      ++ (with unstablePkgs.vimPlugins; [
        # !Warning! Make sure that any plugin loaded here isn't loading treesitters. We can't have
        # it from both stable and unstable ( https://github.com/NixOS/nixpkgs/issues/282927 )

        (avante-nvim.overrideAttrs (_: {
          # Overriding dependencies to prevent treesitter from being loaded from unstable
          # https://github.com/NixOS/nixpkgs/blob/913cc2b4558595a4aafaf87a18935b34f79d5429/pkgs/applications/editors/vim/plugins/non-generated/avante-nvim/default.nix#L54
          dependencies = [
            dressing-nvim
            img-clip-nvim
            nui-nvim
            #nvim-treesitter # yanked
            plenary-nvim
          ];
        }))

        go-nvim
        rustaceanvim
      ])
      ++ [ nvim-lsp-notify ];

    extraConfig = (
      builtins.concatStringsSep "\n" [
        (includeLuaFile "base.lua")
        includeSecrets
        (includeLuaFile "keymap.lua")
        (includeLuaFile "theme.lua")
        (includeLuaFile "buffers.lua")
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

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };
}
