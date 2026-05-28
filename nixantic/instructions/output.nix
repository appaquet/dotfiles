{ pkgs, lib }:

/*
  Output assembly — converts processed scope instruction maps into Nix
  derivations. mkFile wraps individual files, mkPackage assembles all scopes
  into a single symlink-joined package. postProcessContent cleans up
  agent-generated markdown before writing.
*/

let
  # postProcessContent :: string -> string
  #   Cleans up generated markdown output. Applied when mkPackage is called
  #   with postProcess = true. The transformation happens in two stages:
  #
  #   1. Strip exactly one trailing `.` from each line that ends with `.`.
  #   2. Remove blank lines, whitespace-only lines, and lone `.` sentinel
  #      lines (`.`, sometimes emitted by agents as a no-op output marker).
  postProcessContent =
    text:
    let
      # Strip trailing dot: "foo." -> "foo", "foo.." -> "foo.", "." -> ""
      stripTrailingDot =
        line:
        if builtins.match ".*\\.$" line != null then
          builtins.substring 0 (builtins.stringLength line - 1) line
        else
          line;
      stripped = map stripTrailingDot (lib.splitString "\n" text);
      nonEmpty = builtins.filter (
        line: line != "." && null == builtins.match "^[[:space:]]*$" line
      ) stripped;
    in
    builtins.concatStringsSep "\n" nonEmpty;

  # mkFile :: dir -> path -> filename -> content -> derivation
  #   Creates a single output file via pkgs.writeTextFile.
  #   Places file at `/<dir>/<filename>` in the derivation tree.
  #   Derivation name: `<dir>-<path>` with `/` replaced by `-`.
  #
  #   dir      — harness outputDir (e.g. "claude", "opencode")
  #   path     — instruction key (e.g. "commands/my-cmd")
  #   filename — destination filename (e.g. "my-cmd.md")
  #   content  — file body (processed markdown)
  mkFile =
    dir: path: filename: content:
    pkgs.writeTextFile {
      name = builtins.replaceStrings [ "/" ] [ "-" ] "${dir}-${path}";
      text = content;
      destination = "/${dir}/${filename}";
    };

  # mkPackage :: { scopes, postProcess ? false } -> derivation
  #   Assembles all harness scopes into a single symlinkJoin package.
  #
  #   For each scope, processes two instruction sources:
  #     scope.instructions — primary instructions (authored, agents, commands, skills)
  #     scope.skillFiles   — skill sub-files (.md and .nix)
  #
  #   Filename resolution (per instruction):
  #     Uses instr.outputPath if non-null, otherwise defaults to "<key>.md".
  #
  #   postProcess: when true, applies postProcessContent to every file's embed
  #     before writing. Useful for agent-to-human output where agents may emit
  #     blank lines or `.` sentinels.
  mkPackage =
    {
      scopes,
      postProcess ? false,
    }:
    let
      process = if postProcess then postProcessContent else (x: x);
      allFiles = lib.concatLists (
        lib.mapAttrsToList (
          _: scope:
          (lib.mapAttrsToList (
            path: instr:
            let
              filename =
                if instr ? outputPath && instr.outputPath != null then instr.outputPath else "${path}.md";
            in
            mkFile scope.harness.outputDir path filename (process instr.embed)
          ) scope.instructions)
          ++ (lib.mapAttrsToList (
            path: f:
            let
              filename = if f ? outputPath && f.outputPath != null then f.outputPath else "${path}.md";
            in
            mkFile scope.harness.outputDir path filename (process f.embed)
          ) (scope.skillFiles or { }))
        ) scopes
      );
    in
    pkgs.symlinkJoin {
      name = "nixantic-instructions";
      paths = allFiles;
    };
in
{
  inherit postProcessContent mkFile mkPackage;
}
