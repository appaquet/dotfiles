{ pkgs }:
let
  inherit (pkgs) lib;

  # One body file per command. jj-lib.sh is concatenated in front of each body, so a body
  # holds only its own logic while every command shares one set of shell options and
  # helpers.
  bodies = {
    jj-current-branch = ./scripts/jj-current-branch.sh;
    jj-diff-branch = ./scripts/jj-diff-branch.sh;
    jj-diff-unreviewed = ./scripts/jj-diff-unreviewed.sh;
    jj-diff-working = ./scripts/jj-diff-working.sh;
    jj-main-branch = ./scripts/jj-main-branch.sh;
    jj-prev-branch = ./scripts/jj-prev-branch.sh;
    jj-proj-tug = ./scripts/jj-proj-tug.sh;
    jj-promote = ./scripts/jj-promote.sh;
    jj-stacked-branches = ./scripts/jj-stacked-branches.sh;
    jj-stacked-stats = ./scripts/jj-stacked-stats.sh;
    jj-unreviewed-base = ./scripts/jj-unreviewed-base.sh;
    jj-workspace-add = ./scripts/jj-workspace-add.sh;
    jj-workspace-branch = ./scripts/jj-workspace-branch.sh;
    jj-workspace-delete = ./scripts/jj-workspace-delete.sh;
    jj-workspace-exists = ./scripts/jj-workspace-exists.sh;
    jj-workspace-herdr = ./scripts/jj-workspace-herdr.sh;
    jj-workspace-name = ./scripts/jj-workspace-name.sh;
    jj-workspace-path = ./scripts/jj-workspace-path.sh;
    jj-workspace-select = ./scripts/jj-workspace-select.sh;
    jj-workspace-tmux = ./scripts/jj-workspace-tmux.sh;
  };

  wrap =
    name: body:
    pkgs.writeShellScriptBin name (builtins.readFile ./scripts/jj-lib.sh + builtins.readFile body);
in
pkgs.symlinkJoin {
  name = "jj-utils";
  paths = lib.mapAttrsToList wrap bodies;
}
