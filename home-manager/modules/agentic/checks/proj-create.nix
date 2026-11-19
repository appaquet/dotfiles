{ pkgs, projCreate }:

pkgs.runCommand "agentic-proj-create-check"
  {
    nativeBuildInputs = [
      projCreate
      pkgs.git
    ];
  }
  ''
    set -eu

    # Resolved paths keep expectations stable where TMPDIR is a symlink
    TMPDIR=$(readlink -f "$TMPDIR")
    export HOME="$TMPDIR/home"
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME"

    # Expected dates are derived here, never written as a literal dated path
    today=$(date +%Y/%m/%d)
    flat=$(date +%Y-%m-%d)

    init_repo() {
      mkdir -p "$1/docs/features"
      git -C "$1" init -q
    }

    # assert_refusal <directory> <expected fragment> <tool arguments…>
    assert_refusal() {
      directory="$1"
      fragment="$2"
      shift 2
      if (cd "$directory" && agentic-proj-create "$@") > refusal.log 2>&1; then
        echo "Expected agentic-proj-create $* to fail in $directory" >&2
        exit 1
      fi
      if ! grep -qF -- "$fragment" refusal.log; then
        printf 'Expected %s to report:\n%s\nGot:\n%s\n' "$directory" "$fragment" "$(cat refusal.log)" >&2
        exit 1
      fi
    }

    # Created folder and link: the tool composes the dated path itself
    repo="$TMPDIR/repo"
    init_repo "$repo"
    created=$(cd "$repo" && agentic-proj-create demo)
    expected="Project link created: $repo/proj
    Project folder (informative — use the project link for all project file access): $repo/docs/features/$today-demo"
    if [ "$created" != "$expected" ]; then
      printf 'Expected:\n%s\nGot:\n%s\n' "$expected" "$created" >&2
      exit 1
    fi
    case "$(readlink "$repo/proj")" in
      */"$today-demo") ;;
      *)
        echo "Expected $repo/proj to link a slash-separated dated folder $today-demo, got $(readlink "$repo/proj")" >&2
        exit 1
        ;;
    esac
    test -d "$repo/proj"
    test "$(readlink -f "$repo/proj")" = "$repo/docs/features/$today-demo"

    # Configured docs root, resolved through the same rule with ~ expansion
    mkdir -p "$HOME/brain/docs/features"
    configured="$TMPDIR/configured"
    mkdir -p "$configured"
    git -C "$configured" init -q
    git -C "$configured" config agentic.docsRoot '~/brain/docs/features'
    (cd "$configured" && agentic-proj-create cfg) > /dev/null
    test "$(readlink -f "$configured/proj")" = "$HOME/brain/docs/features/$today-cfg"

    # No docs root: refused, and the docs root is never created
    plain="$TMPDIR/plain"
    mkdir -p "$plain"
    assert_refusal "$plain" "Docs root: none" plain-project
    test ! -e "$plain/proj"
    test ! -e "$plain/docs"

    # A project folder that already exists is re-linked rather than refused: this is how a
    # new jj workspace, which carries its own `proj` link, picks the project back up
    relink="$TMPDIR/relink"
    init_repo "$relink"
    mkdir -p "$relink/docs/features/$today-taken"
    relinked=$(cd "$relink" && agentic-proj-create taken)
    expected_relink="Project link created: $relink/proj
    Project folder (informative — use the project link for all project file access): $relink/docs/features/$today-taken"
    if [ "$relinked" != "$expected_relink" ]; then
      printf 'Expected:\n%s\nGot:\n%s\n' "$expected_relink" "$relinked" >&2
      exit 1
    fi
    test "$(readlink -f "$relink/proj")" = "$relink/docs/features/$today-taken"

    # Two dated folders under one name: refused as ambiguous with a listing command, and
    # nothing is created
    ambiguous="$TMPDIR/ambiguous"
    init_repo "$ambiguous"
    year=$(date +%Y)
    first=01
    second=02
    mkdir -p "$ambiguous/docs/features/$year/$first/$first-twice" "$ambiguous/docs/features/$year/$second/$second-twice"
    assert_refusal "$ambiguous" "so the name is ambiguous" twice
    test ! -e "$ambiguous/proj"
    test ! -e "$ambiguous/docs/features/$today-twice"

    # Link already present: refused, and no project folder is created
    linked="$TMPDIR/linked"
    init_repo "$linked"
    touch "$linked/proj"
    assert_refusal "$linked" "already exists" new-project
    test -f "$linked/proj"
    test ! -e "$linked/docs/features/$today-new-project"

    # The old calling style is refused: a relative directory as an existing path, an
    # absolute one as an unusable name
    legacy="$TMPDIR/legacy"
    init_repo "$legacy"
    mkdir -p "$legacy/scratch" "$legacy/docs/features/$today-old"
    assert_refusal "$legacy" "existing path" scratch
    assert_refusal "$legacy" "contains a slash" "$legacy/docs/features/$today-old"
    test ! -e "$legacy/proj"

    # Unusable names
    assert_refusal "$configured" "a project name is required" ""
    assert_refusal "$configured" "starts with a dash" "-x"
    assert_refusal "$configured" "contains a slash" "nested/name"
    assert_refusal "$configured" "already starts with a date" "$flat-dated"
    test "$(readlink -f "$configured/proj")" = "$HOME/brain/docs/features/$today-cfg"

    touch $out
  ''
