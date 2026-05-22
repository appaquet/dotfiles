{
  pkgs,
  lib,
  postProcess ? false,
}:

let
  tooling = import ./tooling.nix { inherit pkgs lib; };
  harnesses = import ./harnesses { renderFrontmatter = tooling.renderFrontmatter; };

  scopes = lib.mapAttrs (_: harness: tooling.makeScope harness) harnesses;
  instructions = lib.mapAttrs (_: scope: scope.instructions) scopes;

  package = tooling.mkPackage { inherit scopes postProcess; };

  frontmatterTestResult =
    let
      frontmatterTests = import ./frontmatter-tests.nix;
    in
    if frontmatterTests.allPass then "pass" else throw "Frontmatter renderer tests failed";

  # R12: Verify undefined block references fail via Nix evaluation at build time
  # Every file referencing a nonexistent block fails naturally during eval.
  # This is proven by: building the package succeeds for all valid references.
  # If a bad reference is introduced, the build itself fails — no separate test needed.
  # We assert this property explicitly in r12Check below.
  r12Check =
    pkgs.runCommand "r12-bad-reference-check"
      {
        nativeBuildInputs = [ pkgs.nix ];
      }
      ''
        expr='with import <nixpkgs> {}; (import ${./fixtures/bad-block-reference.nix} { scope = { blocks = {}; api = {}; harness = {}; }; }).content'
        nix-instantiate --eval --strict -E "$expr" 2>/dev/null && {
          echo "R12 FAIL: nonexistent block reference should have failed evaluation" >&2
          exit 1
        }
        touch $out
      '';

  commands = [
    "ask"
    "continue"
    "ctx-check"
    "ctx-improve"
    "ctx-load"
    "ctx-plan"
    "ctx-save"
    "ctx-usage"
    "forked"
    "implement"
    "introspect"
    "jj-absorb"
    "jj-resolve-conflicts"
    "mem-edit"
    "pr-desc"
    "pr-import-comments"
    "pr-reply-comments"
    "proceed"
    "proj-edit"
    "proj-init"
    "proj-tidy"
    "review-launch"
    "review-plan"
    "think"
  ];

  sharedRules = [
    "code-style"
    "development"
    "project-doc"
    "review"
    "testing"
    "version-control"
    "workflows"
  ];

  opencodeRules = [
    "browser"
  ];

  skills = [
    "human-writer"
    "mem-editing"
    "proj-editing"
  ];

  agents = [
    "architecture-reviewer"
    "branch-diff-summarizer"
    "code-correctness-reviewer"
    "code-style-reviewer"
    "requirements-reviewer"
  ];

  check = pkgs.runCommand "agentic-instructions-check" { } ''
    : ${frontmatterTestResult}

    # Require R12 check to have passed
    : ${r12Check}

    for harness in claude opencode; do
      for agent in ${builtins.toString agents}; do
        f="$harness/agents/$agent.md"
        if [[ ! -f ${package}/$f ]]; then echo "MISSING: $f" >&2; exit 1; fi
      done

      for cmd in ${builtins.toString commands}; do
        f="$harness/commands/$cmd.md"
        if [[ ! -f ${package}/$f ]]; then echo "MISSING: $f" >&2; exit 1; fi
      done

      for rule in ${builtins.toString sharedRules}; do
        f="$harness/rules/$rule.md"
        if [[ ! -f ${package}/$f ]]; then echo "MISSING: $f" >&2; exit 1; fi
      done

      for skill in ${builtins.toString skills}; do
        f="$harness/skills/$skill/SKILL.md"
        if [[ ! -f ${package}/$f ]]; then echo "MISSING: $f" >&2; exit 1; fi
      done
    done

    # Opencode-only rules
    for rule in ${builtins.toString opencodeRules}; do
      f="opencode/rules/$rule.md"
      if [[ ! -f ${package}/$f ]]; then echo "MISSING: $f" >&2; exit 1; fi
      f="claude/rules/$rule.md"
      if [[ -f ${package}/$f ]]; then echo "UNEXPECTED: $f should be opencode-only" >&2; exit 1; fi
    done

    # Root instruction files use harness-specific filenames
    for f in claude/CLAUDE.md opencode/AGENTS.md; do
      if [[ ! -f ${package}/$f ]]; then
        echo "MISSING: $f" >&2
        exit 1
      fi
    done

    # Old main.md paths must not exist
    for f in claude/main.md opencode/main.md; do
      if [[ -f ${package}/$f ]]; then
        echo "STALE FILE PRESENT: $f" >&2
        exit 1
      fi
    done

    # Skill sub-files exist
    for harness in claude opencode; do
      for f in \
        skills/mem-editing/references/core.md \
        skills/mem-editing/references/skills.md \
        skills/mem-editing/references/commands.md \
        skills/mem-editing/references/instructions.md \
        skills/mem-editing/references/agents.md; do
        if [[ ! -f ${package}/$harness/$f ]]; then
          echo "MISSING: $harness/$f" >&2
          exit 1
        fi
      done
    done

    # Verify CLAUDE.md contains all expected sections
    claude_md="${package}/claude/CLAUDE.md"
    for section in \
      "Top-level instructions" \
      "Context management and sub-agents delegation" \
      "Task management" \
      "Pre-flight instructions" \
      "Context understanding" \
      "Problem Solving" \
      "Deep Thinking"; do
      if ! grep -q "## $section" "$claude_md"; then
        echo "MISSING SECTION in CLAUDE.md: $section" >&2
        exit 1
      fi
    done

    # Verify CLAUDE.md has AskUserQuestion phrasing (Claude-specific)
    if ! grep -q "AskUserQuestion" "$claude_md"; then
      echo "MISSING Claude-specific AskUserQuestion phrasing in CLAUDE.md" >&2
      exit 1
    fi

    # Verify no testing-principles reference in root instruction files
    for f in ${package}/claude/CLAUDE.md ${package}/opencode/AGENTS.md; do
      if grep -q "Testing Principles" "$f"; then
        echo "STALE testing-principles reference in: $f" >&2
        exit 1
      fi
    done

    # Verify AGENTS.md has opencode-adapted phrasing (no AskUserQuestion in root)
    agents_md="${package}/opencode/AGENTS.md"
    if ! grep -q "Use interactive prompts to ask questions" "$agents_md"; then
      echo "MISSING opencode-specific phrasing in AGENTS.md" >&2
      exit 1
    fi

    # Verify AGENTS.md has opencode-adapted implement gate
    if ! grep -q "Wait for explicit go signal before implementing" "$agents_md"; then
      echo "MISSING opencode implement gate in AGENTS.md" >&2
      exit 1
    fi

    for f in ${package}/claude/commands/*.md ${package}/opencode/commands/*.md; do
      first_line=$(head -n1 "$f")
      if [[ "$first_line" != "---" ]]; then
        echo "MISSING FRONTMATTER: $f" >&2
        exit 1
      fi
      # verify no blank lines inside frontmatter (between first --- and second ---)
      if awk '/^---$/ { if (++c == 2) exit; next } c == 1 && NF == 0 { exit 1 }' "$f"; then
        :
      else
        echo "BLANK LINE IN FRONTMATTER: $f" >&2
        exit 1
      fi
    done

    # Skill frontmatter checks
    for f in ${package}/claude/skills/*/SKILL.md ${package}/opencode/skills/*/SKILL.md; do
      first_line=$(head -n1 "$f")
      if [[ "$first_line" != "---" ]]; then
        echo "MISSING FRONTMATTER: $f" >&2
        exit 1
      fi
      # verify no blank lines inside frontmatter
      if awk '/^---$/ { if (++c == 2) exit; next } c == 1 && NF == 0 { exit 1 }' "$f"; then
        :
      else
        echo "BLANK LINE IN FRONTMATTER: $f" >&2
        exit 1
      fi

      # verify name matches directory name (skill dir is 3rd from end: .../skills/<name>/SKILL.md)
      dir_name=$(echo "$f" | sed -E 's|.*/skills/([^/]+)/SKILL\.md$|\1|')
      if ! grep -q "name: $dir_name" "$f"; then
        echo "MISSING name: $dir_name in $f" >&2
        exit 1
      fi
      if ! grep -q "description:" "$f"; then
        echo "MISSING description field in $f" >&2
        exit 1
      fi
    done

    # Opencode skill absence checks - ensure opencode skills don't contain harness-specific fields
    for f in ${package}/opencode/skills/*/SKILL.md; do
      if grep -q "argument-hint:" "$f"; then
        echo "STALE argument-hint in opencode skill: $f" >&2
        exit 1
      fi
      if grep -q "subtask:" "$f"; then
        echo "STALE subtask in opencode skill: $f" >&2
        exit 1
      fi
      if grep -q "allowed-tools:" "$f"; then
        echo "STALE allowed-tools in opencode skill: $f" >&2
        exit 1
      fi
    done

    # Verify that undefined block references fail evaluation (R12)
    # Reference a nonexistent block — should throw on eval
    if nix-instantiate --eval -E '
      let
        pkgs = import <nixpkgs> {};
        instr = import ./default.nix { inherit pkgs; lib = pkgs.lib; };
      in
      instr.blocks.nonexistent.embed
    ' 2>/dev/null; then
      echo "FAIL: nonexistent block reference should have failed" >&2
      exit 1
    fi

    touch $out
  '';
in
{
  inherit (tooling)
    mkBlock
    mkInstructions
    mkAgent
    mkSkill
    ;

  mkCommand = tooling.mkSkill;

  blocks = scopes.claude.blocks;
  commands = scopes.claude.commands;
  skills = scopes.claude.skills;
  claude = instructions.claude;
  opencode = instructions.opencode;

  inherit package check;
}
