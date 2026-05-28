let
  inherit (builtins)
    attrNames
    concatLists
    concatStringsSep
    filter
    hasAttr
    isAttrs
    listToAttrs
    map
    match
    pathExists
    readDir
    toString
    ;

  mapAttrsToList = f: attrs: map (name: f name attrs.${name}) (attrNames attrs);

  recursiveUpdate =
    lhs: rhs:
    lhs
    // listToAttrs (
      mapAttrsToList (name: rhsValue: {
        inherit name;
        value =
          if hasAttr name lhs && isAttrs lhs.${name} && isAttrs rhsValue then
            recursiveUpdate lhs.${name} rhsValue
          else
            rhsValue;
      }) rhs
    );

  mergeAll = builtins.foldl' recursiveUpdate { };

  sourceKinds = [
    "blocks"
    "agents"
    "commands"
    "skills"
    "instructions"
  ];

  kindLabels = {
    blocks = "block";
    agents = "agent";
    commands = "command";
    skills = "skill";
    instructions = "authored instruction";
  };

  isReservedHelperPath = relativePath: match "(^|.*/)_support(/.*|$)" relativePath != null;

  collectFragmentFiles =
    root:
    let
      recurse =
        dir: prefix:
        if !pathExists dir then
          [ ]
        else
          let
            entries = readDir dir;
          in
          concatLists (
            map (
              name:
              let
                type = entries.${name};
                fullPath = dir + "/${name}";
                relativePath = if prefix == "" then name else "${prefix}/${name}";
              in
              if isReservedHelperPath relativePath then
                [ ]
              else if type == "directory" then
                recurse fullPath relativePath
              else if
                type == "regular"
                && match ".*\\.nix" name != null
                && relativePath != "lib.nix"
                && relativePath != "default.nix"
              then
                [
                  {
                    path = fullPath;
                    inherit relativePath;
                  }
                ]
              else
                [ ]
            ) (attrNames entries)
          );
    in
    recurse root "";

  sourcesFromFragment =
    fragment:
    let
      imported = import fragment.path;
    in
    if isAttrs imported && imported ? nixantic.sources then imported.nixantic.sources else { };

  artifactEntriesForSources =
    originForOwner: sources:
    concatLists (
      map (
        owner:
        concatLists (
          map (
            kind:
            mapAttrsToList (key: value: {
              inherit
                owner
                kind
                key
                value
                ;
              origin = originForOwner owner;
            }) (sources.${owner}.${kind} or { })
          ) sourceKinds
        )
      ) (attrNames sources)
    );

  artifactEntriesForFragment =
    fragment:
    let
      sources = sourcesFromFragment fragment;
    in
    artifactEntriesForSources (owner: "owner '${owner}' at ${toString fragment.path}") sources;

  artifactEntriesForExplicitSources = artifactEntriesForSources (
    owner: "owner '${owner}' from explicit sources"
  );

  duplicateMessages =
    entries:
    let
      grouped = builtins.groupBy (entry: "${entry.kind}:${entry.key}") entries;
      duplicates = filter (groupKey: builtins.length grouped.${groupKey} > 1) (attrNames grouped);
    in
    map (
      groupKey:
      let
        matches = grouped.${groupKey};
        first = builtins.head matches;
        locations = map (entry: entry.origin) matches;
      in
      "Duplicate ${kindLabels.${first.kind}} key '${first.key}' declared by ${concatStringsSep ", " locations}"
    ) duplicates;

  resolveSources =
    {
      sourceRoots ? [ ],
      sources ? { },
    }:
    let
      fragments = concatLists (map collectFragmentFiles sourceRoots);
      entries =
        concatLists (map artifactEntriesForFragment fragments) ++ artifactEntriesForExplicitSources sources;
      duplicates = duplicateMessages entries;
    in
    assert
      duplicates == [ ]
      || builtins.throw "Duplicate nixantic source fragment keys: ${concatStringsSep "; " duplicates}";
    mergeAll (map sourcesFromFragment fragments ++ [ sources ]);

  discoverSources = root: resolveSources { sourceRoots = [ root ]; };
in
{
  inherit
    collectFragmentFiles
    discoverSources
    isReservedHelperPath
    resolveSources
    ;
}
