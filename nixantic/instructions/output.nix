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
  #   with postProcess = true. Two transformations run in order, line by line:
  #
  #   1. Strip exactly one trailing `.` from every line that ends in `.`.
  #      This is intentionally broad: it normalizes generated prose so a line
  #      ending in `.` renders without it ("foo." -> "foo", "foo.." -> "foo.",
  #      lone "." -> "").
  #   2. Drop blank lines, whitespace-only lines, and lone `.` sentinel lines
  #      (agents sometimes emit a bare `.` as a no-op output marker).
  postProcessContent =
    text:
    let
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
      resolveFilename =
        path: item: if item ? outputPath && item.outputPath != null then item.outputPath else "${path}.md";
      # Each entry tracks its final destination path so collisions can be caught
      # with a clear diagnostic. Without this guard, two files resolving to the
      # same destination (e.g. a skill sub-file whose path equals an
      # instruction's outputPath) only surface as an opaque symlinkJoin clash.
      fileEntries = lib.concatLists (
        lib.mapAttrsToList (
          _: scope:
          (lib.mapAttrsToList (
            path: instr:
            let
              filename = resolveFilename path instr;
            in
            {
              destination = "${scope.harness.outputDir}/${filename}";
              file = mkFile scope.harness.outputDir path filename (process instr.embed);
            }
          ) scope.instructions)
          ++ (lib.mapAttrsToList (
            path: f:
            let
              filename = resolveFilename path f;
            in
            {
              destination = "${scope.harness.outputDir}/${filename}";
              file = mkFile scope.harness.outputDir path filename (process f.embed);
            }
          ) (scope.skillFiles or { }))
        ) scopes
      );

      duplicateDestinations =
        let
          grouped = lib.groupBy (entry: entry.destination) fileEntries;
        in
        builtins.filter (dest: builtins.length grouped.${dest} > 1) (builtins.attrNames grouped);

      allFiles = map (entry: entry.file) fileEntries;
    in
    assert
      duplicateDestinations == [ ]
      || throw "Multiple nixantic files resolve to the same destination: ${builtins.concatStringsSep ", " duplicateDestinations}";
    pkgs.symlinkJoin {
      name = "nixantic-instructions";
      paths = allFiles;
    };
in
{
  inherit postProcessContent mkFile mkPackage;
}
