{
  package,
  pkgs,
  testResult,
}:

# Generic check derivation for the renderer. Corpus-specific output assertions
# belong with the corpus that owns those sources.

let
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
  : ${package}
  touch $out
''
