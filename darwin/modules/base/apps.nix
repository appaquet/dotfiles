{ ... }:

{
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated formulae and casks
      cleanup = "zap"; # Uninstalls all formulae (and related files) not listed in the generated Brewfile

      extraEnv = {
        # Prevent homebrew from auto-updating casks that have their own updater
        HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS = "1";
      };
    };

    # Mac App Store apps to install
    # Need to install manually once per account
    # To find the ID, click on share and copy the ID in the link
    masApps = {
      Xcode = 497799835;
      Tailscale = 1475387142;
      iMovie = 408981434;
    };

    brews = [
      "libusb"
      "zstd"
      "pkg-config"

      "terminal-notifier" # notify
      "reattach-to-user-namespace" # pbcopy via tmux
    ];

    casks = [
      {
        name = "ghostty";
      }

      {
        name = "google-chrome";
      }

      {
        name = "1password";
      }
      {
        name = "appcleaner";
      }
      {
        name = "claude";
      }
    ];
  };
}
