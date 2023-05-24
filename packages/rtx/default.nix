{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.30.4/rtx-v1.30.4-linux-x64";
      sha256 = "18r7mh2wd4f9w4vabsffnfz2mlizafp9dn42d92j0z6hi75030y5";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.30.4/rtx-v1.30.4-macos-arm64";
      sha256 = "1bqzh1krmn2z3famacvx3683kqax363r9imj6n2mykisydy11llb";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.30.4/rtx-v1.30.4-macos-x64";
      sha256 = "0xkv9mga8rv42a050p82wq5k7m76jjqffi4pg3ah84b43mh5lvqx";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.30.4";

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
