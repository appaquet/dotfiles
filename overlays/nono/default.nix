{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,

  pkg-config,

  dbus,
}:

rustPlatform.buildRustPackage rec {
  pname = "nono";
  version = "0.43.0";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    rev = "v${version}";
    hash = "sha256-V0QdcaNxn0bVOK5YZdN/bA//WBJXesDw7P9AzGbRQdk=";
  };

  cargoHash = "sha256-qLL6tq2Q6smB8eb4lsN3VlEStn/7RoXPg23W/yONrog=";

  preCheck = ''
    mkdir -p /tmp/a /tmp/b
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = lib.optionals stdenv.isLinux [
    dbus
  ];

  meta = {
    description = "Secure, kernel-enforced sandbox for AI agents, MCP and LLM workloads";
    homepage = "https://github.com/always-further/nono";
    changelog = "https://github.com/always-further/nono/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      jk
    ];
    mainProgram = "nono";
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
