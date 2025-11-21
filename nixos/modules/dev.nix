{
  pkgs,
  config,
  ...
}:

{
  environment.systemPackages =
    (with pkgs; [
      distrobox
    ])
    ++ [
      config.boot.kernelPackages.perf # perf, aligned with current kernel version
    ];
}
