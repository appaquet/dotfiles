{ pkgs, lib }:

let
  /*
    Recursively or flat-import all .nix files from a directory. Returns attrset keyed by filename
    stem (flat) or relative path (recursive). Skips default.nix. Used by makeScope to discover
    authored blocks, agents, commands, and instructions.
  */
  importDir =
    {
      dir,
      args,
      recursive ? false,
    }:
    let
      inherit (builtins)
        readDir
        attrNames
        match
        listToAttrs
        concatMap
        ;

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

  /*
    Traverses a directory of skill subdirectories, each with a default.nix. Returns attrset keyed
    by directory name. Each value is `{ kind = "directory"; main = <imported data>; files = <subfile
    attrset> }`. Collects .md and .nix subfiles recursively.
  */
  importSkillsDir =
    {
      dir,
      args,
    }:
    let
      inherit (builtins)
        attrNames
        concatLists
        listToAttrs
        match
        pathExists
        readDir
        ;

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
  inherit importDir importSkillsDir;
}
