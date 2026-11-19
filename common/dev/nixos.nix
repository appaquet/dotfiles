{
  pkgs,
  ...
}:

{
  environment.systemPackages = with pkgs; [
    distrobox
    perf
    sysstat # iostat
  ];
}
