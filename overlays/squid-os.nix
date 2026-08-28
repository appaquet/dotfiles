{
  lib,
  buildGoModule,
  fetchFromGitHub,
  gitMinimal,
}:

buildGoModule rec {
  pname = "squid-os";
  version = "eefecc6c";

  # https://github.com/gogluejf/squid-os
  src = fetchFromGitHub {
    owner = "gogluejf";
    repo = "squid-os";
    rev = "eefecc6c71f94b23d405287343574bd526379e51";
    hash = "sha256-R3dr2c+AY75gn12ExUSQ/deqhqL+Qhb2sz3vjHW0xI0=";
  };

  # vendorHash = null opts into the offline vendored build.
  vendorDir = "vendor";
  vendorHash = null;

  # Go tests in internal/git shell out to git.
  nativeBuildInputs = [ gitMinimal ];

  # TestURLLimitsValidateURL_AllowedSchemes resolves example.com and cannot run
  # in the offline build sandbox.
  env = {
    # buildGoModule's check phase appends $checkFlags to `go test`.
    checkFlags = "-skip TestURLLimitsValidateURL_AllowedSchemes";
  };

  # Upstream injects the git commit at build time via ldflags.
  ldflags = [ "-X squid-os/internal/version.GitCommit=${version}" ];

  meta = with lib; {
    description = "TUI AI chat client";
    homepage = "https://github.com/gogluejf/squid-os";
    license = licenses.mit;
    mainProgram = "squid-os";
    platforms = platforms.all;
  };
}
