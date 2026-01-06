{ ... }:
{
  # Inspired from https://github.com/ryan4yin/nix-darwin-kickstarter/blob/main/rich-demo/modules/system.nix
  system = {
    keyboard = {
      enableKeyMapping = true;
      remapCapsLockToEscape = true;
    };

    defaults = {
      menuExtraClock.Show24Hour = true;

      dock = {
        tilesize = 32; # icon size
        magnification = true;
        largesize = 70; # magnification size

        # Hot corners
        wvous-bl-corner = 2; # bottom left = Mission Control
        wvous-br-corner = 5; # bottom right = Screen Saver

        # Spaces
        mru-spaces = false; # disable reordering spaces based on most recent use
      };

      spaces = {
        spans-displays = false; # each screen has their own spaces
      };

      loginwindow = {
        GuestEnabled = false; # disable guest user
      };

      WindowManager = {
        EnableStandardClickToShowDesktop = false; # prevent expose when clicking on the desktop
        EnableTiledWindowMargins = false; # disable window margins when snapping / tiling windows
      };

      finder = {
        AppleShowAllExtensions = true; # show all file extensions
        FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
        QuitMenuItem = true; # enable quit menu item
        ShowPathbar = true; # show path bar
        ShowStatusBar = true; # show status bar
      };

      trackpad = {
        Clicking = true; # enable tap to click
        TrackpadRightClick = true; # enable two finger right click
      };

      screencapture = {
        location = "~/DocumentsApp/Screenshots/";
        type = "png";
      };

      # Customize settings that not supported by nix-darwin directly
      # Incomplete list of macOS `defaults` commands :
      #   https://github.com/yannbertrand/macos-defaults
      # Use `defaults read NSGlobalDomain` to list all custom settings
      NSGlobalDomain = {
        AppleInterfaceStyle = "Dark";
        AppleInterfaceStyleSwitchesAutomatically = false; # don't switch automatically

        # Finder
        AppleShowAllExtensions = true; # show all file extensions

        # Keyboard
        InitialKeyRepeat = 15; # normal minimum is 15 (225 ms), maximum is 120 (1800 ms)
        KeyRepeat = 2; # normal minimum is 2 (30 ms), maximum is 120 (1800 ms)
        ApplePressAndHoldEnabled = false; # long press doesn't show accented chars selector
        "com.apple.keyboard.fnState" = true; # use F1, F2, etc. keys as standard function keys
        NSAutomaticPeriodSubstitutionEnabled = false; # prevent adding a `.` after two consecutive spaces

        # Trackpad
        "com.apple.swipescrolldirection" = true; # enable natural scrolling
      };

      # Customize settings that not supported by nix-darwin directly
      # see the source code of this project to get more undocumented options:
      #    https://github.com/rgcr/m-cli
      #
      # All custom entries can be found by running `defaults read` command.
      # or `defaults read xxx` to read a specific domain.
      CustomUserPreferences = {
        NSGlobalDomain = {
          AppleLanguages = [
            "en"
            "en-CA"
            "fr-CA"
          ];

          SLSMenuBarUseBlurredAppearance = true; # enable translucent menu bar, fixes white bars in tahoe
        };

        "com.apple.screensaver" = {
          # Require password immediately after sleep or screen saver begins
          askForPassword = 1;
          askForPasswordDelay = 0;
        };

        "com.apple.HIToolbox" = {
          AppleGlobalTextInputProperties = {
            TextInputGlobalPropertyPerContextInput = true; # per-input source language
          };
        };
      };
    };
  };
}
