{ config, pkgs, lib, libs, ... }:

{
  home.packages = with pkgs; [
    any-nix-shell # allows using fish for `nix shell`
  ];

  programs.fish = {
    enable = true;
    package = pkgs.fish;

    interactiveShellInit = ''
      # Disable greeting
      set fish_greeting

      # vi mode
      fish_vi_key_bindings

      # Add support for nix run and nix-shell in fish
      ${pkgs.any-nix-shell}/bin/any-nix-shell fish --info-right | source

      # Term color support + theme
      set -x TERM xterm-256color
      set -g theme_display_cmd_duration no
      set -g theme_display_date no
      set -g theme_newline_cursor yes # have prompt start on sep line
      set -g theme_color_scheme base16 # Use `bobthefish_display_colors --all` to list themes

      # Source any local stuff from .profile
      if test -f ~/.profile
        fenv source ~/.profile
      end

      # Apparently the plugin doesn't do this for us on MacOS for some reason
      fzf_configure_bindings
    '';

    plugins = [
      #{
        #name = "bobthefish";
        #src = pkgs.fetchFromGitHub {
          #owner = "oh-my-fish";
          #repo = "theme-bobthefish";
          #rev = "2dcfcab653ae69ae95ab57217fe64c97ae05d8de";
          #sha256 = "118hj100c4bb8hyhr22mrsjhg97pyd24cwb1l39bhryd0k9yc5lc";
        #};
      #}
      {
        name = "fzf-fish";
        src = pkgs.fishPlugins.fzf-fish.src;
      }
      {
        name = "foreign-env";
        src = pkgs.fishPlugins.foreign-env.src;
      }
    ];

    shellAliases = {
      l = "ls";
      ll = "ls -lash";
      k = "kubectl";
      randstr = "randstr 'tr -cd \"[:alnum:]\" < /dev/urandom | fold -w30 | head -n1'";
      x = "~/dotfiles/x";
    };

    shellAbbrs = {
      gs = "git status";
      gl = "git log";
      gls = "git log --stat";
      glm = "git log --merges --first-parent";
      gd = "git diff";
      gds = "git diff --staged";
      gp = "git pull";
      gck = "git checkout";
      gcm = "git commit -m";
      gchm = "git commit -m (git log -1 --pretty=format:%s)";
      gpom = "git pull origin master";
      gpr = "git pull --rebase --autostash";
      gca = "git commit --amend";
      gr = "git rev-parse --short=7 @";
      grsw = "git restore --staged --worktree";
      grws = "git restore --staged --worktree";
      grs = "git restore --staged";
      ghpr = "gh pr create --draft --body \"\" --title";
      gts = "git tag --sort version:refname";
    };

    functions = {
      # Reload fish with latest paths from nix.
      # If not working, make sure that fish_user_paths are correctly set as explained in the README.
      reload = ''
        set CLEAR (which clear)
        set -e PATH
        set -e __HM_SESS_VARS_SOURCED
        $CLEAR
        ~/.nix-profile/bin/fish
      '';
    };
  };


  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    settings = {
      username = {
        disabled = false;
        show_always = true;
        style_user = "white";
        style_root = "red";
        format = "[$user]($styte)[@](fg:#808080)";
      };

      hostname = {
        ssh_only = false;
        style = "white";
        format = "[$hostname ]($style)";
      };

      gcloud = { disabled = true; };
      nix_shell = { disabled = true; };
      package = { disabled = true; };
      golang = { disabled = true; };
      nodejs = { disabled = true; };
      rust = { disabled = true; };
    };

    #settings = {
      ## adapted from https://gist.github.com/notheotherben/92302a60f8599ba73f1c2840f3c6d455
      #format = lib.concatStrings [
        #"[](fg:#1C4961)" # round start

        #"$username$hostname"
        #"[](fg:#1C4961 bg:#3E7EA0)"

        #"[ $directory](bg:#3E7EA0 fg:#C8E1EE)"
        #"[](fg:#3E7EA0 bg:#5A98B9)"

        #"[ $git_branch ](bg:#5A98B9 fg:#C7D8E1)"
        #"[](fg:#5A98B9 bg:#5EADD7)"

        #"[ $git_status ](bg:#5EADD7 fg:#E1E9ED)"
        #"[](fg:#5EADD7 bg:#79C3EC)"

        #"[ $time ](bg:#79C3EC fg:#F1FAFF)"
        #"[](fg:#79C3EC bg:none)"

        #" $all$character"
      #];

      #add_newline = true;

      #username = {
        #show_always = false;
        #style_user = "bg:#1C4961 fg:#93ACBA";
        #style_root = "bg:#1C4961 fg:#93ACBA";
        #format = "[$user@]($style)";
      #};
      #hostname = {
        #ssh_only = false;
        #style = "bg:#1C4961 fg:#93ACBA";
        #format = "[$hostname]($style)";
      #};
      #directory = {
        #style = "bg:#3E7EA0 fg:#A4C7DA";
        #read_only_style = "bg:#3E7EA0 fg:red";
        #truncate_to_repo = false;
        #truncation_length = 2; # show 2 parent dirs in full length
        #fish_style_pwd_dir_length = 1; # past truncation, shorten parents to 1 char
      #};
      #git_branch = {
        #format = "$symbol$branch";
        #style = "";
      #};
      #git_status = {
        #format = "$all_status$ahead_behind";
        #style = "";
      #};
      #time = {
        #disabled = false;
        #format = "$time";
        #style = "";
      #};

      #gcloud = { disabled = true; };
      #nix_shell = { disabled = true; };
      #package = { disabled = true; };
      #golang = { disabled = true; };
      #nodejs = { disabled = true; };
      #rust = { disabled = true; };
    #};
  };
}
