# A discovered fragment that forgot the `nixantic.sources` wrapper. Discovery
# must fail loudly rather than silently dropping it.
{
  blocks = {
    "orphan-block" = {
      heading = "Orphan Block";
      content = "This block is not wrapped in nixantic.sources";
    };
  };
}
