{ pkgs, lib }:

/*
  Output assembly — converts processed scope instruction maps into Nix
  derivations. mkFile wraps individual files, mkPackage assembles all scopes
  into a single symlink-joined package. postProcessContent cleans up
  agent-generated markdown before writing.
*/

let
  vendoredCl100kBaseHash = "223921b76ee99bde995b7ff738513eef100fb51d18c93597a113bcffe865b2a7";
  vendoredCl100kBase = pkgs.fetchurl {
    url = "https://openaipublic.blob.core.windows.net/encodings/cl100k_base.tiktoken";
    hash = "sha256-Ijkht27pm96ZW3/3OFE+7xAPtR0YyTWXoRO8/+hlsqc=";
  };

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

  # mkPackage :: { scopes, postProcess ? false, bom ? { ... } } -> derivation
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
  #
  #   bom: package/render-only bill-of-materials export.
  #     Uses tiktoken with an encoding-first configuration and writes one
  #     estimated-count markdown report to each harness root.
  mkPackage =
    {
      scopes,
      postProcess ? false,
      bom ? { },
    }:
    let
      process = if postProcess then postProcessContent else (x: x);
      bomConfig = {
        encoding = "cl100k_base";
        encodingPath = vendoredCl100kBase;
        encodingHash = vendoredCl100kBaseHash;
        tiktokenPackage = pkgs.python3Packages.tiktoken;
      }
      // bom;
      resolveFilename =
        path: item: if item ? outputPath && item.outputPath != null then item.outputPath else "${path}.md";
      startsWith = prefix: text: builtins.substring 0 (builtins.stringLength prefix) text == prefix;
      classifyEntry =
        source: relativePath:
        if source == "skillFile" then
          "skillSubfiles"
        else if startsWith "agents/" relativePath then
          "agents"
        else if startsWith "commands/" relativePath then
          "commands"
        else if builtins.match "skills/[^/]+/SKILL\\.md" relativePath != null then
          "skills"
        else
          "instructions";
      mkEntry =
        scope: source: path: item:
        let
          harnessName = scope.harness.name or scope.harness.outputDir;
          filename = resolveFilename path item;
          content = process item.embed;
        in
        {
          inherit content source;
          inherit harnessName;
          harnessDir = scope.harness.outputDir;
          relativePath = filename;
          destination = "${scope.harness.outputDir}/${filename}";
          category = classifyEntry source filename;
          file = mkFile scope.harness.outputDir path filename content;
        };
      # Each entry tracks its final destination path so collisions can be caught
      # with a clear diagnostic. Without this guard, two files resolving to the
      # same destination (e.g. a skill sub-file whose path equals an
      # instruction's outputPath) only surface as an opaque symlinkJoin clash.
      fileEntries = lib.concatLists (
        lib.mapAttrsToList (
          _: scope:
          (lib.mapAttrsToList (mkEntry scope "instruction") scope.instructions)
          ++ (lib.mapAttrsToList (mkEntry scope "skillFile") (scope.skillFiles or { }))
        ) scopes
      );

      bomDestinations = lib.mapAttrsToList (_: scope: "${scope.harness.outputDir}/BOM.md") scopes;

      duplicateDestinations =
        let
          destinations = (map (entry: entry.destination) fileEntries) ++ bomDestinations;
          grouped = lib.groupBy (destination: destination) destinations;
        in
        builtins.filter (destination: builtins.length grouped.${destination} > 1) (
          builtins.attrNames grouped
        );

      bomEntries = lib.mapAttrs (
        _: scope:
        let
          harnessName = scope.harness.name or scope.harness.outputDir;
        in
        builtins.map (entry: {
          inherit (entry)
            category
            content
            relativePath
            source
            ;
        }) (builtins.filter (entry: entry.harnessName == harnessName) fileEntries)
      ) scopes;

      bomFiles = lib.mapAttrsToList (
        _: scope:
        let
          harnessName = scope.harness.name or scope.harness.outputDir;
        in
        mkBomFile scope bomConfig.encoding bomConfig.tiktokenPackage bomConfig.encodingPath
          bomConfig.encodingHash
          bomEntries.${harnessName}
      ) scopes;

      allFiles = (map (entry: entry.file) fileEntries) ++ bomFiles;
    in
    assert
      duplicateDestinations == [ ]
      || throw "Multiple nixantic files resolve to the same destination: ${builtins.concatStringsSep ", " duplicateDestinations}";
    pkgs.symlinkJoin {
      name = "nixantic-instructions";
      paths = allFiles;
      passthru.bom = {
        encoding = bomConfig.encoding;
        entries = bomEntries;
      };
    };

  mkBomFile =
    scope: encoding: tiktokenPackage: encodingPath: encodingHash: entries:
    let
      harnessName = scope.harness.name or scope.harness.outputDir;
      manifest = pkgs.writeText "${scope.harness.outputDir}-bom-manifest.json" (
        builtins.toJSON {
          harness = harnessName;
          inherit encoding encodingHash entries;
          encodingPath = toString encodingPath;
        }
      );
      python = pkgs.python3.withPackages (_: [ tiktokenPackage ]);
    in
    pkgs.runCommand "${scope.harness.outputDir}-bom"
      {
        nativeBuildInputs = [ python ];
      }
      ''
        if [ ! -f ${lib.escapeShellArg (toString encodingPath)} ]; then
          echo "missing local tiktoken encoding asset: ${toString encodingPath}" >&2
          exit 1
        fi

        mkdir -p "$out/${scope.harness.outputDir}"
        python ${./render-bom.py} ${manifest} "$out/${scope.harness.outputDir}/BOM.md"
      '';
in
{
  inherit
    postProcessContent
    mkFile
    mkPackage
    mkBomFile
    ;
}
