{ inputs, ... }:
{
  imports =
    (with inputs.self.modules.darwin; [
      base
    ])
    ++ [
      ./apps.nix
    ];

  networking.localHostName = "exapp";
}
