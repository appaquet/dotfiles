{ renderFrontmatter }:
{
  claude = import ./claude.nix { inherit renderFrontmatter; };
  opencode = import ./opencode.nix { inherit renderFrontmatter; };
}
