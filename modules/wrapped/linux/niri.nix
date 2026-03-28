{
  wlib,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  wrappedKitty = inputs.self.wrappers.kitty.wrap { inherit pkgs; };
  wrappedNoctalia = inputs.self.wrappers.noctalia-shell.wrap { inherit pkgs; };

  kittyBin = lib.getExe wrappedKitty;
  noctaliaBin = lib.getExe wrappedNoctalia;

  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
    sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
  };
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  playerctl = lib.getExe pkgs.playerctl;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  jq = lib.getExe pkgs.jq;

  msi = "Microstep MSI MAG321CQR KA3H071804955";
in
{
  imports = [ wlib.wrapperModules.niri ];

  # Use my fork with on-output window rule support
  config.package = lib.mkForce inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;

  # Runtime libs for nested mode (demo inside an existing session)
  config.prefixVar = [
    {
      data = [
        "LD_LIBRARY_PATH"
        ":"
        (lib.makeLibraryPath [
          pkgs.libxcursor
          pkgs.libxrandr
          pkgs.libxi
          pkgs.libx11
        ])
      ];
    }
  ];

  config.settings = {

    # ── Input ──────────────────────────────────────────────────────

    input = {
      keyboard = {
        xkb = {
          layout = "us";
        };
        numlock = null;
      };
      touchpad = {
        tap = null;
        natural-scroll = null;
      };
      mouse = { };
      trackpoint = {
        accel-speed = -0.25;
        accel-profile = "flat";
      };
      touch = {
        map-to-output = "eDP-1";
      };
      disable-power-key-handling = null;
    };

    # ── Outputs ────────────────────────────────────────────────────

    outputs = {
      # aegis — lenovo x220 display
      "LG Display 0x02D8 Unknown" = {
        mode = "1366x768@60.019";
        scale = 1;
        transform = "normal";
      };

      # modus — framework 13 display
      "BOE NE135A1M-NY1 Unknown" = {
        mode = "2880x1920@120";
        scale = 2;
        transform = "normal";
        position = {
          _attrs = {
            x = 560;
            y = 1440;
          };
        };
      };

      # praxis — gpd pocket 4 display
      "PNP(HSX) YHB03P24 0x00888888" = {
        mode = "1600x2560@143.999";
        scale = 2;
        transform = "normal";
        position = {
          _attrs = {
            x = 640;
            y = 1440;
          };
        };
      };

      # shared — MSI MAG321CQR 32" curved monitor
      ${msi} = {
        mode = "2560x1440@144";
        scale = 1;
        transform = "normal";
        position = {
          _attrs = {
            x = 0;
            y = 0;
          };
        };
        layout = {
          default-column-width = {
            proportion = 0.33333;
          };
          preset-column-widths = [
            { proportion = 0.25; }
            { proportion = 0.33333; }
            { proportion = 0.5; }
            { proportion = 0.66667; }
          ];
        };
      };
    };

    # ── Cursor ─────────────────────────────────────────────────────

    cursor = {
      xcursor-theme = "phinger-cursors-dark";
      xcursor-size = 24;
      hide-after-inactive-ms = 1000;
    };

    # ── Layout ─────────────────────────────────────────────────────

    layout = {
      gaps = 6;
      center-focused-column = "never";

      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];

      default-column-width = {
        proportion = 0.5;
      };

      focus-ring = {
        off = null;
      };

      border = {
        width = 2;
        active-color = "#00C0A3";
        inactive-color = "#292e42";
      };

      shadow = {
        on = null;
      };

      struts = { };
    };

    # ── Startup ────────────────────────────────────────────────────

    spawn-at-startup = [
      noctaliaBin
      (lib.getExe (
        pkgs.writeShellScriptBin "wallpaper" "${lib.getExe pkgs.swaybg} -i ${wallpaper} -m fill"
      ))
    ];

    hotkey-overlay = {
      skip-at-startup = null;
      hide-not-bound = null;
    };

    prefer-no-csd = null;

    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    animations = {
      slowdown = 0.5;
    };

    # ── Window Rules ───────────────────────────────────────────────

    window-rules = [
      # Firefox/LibreWolf: 1/3 width on the MSI monitor
      {
        matches = [
          {
            app-id = "firefox";
            on-output = msi;
          }
          {
            app-id = "librewolf";
            on-output = msi;
          }
        ];
        default-column-width = {
          proportion = 0.33333;
        };
      }

      # Firefox/LibreWolf: open maximized on laptop displays
      {
        matches = [
          { app-id = "firefox"; }
          { app-id = "librewolf"; }
        ];
        excludes = [
          { on-output = msi; }
        ];
        open-maximized = true;
      }

      {
        matches = [
          { app-id = "firefox"; }
          { app-id = "librewolf"; }
        ];
        clip-to-geometry = true;
      }

      # Communication apps: 50% width on the MSI 32"
      {
        matches = [
          {
            app-id = "^discord$";
            on-output = msi;
          }
          {
            app-id = "^vesktop$";
            on-output = msi;
          }
          {
            app-id = "^Element";
            on-output = msi;
          }
          {
            app-id = "^signal$";
            on-output = msi;
          }
        ];
        default-column-width = {
          proportion = 0.5;
        };
      }

      # Communication apps: open maximized on all other displays
      {
        matches = [
          { app-id = "^discord$"; }
          { app-id = "^vesktop$"; }
          { app-id = "^Element"; }
          { app-id = "^signal$"; }
        ];
        excludes = [
          { on-output = msi; }
        ];
        open-maximized = true;
      }
    ];

    # ── Binds ──────────────────────────────────────────────────────

    binds = {
      "Mod+Shift+Slash" = {
        show-hotkey-overlay = null;
      };

      "Mod+Return" = {
        _attrs = {
          hotkey-overlay-title = "Open a Terminal: kitty";
        };
        spawn = kittyBin;
      };
      "Mod+Shift+Return" = {
        _attrs = {
          hotkey-overlay-title = "Open Terminal Here";
        };
        spawn = toString (
          pkgs.writeShellScript "kitty-here" ''
            set -- $(niri msg -j focused-window 2>/dev/null | ${jq} -r '.app_id, .pid')
            if [ "$1" = kitty ]; then
              child=$(ps -o pid=,tty= --ppid "$2" | grep -v '?' | head -1 | awk '{print $1}')
              [ -n "$child" ] && exec ${kittyBin} -d "$(readlink -f /proc/"$child"/cwd)"
            fi
            exec ${kittyBin}
          ''
        );
      };
      "Mod+D" = {
        _attrs = {
          hotkey-overlay-title = "Run an Application";
        };
        spawn = [
          noctaliaBin
          "ipc"
          "call"
          "launcher"
          "toggle"
        ];
      };
      "Mod+Alt+V" = {
        _attrs = {
          hotkey-overlay-title = "Clipboard History";
        };
        spawn = [
          noctaliaBin
          "ipc"
          "call"
          "launcher"
          "clipboard"
        ];
      };
      "Super+Alt+L" = {
        _attrs = {
          hotkey-overlay-title = "Lock the Screen";
        };
        spawn = [
          noctaliaBin
          "ipc"
          "call"
          "lockScreen"
          "lock"
        ];
      };

      # Volume
      "XF86AudioRaiseVolume" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn = [
          wpctl
          "set-volume"
          "@DEFAULT_AUDIO_SINK@"
          "5%+"
        ];
      };
      "XF86AudioLowerVolume" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn = [
          wpctl
          "set-volume"
          "@DEFAULT_AUDIO_SINK@"
          "5%-"
        ];
      };
      "XF86AudioMute" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn = [
          wpctl
          "set-mute"
          "@DEFAULT_AUDIO_SINK@"
          "toggle"
        ];
      };
      "XF86AudioMicMute" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn = [
          wpctl
          "set-mute"
          "@DEFAULT_AUDIO_SOURCE@"
          "toggle"
        ];
      };

      # Media
      "XF86AudioPlay" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn-sh = "${playerctl} play-pause";
      };
      "XF86AudioStop" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn-sh = "${playerctl} stop";
      };
      "XF86AudioPrev" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn-sh = "${playerctl} previous";
      };
      "XF86AudioNext" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn-sh = "${playerctl} next";
      };

      # Brightness
      "XF86MonBrightnessUp" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn = [
          brightnessctl
          "set"
          "5%+"
        ];
      };
      "XF86MonBrightnessDown" = {
        _attrs = {
          allow-when-locked = true;
        };
        spawn = [
          brightnessctl
          "set"
          "5%-"
        ];
      };

      # Overview
      "Mod+O" = {
        _attrs = {
          repeat = false;
        };
        toggle-overview = null;
      };

      # Window management
      "Mod+Q" = {
        _attrs = {
          repeat = false;
        };
        close-window = null;
      };

      "Mod+H".focus-column-left = null;
      "Mod+J".focus-window-or-workspace-down = null;
      "Mod+K".focus-window-or-workspace-up = null;
      "Mod+L".focus-column-right = null;

      "Mod+Shift+H".move-column-left = null;
      "Mod+Shift+J".move-window-down-or-to-workspace-down = null;
      "Mod+Shift+K".move-window-up-or-to-workspace-up = null;
      "Mod+Shift+L".move-column-right = null;

      "Mod+Home".focus-column-first = null;
      "Mod+End".focus-column-last = null;
      "Mod+Ctrl+Home".move-column-to-first = null;
      "Mod+Ctrl+End".move-column-to-last = null;

      "Mod+Ctrl+H".focus-monitor-left = null;
      "Mod+Ctrl+J".focus-monitor-down = null;
      "Mod+Ctrl+K".focus-monitor-up = null;
      "Mod+Ctrl+L".focus-monitor-right = null;

      "Mod+Shift+Ctrl+H".move-column-to-monitor-left = null;
      "Mod+Shift+Ctrl+J".move-column-to-monitor-down = null;
      "Mod+Shift+Ctrl+K".move-column-to-monitor-up = null;
      "Mod+Shift+Ctrl+L".move-column-to-monitor-right = null;

      "Mod+U".focus-workspace-down = null;
      "Mod+I".focus-workspace-up = null;
      "Mod+Ctrl+U".move-column-to-workspace-down = null;
      "Mod+Ctrl+I".move-column-to-workspace-up = null;

      "Mod+Shift+U".move-workspace-down = null;
      "Mod+Shift+I".move-workspace-up = null;

      # Mouse wheel workspace switching
      "Mod+WheelScrollDown" = {
        _attrs = {
          cooldown-ms = 150;
        };
        focus-workspace-down = null;
      };
      "Mod+WheelScrollUp" = {
        _attrs = {
          cooldown-ms = 150;
        };
        focus-workspace-up = null;
      };
      "Mod+Ctrl+WheelScrollDown" = {
        _attrs = {
          cooldown-ms = 150;
        };
        move-column-to-workspace-down = null;
      };
      "Mod+Ctrl+WheelScrollUp" = {
        _attrs = {
          cooldown-ms = 150;
        };
        move-column-to-workspace-up = null;
      };

      "Mod+WheelScrollRight".focus-column-right = null;
      "Mod+WheelScrollLeft".focus-column-left = null;
      "Mod+Ctrl+WheelScrollRight".move-column-right = null;
      "Mod+Ctrl+WheelScrollLeft".move-column-left = null;

      "Mod+Shift+WheelScrollDown".focus-column-right = null;
      "Mod+Shift+WheelScrollUp".focus-column-left = null;
      "Mod+Ctrl+Shift+WheelScrollDown".move-column-right = null;
      "Mod+Ctrl+Shift+WheelScrollUp".move-column-left = null;

      # Workspaces by index
      "Mod+1".focus-workspace = 1;
      "Mod+2".focus-workspace = 2;
      "Mod+3".focus-workspace = 3;
      "Mod+4".focus-workspace = 4;
      "Mod+5".focus-workspace = 5;
      "Mod+6".focus-workspace = 6;
      "Mod+7".focus-workspace = 7;
      "Mod+8".focus-workspace = 8;
      "Mod+9".focus-workspace = 9;
      "Mod+Shift+1".move-column-to-workspace = 1;
      "Mod+Shift+2".move-column-to-workspace = 2;
      "Mod+Shift+3".move-column-to-workspace = 3;
      "Mod+Shift+4".move-column-to-workspace = 4;
      "Mod+Shift+5".move-column-to-workspace = 5;
      "Mod+Shift+6".move-column-to-workspace = 6;
      "Mod+Shift+7".move-column-to-workspace = 7;
      "Mod+Shift+8".move-column-to-workspace = 8;
      "Mod+Shift+9".move-column-to-workspace = 9;

      # Column management
      "Mod+BracketLeft".consume-or-expel-window-left = null;
      "Mod+BracketRight".consume-or-expel-window-right = null;
      "Mod+Comma".consume-window-into-column = null;
      "Mod+Period".expel-window-from-column = null;

      # Sizing
      "Mod+R".switch-preset-column-width = null;
      "Mod+Shift+R".switch-preset-window-height = null;
      "Mod+Ctrl+R".reset-window-height = null;
      "Mod+F".maximize-column = null;
      "Mod+Shift+F".fullscreen-window = null;
      "Mod+Ctrl+F".expand-column-to-available-width = null;

      "Mod+C".center-column = null;
      "Mod+Ctrl+C".center-visible-columns = null;

      "Mod+Minus".set-column-width = "-10%";
      "Mod+Equal".set-column-width = "+10%";
      "Mod+Shift+Minus".set-window-height = "-10%";
      "Mod+Shift+Equal".set-window-height = "+10%";

      # Floating / tabbed
      "Mod+V".toggle-window-floating = null;
      "Mod+Shift+V".switch-focus-between-floating-and-tiling = null;
      "Mod+W".toggle-column-tabbed-display = null;

      # Screenshots
      "Print".screenshot = null;
      "Ctrl+Print".screenshot-screen = null;
      "Alt+Print".screenshot-window = null;

      # Session
      "Mod+Escape" = {
        _attrs = {
          allow-inhibiting = false;
        };
        toggle-keyboard-shortcuts-inhibit = null;
      };
      "Mod+Shift+E".quit = null;
      "Ctrl+Alt+Delete".quit = null;
      "Mod+Shift+P".power-off-monitors = null;
    };
  };
}
