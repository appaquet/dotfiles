{
  package,
  pkgs,
  frontmatterTestResult,
}:

let
  # Verify that referencing a nonexistent block fails Nix evaluation.
  # Proves the Nix-level reference validation mechanism works at build time.
  badRefCheck =
    pkgs.runCommand "bad-block-reference-check"
      {
        nativeBuildInputs = [ pkgs.nix ];
      }
      ''
        expr='with import <nixpkgs> {}; (import ${./fixtures/bad-block-reference.nix} { scope = { blocks = {}; api = {}; harness = {}; }; }).content'
        nix-instantiate --eval --strict -E "$expr" 2>/dev/null && {
          echo "FAIL: nonexistent block reference should have failed evaluation" >&2
          exit 1
        }
        touch $out
      '';
in
pkgs.runCommand "agentic-instructions-check" { } ''
  : ${frontmatterTestResult}
  : ${badRefCheck}

  # Verify output directory structure
  for harness in claude opencode; do
    for dir in commands agents rules skills; do
      test -d ${package}/$harness/$dir || {
        echo "MISSING directory: $harness/$dir" >&2; exit 1;
      }
    done
  done

  # Verify root instruction files exist with correct filenames
  test -f ${package}/claude/CLAUDE.md || { echo "MISSING: claude/CLAUDE.md" >&2; exit 1; }
  test -f ${package}/opencode/AGENTS.md || { echo "MISSING: opencode/AGENTS.md" >&2; exit 1; }

  # Verify stale main.md does not exist
  test ! -f ${package}/claude/main.md || { echo "STALE: claude/main.md" >&2; exit 1; }
  test ! -f ${package}/opencode/main.md || { echo "STALE: opencode/main.md" >&2; exit 1; }

  # Verify CLAUDE.md contains expected sections
  claude_md="${package}/claude/CLAUDE.md"
  for section in \
    "Top-level instructions" \
    "Context management and sub-agents delegation" \
    "Task management" \
    "Pre-flight instructions" \
    "Context understanding" \
    "Problem Solving" \
    "Deep Thinking"; do
    grep -q "## $section" "$claude_md" || {
      echo "MISSING SECTION in CLAUDE.md: $section" >&2; exit 1;
    }
  done

  # Verify CLAUDE.md has Claude-specific phrasing
  grep -q "AskUserQuestion" "$claude_md" || {
    echo "MISSING Claude-specific phrasing in CLAUDE.md" >&2; exit 1;
  }

  # Verify AGENTS.md has opencode-adapted phrasing
  agents_md="${package}/opencode/AGENTS.md"
  grep -q "Use interactive prompts to ask questions" "$agents_md" || {
    echo "MISSING opencode phrasing in AGENTS.md" >&2; exit 1;
  }
  grep -q "Wait for explicit go signal before implementing" "$agents_md" || {
    echo "MISSING opencode implement gate in AGENTS.md" >&2; exit 1;
  }

  # Verify no testing-principles reference in root instruction files
  for f in ${package}/claude/CLAUDE.md ${package}/opencode/AGENTS.md; do
    grep -q "Testing Principles" "$f" && {
      echo "STALE testing-principles reference in: $f" >&2; exit 1;
    }
  done

  # Verify command frontmatter validity across all harnesses
  for f in ${package}/claude/commands/*.md ${package}/opencode/commands/*.md; do
    first_line=$(head -n1 "$f")
    [[ "$first_line" != "---" ]] && { echo "MISSING FRONTMATTER: $f" >&2; exit 1; }
    # No blank lines inside frontmatter block (between --- delimiters)
    awk '/^---$/ { if (++c == 2) exit; next } c == 1 && NF == 0 { exit 1 }' "$f" || {
      echo "BLANK LINE IN FRONTMATTER: $f" >&2; exit 1;
    }
  done

  # Verify skill frontmatter validity across all harnesses
  for f in ${package}/claude/skills/*/SKILL.md ${package}/opencode/skills/*/SKILL.md; do
    first_line=$(head -n1 "$f")
    [[ "$first_line" != "---" ]] && { echo "MISSING FRONTMATTER: $f" >&2; exit 1; }
    awk '/^---$/ { if (++c == 2) exit; next } c == 1 && NF == 0 { exit 1 }' "$f" || {
      echo "BLANK LINE IN FRONTMATTER: $f" >&2; exit 1;
    }
    # Skill name must match directory name
    dir_name=$(echo "$f" | sed -E 's|.*/skills/([^/]+)/SKILL\.md$|\1|')
    grep -q "name: $dir_name" "$f" || {
      echo "MISSING name: $dir_name in $f" >&2; exit 1;
    }
    grep -q "description:" "$f" || {
      echo "MISSING description field in $f" >&2; exit 1;
    }
  done

  # Verify opencode skills omit Claude-specific frontmatter fields
  for f in ${package}/opencode/skills/*/SKILL.md; do
    for field in argument-hint subtask allowed-tools; do
      grep -q "$field:" "$f" && {
        echo "STALE $field in opencode skill: $f" >&2; exit 1;
      }
    done
  done

  # Verify dual-output: ctx-load and ctx-save also appear as opencode skills
  for cmd in ctx-load ctx-save; do
    test -f ${package}/opencode/skills/$cmd/SKILL.md || { echo "MISSING: opencode dual-output skill from $cmd" >&2; exit 1; }
  done

  # Verify Claude does NOT get redundant skill output (Claude treats commands as skills natively)
  for cmd in ctx-load ctx-save; do
    test ! -f ${package}/claude/skills/$cmd/SKILL.md || { echo "STALE: claude should NOT have dual-output skill for $cmd" >&2; exit 1; }
  done

  # Verify dual-output skill frontmatter for opencode
  for cmd in ctx-load ctx-save; do
    f=${package}/opencode/skills/$cmd/SKILL.md
    grep -q "name: $cmd" "$f" || { echo "MISSING name in dual-output skill-from-$cmd: $f" >&2; exit 1; }
    grep -q "description:" "$f" || { echo "MISSING description in dual-output skill-from-$cmd: $f" >&2; exit 1; }
  done

  # Verify opencode skills from commands omit Claude-specific fields
  for cmd in ctx-load ctx-save; do
    grep -q "argument-hint:" ${package}/opencode/skills/$cmd/SKILL.md && {
      echo "STALE argument-hint in opencode dual-output skill ($cmd)" >&2; exit 1;
    }
  done

  touch $out
''
