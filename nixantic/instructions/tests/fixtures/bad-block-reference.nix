{ scope }:
{
  content = ''
    This references a nonexistent block: ${scope.blocks.nonexistent.embed}
  '';
}
