# The one docs-root rule shared by the project tools: git config `agentic.docsRoot`
# (path-typed, so `~` expands), else `docs/features` at the repository root.
#
# This shell text is inlined into `agentic-proj-docs` and `agentic-proj-create`, so
# reporting and creation can never resolve the docs root differently. It leaves its
# result in shell variables and prints nothing, letting each caller choose its own
# wording:
#
#   docs_root_state   configured | default | missing | none
#   docs_root_path    resolved directory; empty for missing and none
#   docs_root_report  the "Docs root: …" line
#
# It never fails, since `agentic-proj-docs` embeds its report in prompts.
_: ''
  # shellcheck disable=SC2034  # each caller reads the subset of these variables it needs
  resolve_docs_root() {
    local configured toplevel

    docs_root_state="none"
    docs_root_path=""
    docs_root_report=""

    if configured=$(git config --type=path --get agentic.docsRoot 2>/dev/null) && [ -n "$configured" ]; then
      if [ -d "$configured" ]; then
        docs_root_state="configured"
        docs_root_path=$(readlink -f "$configured")
        docs_root_report="Docs root: $docs_root_path (from git config agentic.docsRoot)"
      else
        # A misconfigured key must stay visible instead of falling back
        docs_root_state="missing"
        docs_root_report="Docs root: missing, $configured from git config agentic.docsRoot does not exist"
      fi
      return
    fi

    toplevel=$(git rev-parse --show-toplevel 2>/dev/null) || toplevel="$PWD"
    if [ -d "$toplevel/docs/features" ]; then
      docs_root_state="default"
      docs_root_path=$(readlink -f "$toplevel/docs/features")
      docs_root_report="Docs root: $docs_root_path (default docs/features)"
      return
    fi

    docs_root_report="Docs root: none, git config agentic.docsRoot unset and no $toplevel/docs/features"
  }
''
