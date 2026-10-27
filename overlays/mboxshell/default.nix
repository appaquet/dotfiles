{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mboxshell";
  version = "1.2.0";

  # https://github.com/dcarrero/mboxshell
  src = fetchFromGitHub {
    owner = "dcarrero";
    repo = "mboxshell";
    rev = "v${version}";
    hash = "sha256-bwLVL7GoNS789fH1OdglOyZGSHf0W9L/9VRylFM9S34=";
  };

  cargoHash = "sha256-Rp0LlCg7/o6Qoq5xuMkoJYF2v0qsA8uw9mfm5tzwukc=";

  doCheck = false;

  meta = {
    description = "Fast terminal TUI viewer for MBOX files of any size";
    homepage = "https://github.com/dcarrero/mboxshell";
    license = lib.licenses.mit;
    mainProgram = "mboxshell";
  };
}
