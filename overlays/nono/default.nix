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
  version = "0.24.0";

  src = fetchFromGitHub {
    owner = "always-further";
    repo = "nono";
    rev = "v${version}";
    hash = "sha256-LhI5O85lwnSmMCoy5lbC9UCAKdMvRdtU2nt4WXyMPSk=";
  };

  cargoHash = "sha256-5H9TgMh4MhSvz7szbFPHdIkHk8RbpqSEw86ltn4Rr0E=";

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
