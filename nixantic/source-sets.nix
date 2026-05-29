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

  # Discovery contract: a sourceRoot is a fragment-only authoring tree. Every
  # non-reserved `.nix` file under it is imported as a fragment and must export
  # `nixantic.sources`; this keeps missing wrappers and accidental misplaced files
  # fail-loud. Keep ordinary helper/generated Nix outside sourceRoots or under a
  # reserved path. Two path shapes are reserved and never discovered:
  #   - `_support/` subtrees hold helper code, not source fragments.
  #   - `tests/` subtrees hold test/fixture trees that must never leak into
  #     shipped output. Consumers keep authored tests under a `tests/` directory
  #     (or outside their sourceRoots entirely).
  isReservedHelperPath =
    relativePath:
    match "(^|.*/)_support(/.*|$)" relativePath != null
    || match "(^|.*/)tests(/.*|$)" relativePath != null;

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
              else if type == "regular" && match ".*\\.nix" name != null then
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

  # A discovered fragment must export `nixantic.sources`. Anything else (a
  # `{ pkgs, lib }:` function, or an attrset that forgot the wrapper) is a
  # misplaced or malformed fragment; fail loudly rather than silently dropping
  # it, so authoring mistakes never vanish from output. Genuine non-fragment
  # files belong under a reserved `_support/` or `tests/` path.
  sourcesFromFragment =
    fragment:
    let
      imported = import fragment.path;
    in
    if isAttrs imported && imported ? nixantic.sources then
      imported.nixantic.sources
    else
      builtins.throw "Discovered nixantic fragment at ${toString fragment.path} does not export nixantic.sources; place non-fragment files under a _support/ or tests/ path";

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
      # Overlapping roots (the same root listed twice, or one nested under
      # another) rediscover the same physical file. Dedup by absolute path so an
      # identical re-discovery is not mistaken for a conflicting declaration;
      # only genuinely distinct files reach the duplicate-key check.
      discoveredFragments = concatLists (map collectFragmentFiles sourceRoots);
      fragments = builtins.attrValues (
        listToAttrs (
          map (fragment: {
            name = toString fragment.path;
            value = fragment;
          }) discoveredFragments
        )
      );
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
