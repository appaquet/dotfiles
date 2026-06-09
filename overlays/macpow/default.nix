{
  lib,
  rustPlatform,
  fetchFromGitHub,
  apple-sdk,
}:

rustPlatform.buildRustPackage rec {
  pname = "macpow";
  version = "0.1.19";

  # https://github.com/k06a/macpow
  src = fetchFromGitHub {
    owner = "k06a";
    repo = "macpow";
    rev = "v${version}";
    hash = "sha256-4sYG6vbiYWT6w5jGoNHjIva3RahUBwtQgp101xTzfvY=";
  };

  cargoHash = "sha256-bo7jcyfb6XQGiwp1DvRlsY5Ag03zUgc5O6Ovhuwh19U=";

  buildInputs = [
    apple-sdk
  ];

  # IOReport is a private Apple dylib not in the Nix SDK
  env.RUSTFLAGS = "-L /usr/lib";

  doCheck = false;

  meta = {
    description = "Real-time power consumption TUI for Apple Silicon Macs";
    homepage = "https://github.com/k06a/macpow";
    license = lib.licenses.mit;
    platforms = [ "aarch64-darwin" ];
    mainProgram = "macpow";
  };
}
