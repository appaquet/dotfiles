{ pkgs, ... }:

let
  mcp-npx = import ./mcp-npx.nix { inherit pkgs; };
  vcsContext = import ./vcs-context.nix { inherit pkgs; };
  agentic-proj-docs = import ./proj-docs.nix { inherit pkgs; };
  agentic-proj-create-adhoc = import ./proj-create-adhoc.nix { inherit pkgs; };
  agentic-proj-create = import ./proj-create.nix { inherit pkgs; };
  pi-session-query = import ./pi-session-query.nix { inherit pkgs; };
  showMeServe = import ./show-me-serve.nix { inherit pkgs; };
in
{
  home.packages = [
    mcp-npx
    vcsContext
    agentic-proj-docs
    agentic-proj-create-adhoc
    agentic-proj-create
    pi-session-query
    showMeServe
  ];
}
