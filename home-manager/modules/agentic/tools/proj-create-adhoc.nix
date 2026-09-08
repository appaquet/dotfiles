{ pkgs }:

pkgs.writeShellApplication {
  name = "agentic-proj-create-adhoc";

  runtimeInputs = [
    pkgs.coreutils
  ];

  text = ''
    if [ "$#" -ne 0 ]; then
      echo "Usage: agentic-proj-create-adhoc" >&2
      exit 2
    fi

    workspace_root=$(pwd -P) || {
      echo "Unable to resolve the physical workspace root." >&2
      exit 1
    }
    proj="$workspace_root/proj"
    ad_hoc="$workspace_root/proj-adhoc"

    if [ -e "$proj" ] || [ -L "$proj" ]; then
      echo "Cannot create an ad hoc project: $proj already exists. Remove or finish the existing project first." >&2
      exit 1
    fi

    if [ -L "$ad_hoc" ]; then
      if [ -e "$ad_hoc" ]; then
        echo "Cannot create an ad hoc project: $ad_hoc is an active symlink and will not be replaced." >&2
        exit 1
      fi

      if ! rm "$ad_hoc"; then
        echo "Cannot replace dangling ad hoc project link: failed to remove $ad_hoc." >&2
        exit 1
      fi
    elif [ -e "$ad_hoc" ]; then
      echo "Cannot create an ad hoc project: $ad_hoc exists and is not a dangling symlink." >&2
      exit 1
    fi

    if ! target=$(umask 077 && mktemp -d "''${TMPDIR:-/tmp}/ctx-plan.XXXXXX"); then
      echo "Cannot create a private temporary project directory. Check TMPDIR and available disk space." >&2
      exit 1
    fi

    if ! ln -s "$target" "$ad_hoc"; then
      rm -rf -- "$target"
      echo "Cannot create $ad_hoc. The temporary directory $target was removed." >&2
      exit 1
    fi

    echo "Created ad hoc project link: $ad_hoc"
    echo "Temporary project directory: $target"
  '';
}
