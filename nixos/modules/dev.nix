{
  pkgs,
  config,
  ...
}:

{
  environment.systemPackages =
    (with pkgs; [
      distrobox
      sysstat # iostat
    ])
    ++ [
      config.boot.kernelPackages.perf # perf, aligned with current kernel version
    ];
}
