{
  lib,
  fetchFromGitHub,
  nix-update-script,
  openssl,
  pkg-config,
  rustPlatform,
  stdenv,
  vimPlugins,
  vimUtils,
  makeWrapper,
  pkgs,
}:
let
  version = "0.0.23";
  src = fetchFromGitHub {
    owner = "yetone";
    repo = "avante.nvim";
    # tag = "v${version}";
    # hash = "sha256-Ud4NkJH7hze5796KjVe5Nj9DzxwQkDQErCJDDiBzAIY=";
    rev = "697384f1cbb03899ecf1fab7725d69d398467ec9";
    hash = "sha256-E6B4JyeB+6Ann6QhcXEUjhyl2B9nhhw1Op6CV7ioIAA=";
  };
  avante-nvim-lib = rustPlatform.buildRustPackage {
    pname = "avante-nvim-lib";
    inherit version src;

    useFetchCargoVendor = true;
    cargoHash = "sha256-pmnMoNdaIR0i+4kwW3cf01vDQo39QakTCEG9AXA86ck=";

    nativeBuildInputs = [
      pkg-config
      makeWrapper
      pkgs.perl
    ];

    buildInputs = [
      openssl
    ];

    buildFeatures = [ "luajit" ];

    checkFlags = [
      # Disabled because they access the network.
      "--skip=test_hf"
      "--skip=test_public_url"
      "--skip=test_roundtrip"
      "--skip=test_fetch_md"
    ];
  };
in
vimUtils.buildVimPlugin {
  pname = "avante.nvim";
  inherit version src;

  dependencies = with vimPlugins; [
    dressing-nvim
    img-clip-nvim
    nui-nvim
    nvim-treesitter
    plenary-nvim
  ];

  postInstall =
    let
      ext = stdenv.hostPlatform.extensions.sharedLibrary;
    in
    ''
      mkdir -p $out/build
      ln -s ${avante-nvim-lib}/lib/libavante_repo_map${ext} $out/build/avante_repo_map${ext}
      ln -s ${avante-nvim-lib}/lib/libavante_templates${ext} $out/build/avante_templates${ext}
      ln -s ${avante-nvim-lib}/lib/libavante_tokenizers${ext} $out/build/avante_tokenizers${ext}
      ln -s ${avante-nvim-lib}/lib/libavante_html2md${ext} $out/build/avante_html2md${ext}
    '';

  passthru = {
    updateScript = nix-update-script {
      attrPath = "vimPlugins.avante-nvim.avante-nvim-lib";
    };

    # needed for the update script
    inherit avante-nvim-lib;
  };

  nvimSkipModules = [
    # Requires setup with corresponding provider
    "avante.providers.azure"
    "avante.providers.copilot"
    "avante.providers.vertex"
    "avante.providers.ollama"
    "avante.providers.vertex_claude"
    "avante.providers.gemini"
  ];

  meta = {
    description = "Neovim plugin designed to emulate the behaviour of the Cursor AI IDE";
    homepage = "https://github.com/yetone/avante.nvim";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      ttrei
      aarnphm
      jackcres
    ];
  };
}
