{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.18.0/rtx-v1.18.0-linux-x64";
      sha256 = "0k6y13qyzn6qhfzcrg3mls9bdhpj2hwndh59cbch9y6l5fh8pcmi";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.18.0/rtx-v1.18.0-macos-arm64";
      sha256 = "1zffg3h6wr6m8rgg2biwp8lp43scfsrbawjq1haqzkxfmmkrcg90";
    };
  };
in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.18.0";

  # Use `nix-prefetch-url https://...` to get hash
  # Supported platforms are asserted automatically by the meta.platforms field
  src = sources.${system};
  dontUnpack = true;

  # From https://nixos.wiki/wiki/Packaging/Binaries
  # lib.optionals returns [ ] if the condition is false so it's a noop on other platforms
  nativeBuildInputs = lib.optionals stdenv.isLinux [
    autoPatchelfHook
  ];

  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/rtx
    chmod +x $out/bin/rtx
  '';

  meta = with lib; {
    description = "Runtime Executor (asdf rust clone) ";
    homepage = "https://github.com/jdxcode/rtx";
    license = licenses.mit;
    platforms = builtins.attrNames sources;
  };
}