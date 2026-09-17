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

  version = "0.43.0-git-worktree-adopt";

  # Points to https://github.com/jj-vcs/jj/pull/9943
  # Support for adopting existing git worktrees
  src = fetchFromGitHub {
    owner = "jj-vcs";
    repo = "jj";
    rev = "69374e4e1b9d149985fd8b35ee44255b5e624754";
    hash = "sha256-ikwa1/PHq/or11JjGJADbGNCOaylM3wVL3fboT92Vic=";
  };

  cargoHash = "sha256-x3fffc8P15LwKkq3M2j3wA3YRxUYTCL69qfD6SkI/j0=";

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
