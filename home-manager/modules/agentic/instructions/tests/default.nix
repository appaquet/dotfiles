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
      name = "hierarchical-valid";
      result = (import ./hierarchical-valid.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "hierarchical-duplicate-agents";
      result = (import ./hierarchical-duplicate-agents.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "hierarchical-duplicate-blocks";
      result = (import ./hierarchical-duplicate-blocks.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "hierarchical-duplicate-commands";
      result = (import ./hierarchical-duplicate-commands.nix { inherit pkgs lib; }).allPass;
    }
    {
      name = "post-process";
      result = (import ./post-process.nix { inherit pkgs lib; }).allPass;
    }
  ];

  checkCase = case: if case.result then true else throw "FAIL [${case.name}]";

  allPass = builtins.foldl' (acc: case: acc && checkCase case) true cases;
in
{
  inherit allPass;
}
