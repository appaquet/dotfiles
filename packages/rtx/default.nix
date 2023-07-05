{ lib, stdenv, fetchurl, system, autoPatchelfHook }:

let
  sources = {
    # Use `nix-prefetch-url https://...` to get hash
    "x86_64-linux" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.32.2/rtx-v1.32.2-linux-x64";
      sha256 = "146zfc5s1isvk08nxai7xjj6l5b1a1vkmd4qiclikayvcmx8dpsj";
    };
    "aarch64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.32.2/rtx-v1.32.2-macos-arm64";
      sha256 = "195mr77qdg7k85vjnmzjnpkikdgrqljx2qags7q82w6m43z230w0";
    };
    "x86_64-darwin" = fetchurl {
      url = "https://github.com/jdxcode/rtx/releases/download/v1.32.2/rtx-v1.32.2-macos-x64";
      sha256 = "16hc06wjs4rrdz8c1q1ayj2pmp1l80b7ms1j1fx03kxx1hlz6m6q";
    };
  };

in

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.32.2";

  # Supported platforms are asserted automatically by the meta.platforms field
  src = sources.${system};
  dontUnpack = true;

  buildInputs = lib.optionals stdenv.isLinux [ stdenv.cc.cc.lib ];

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
