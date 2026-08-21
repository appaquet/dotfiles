{ lib, renderFrontmatter }:

let
  isSafeRelativePath =
    path:
    builtins.isString path
    && path != ""
    && !(lib.hasPrefix "/" path)
    && builtins.all (part: part != "" && part != "." && part != "..") (lib.splitString "/" path);

  validateOutputPath =
    source: path:
    if isSafeRelativePath path then
      path
    else
      throw "Nixantic ${source} must be a non-empty safe relative path";

  duplicateKeys =
    values:
    builtins.filter (value: builtins.length (builtins.filter (other: other == value) values) > 1) (
      lib.unique values
    );

  validateRendererResult =
    result:
    let
      resultKeys = builtins.attrNames result;
      requiredKeys = [
        "frontmatter"
        "frontmatterOrder"
        "outputPath"
      ];
      frontmatterKeys =
        if builtins.isAttrs result.frontmatter then builtins.attrNames result.frontmatter else [ ];
      order = result.frontmatterOrder;
      duplicateOrder = if builtins.isList order then duplicateKeys order else [ ];
    in
    if resultKeys != requiredKeys then
      throw "Nixantic artifact renderer must return exactly outputPath, frontmatter, and frontmatterOrder"
    else if !builtins.isAttrs result.frontmatter then
      throw "Nixantic artifact renderer frontmatter must be an attrset"
    else if !builtins.isList order || !builtins.all builtins.isString order then
      throw "Nixantic artifact renderer frontmatterOrder must be a list of frontmatter keys"
    else if duplicateOrder != [ ] then
      throw "Nixantic artifact renderer frontmatterOrder contains duplicate keys: ${builtins.concatStringsSep ", " duplicateOrder}"
    else if lib.sort builtins.lessThan order != frontmatterKeys then
      throw "Nixantic artifact renderer frontmatterOrder must contain every frontmatter key exactly once"
    else
      result // { outputPath = validateOutputPath "artifact renderer outputPath" result.outputPath; };

  renderArtifact =
    harness: artifact:
    let
      result = validateRendererResult (harness.renderArtifact artifact);
      outputPath =
        if artifact.authoredOutputPath != null then
          validateOutputPath "authored outputPath" artifact.authoredOutputPath
        else
          result.outputPath;
      frontmatter = renderFrontmatter (
        map (key: {
          label = key;
          value = result.frontmatter.${key};
        }) result.frontmatterOrder
      );
    in
    {
      inherit outputPath;
      kind = artifact.kind;
      role = artifact.role or null;
      embed = if frontmatter == "" then artifact.content else "${frontmatter}\n${artifact.content}";
    };
in
{
  inherit isSafeRelativePath validateRendererResult renderArtifact;
}
