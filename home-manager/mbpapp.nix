{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    inputs.secrets.homeManager.exomind
  ]
  ++ (with inputs.self.modules.homeManager; [
    base
    agentic
    dev
    docker
    ghostty
    media
    work
  ]);

  dotfiles.nono.profiles.machine.filesystem.allow = [
    "$HOME/exomind"
    "$HOME/work/dotcore"
    "$HOME/dotfiles"
  ];
  programs.direnv.config = {
    whitelist = {
      prefix = [
        "/Users/appaquet/work/dotcore/dotcore"
      ];
    };
  };

  dotfiles.hc.space-url.vars = [ "DOTCORE_FRONTEND_ORIGIN" ];

  dotfiles.ssh-agent.defaultSocket = "/Users/appaquet/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock";

  dotfiles.restic.backup = {
    enable = true;
    hostname = "mbpapp";
    sopsFile = config.sops.secretsFiles.home;
    backups.home = {
      paths = [ "/Users/appaquet" ];
      exclude = [
        "Applications"
        "Library"
        "documents_app" # Syncthing
        "Documents" # On iCloud
        "Desktop" # On iCloud
        "Pictures" # On iCloud
      ];
    };
  };

  home.packages = [
    (pkgs.writeShellScriptBin "yt-vlc" ''
      URL=$1
      VIDEO_URL=$(yt-dlp -g -f 136 $URL)
      AUDIO_URL=$(yt-dlp -g -f 'bestaudio' $URL)
      vlc --video-on-top --no-video-title-show $VIDEO_URL --input-slave $AUDIO_URL
    '')
  ];

  home.username = "appaquet";
  home.homeDirectory = "/Users/appaquet";
  home.stateVersion = "23.11";
}
