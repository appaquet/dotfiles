{
  pkgs,
  lib,
  secrets,
  inputs',
  ...
}:

let
  # Set mold as linker
  # Disable readonly segment in mold for `perf` (See https://github.com/flamegraph-rs/flamegraph)
  cargoConfig =
    ""
    + (
      if pkgs.stdenv.isLinux then
        ''
          [target.x86_64-unknown-linux-gnu]
          linker = "clang"
          rustflags = ["-Clink-arg=-fuse-ld=${pkgs.mold-wrapped}/bin/mold", "-Clink-arg=-Wl,--no-rosegment"]
        ''
      else
        ""
    );

in
{
  imports = [
    secrets.devHome
  ];

  home.packages =
    (with pkgs; [
      tokei

      protobuf
      capnproto
      flatbuffers

      gnumake
      bintools # ld, objdump, etc.

      inputs'.nix-ai-tools.packages.codex
      inputs'.nix-ai-tools.packages.opencode
      inputs'.nix-ai-tools.packages.gemini-cli
    ])
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.mold-wrapped
      pkgs.binsider # binary analysis tool
    ];

  home.file.".cargo/config.toml".text = cargoConfig;
}
