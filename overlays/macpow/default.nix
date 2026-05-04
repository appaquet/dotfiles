{
  lib,
  rustPlatform,
  fetchFromGitHub,
  apple-sdk,
}:

rustPlatform.buildRustPackage {
  pname = "macpow";
  version = "0.1.14";

  # https://github.com/k06a/macpow
  src = fetchFromGitHub {
    owner = "k06a";
    repo = "macpow";
    rev = "v0.1.14";
    hash = "sha256-u3spvhamRmhcwLxrEcswgO7XU/w2JXANF2wk21ovH40=";
  };

  cargoHash = "sha256-yIVWp1y+yt0j/eej1yIkAE+JYDav6cX89Ww58gKT8Q4=";

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
