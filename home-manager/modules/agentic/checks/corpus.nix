{
  pkgs,
  jjInstructions,
  gitInstructions,
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
  claudeCommands = [
    "ask"
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
    "orchestrator-on"
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
      "orchestrator-on"
    ])
  ) claudeCommands;
  gitClaudeCommands = builtins.filter (
    command:
    !(builtins.elem command [
      "jj-absorb"
      "jj-resolve-conflicts"
    ])
  ) claudeCommands;
  gitCommands = builtins.filter (command: builtins.elem command gitClaudeCommands) commonCommands;
  claudeRules = [
    "development"
    "orchestration"
    "personal-context"
    "planning"
    "project-doc"
    "review-comments"
    "task-management"
    "version-control"
  ];
  opencodeRules = builtins.filter (rule: rule != "planning") claudeRules;
  piRules = [
    "development"
    "orchestration"
    "personal-context"
    "pi-prompts"
    "pi-questionnaire"
    "pi-workflows"
    "project-doc"
    "review-comments"
    "task-management"
    "version-control"
  ];
  claudeSkills = [
    "human-writer"
    "mem-writing"
    "proj-writing"
  ];
  opencodeSkills = claudeSkills ++ [
    "proj-load"
    "proj-save"
  ];

  filesIn =
    harness: directory: names:
    map (name: "${harness}/${directory}/${name}.md") names;
  skillFiles = harness: names: map (name: "${harness}/skills/${name}/SKILL.md") names;
  expectedFiles =
    claudeCommandsForMode: commonCommandsForMode:
    builtins.sort builtins.lessThan (
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
      ++ filesIn "claude" "commands" claudeCommandsForMode
      ++ filesIn "claude" "rules" claudeRules
      ++ skillFiles "claude" claudeSkills
      ++ filesIn "opencode" "agents" agents
      ++ filesIn "opencode" "commands" commonCommandsForMode
      ++ filesIn "opencode" "rules" opencodeRules
      ++ skillFiles "opencode" opencodeSkills
      ++ filesIn "pi" "agents" agents
      ++ filesIn "pi" "prompts" commonCommandsForMode
      ++ filesIn "pi" "rules" piRules
      ++ skillFiles "pi" claudeSkills
    );
  mkAcceptanceCheck =
    name: instructions: expectedVcs: unexpectedVcs:
    let
      commonCommandsForMode =
        if expectedVcs == "git branch --show-current" then gitCommands else commonCommands;
      claudeCommandsForMode =
        if expectedVcs == "git branch --show-current" then gitClaudeCommands else claudeCommands;
      manifest = pkgs.writeText "${name}-manifest" "${builtins.concatStringsSep "\n" (expectedFiles claudeCommandsForMode commonCommandsForMode)}\n";
    in
    pkgs.runCommand name { } ''
      set -eu
      : ${instructions.check}
      : ${instructions.package}

      find -L ${instructions.package} -type f -printf '%P\n' | sort > actual-manifest
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

      personal_context='My name is AP, using NixOS+MacOS (home manager+nixos+nix darwin) and fish shell'
      grep -F "$personal_context" ${instructions.package}/claude/rules/personal-context.md
      grep -F "$personal_context" ${instructions.package}/opencode/rules/personal-context.md
      grep -F "$personal_context" ${instructions.package}/pi/rules/personal-context.md

      pi=${instructions.package}/pi
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

      grep -F 'Agent Skill guidance' "$pi/prompts/pr-desc.md"
      ! grep -F 'using the `Skill` tool' "$pi/prompts/pr-desc.md"
      ! grep -F 'forked context' "$pi/prompts/pr-desc.md"
      grep -F 'Context: `$ARGUMENTS`' "$pi/prompts/think.md"
      grep -F 'argument-hint: "[problem or context]"' "$pi/prompts/think.md"
      ! grep -F -- "--replace='DB: \$1" "$pi/prompts/pr-reply-comments.md"
      grep -F '`AGENTS.md` is active context' "$pi/skills/mem-writing/SKILL.md"
      grep -F 'Agent Skills under `skills/<name>/SKILL.md`' "$pi/skills/mem-writing/SKILL.md"
      grep -F 'Markdown prompt templates under `prompts/`' "$pi/skills/mem-writing/SKILL.md"

      for agent in ${builtins.concatStringsSep " " agents}; do
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

        grep -F 'Select the agent for each task using <sub-agent-selection>' "$root/commands/ctx-plan.md"
        grep -F 'Select the agent for each task using <sub-agent-selection>' "$root/commands/proj-plan.md"
        grep -F 'select it using <sub-agent-selection>' "$root/skills/proj-writing/SKILL.md"
        grep -F 'reselect using <sub-agent-selection>' "$root/commands/implement.md"
        grep -F 'Use <sub-agents-workflows> for exploration, research and investigation' "$root/commands/ctx-plan.md"
        grep -F 'Use <sub-agents-workflows> for exploration, research and investigation' "$root/commands/proj-plan.md"
        grep -F 'Use <sub-agents-workflows> for exploration, research and investigation' "$root/commands/ctx-improve.md"
        grep -F 'You need to follow <sub-agents-workflows>' "$root/commands/implement.md"
        grep -F 'agentic-proj-create-adhoc' "$root/commands/ctx-plan.md"
      done
      grep -F 'agentic-proj-create-adhoc' "$pi/prompts/ctx-plan.md"

      for version_control in \
        ${instructions.package}/claude/rules/version-control.md \
        ${instructions.package}/opencode/rules/version-control.md \
        "$pi/rules/version-control.md"; do
        grep -F '${expectedVcs}' "$version_control"
        ! grep -F '${unexpectedVcs}' "$version_control"
      done

      touch "$out"
    '';
in
{
  jj =
    mkAcceptanceCheck "agent-instructions-check" jjInstructions "jj-current-branch"
      "git branch --show-current";
  git =
    mkAcceptanceCheck "agent-instructions-git-check" gitInstructions "git branch --show-current"
      "jj-current-branch";
}
