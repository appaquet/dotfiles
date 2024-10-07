{ pkgs, secrets, ... }:

{
  home.packages = with pkgs; [
    jira-cli-go
  ];

  programs.fish = {
    functions.jira-list = "jira sprint list --current -a(jira me) --plain --columns \"key,summary,status\" --order-by rank --reverse";

    shellAbbrs = {
      jb = "jira-board"; # from humanfirst shared
      jl = "jira-list";
    };
  };

  programs.fish.interactiveShellInit = ''
    set -x JIRA_API_TOKEN (cat ${secrets.work.jiraToken})
  '';
}
