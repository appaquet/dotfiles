{ pkgs, ... }:

let
  # npx wrapper for mcp use in coding agents
  mcp-npx = pkgs.writeShellScriptBin "mcp-npx" ''
    export PATH="$PATH:${pkgs.nodejs}/bin"
    npx "$@"
  '';

  agentic-proj-docs = pkgs.writeShellApplication {
    name = "agentic-proj-docs";

    runtimeInputs = [
      pkgs.coreutils
    ];

    text = ''
      candidates=("$PWD")
      [ -n "''${OPENCODE_ROOT:-}" ] && candidates+=("$OPENCODE_ROOT")
      [ -n "''${CLAUDE_ROOT:-}" ] && candidates+=("$CLAUDE_ROOT")
      print_proj_files() {
        local label="$1"
        local proj="$2"
        local abs

        abs=$(readlink -f "$proj")
        echo "$label ($abs) files:"
        ls "$proj/"
      }

      select_project() {
        local name="$1"
        local root entry

        for root in "''${candidates[@]}"; do
          entry="$root/$name"
          if [ -L "$entry" ] && [ ! -e "$entry" ] && [ "$name" = "proj-adhoc" ]; then
            continue
          fi

          if [ -e "$entry" ] || [ -L "$entry" ]; then
            if [ -d "$entry" ]; then
              print_proj_files "$entry" "$entry"
              exit 0
            fi

            echo "Invalid $entry: expected a directory or symlink to a directory" >&2
            exit 1
          fi
        done
      }

      select_project proj
      select_project proj-adhoc

      echo "No project files found."
    '';
  };

  agentic-proj-create-adhoc = pkgs.writeShellApplication {
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
  };
in
{
  home.packages = [
    mcp-npx
    agentic-proj-docs
    agentic-proj-create-adhoc
  ];
}
