final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "d1570ddc00fc";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "d1570ddc00fc4fc4caf7422803805ee22cca14ff";
        sha256 = "sha256-yw3KrsbRPtdoaCZ6SUEjaKR5uo3f8gvDv22lqNmPCSs=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/dlyongemallo/diffview-plus.nvim
    diffview-nvim = prev.vimUtils.buildVimPlugin {
      pname = "diffview-nvim";
      version = "fae72d6c9810";
      src = prev.fetchFromGitHub {
        owner = "dlyongemallo";
        repo = "diffview-plus.nvim";
        rev = "fae72d6c981075dce2e0f946f002382ce0cb44e1";
        sha256 = "sha256-JZr63uzY+Ms6kdvIPyUJsl33PmSPA9SND7FBzdRgELY=";
      };
      doCheck = false;
      meta.homepage = "https://github.com/dlyongemallo/diffview-plus.nvim/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/balaenis/pi-x-ide/tree/83c2e6978035363c87a0ebf11144167fcc13a134/ide-plugins/nvim
    pi-x-ide-nvim = prev.vimUtils.buildVimPlugin {
      pname = "pi-x-ide-nvim";
      version = "83c2e6978035";
      src = prev.fetchFromGitHub {
        owner = "balaenis";
        repo = "pi-x-ide";
        rev = "83c2e6978035363c87a0ebf11144167fcc13a134";
        sha256 = "sha256-DuU2vFYnim+czky43z6XlgSPbFCiEuZ00hRUon/mrh4=";
      };
      sourceRoot = "source/ide-plugins/nvim";
      postPatch = ''
        substituteInPlace lua/pi_x_ide/init.lua \
          --replace-fail '  download.prefetch()' \
          '  if not state.config.sidecar_cmd then
            download.prefetch()
          end'
      '';
      meta.homepage = "https://github.com/balaenis/pi-x-ide/";
      meta.hydraPlatforms = [ ];
    };
  };
}
