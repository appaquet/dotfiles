{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.29.3/rtx-v1.29.3-linux-x64";
      sha256 = "0fr4m814yylvm2c7r7lrnlf16sgsqrqn3mq45ynql1yd654bn357";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.29.3/rtx-v1.29.3-macos-arm64";
      sha256 = "0maz5kkb8z2c30wj30kwh146ligzmz7h4z6zmfmga4pf7dx49498";
    };
  };
in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.20.2";

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
