{ wlib, ... }:
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  plugins = {
    version = 2;
    sources = [
      {
        name = "Noctalia Plugins";
        url = "https://github.com/noctalia-dev/noctalia-plugins";
        enabled = true;
      }
    ];
  };
  preInstalledPlugins = {
    niri-display.src = ./plugins/niri-display;
    voxtype.src = ./plugins/voxtype;
  };

  # This is the predefined palette Noctalia normally writes to colors.json.
  colors = {
    mPrimary = "#7aa2f7";
    mOnPrimary = "#16161e";
    mSecondary = "#bb9af7";
    mOnSecondary = "#16161e";
    mTertiary = "#9ece6a";
    mOnTertiary = "#16161e";
    mError = "#f7768e";
    mOnError = "#16161e";
    mSurface = "#1a1b26";
    mOnSurface = "#c0caf5";
    mSurfaceVariant = "#24283b";
    mOnSurfaceVariant = "#9aa5ce";
    mOutline = "#353D57";
    mShadow = "#15161e";
    mHover = "#9ece6a";
    mOnHover = "#16161e";
  };

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
          { id = "plugin:niri-display"; }
          { id = "plugin:voxtype"; }
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
      name = "Blacks Ford";
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
