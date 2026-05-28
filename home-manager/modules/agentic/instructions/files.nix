{ pkgs, lib }:

/*
  File discovery — imports authored instruction sources from disk into the scope
  pipeline. Import strategies cover legacy flat/recursive directories,
  hierarchical authoring directories that export flat keys, local block
  directories, and the directory-per-skill layout with subfile collection.
*/

let
  inherit (builtins)
    attrNames
    baseNameOf
    concatLists
    concatMap
    concatStringsSep
    filter
    groupBy
    head
    length
    listToAttrs
    map
    match
    pathExists
    readDir
    toString
    ;

  artifactKindForDir =
    dir:
    {
      agents = "agent";
      blocks = "block";
      commands = "command";
    }
    .${baseNameOf (toString dir)} or "artifact";

  # listToAttrsUnique :: { kind, entries } -> attrs
  #   Converts [{ key, value, path }] to an attrset after validating that no key
  #   appears more than once. Unlike builtins.listToAttrs, duplicate keys are hard
  #   errors because hierarchical importers flatten directory paths into one
  #   namespace.
  listToAttrsUnique =
    {
      kind,
      entries,
    }:
    let
      grouped = groupBy (entry: entry.key) entries;
      duplicates = filter (key: length grouped.${key} > 1) (attrNames grouped);
      duplicateMessages = map (
        key:
        let
          paths = map (entry: toString entry.path) grouped.${key};
        in
        "Duplicate ${kind} key '${key}' found at: ${concatStringsSep ", " paths}"
      ) duplicates;
    in
    if duplicates != [ ] then
      throw (concatStringsSep "\n" duplicateMessages)
    else
      listToAttrs (
        map (entry: {
          name = entry.key;
          inherit (entry) value;
        }) entries
      );

  # importDir :: { dir, args, recursive ? false, reservedDirs ? [ ] } -> attrs
  #   Imports .nix files from a directory. Each file is imported with `args`
  #   (which receives { scope = self } from scope.nix). Skips default.nix.
  #
  #   Flat mode (recursive = false):
  #     Keys are filename stems. `my-block.nix` → key `my-block`.
  #     Used for: blocks, agents, commands.
  #
  #   Recursive mode (recursive = true):
  #     Keys are relative paths without .nix. `rules/development.nix` →
  #     key `rules/development`. Traverses subdirectories except reservedDirs.
  #     Used for: authored instructions.
  #
  #   Returns: attrset of import results keyed by stem or relative path.
  importDir =
    {
      dir,
      args,
      recursive ? false,
      reservedDirs ? [ ],
    }:
    let
      flat =
        d:
        let
          entries = readDir d;
        in
        listToAttrs (
          builtins.filter (x: x != null) (
            map (
              name:
              let
                m = match "(.*)\\.nix" name;
              in
              if m != null && name != "default.nix" && entries.${name} == "regular" then
                {
                  name = builtins.head m;
                  value = import (d + "/${name}") args;
                }
              else
                null
            ) (attrNames entries)
          )
        );

      recurse =
        d: prefix:
        let
          entries = readDir d;
        in
        concatMap (
          name:
          let
            type = entries.${name};
          in
          if type == "directory" then
            if builtins.elem name reservedDirs then
              [ ]
            else
              recurse (d + "/${name}") (if prefix == "" then name else "${prefix}/${name}")
          else
            let
              m = match "(.*)\\.nix" name;
            in
            if m != null && name != "default.nix" && type == "regular" then
              let
                base = builtins.head m;
                key = if prefix == "" then base else "${prefix}/${base}";
              in
              [
                {
                  name = key;
                  value = import (d + "/${name}") args;
                }
              ]
            else
              [ ]
        ) (attrNames entries);
    in
    if recursive then listToAttrs (recurse dir "") else flat dir;

  # importFlatTree :: { dir, args, reservedDirs ? [ "blocks" ] } -> attrs
  #   Recursively imports .nix files from a directory tree while preserving a flat
  #   key namespace. Keys are filename stems only; default.nix and reserved
  #   directories are skipped. Duplicate stems across the tree throw descriptive
  #   errors before attrset conversion.
  importFlatTree =
    {
      dir,
      args,
      reservedDirs ? [ "blocks" ],
    }:
    let
      kind = artifactKindForDir dir;

      recurse =
        d:
        let
          entries = readDir d;
        in
        concatMap (
          name:
          let
            type = entries.${name};
            fullPath = d + "/${name}";
          in
          if type == "directory" then
            if builtins.elem name reservedDirs then [ ] else recurse fullPath
          else
            let
              m = match "(.*)\\.nix" name;
            in
            if m != null && name != "default.nix" && type == "regular" then
              [
                {
                  key = head m;
                  path = fullPath;
                  value = import fullPath args;
                }
              ]
            else
              [ ]
        ) (attrNames entries);
    in
    listToAttrsUnique {
      inherit kind;
      entries = recurse dir;
    };

  # importBlocksTree :: { roots, args } -> attrs
  #   Imports blocks from multiple source roots into one flat namespace. A root
  #   named blocks contributes its direct .nix files. Other roots are searched
  #   recursively for directories named blocks, and each discovered blocks
  #   directory contributes its direct .nix files. Search continues through blocks
  #   directories so nested blocks/ directories are discovered too.
  importBlocksTree =
    {
      roots,
      args,
    }:
    let
      collectFilesInBlocksDir =
        d:
        let
          entries = readDir d;
        in
        concatMap (
          name:
          let
            type = entries.${name};
            fullPath = d + "/${name}";
            m = match "(.*)\\.nix" name;
          in
          if m != null && name != "default.nix" && type == "regular" then
            [
              {
                key = head m;
                path = fullPath;
                value = import fullPath args;
              }
            ]
          else
            [ ]
        ) (attrNames entries);

      searchForBlocksDirs =
        d:
        let
          entries = readDir d;
        in
        concatMap (
          name:
          let
            type = entries.${name};
            fullPath = d + "/${name}";
          in
          if type == "directory" then
            (if name == "blocks" then collectFilesInBlocksDir fullPath else [ ]) ++ searchForBlocksDirs fullPath
          else
            [ ]
        ) (attrNames entries);

      collectRoot =
        root:
        if baseNameOf (toString root) == "blocks" then
          collectFilesInBlocksDir root ++ searchForBlocksDirs root
        else
          searchForBlocksDirs root;
    in
    listToAttrsUnique {
      kind = "block";
      entries = concatLists (map collectRoot roots);
    };

  # importSkillsDir :: { dir, args } -> attrs
  #   Imports a directory of skill subdirectories. Each subdirectory must
  #   contain a default.nix. Returns an attrset keyed by directory name.
  #
  #   Return shape per skill:
  #     {
  #       kind = "directory";
  #       main = <imported default.nix value>;
  #       files = { <relative-path> = { kind = "nix"|"md"; content = ...; }; ... };
  #     }
  #
  #   Subfile collection (collectSubFiles, recursive):
  #     .nix files → { kind = "nix"; content = <imported value>; }
  #     .md files  → { kind = "md";  content = <raw file contents>; }
  #     Other files are silently skipped.
  #
  #   Used by scope.nix addRawContent for skills discovery.
  importSkillsDir =
    {
      dir,
      args,
    }:
    let
      entries = readDir dir;

      subdirs = builtins.filter (n: entries.${n} == "directory") (attrNames entries);

      collectSubFile =
        d: name: args:
        let
          entries = readDir d;
          fullPath = d + "/${name}";
        in
        if entries.${name} == "regular" then
          if match ".*\\.md" name != null then
            [
              {
                inherit name;
                value = {
                  kind = "md";
                  content = builtins.readFile fullPath;
                };
              }
            ]
          else if match ".*\\.nix" name != null && name != "default.nix" then
            [
              {
                inherit name;
                value = {
                  kind = "nix";
                  content = import fullPath args;
                };
              }
            ]
          else
            [ ]
        else if entries.${name} == "directory" then
          if name == "blocks" then
            [ ]
          else
            map
              (nv: {
                name = "${name}/${nv.name}";
                value = nv.value;
              })
              (
                lib.mapAttrsToList (n: v: {
                  name = n;
                  value = v;
                }) (collectSubFiles fullPath args)
              )
        else
          [ ];

      collectSubFiles =
        d: args: listToAttrs (concatLists (map (name: collectSubFile d name args) (attrNames (readDir d))));

    in
    listToAttrs (
      map (
        n:
        let
          d = dir + "/${n}";
        in
        if pathExists (d + "/default.nix") then
          {
            name = n;
            value = {
              kind = "directory";
              main = import (d + "/default.nix") args;
              files = collectSubFiles d args;
            };
          }
        else
          throw "Skills directory '${n}' has no default.nix"
      ) subdirs
    );
in
{
  inherit
    listToAttrsUnique
    importDir
    importFlatTree
    importBlocksTree
    importSkillsDir
    ;
}
