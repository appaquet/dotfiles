{
  pkgs,
  lib,
  inputs,
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
          rustflags = ["-Clink-arg=-fuse-ld=${pkgs.mold}/bin/mold", "-Clink-arg=-Wl,--no-rosegment"]
        ''
      else
        ""
    );

in
{
  imports = [
    inputs.secrets.homeManager.dev
  ];

  home.packages =
    (with pkgs; [
      tokei

      protobuf
      capnproto
      flatbuffers

      gnumake
      bintools # ld, objdump, etc.
    ])
    ++ lib.optionals pkgs.stdenv.isLinux [
      pkgs.mold
      pkgs.binsider # binary analysis tool
    ];

  home.file.".cargo/config.toml".text = cargoConfig;
}
