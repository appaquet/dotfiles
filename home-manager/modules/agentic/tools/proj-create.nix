{ pkgs, docsRootLib }:

pkgs.writeShellApplication {
  name = "agentic-proj-create";

  runtimeInputs = [
    pkgs.coreutils
    pkgs.git
  ];

  text = docsRootLib + ''
    if [ "$#" -ne 1 ]; then
      echo "Usage: agentic-proj-create <project-name>  # the tool builds the dated project folder itself" >&2
      exit 2
    fi

    project_name="$1"

    reject_name() {
      echo "Cannot create a committed project: '$project_name' $1. Pass a bare project name; agentic-proj-create builds the dated project folder itself." >&2
      exit 2
    }

    if [ -z "$project_name" ]; then
      echo "Cannot create a committed project: a project name is required." >&2
      exit 2
    fi

    case "$project_name" in
      -*) reject_name "starts with a dash" ;;
      */*) reject_name "contains a slash" ;;
      [0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*) reject_name "already starts with a date" ;;
    esac

    if [ -e "$project_name" ] || [ -L "$project_name" ]; then
      echo "Cannot create a committed project: '$project_name' is an existing path, not a project name. Pass a bare project name; agentic-proj-create builds the dated project folder itself." >&2
      exit 2
    fi

    workspace_root=$(pwd -P) || {
      echo "Unable to resolve the physical workspace root." >&2
      exit 1
    }
    proj="$workspace_root/proj"

    if [ -e "$proj" ] || [ -L "$proj" ]; then
      echo "Cannot create a committed project link: $proj already exists. Remove or finish the existing project first." >&2
      exit 1
    fi

    resolve_docs_root
    case "$docs_root_state" in
      configured | default) ;;
      *)
        echo "Cannot create a committed project: $docs_root_report. Set git config agentic.docsRoot, or create docs/features at the repository root; agentic-proj-create never creates the docs root." >&2
        exit 1
        ;;
    esac

    # A project keeps one dated folder, found as <docs-root>/<yyyy>/<mm>/<dd>-<project-name>.
    # Re-running the tool re-links that folder, which is how a new jj workspace — each has
    # its own `proj` link — picks an existing project back up without anyone typing a date.
    folders=()
    while IFS= read -r candidate; do
      leaf=''${candidate##*/}
      [ "''${leaf#??-}" = "$project_name" ] && folders+=("$candidate")
    done < <(find "$docs_root_path" -mindepth 3 -maxdepth 3 -type d -name '[0-9][0-9]-*')

    case "''${#folders[@]}" in
      0) ;;
      1) project_folder="''${folders[0]}" ;;
      *)
        echo "Cannot create a committed project: $project_name already has ''${#folders[@]} project folders under $docs_root_path, so the name is ambiguous. List them with: find $docs_root_path -mindepth 3 -maxdepth 3 -type d -name '[0-9][0-9]-*' and pass a more specific project name." >&2
        exit 1
        ;;
    esac

    # Composed here, and only for a new project, so no caller — and no model — ever
    # writes a dated path by hand.
    if [ "''${#folders[@]}" -eq 0 ]; then
      project_folder="$docs_root_path/$(date +%Y/%m/%d)-$project_name"
      if ! mkdir -p "$project_folder"; then
        echo "Cannot create the project folder $project_folder." >&2
        exit 1
      fi
    fi

    if ! ln -s "$project_folder" "$proj"; then
      if [ "''${#folders[@]}" -eq 0 ]; then
        rmdir "$project_folder" 2>/dev/null
        echo "Cannot create $proj. The empty project folder $project_folder was removed." >&2
      else
        echo "Cannot create $proj. The existing project folder $project_folder was left untouched." >&2
      fi
      exit 1
    fi

    echo "Project link created: $proj"
    echo "Project folder (informative — use the project link for all project file access): $project_folder"
  '';
}
