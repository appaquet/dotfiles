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
    ];

    casks = [
      {
        name = "iterm2";
        greedy = true;
      }
      {
        name = "ghostty";
        greedy = true;
      }

      {
        name = "firefox";
        greedy = true;
      }
      {
        name = "google-chrome";
        greedy = true;
      }

      {
        name = "1password";
        greedy = true;
      }
      {
        name = "bartender";
        greedy = true;
      }
      {
        name = "bettertouchtool";
        greedy = true;
      }

      {
        name = "signal";
        greedy = true;
      }
      {
        name = "discord";
        greedy = true;
      }
      {
        name = "chatgpt";
        greedy = true;
      }

      {
        name = "spotify";
        greedy = true;
      }

      {
        name = "vlc";
        greedy = true;
      }
      {
        name = "gimp";
        greedy = true;
      }

      {
        name = "notion";
        greedy = true;
      }
      {
        name = "notion-calendar";
        greedy = true;
      }
      {
        name = "fellow";
        greedy = true;
      }

      {
        name = "postman";
        greedy = true;
      }
      {
        name = "wireshark";
        greedy = true;
      }
      {
        name = "appcleaner";
        greedy = true;
      }
      {
        name = "blackhole-2ch";
        greedy = true;
      }
      {
        name = "utm";
        greedy = true;
      }
    ];
  };
}
