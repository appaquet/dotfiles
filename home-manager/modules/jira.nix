{ pkgs, ... }:

{
  home.packages = with pkgs; [
    jira-cli-go
  ];

  programs.fish.shellAbbrs = {
    jiraboard = "jira sprint list --current -a(jira me) --plain --columns \"key,summary,status\" --order-by rank --reverse | fzf --height 40% --reverse --header-lines 1 --preview \"jira issue view {1}\" --preview-window \"right,:+6\" --bind \"e:execute(jira issue edit {1})\" --bind \"m:execute(jira issue move {1})\" --header \"<m> Move to column | <C-r> Reload\"";
    jiralist = "jira sprint list --current -a(jira me) --plain --columns \"key,summary,status\" --order-by rank --reverse";
  };
}
