{ ... }:

{
  # Homebrew needs to be installed manually first
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = true; # Fetch the newest stable branch of Homebrew's git repo
      upgrade = true; # Upgrade outdated casks, formulae, and App Store apps
      # 'zap': uninstalls all formulae(and related files) not listed in the generated Brewfile
      # cleanup = "zap";
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
      "1password"
      "google-chrome"
      "bartender"
      "iterm2"
      "firefox"

      "signal"
      "discord"

      "chatgpt"

      "vlc"
      "gimp"

      "postman"
      "wireshark"
      "appcleaner"
      "spotify"
    ];
  };
}
