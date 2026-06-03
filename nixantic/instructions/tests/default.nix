{ pkgs, lib }:

let
  cases = [
    {
      name = "frontmatter";
      result = (import ./frontmatter.nix).allPass;
    }
    {
      name = "dual-output";
      result = (import ./dual-output.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "post-process";
      result = (import ./post-process.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "option-sources";
      result = (import ./option-sources.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "source-sets";
      result = (import ./source-sets.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "install-files";
      result = (import ./install-files.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "package-collisions";
      result = (import ./package-collisions.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "bom";
      result = (import ./bom.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "settings";
      result = (import ./settings.nix { inherit pkgs lib; }).allPass;
    }
  ];

  checkCase = case: if case.result then true else throw "FAIL [${case.name}]";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
