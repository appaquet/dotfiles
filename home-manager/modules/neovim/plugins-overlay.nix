final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "v3.0.4";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "7e6723aabea044519462958ffcea68d7985c5ed0";
        sha256 = "sha256-nrKBq1K43l34S812udQHKIPWoSamCgQLtfYq/AjBu5I=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/dlyongemallo/diffview-plus.nvim
    diffview-nvim = prev.vimUtils.buildVimPlugin {
      pname = "diffview-nvim";
      version = "v0.36";
      src = prev.fetchFromGitHub {
        owner = "dlyongemallo";
        repo = "diffview-plus.nvim";
        rev = "62dc5adf4e77489a2a6d3bf36ef6e4ac5738b634";
        sha256 = "sha256-yqFT+Iastcr3YxlqjKtlDzuEvcw7oSLDGAdcEiodvs0=";
      };
      doCheck = false;
      meta.homepage = "https://github.com/dlyongemallo/diffview-plus.nvim/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/balaenis/pi-x-ide/tree/v1.19.4/ide-plugins/nvim
    pi-x-ide-nvim = prev.vimUtils.buildVimPlugin {
      pname = "pi-x-ide-nvim";
      version = "1.19.4";
      src = prev.fetchFromGitHub {
        owner = "balaenis";
        repo = "pi-x-ide";
        rev = "6aed4540664c49a5749fe23b5085985feda504ea";
        sha256 = "sha256-Rwolq2T6uyqpy6yTra7KUeTKvBbS1VFhet9F1OiyfD8=";
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
