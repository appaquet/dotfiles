{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:

rustPlatform.buildRustPackage rec {
  pname = "mboxshell";
  version = "1.4.0";

  # https://github.com/dcarrero/mboxshell
  src = fetchFromGitHub {
    owner = "dcarrero";
    repo = "mboxshell";
    rev = "v${version}";
    hash = "sha256-NX+7SJg26ResYOeJntcJKbVCpL71trqCxN2OeRRKjGI=";
  };

  cargoHash = "sha256-0qx/0WtD5ao90N08oD/ffpuXriMfqBEhBJT/+CIr45w=";

  doCheck = false;

  meta = {
    description = "Fast terminal TUI viewer for MBOX files of any size";
    homepage = "https://github.com/dcarrero/mboxshell";
    license = lib.licenses.mit;
    mainProgram = "mboxshell";
  };
}
