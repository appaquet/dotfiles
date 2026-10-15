final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "84c129a0fe68";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "84c129a0fe6841743ad7180fb714d4018e132f1e";
        sha256 = "sha256-Ni81ELSa+4WOyBQKNujEb7kc/G3PDlVykH+Ivk/cOiU=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/dlyongemallo/diffview-plus.nvim
    diffview-nvim = prev.vimUtils.buildVimPlugin {
      pname = "diffview-nvim";
      version = "2a2d89a07f5d";
      src = prev.fetchFromGitHub {
        owner = "dlyongemallo";
        repo = "diffview-plus.nvim";
        rev = "2a2d89a07f5d5d3cef7f542b99c3e28050ca205c";
        sha256 = "sha256-0Zu2HPU9rzsyIOVLPWB9ABmfu5UffYkJtkIQUtBLVOs=";
      };
      doCheck = false;
      meta.homepage = "https://github.com/dlyongemallo/diffview-plus.nvim/";
      meta.hydraPlatforms = [ ];
    };

    # https://github.com/balaenis/pi-x-ide/tree/f5f3165a3f90fa2a42d577fe3f2a407b093cacab/ide-plugins/nvim
    pi-x-ide-nvim = prev.vimUtils.buildVimPlugin {
      pname = "pi-x-ide-nvim";
      version = "f5f3165a3f90";
      src = prev.fetchFromGitHub {
        owner = "balaenis";
        repo = "pi-x-ide";
        rev = "f5f3165a3f90fa2a42d577fe3f2a407b093cacab";
        sha256 = "sha256-mbHGnQhXJYBZQqybkvfewqjR/3z7wN+WNGEMqLaNglc=";
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
