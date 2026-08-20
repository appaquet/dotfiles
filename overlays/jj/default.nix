{
  lib,
  stdenv,
  rustPlatform,
  fetchFromGitHub,
  installShellFiles,
  gitMinimal,
  gnupg,
  openssh,
  buildPackages,
}:

rustPlatform.buildRustPackage rec {
  pname = "jujutsu";
  version = "0.44.0-worktree-adopt";

  # Points to https://github.com/jj-vcs/jj/pull/9943
  # Git worktree adopt command for existing git worktrees
  src = fetchFromGitHub {
    owner = "jj-vcs";
    repo = "jj";
    rev = "997637e3eabd9b76d1424150d4320a9768c79ec5";
    hash = "sha256-1fP+SGtHIllvFrRRA0VdK5nDaZEz7jxJyh1jIjkWLRI=";
  };

  cargoHash = "sha256-obwGPIZWqjhZQrLOut47CKb2pqVQCnlBCY9u8tMdA+Q=";

  nativeBuildInputs = [
    installShellFiles
  ];

  nativeCheckInputs = [
    gitMinimal
    gnupg
    openssh
  ];

  cargoBuildFlags = [
    # Don't install the `gen-protos` build tool.
    "--bin"
    "jj"
  ];

  env = {
    # Disable vendored libraries.
    ZSTD_SYS_USE_PKG_CONFIG = "1";
    LIBGIT2_NO_VENDOR = "1";
    LIBSSH2_SYS_USE_PKG_CONFIG = "1";
  };

  postInstall =
    let
      jj = "${stdenv.hostPlatform.emulator buildPackages} $out/bin/jj";
    in
    lib.optionalString (stdenv.hostPlatform.emulatorAvailable buildPackages) ''
      mkdir -p $out/share/man
      ${jj} util install-man-pages $out/share/man/

      installShellCompletion --cmd jj \
        --bash <(COMPLETE=bash ${jj}) \
        --fish <(COMPLETE=fish ${jj}) \
        --zsh <(COMPLETE=zsh ${jj})
    '';

  doCheck = false;
  doInstallCheck = false;

  meta = {
    description = "Git-compatible DVCS that is both simple and powerful";
    homepage = "https://jj-vcs.dev/";
    changelog = "https://github.com/jj-vcs/jj/blob/${src.rev}/CHANGELOG.md";
    license = lib.licenses.asl20;
    maintainers = with lib.maintainers; [
      _0x4A6F
      thoughtpolice
      emily
      bbigras
    ];
    mainProgram = "jj";
  };
}
