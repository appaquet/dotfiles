{
  lib,
  pkgs,
  inputs',
  ...
}:

{
  nixantic = {
    versionControl.mode = lib.mkDefault "jj";
    sourceRoots = [ ./instructions ];

    instructions = {
      postProcess = true;
      harnesses = {
        claude.rules.output = "files";
        opencode.rules.output = "files";
        pi = {
          rules.output = "merge-main";
          agents = "tintinweb";
          tasks = "tintinweb";
          questions = "rpiv-ask-user-question";
        };
      };
    };

    sources.harnesses.skills."herdr-core".main = {
      file = "${inputs'.llm-agents.packages.herdr-core.src}/skills/herdr-core/SKILL.md";
    };

    # The herdr-app source ships its skill without frontmatter, so the body is wrapped here.
    sources.harnesses.skills."herdr-app".main = {
      description = "Control the Herdr window with herdr-app: show, arrange or focus spaces, tabs and panes. Use only to change what the person sees; use herdr-core (hc) to start, read, message or clean up agents and programs.";
      content = builtins.readFile "${inputs'.llm-agents.packages.herdr-app.src}/src/SKILL.md";
    };

    sources.harnesses.skills."security-audit".directory =
      let
        securityAuditSource = pkgs.fetchFromGitHub {
          owner = "cloudflare";
          repo = "security-audit-skill";
          rev = "c1c8a8c1471069fb0e188eeaff69b8e8db6564a8";
          hash = "sha256-g4TIPxoqygW6/U1VwegfsAhDcr4hVsCT+Xec9xbcRNY=";
          postFetch = ''
            cp "$out/LICENSE" "$out/skills/security-audit/LICENSE"
          '';
        };
      in
      "${securityAuditSource}/skills/security-audit";
  };
}
