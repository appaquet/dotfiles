{ ... }:

{
  homebrew = {
    masApps = {
      Notability = 360593530;
    };

    brews = [
      # For SDR++
      "fftw"
      "glfw"
      "airspy"
      "airspyhf"
      "portaudio"
      "hackrf"
      "rtl-sdr"
      "libbladerf"
      "codec2"

      "xcodegen"
    ];

    casks = [
      {
        name = "firefox";
      }
      {
        name = "bartender";
      }
      {
        name = "steermouse";
      }
      {
        name = "istat-menus";
      }
      {
        name = "macwhisper";
      }

      {
        name = "signal";
      }
      {
        name = "discord";
      }
      {
        name = "slack";
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
        name = "bambu-studio";
      }
      {
        name = "thumbhost3mf"; # 3mf finder preview
      }
      {
        name = "autodesk-fusion";
      }

      {
        name = "moonlight";
      }
      {
        name = "syncthing-app";
      }

      {
        name = "notion";
      }

      {
        name = "docker-desktop";
      }
      {
        name = "visual-studio-code";
      }
      {
        name = "wireshark-app";
      }
      {
        name = "blackhole-2ch";
      }
      {
        name = "utm";
      }

      {
        name = "yubico-authenticator";
      }
    ];
  };
}
