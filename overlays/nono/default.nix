{
  lib,
  rustPlatform,
  fetchFromGitHub,

  pkg-config,

  dbus,
}:

rustPlatform.buildRustPackage rec {
  pname = "nono";
  version = "0.53.0";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    tag = "v${version}";
    hash = "sha256-jK3/NDNQkeeCKP2iMIJMCq9lrDZ9ksiEnHhFmrz+gew=";
  };
  cargoHash = "sha256-OK2vlXYFdjMHqzVR6ZoRn7WEfAUVATGhk32JLoDED5c=";

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
