{ renderFrontmatter }:

{
  # REVIEW: Why not just put that in `default.nix` instead?
  claude = import ./claude.nix { inherit renderFrontmatter; };
  opencode = import ./opencode.nix { inherit renderFrontmatter; };
}
