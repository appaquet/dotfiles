{
  package,
  pkgs,
  frontmatterTestResult,
  dualOutputTestResult,
  hierarchicalValidTestResult,
  hierarchicalDupAgentsTestResult,
  hierarchicalDupBlocksTestResult,
  hierarchicalDupCmdsTestResult,
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
        expr='(import ${./fixtures/bad-block-reference.nix} { scope = { blocks = {}; api = {}; harness = {}; }; }).content'
        err="$TMPDIR/bad-ref-check-err"
        nix-instantiate --eval --strict -E "$expr" 2>"$err" && {
          echo "FAIL: nonexistent block reference should have failed evaluation" >&2
          exit 1
        }
        grep -q 'nonexistent' "$err" || {
          echo "FAIL: nonexistent block reference failed for an unexpected reason" >&2
          cat "$err" >&2
          exit 1
        }
        touch $out
      '';
in
pkgs.runCommand "agentic-instructions-check" { } ''
  : ${frontmatterTestResult}
  : ${dualOutputTestResult}
  : ${hierarchicalValidTestResult}
  : ${hierarchicalDupAgentsTestResult}
  : ${hierarchicalDupBlocksTestResult}
  : ${hierarchicalDupCmdsTestResult}
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

  # Verify harness-filtered commands only render for selected harnesses
  test -f ${package}/claude/commands/orchestrator.md || { echo "MISSING: claude/commands/orchestrator.md" >&2; exit 1; }
  test ! -f ${package}/opencode/commands/orchestrator.md || { echo "STALE: opencode/commands/orchestrator.md" >&2; exit 1; }

  # Verify the reverse direction: an opencode-only definition (rules/browser.nix,
  # harnesses = ["opencode"]) renders for opencode and is absent from Claude output.
  test -f ${package}/opencode/rules/browser.md || { echo "MISSING: opencode/rules/browser.md" >&2; exit 1; }
  test ! -f ${package}/claude/rules/browser.md || { echo "STALE: claude/rules/browser.md" >&2; exit 1; }

  # Verify CLAUDE.md contains expected sections
  claude_md="${package}/claude/CLAUDE.md"
  for section in \
    "Top-level instructions" \
    "Sub-agents workflows" \
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

  # Verify AGENTS.md carries the core question-asking and implement-gate guidance
  agents_md="${package}/opencode/AGENTS.md"
  grep -q "finish a message with a list of questions" "$agents_md" || {
    echo "MISSING question-asking guidance in AGENTS.md" >&2; exit 1;
  }
  grep -q "NEVER implement until you receive this exact signal" "$agents_md" || {
    echo "MISSING implement gate in AGENTS.md" >&2; exit 1;
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

  # Verify command pre-flight injection defaults and opt-outs
  preflight='Imperative follow <pre-flight> instructions before doing anything'
  preflight_count() {
    grep -F -c "$preflight" "$1" || true
  }
  assert_preflight_count() {
    expected="$1"
    f="$2"
    count=$(preflight_count "$f")
    [[ "$count" == "$expected" ]] || {
      echo "WRONG pre-flight count in $f: expected $expected, got $count" >&2; exit 1;
    }
  }

  for f in ${package}/claude/commands/*.md ${package}/opencode/commands/*.md; do
    cmd=$(basename "$f" .md)
    if [[ "$cmd" == "continue" ]]; then
      assert_preflight_count 0 "$f"
    else
      assert_preflight_count 1 "$f"
    fi
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
    assert_preflight_count 1 "$f"
  done

  # Verify opencode skills from commands omit Claude-specific fields
  for cmd in ctx-load ctx-save; do
    grep -q "argument-hint:" ${package}/opencode/skills/$cmd/SKILL.md && {
      echo "STALE argument-hint in opencode dual-output skill ($cmd)" >&2; exit 1;
    }
  done

  # ── Hierarchical authoring assertions ─────────────────────────────────────

  # Verify no nested output paths: agent and command output files must be flat,
  # even when source files are organized in subdirectories.
  for harness in claude opencode; do
    for nested_dir in agents/reviewers agents/other commands/project; do
      if test -d ${package}/$harness/$nested_dir; then
        echo "STALE: hierarchical source directory leaked into output: $harness/$nested_dir" >&2; exit 1;
      fi
    done
  done

  # Verify block content from local blocks/ (moved reviewing-agent.nix) still
  # appears in generated reviewer agent .md files. The reviewing-agent block
  # was moved from global blocks/ to agents/reviewers/blocks/ — this proves the
  # multi-root block import works correctly.
  reviewer_block_string="Sub-agent Rules"
  for harness in claude opencode; do
    for agent in code-style-reviewer code-correctness-reviewer architecture-reviewer requirements-reviewer; do
      f=${package}/$harness/agents/$agent.md
      if test -f "$f"; then
        grep -q -F "$reviewer_block_string" "$f" || {
          echo "MISSING reviewing-agent block content in: $f" >&2; exit 1;
        }
      fi
    done
  done

  # Verify no blocks/ subdirectories leak into skill output.
  for harness in claude opencode; do
    if test -d ${package}/$harness/skills; then
      for skill_dir in ${package}/$harness/skills/*/; do
        if test -d "${skill_dir}blocks"; then
          echo "STALE: blocks/ subdirectory leaked into skill output: ${skill_dir}blocks" >&2; exit 1;
        fi
      done
    fi
  done

  touch $out
''
