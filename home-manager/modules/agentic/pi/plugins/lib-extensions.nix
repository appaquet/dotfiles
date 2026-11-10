{ pkgs }:

# Pi resolves extension symlinks to their real path before resolving imports.
# Extensions that import `../lib/*` must therefore live next to `lib/` in one
# store directory, instead of being copied into the store one file at a time.
pkgs.runCommand "pi-lib-extensions" { } ''
  mkdir -p "$out/extensions" "$out/lib"
  cp ${./mode-switch.ts} "$out/extensions/mode-switch.ts"
  cp ${./scope-provider.ts} "$out/extensions/scope-provider.ts"
  cp ${../lib/fuzzy-selector.ts} "$out/lib/fuzzy-selector.ts"
''
