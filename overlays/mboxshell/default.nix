{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mboxshell";
  version = "1.3.0";

  # https://github.com/dcarrero/mboxshell
  src = fetchFromGitHub {
    owner = "dcarrero";
    repo = "mboxshell";
    rev = "v${version}";
    hash = "sha256-dOnq4zEV72uEyw5cguKf+2FVuOsSpP+ACWmOZmtLPd8=";
  };

  cargoHash = "sha256-/eoMM7aTZiA1FV39HT/xmpnWO9r5zpEn6DuBpve/8ec=";

  doCheck = false;

  meta = {
    description = "Fast terminal TUI viewer for MBOX files of any size";
    homepage = "https://github.com/dcarrero/mboxshell";
    license = lib.licenses.mit;
    mainProgram = "mboxshell";
  };
}
