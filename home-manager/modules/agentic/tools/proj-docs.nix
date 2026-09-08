{ pkgs }:

pkgs.writeShellApplication {
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
}
