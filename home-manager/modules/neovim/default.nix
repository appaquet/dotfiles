{
  pkgs-nvim,
  config,
  secrets,
  lib,
  cfg,
  ...
}:

let
  devMode = true; # Include files from dotfiles directly instead of via nix store

  pkgsChannel = pkgs-nvim;
  agenticEnabled = !cfg.minimalNvim;

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
  nvim-lsp-notify = pkgsChannel.vimUtils.buildVimPlugin {
    name = "lsp-notify";
    src = ./plugins/lsp-notify;
  };

  copilot-lsp = pkgsChannel.vimUtils.buildVimPlugin {
    pname = "copilot-lsp";
    version = "2025-09-20";
    src = pkgsChannel.fetchFromGitHub {
      owner = "copilotlsp-nvim";
      repo = "copilot-lsp";
      rev = "5030766af6dce2181d48b928537ebe1919ec8d22";
      sha256 = "sha256-AJGpzPkf+A+tcAQMcD9wLAuNyBL8r8x/ydqQJ9sqTP0";
    };
    meta.homepage = "https://github.com/copilotlsp-nvim/copilot-lsp/";
    meta.hydraPlatforms = [ ];
  };

  copilot-lua = pkgsChannel.vimUtils.buildVimPlugin {
    pname = "copilot.lua";
    version = "2025-09-20";
    src = pkgsChannel.fetchFromGitHub {
      owner = "zbirenbaum";
      repo = "copilot.lua";
      rev = "6fba2272a2ddb18488dd927d3848d8219124854a";
      sha256 = "sha256-ptbedGYFOWLBsPV+WqAXYSjOSdodiMBCudoSJPB5WVU=";
    };
    meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
    meta.hydraPlatforms = [ ];
  };

  # claudecode-nvim = pkgsChannel.vimUtils.buildVimPlugin {
  #   name = "claudecode-nvim";
  #   src = pkgsChannel.fetchFromGitHub {
  #     owner = "coder";
  #     repo = "claudecode.nvim";
  #     rev = "d0f9748";
  #     sha256 = "sha256-qmZPjZJ9UFxAWCY3NQwsu0nEniG/UasV/iCrG3S5tPQ=";
  #   };
  # };

  # Fixes perf issues
  # gitsigns-nvim = pkgsChannel.vimUtils.buildVimPlugin {
  #   name = "gitsigns-nvim";
  #   src = pkgsChannel.fetchFromGitHub {
  #     owner = "lewis6991";
  #     repo = "gitsigns.nvim";
  #     rev = "b014331";
  #     sha256 = "sha256-7BKwxHoFWGepqm8/J+RB6zu+7IpGUUmgLP4a2O2lIuA=";
  #   };
  # };
  #
  # avante-nvim-override = pkgs.callPackage ./plugins/avante.nix {
  #   pkgs = pkgsChannel;
  # };
  #
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
        nvim-colorizer-lua # colorize hex codes, etc.

        # Layout
        nvim-tree-lua
        lualine-nvim # https://github.com/nvim-lualine/lualine.nvim
        auto-session # automatically restore last session
        zen-mode-nvim

        # Tools
        fzf-lua
        delimitMate # auto close quotes, parens, etc
        which-key-nvim # show keymap hints
        todo-comments-nvim # highlight TODO, FIXME, etc
        multicursors-nvim
        mini-nvim # tabline, bufremove, etc.
        snacks-nvim # profiler

        # Notifications
        (nvim-notify.overrideAttrs (_: {
          doCheck = false; # flaky on ci
        }))
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
        nvim-navic # symbol breadcrumbs in statusline
        render-markdown-nvim
        nvim-lint

        # Autocomplete
        nvim-cmp # https://github.com/hrsh7th/nvim-cmp
        cmp-cmdline
        cmp-nvim-lsp
        cmp-nvim-lsp-signature-help
        cmp-nvim-lsp-document-symbol
        cmp-cmdline
        copilot-lua # use `Copilot auth` to login
        copilot-lsp # needed for NES on copilot-lua

        # Snippets
        luasnip
        cmp_luasnip
        friendly-snippets # easy load from vscode, languages, etc.

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
          p.gosum
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
          p.yaml
        ]))
        nvim-treesitter-textobjects # provides object manipulation
      ])
      ++ (lib.optionals agenticEnabled [
        # Agentic plugins
        pkgsChannel.vimPlugins.codecompanion-nvim
        pkgsChannel.mcphub-nvim
        pkgsChannel.vimPlugins.claudecode-nvim

        # Avante
        #avante-nvim-override
        pkgsChannel.vimPlugins.avante-nvim

        # Avante deps (if dev mode)
        # pkgs.vimPlugins.dressing-nvim
        # pkgs.vimPlugins.img-clip-nvim
        # pkgs.vimPlugins.nui-nvim
        # pkgs.vimPlugins.nvim-treesitter
        # pkgs.vimPlugins.plenary-nvim
      ])
      ++ [
        nvim-lsp-notify
      ];

    extraConfig = (
      builtins.concatStringsSep "\n" (
        [
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
          (includeLuaFile "linting.lua")

          (includeLuaFile "copilot.lua")

          (includeLuaFile "diag.lua")
          (includeLuaFile "testing.lua")
          (includeLuaFile "quickfix.lua")
          (includeLuaFile "debugging.lua")

          (includeLuaFile "profiling.lua")
        ]
        ++ (lib.optionals agenticEnabled [
          (includeLuaFile "agentic.lua")
        ])
      )
    );

    extraPackages =
      (with pkgsChannel; [
        nixd # nix lsp

        marksman # markdown lsp
        markdownlint-cli # via nvim-lint

        nodejs # for copilot
        typescript-language-server

        stylua # lua formatting, `npx` for some MCPs
        lua-language-server # lua lsp

        bash-language-server # bash lsp
        shfmt # shell formatting (via lsp)
        shellcheck # shell linting (via lsp)

        rust-analyzer

        pyright
        ruff
      ])
      ++ (lib.optionals agenticEnabled [
        pkgsChannel.mcp-hub # via overlay
        pkgsChannel.uv # for `uvx` for some MCPs
      ]);
  };

  # Force load after the rest
  # May have to delete session if not working, or check `:scriptnames` / `:set runtimepath?`
  xdg.configFile."nvim/after/ftplugin" = {
    recursive = true;
    source = ./ftplugin;
  };

}
