{ pkgs }:

pkgs.writeShellApplication {
  name = "agentic-proj-docs";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.git
  ];

  text = ''
    candidates=("$PWD")
    [ -n "''${OPENCODE_ROOT:-}" ] && candidates+=("$OPENCODE_ROOT")
    [ -n "''${CLAUDE_ROOT:-}" ] && candidates+=("$CLAUDE_ROOT")

    # Prints the docs root: git config agentic.docsRoot, else docs/features at
    # the repository root. Never fails, since its output is embedded in prompts.
    print_docs_root() {
      local configured toplevel

      if configured=$(git config --type=path --get agentic.docsRoot 2>/dev/null) && [ -n "$configured" ]; then
        if [ -d "$configured" ]; then
          echo "Docs root: $(readlink -f "$configured") (from git config agentic.docsRoot)"
        else
          # A misconfigured key must stay visible instead of falling back
          echo "Docs root: missing, $configured from git config agentic.docsRoot does not exist"
        fi
        return
      fi

      toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || toplevel="$PWD"
      if [ -d "$toplevel/docs/features" ]; then
        echo "Docs root: $(readlink -f "$toplevel/docs/features") (default docs/features)"
        return
      fi

      echo "Docs root: none, git config agentic.docsRoot unset and no $toplevel/docs/features"
    }

    print_proj_files() {
      local kind="$1"
      local proj="$2"
      local file found=0

      echo "Project link ($kind): $proj"
      echo "Project folder: $(readlink -f "$proj")"
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
