{
  package,
  pkgs,
  lib,
  testResult,
}:

# Generic check derivation for the renderer. Corpus-specific output assertions
# belong with the corpus that owns those sources.

let
  tooling = import ./builders.nix { inherit pkgs lib; };
  bomRendererPython = pkgs.python3.withPackages (_: [ pkgs.python3Packages.tiktoken ]);
  sourceSets = import ../source-sets.nix;
  harnesses = import ./harnesses { renderFrontmatter = tooling.renderFrontmatter; };
  missingVendoredEncodingManifest = pkgs.writeText "missing-vendored-encoding-manifest.json" (
    builtins.toJSON {
      harness = "claude";
      encoding = "cl100k_base";
      encodingPath = "/definitely/missing-cl100k_base.tiktoken";
      encodingHash = "223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7";
      entries = [ ];
    }
  );

  renderedPackageSources = tooling.normalizeSourceDeclarations (
    sourceSets.resolveSources { sourceRoots = [ ./tests/fixtures/rendered-package ]; }
  );
  renderedPackageScopes = lib.mapAttrs (
    _: harness:
    tooling.makeScope {
      inherit harness;
      sources = renderedPackageSources.sources;
    }
  ) harnesses;
  renderedPackage = tooling.mkPackage {
    scopes = renderedPackageScopes;
    postProcess = false;
  };

  renderedPackageCheck = pkgs.runCommand "rendered-package-check" { } ''
    test -f ${renderedPackage}/claude/CLAUDE.md
    test -f ${renderedPackage}/claude/BOM.md
    test -f ${renderedPackage}/claude/commands/safe-command.md
    test -f ${renderedPackage}/opencode/AGENTS.md
    test -f ${renderedPackage}/opencode/BOM.md
    test -f ${renderedPackage}/opencode/skills/safe-skill/SKILL.md
    test -f ${renderedPackage}/opencode/skills/safe-skill/refs/example.md

    grep -F 'description: "Run: safely # not a YAML comment"' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'argument-hint: "[path:with:colon]"' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'allowed-tools: ["Bash(command: test)", "Read # docs"]' ${renderedPackage}/claude/commands/safe-command.md
    grep -F 'Command body.' ${renderedPackage}/claude/commands/safe-command.md
    grep -F '# Rendered Package OpenCode' ${renderedPackage}/opencode/AGENTS.md
    grep -F 'Bundled reference body.' ${renderedPackage}/opencode/skills/safe-skill/refs/example.md
    grep -F '# Instruction BOM: claude' ${renderedPackage}/claude/BOM.md
    grep -F 'Estimated token counts using tiktoken encoding `cl100k_base`' ${renderedPackage}/claude/BOM.md
    grep -F 'not provider-authoritative context billing' ${renderedPackage}/claude/BOM.md
    grep -F '| Generated instructions | 1 |' ${renderedPackage}/claude/BOM.md
    grep -F '| Commands | 1 |' ${renderedPackage}/claude/BOM.md
    grep -F '| Skills | 1 |' ${renderedPackage}/opencode/BOM.md
    grep -F '| Skill subfiles | 1 |' ${renderedPackage}/opencode/BOM.md
    grep -F '| skills/safe-skill/refs/example.md |' ${renderedPackage}/opencode/BOM.md
    grep -F '## Root/main instruction summary' ${renderedPackage}/claude/BOM.md
    grep -F '## Per-command file-cost' ${renderedPackage}/claude/BOM.md
    ! grep -F '| BOM.md |' ${renderedPackage}/claude/BOM.md
    touch $out
  '';

  missingVendoredEncodingCheck =
    pkgs.runCommand "missing-vendored-encoding-check"
      {
        nativeBuildInputs = [ bomRendererPython ];
      }
      ''
        err="$TMPDIR/missing-vendored-encoding.err"
        python ${./render-bom.py} ${missingVendoredEncodingManifest} "$TMPDIR/BOM.md" 2>"$err" && {
          echo "FAIL: missing vendored encoding asset should have failed" >&2
          exit 1
        }
        grep -F 'Missing local tiktoken encoding asset for BOM generation' "$err" || {
          echo "FAIL: missing vendored encoding asset failed for an unexpected reason" >&2
          cat "$err" >&2
          exit 1
        }
        touch $out
      '';

  # Verify that referencing a nonexistent block fails Nix evaluation.
  # Proves the Nix-level reference validation mechanism works at build time.
  badRefCheck =
    pkgs.runCommand "bad-block-reference-check"
      {
        nativeBuildInputs = [ pkgs.nix ];
      }
      ''
        expr='(import ${./tests/fixtures/bad-block-reference.nix} { scope = { blocks = {}; }; }).content'
        err="$TMPDIR/bad-ref-check-err"
        nix-instantiate --eval --strict -E "$expr" 2>"$err" && {
          echo "FAIL: nonexistent block reference should have failed evaluation" >&2
          exit 1
        }
        grep -q 'nonexistent' "$err" || {
          echo "FAIL: nonexistent block reference failed for an unexpected reason" >&2
          cat "$err" >&2
          exit 1
        }
        touch $out
      '';
in
pkgs.runCommand "nixantic-instructions-check" { } ''
  : ${testResult}
  : ${badRefCheck}
  : ${missingVendoredEncodingCheck}
  : ${renderedPackageCheck}
  : ${package}
  touch $out
''
