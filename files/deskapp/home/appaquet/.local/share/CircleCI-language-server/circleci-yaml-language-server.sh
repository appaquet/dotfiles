#!/usr/bin/env bash

export PATH=/home/appaquet/.local/share/mise/installs/kubectl/latest/bin:/home/appaquet/.local/share/mise/installs/kubectx/latest/bin:/home/appaquet/.local/share/mise/installs/k9s/latest/bin:/home/appaquet/.cargo/bin:/home/appaquet/.local/utils/:/run/wrappers/bin:/home/appaquet/.nix-profile/bin:/nix/profile/bin:/home/appaquet/.local/state/nix/profile/bin:/etc/profiles/per-user/appaquet/bin:/nix/var/nix/profiles/default/bin:/run/current-system/sw/bin

cd /home/appaquet/.local/share/CircleCI-language-server
/run/current-system/sw/bin/nix-alien-ld circleci-yaml-language-server.old "$@"
