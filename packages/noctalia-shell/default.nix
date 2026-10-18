{
  lib,
  pkgs,
  wlib,
  ...
}:
{
  imports = [ wlib.wrapperModules.noctalia-shell ];

  package = pkgs.noctalia-shell.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ./patches/system-monitor-gpu-telemetry.patch
      ./patches/system-monitor-bar-gpu-usage.patch
      ./patches/system-monitor-panel-gpu-card.patch
      ./patches/system-monitor-stable-widths.patch
      ./patches/system-monitor-adaptive-compact-mode.patch
    ];

    # Intel xe has no gpu_busy_percent. The pinned nvtop and jq parser are
    # substituted into the telemetry command, keeping every executable it uses
    # in the runtime closure.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace Services/System/SystemStatService.qml \
        --replace-fail @intelNvtop@ ${pkgs.nvtopPackages.intel} \
        --replace-fail @jq@ ${lib.getExe' pkgs.jq "jq"} \
        --replace-fail @gawk@ ${pkgs.gawk} \
        --replace-fail @nvidiaSmi@ ${lib.getBin pkgs.linuxPackages.nvidia_x11} \
        --replace-fail @coreutils@ ${pkgs.coreutils} \
        --replace-fail @bash@ ${pkgs.bash}

      # Tray items without a tooltip fell back to their StatusNotifierItem id,
      # which Tauri apps such as Handy derive from the PID ("tray-icon tray app
      # 1234-1"). Prefer the item's title before the id everywhere a tray label
      # is chosen: bar widget, tray drawer and tray menu (8 places in 4.7.7).
      grep -rlE '\.tooltipTitle \|\| ' --include='*.qml' Modules \
        | xargs sed -i -E 's/([A-Za-z0-9_]+\??)\.tooltipTitle \|\| /\1.tooltipTitle || \1.title || /g'
      patched=$(grep -rhoE '\.tooltipTitle \|\| [A-Za-z0-9_]+\??\.title \|\| ' --include='*.qml' Modules | wc -l)
      if [ "$patched" -lt 8 ]; then
        echo "tray title fallback: expected at least 8 label sites, patched $patched" >&2
        exit 1
      fi
    '';
  });

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
    mullvad = {
      src = ./plugins/mullvad;
      settings = {
        compactMode = true;
        showCityName = false;
        showIp = false;
        clickAction = "panel";
      };
    };
    niri-display.src = ./plugins/niri-display;
    tailscale = {
      src = ./plugins/tailscale;
      settings = {
        compactMode = true;
        showIpAddress = false;
        showPeerCount = false;
        terminalCommand = "kitty";
      };
    };
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
      widgets = import ./bar-widgets.nix;
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
