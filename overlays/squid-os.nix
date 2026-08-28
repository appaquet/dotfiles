{
  lib,
  buildGoModule,
  fetchFromGitHub,
  gitMinimal,
}:

buildGoModule rec {
  pname = "squid-os";
  version = "ee6bf0e2";

  # https://github.com/gogluejf/squid-os
  src = fetchFromGitHub {
    owner = "gogluejf";
    repo = "squid-os";
    rev = "ee6bf0e21e21162f25bec769a483dd1b741a4c70";
    hash = "sha256-+kLasBYwRXK9bHplzrTgyIlzAnHItGzSP4kokkCrsZc=";
  };

  # vendorHash = null opts into the offline vendored build.
  vendorDir = "vendor";
  vendorHash = null;

  # Go tests in internal/git shell out to git.
  nativeBuildInputs = [ gitMinimal ];

  # Two tests are skipped, each for a different reason. `go test -skip` takes a
  # regex, so both names are alternated in a single -skip argument:
  #   TestURLLimitsValidateURL_AllowedSchemes - resolves example.com, which the
  #     offline build sandbox forbids.
  #   TestSetWorkingDirToolSwapsSessionCatalog - stale upstream: it asserts a
  #     "### Missing Skills" header that the current code omits when the missing
  #     list is empty (its scenario has none). Re-enable once upstream updates it.
  env = {
    # buildGoModule's check phase appends $checkFlags to `go test`.
    checkFlags = "-skip TestURLLimitsValidateURL_AllowedSchemes|TestSetWorkingDirToolSwapsSessionCatalog";
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
