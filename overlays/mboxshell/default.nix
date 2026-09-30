{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mboxshell";
  version = "0.8.0";

  # https://github.com/dcarrero/mboxshell
  src = fetchFromGitHub {
    owner = "dcarrero";
    repo = "mboxshell";
    rev = "v${version}";
    hash = "sha256-OGpQYcTDmA1PwcmBiz928d2mJ8wCuE0YVYYjoWACRDg=";
  };

  cargoHash = "sha256-OAY2aH6unX3XiLV6LymqzpSMpL/2s+IEdkigQiGgzuY=";

  doCheck = false;

  meta = {
    description = "Fast terminal TUI viewer for MBOX files of any size";
    homepage = "https://github.com/dcarrero/mboxshell";
    license = lib.licenses.mit;
    mainProgram = "mboxshell";
  };
}
