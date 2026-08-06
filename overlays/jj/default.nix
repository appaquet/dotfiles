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
  version = "0.43.0-colocated-workspaces-cli";

  # Points to https://github.com/jj-vcs/jj/pull/8834
  # Support for git colocated workspaces
  src = fetchFromGitHub {
    owner = "jj-vcs";
    repo = "jj";
    rev = "a0e7ebe7b037e822c506fcf6308055f8eecfb48a";
    hash = "sha256-y7yBZlFcBkWU8rLKTv4BoU4ld16fH6dFZ6EVGdNV0Tw=";
  };

  cargoHash = "sha256-0yD9WuIPIuYA9vk2qG0ycauuaRBFsakIJ8Rkf2p4Ayo=";

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
