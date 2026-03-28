{
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  # To tweak via GUI and capture back to Nix:
  #   1. Temporarily set: outOfStoreConfig = "$HOME/.config/noctalia";
  #   2. Tweak in the GUI
  #   3. Run: dump-noctalia-shell
  #   4. Paste the output back here, remove outOfStoreConfig

  settings = {
    general = {
      terminal = "kitty";
      clockFormat = "h:mm\\nAP";
      animationSpeed = 1;
      radiusRatio = 1;
      enableShadows = true;
      lockOnSuspend = true;
    };
    colorSchemes = {
      predefinedScheme = "Tokyo Night";
      darkMode = true;
    };
    appLauncher = {
      terminalCommand = "kitty -e";
      enableClipboardHistory = true;
      position = "center";
      showCategories = true;
      sortByMostUsed = true;
      viewMode = "list";
    };
    audio = {
      volumeStep = 5;
      volumeOverdrive = false;
      externalMixer = "pwvucontrol || pavucontrol";
    };
    bar = {
      barType = "simple";
      position = "top";
      outerCorners = false;
      exclusive = true;
      floating = false;
      widgets = {
        left = [
          { id = "Launcher"; }
          {
            id = "Clock";
            formatHorizontal = "h:mm AP";
          }
          { id = "SystemMonitor"; }
          { id = "ActiveWindow"; }
          { id = "MediaMini"; }
        ];
        center = [
          { id = "Workspace"; }
        ];
        right = [
          { id = "Tray"; }
          { id = "NotificationHistory"; }
          { id = "VPN"; }
          { id = "Network"; }
          { id = "Battery"; }
          { id = "Volume"; }
          { id = "Brightness"; }
          { id = "ControlCenter"; }
        ];
      };
    };
    calendar = {
      cards = [
        {
          enabled = true;
          id = "calendar-header-card";
        }
        {
          enabled = true;
          id = "calendar-month-card";
        }
        {
          enabled = true;
          id = "timer-card";
        }
        {
          enabled = true;
          id = "weather-card";
        }
      ];
    };
    controlCenter = {
      cards = [
        {
          enabled = true;
          id = "profile-card";
        }
        {
          enabled = true;
          id = "shortcuts-card";
        }
        {
          enabled = true;
          id = "audio-card";
        }
        {
          enabled = true;
          id = "weather-card";
        }
        {
          enabled = true;
          id = "media-sysmon-card";
        }
      ];
      shortcuts = {
        left = [
          { id = "WiFi"; }
          { id = "Bluetooth"; }
        ];
        right = [
          { id = "Notifications"; }
          { id = "PowerProfile"; }
        ];
      };
    };
    dock = {
      enabled = false;
    };
    location = {
      name = "Blacks Ford"; # noctalia geocodes this — no GeoClue auto-detect
      useFahrenheit = true;
      use12hourFormat = true;
      weatherEnabled = true;
      showCalendarWeather = true;
      weatherShowEffects = true;
    };
    nightLight = {
      enabled = false;
    };
    notifications = {
      enabled = true;
      location = "top_right";
    };
    osd = {
      enabled = true;
      location = "top_right";
    };
    wallpaper = {
      enabled = false; # handled by swaybg in niri wrapper
    };
    desktopWidgets = {
      enabled = false;
    };
  };
}
