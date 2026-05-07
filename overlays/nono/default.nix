{
  lib,
  rustPlatform,
  fetchFromGitHub,

  pkg-config,

  dbus,
}:

rustPlatform.buildRustPackage rec {
  pname = "nono";
  version = "0.49.0";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    rev = "v${version}";
    hash = "sha256-LUcod8nysDDQohUv8PAUuF91zsv3KWNY4I17s9/cYyA=";
  };

  cargoHash = "sha256-T0MP+1KshqxWF7NbxHynEYFzyF6YDRaMyRsW7wPPfpI=";

  preCheck = ''
    mkdir -p /tmp/a /tmp/b
  '';

  nativeBuildInputs = [
    pkg-config
  ];

  buildInputs = [
    dbus
  ];

  # Bunch of issues + twice as long to build
  doCheck = false;

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
