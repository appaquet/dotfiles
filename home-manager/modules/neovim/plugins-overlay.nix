final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "901a6c564abb";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "901a6c564abb45c7703401ecc6416bb0d15afd37";
        sha256 = "sha256-my1i//xS11rx1d+zaDAv/vhfIlw4dS9fOA98SPmJdyY=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/dlyongemallo/diffview-plus.nvim
    diffview-nvim = prev.vimUtils.buildVimPlugin {
      pname = "diffview-nvim";
      version = "be86a001f13b";
      src = prev.fetchFromGitHub {
        owner = "dlyongemallo";
        repo = "diffview-plus.nvim";
        rev = "be86a001f13b4d307814bd6e06eac429a2777ae8";
        sha256 = "sha256-NoIX2kid3Hfb/LExxSXYGllG0/5/mY7NYT5jzx0DqBw=";
      };
      doCheck = false;
      meta.homepage = "https://github.com/dlyongemallo/diffview-plus.nvim/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/balaenis/pi-x-ide/tree/4e557c18c54901c0176f4510da6bd8258af5a69a/ide-plugins/nvim
    pi-x-ide-nvim = prev.vimUtils.buildVimPlugin {
      pname = "pi-x-ide-nvim";
      version = "4e557c18c549";
      src = prev.fetchFromGitHub {
        owner = "balaenis";
        repo = "pi-x-ide";
        rev = "4e557c18c54901c0176f4510da6bd8258af5a69a";
        sha256 = "sha256-88xdhYnwisP7jVL6wPDVuX7IQ3v54VlfnZ1QnV6llLs=";
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
