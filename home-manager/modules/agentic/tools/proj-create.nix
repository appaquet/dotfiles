{ pkgs }:

pkgs.writeShellApplication {
  name = "agentic-proj-create";

  runtimeInputs = [
    pkgs.coreutils
  ];

  text = ''
    if [ "$#" -ne 1 ]; then
      echo "Usage: agentic-proj-create <docs-directory>" >&2
      exit 2
    fi

    workspace_root=$(pwd -P) || {
      echo "Unable to resolve the physical workspace root." >&2
      exit 1
    }
    docs_directory="$1"
    proj="$workspace_root/proj"

    if [ ! -d "$docs_directory" ]; then
      echo "Cannot create a committed project link: $docs_directory is not an existing directory." >&2
      exit 1
    fi

    if [ -e "$proj" ] || [ -L "$proj" ]; then
      echo "Cannot create a committed project link: $proj already exists. Remove or finish the existing project first." >&2
      exit 1
    fi

    if ! ln -s "$docs_directory" "$proj"; then
      echo "Cannot create $proj." >&2
      exit 1
    fi

    echo "Created committed project link: $proj -> $(readlink -f "$proj")"
  '';
}
