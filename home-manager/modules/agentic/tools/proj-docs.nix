{ pkgs, docsRootLib }:

pkgs.writeShellApplication {
  name = "agentic-proj-docs";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.git
  ];

  text = docsRootLib + ''
    candidates=("$PWD")
    [ -n "''${OPENCODE_ROOT:-}" ] && candidates+=("$OPENCODE_ROOT")
    [ -n "''${CLAUDE_ROOT:-}" ] && candidates+=("$CLAUDE_ROOT")

    # Prints the docs root through the shared rule. Never fails, since its output is
    # embedded in prompts.
    print_docs_root() {
      resolve_docs_root
      echo "$docs_root_report"
    }

    print_proj_files() {
      local kind="$1"
      local proj="$2"
      local file found=0

      echo "Project link ($kind): $proj"
      echo "Project files:"
      for file in "$proj"/*; do
        [ -e "$file" ] || continue
        echo "* $(basename "$file")"
        found=1
      done
      [ "$found" -eq 1 ] || echo "* none"
    }

    select_project() {
      local name="$1"
      local kind="$2"
      local root entry

      for root in "''${candidates[@]}"; do
        entry="$root/$name"
        if [ -L "$entry" ] && [ ! -e "$entry" ] && [ "$name" = "proj-adhoc" ]; then
          continue
        fi

        if [ -e "$entry" ] || [ -L "$entry" ]; then
          if [ -d "$entry" ]; then
            print_proj_files "$kind" "$entry"
            exit 0
          fi

          echo "Invalid $entry: expected a directory or symlink to a directory" >&2
          exit 1
        fi
      done
    }

    print_docs_root

    select_project proj committed
    select_project proj-adhoc ad-hoc

    echo "No project files found."
  '';
}
