{ lib, stdenv, fetchurl }:

stdenv.mkDerivation {
  pname = "rtx";
  version = "v1.18.0";

  # Use `nix-prefetch-url https://...` to get hash
  src =
    (if stdenv.isLinux then
      fetchurl
        {
          url = "https://github.com/jdxcode/rtx/releases/download/v1.18.0/rtx-v1.18.0-linux-x64";
          sha256 = "0k6y13qyzn6qhfzcrg3mls9bdhpj2hwndh59cbch9y6l5fh8pcmi";
        }
    else if stdenv.isDarwin && stdenv.isAarch64 then
      fetchurl
        {
          url = "https://github.com/jdxcode/rtx/releases/download/v1.18.0/rtx-v1.18.0-macos-arm64";
          sha256 = "1zffg3h6wr6m8rgg2biwp8lp43scfsrbawjq1haqzkxfmmkrcg90";
        }
    else abort ("unsupported os & arch")
    );

  phases = [ "installPhase" "patchPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/rtx
    chmod +x $out/bin/rtx
  '';

  meta = with lib; {
    description = "Runtime Executor (asdf rust clone) ";
    homepage = "https://github.com/jdxcode/rtx";
    license = licenses.mit;
  };
}
