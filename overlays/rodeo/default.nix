{
  lib,
  stdenvNoCC,
  fetchurl,
}:
let
  version = "0.2.1";

  # Map Nix system -> upstream release asset suffix and content hash.
  # https://github.com/lukeed/rodeo
  # On a version bump: set `version`, replace every hash with lib.fakeHash, then read
  # the real values from the four build errors and build once more.
  assets = {
    x86_64-linux = {
      name = "x86_64-unknown-linux-musl";
      hash = "sha256-0r7u6VCW4N8f9w5BbjIY+Xh8olC8hmunHAH/yBxYNco=";
    };
    aarch64-linux = {
      name = "aarch64-unknown-linux-musl";
      hash = "sha256-Sl9ltclymgrKnl+B1LVp324oMbZBe2E2VXayUR8A6YM=";
    };
    aarch64-darwin = {
      name = "aarch64-apple-darwin";
      hash = "sha256-4MpHzDw69SMu7KbseGm+pE41RgHz8F5d/B9frAz2Xow=";
    };
  };

  asset =
    assets.${stdenvNoCC.hostPlatform.system}
      or (throw "rodeo: no release asset for system ${stdenvNoCC.hostPlatform.system}");
in
stdenvNoCC.mkDerivation {
  pname = "rodeo";
  inherit version;

  src = fetchurl {
    url = "https://github.com/lukeed/rodeo/releases/download/v${version}/rodeo-${asset.name}.tar.gz";
    inherit (asset) hash;
  };

  # The archives hold one prebuilt `rodeo` binary at their root, with no top-level
  # directory: no compilation, nothing to strip, and the artifact is installed
  # untouched so the binary keeps matching its published checksum.
  dontBuild = true;
  dontStrip = true;
  sourceRoot = ".";

  installPhase = ''
    runHook preInstall
    install -Dm755 rodeo "$out/bin/rodeo"
    runHook postInstall
  '';

  meta = {
    description = "Keyboard-first terminal UI for herdr-core";
    homepage = "https://github.com/lukeed/rodeo";
    license = lib.licenses.mit;
    mainProgram = "rodeo";
    # Upstream ships static musl Linux binaries and macOS binaries that link only
    # system libraries, so no SDK or dynamic loader patching is involved.
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = builtins.attrNames assets;
  };
}
