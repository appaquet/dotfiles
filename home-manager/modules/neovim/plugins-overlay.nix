final: prev: {
  vimPlugins = prev.vimPlugins // {
    # https://github.com/zbirenbaum/copilot.lua
    copilot-lua = prev.vimUtils.buildVimPlugin {
      pname = "copilot.lua";
      version = "2026-05-04";
      src = prev.fetchFromGitHub {
        owner = "zbirenbaum";
        repo = "copilot.lua";
        rev = "78c638293f0ea6a2245eca46e9933ee271792d7e";
        sha256 = "sha256-3SCx1KPu/d0oPZDSrvIzZykw9Vijrir0/BWBl8kHztg=";
      };
      meta.homepage = "https://github.com/zbirenbaum/copilot.lua/";
      meta.hydraPlatforms = [ ];
    };
  };
}
