{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mboxshell";
  version = "0.7.3";

  # https://github.com/dcarrero/mboxshell
  src = fetchFromGitHub {
    owner = "dcarrero";
    repo = "mboxshell";
    rev = "v${version}";
    hash = "sha256-Nr8Qgg9IK91zUpF7r1aAe2hz/U0AYivVHVnxUlh5WFw=";
  };

  cargoHash = "sha256-5P8GrYv3CwUF3UAtYOO+dr25FJmtmVNZk1Eu/xhppGw=";

  doCheck = false;

  meta = {
    description = "Fast terminal TUI viewer for MBOX files of any size";
    homepage = "https://github.com/dcarrero/mboxshell";
    license = lib.licenses.mit;
    mainProgram = "mboxshell";
  };
}
