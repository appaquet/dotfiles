{
  pkgs,
  jjInstructions,
}:

let
  agents = [
    "architecture-reviewer"
    "branch-diff-summarizer"
    "code-correctness-reviewer"
    "code-style-reviewer"
    "junior-dev"
    "mid-dev"
    "principal-dev"
    "requirements-reviewer"
    "senior-dev"
    "staff-dev"
  ];
  piAgents = [ "Explore" ];
  claudeCommands = [
    "ask"
    "builder"
    "continue"
    "ctx-check"
    "ctx-improve"
    "ctx-plan"
    "ctx-usage"
    "implement"
    "introspect"
    "jj-absorb"
    "jj-resolve-conflicts"
    "mem-edit"
    "orchestrator"
    "pr-desc"
    "pr-import-comments"
    "pr-reply-comments"
    "proceed"
    "proj-load"
    "proj-plan"
    "proj-save"
    "proj-tidy"
    "review-interactive"
    "review-launch"
    "review-plan"
    "think"
  ];
  commonCommands = builtins.filter (
    command:
    !(builtins.elem command [
      "ctx-usage"
      "orchestrator"
      "builder"
    ])
  ) claudeCommands;
  piCommands = builtins.filter (command: command != "ctx-usage") claudeCommands;
  claudeRules = [
    "development"
    "orchestration"
    "planning"
    "review-comments"
    "reviewer-usage"
    "task-management"
  ];
  opencodeRules = builtins.filter (rule: rule != "planning") claudeRules;
  piRules = [
    "development"
    "orchestration"
    "pi-mode"
    "pi-prompts"
    "pi-questionnaire"
    "pi-workflows"
    "review-comments"
    "reviewer-usage"
    "task-management"
  ];
  claudeSkills = [
    "frontend"
    "human-writer"
    "mem-writing"
    "pi-nix-config"
    "version-control"
  ];
  opencodeSkills = claudeSkills ++ [
    "proj-load"
    "proj-save"
  ];
  piSkills = claudeSkills ++ [
    "pi-recaller"
    "proj-load"
    "proj-save"
    "show-me"
  ];

  filesIn =
    harness: directory: names:
    map (name: "${harness}/${directory}/${name}.md") names;
  skillFiles = harness: names: map (name: "${harness}/skills/${name}/SKILL.md") names;
  expectedFiles = builtins.sort builtins.lessThan (
    [
      "claude/BOM.md"
      "claude/CLAUDE.md"
      "opencode/.gitignore"
      "opencode/AGENTS.md"
      "opencode/BOM.md"
      "pi/AGENTS.md"
      "pi/BOM.md"
    ]
    ++ filesIn "claude" "agents" agents
    ++ filesIn "claude" "commands" claudeCommands
    ++ filesIn "claude" "rules" claudeRules
    ++ skillFiles "claude" claudeSkills
    ++ filesIn "opencode" "agents" agents
    ++ filesIn "opencode" "commands" commonCommands
    ++ filesIn "opencode" "rules" opencodeRules
    ++ skillFiles "opencode" opencodeSkills
    ++ filesIn "pi" "agents" agents
    ++ filesIn "pi" "agents" piAgents
    ++ filesIn "pi" "prompts" piCommands
    ++ filesIn "pi" "rules" piRules
    ++ skillFiles "pi" piSkills
    ++ [ "pi/skills/show-me/template.html" ]
  );
  mkAcceptanceCheck =
    name: instructions:
    let
      expectedVcsContext = "agentic-vcs-context";
      unexpectedVcsContext = "agentic-vcs-context git";
      wrappedVcsContext = "`!`${expectedVcsContext}``";
      manifest = pkgs.writeText "${name}-manifest" "${builtins.concatStringsSep "\n" expectedFiles}\n";
    in
    pkgs.runCommand name { } ''
      set -eu
      : ${instructions.check}
      : ${instructions.package}

      find -L ${instructions.package} -type f -printf '%P\n' \
        | grep -v -E '^(claude|opencode|pi)/(rules/project-doc[.]md|skills/(proj-writing|project-docs)/SKILL[.]md)$' \
        | sort > actual-manifest
      diff -u ${manifest} actual-manifest

      for harness in claude opencode pi; do
        test -n "$(find -L ${instructions.package}/$harness/agents -mindepth 1 -maxdepth 1 -type f -print -quit)"
      done
      test -d ${instructions.package}/claude/commands
      test -d ${instructions.package}/claude/skills
      test -d ${instructions.package}/opencode/commands
      test -d ${instructions.package}/opencode/skills
      test -d ${instructions.package}/pi/prompts
      test -d ${instructions.package}/pi/rules
      test -d ${instructions.package}/pi/skills

      pi=${instructions.package}/pi

      for dir in "$pi/prompts" "${instructions.package}/claude/commands" \
        "${instructions.package}/opencode/commands"; do
        missing=$(grep -L -F '$ARGUMENTS' "$dir"/*.md || true)
        if [ -n "$missing" ]; then
          echo "missing \$ARGUMENTS in: $missing" >&2
          exit 1
        fi
      done

      for harness in pi opencode; do
        leaked=$(grep -l -F '$ARGUMENTS' \
          "${instructions.package}/$harness"/skills/*/SKILL.md || true)
        if [ -n "$leaked" ]; then
          echo "unexpected \$ARGUMENTS in: $leaked" >&2
          exit 1
        fi
      done
      grep -R -F '`Agent`' "$pi"
      grep -R -F '`get_subagent_result`' "$pi"
      grep -R -F '`steer_subagent`' "$pi"
      grep -R -F '`TaskCreate`' "$pi"
      grep -R -F '`ask_user_question`' "$pi"
      ! grep -R -F 'AskUserQuestion' "$pi"
      ! grep -R -F 'EnterPlanMode' "$pi"
      ! grep -R -F 'TaskOutput' "$pi"
      ! grep -R -F 'todowrite' "$pi"
      ! grep -R -F '!`' "$pi"
      ! grep -R -F '@rules/' "$pi"
      ! grep -R -F 'using the `Skill` tool' "$pi"
      ! grep -R -F 'forked context' "$pi"

      for agent in ${builtins.concatStringsSep " " (agents ++ piAgents)}; do
        agent_path="$pi/agents/$agent.md"
        test -f "$agent_path"
        grep -F "name: \"$agent\"" "$agent_path"
        grep -F 'allowed_subagents: false' "$agent_path"
      done

      for harness in claude opencode; do
        root=${instructions.package}/$harness
        orchestration="$root/rules/orchestration.md"
        workflow_open=$(grep -n -m1 '^<sub-agents-workflows>$' "$orchestration" | cut -d: -f1)
        selection_open=$(grep -n -m1 '^<sub-agent-selection>$' "$orchestration" | cut -d: -f1)
        selection_close=$(grep -n -m1 '^</sub-agent-selection>$' "$orchestration" | cut -d: -f1)
        workflow_close=$(grep -n -m1 '^</sub-agents-workflows>$' "$orchestration" | cut -d: -f1)
        test "$workflow_open" -lt "$selection_open"
        test "$selection_open" -lt "$selection_close"
        test "$selection_close" -lt "$workflow_close"
      done

      for path in \
        "${instructions.package}/claude/commands/ctx-plan.md" \
        "${instructions.package}/claude/commands/proj-load.md" \
        "${instructions.package}/claude/commands/proj-plan.md" \
        "${instructions.package}/claude/commands/pr-import-comments.md" \
        "${instructions.package}/claude/agents/branch-diff-summarizer.md" \
        "${instructions.package}/opencode/commands/ctx-plan.md" \
        "${instructions.package}/opencode/commands/proj-load.md" \
        "${instructions.package}/opencode/commands/proj-plan.md" \
        "${instructions.package}/opencode/commands/pr-import-comments.md" \
        "${instructions.package}/opencode/agents/branch-diff-summarizer.md" \
        "${instructions.package}/opencode/skills/proj-load/SKILL.md" \
        "$pi/prompts/ctx-plan.md" \
        "$pi/prompts/proj-load.md" \
        "$pi/prompts/proj-plan.md" \
        "$pi/prompts/pr-import-comments.md" \
        "$pi/agents/branch-diff-summarizer.md" \
        "$pi/skills/proj-load/SKILL.md"; do
        grep -F '${expectedVcsContext}' "$path"
        ! grep -F '${unexpectedVcsContext}' "$path"
        ! grep -F '${wrappedVcsContext}' "$path"
      done

      touch "$out"
    '';
in
{
  jj = mkAcceptanceCheck "agent-instructions-check" jjInstructions;
}
