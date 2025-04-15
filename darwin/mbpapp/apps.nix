{ ... }:

{
  # Homebrew needs to be installed manually first
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
      cleanup = "zap"; # Uninstalls all formulae (and related files) not listed in the generated Brewfile
    };

    # Mac App Store apps to install
    # Need to install manually once per account
    # To find the ID, click on share and copy the ID in the link
    masApps = {
      Xcode = 497799835;
      Tailscale = 1475387142;
      Notability = 360593530;
    };

    brews = [
      # For SDR++
      "libusb"
      "fftw"
      "glfw"
      "airspy"
      "airspyhf"
      "portaudio"
      "hackrf"
      "rtl-sdr"
      "libbladerf"
      "codec2"
      "zstd"
      "pkg-config"
      "terminal-notifier"
    ];

    casks = [
      {
        name = "iterm2";
      }
      {
        name = "wezterm";
      }

      {
        name = "google-chrome";
      }
      {
        name = "firefox";
      }

      {
        name = "1password";
      }
      {
        name = "bartender";
      }
      {
        name = "bettertouchtool";
      }
      {
        name = "steermouse";
      }

      {
        name = "signal";
      }
      {
        name = "discord";
      }
      {
        name = "chatgpt";
      }

      {
        name = "spotify";
      }

      {
        name = "vlc";
      }
      {
        name = "gimp";
      }

      {
        name = "notion";
      }
      {
        name = "notion-calendar";
      }
      {
        name = "fellow";
      }

      {
        name = "postman";
      }
      {
        name = "wireshark";
      }
      {
        name = "appcleaner";
      }
      {
        name = "blackhole-2ch";
      }
      {
        name = "utm";
      }
    ];
  };
}
