{
  wlib,
  pkgs,
  lib,
  inputs,
  ...
}:
let
  # Referenced by name from PATH (provided by desktop.nix systemPackages)
  # so that niri's config doesn't bake in store paths — rebuilding kitty/zsh/tmux
  # takes effect in new terminals without restarting the compositor.
  kittyBin = "kitty";
  noctaliaBin = "noctalia-shell";
  emptyNode = _: { };

  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
    sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
  };
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  playerctl = lib.getExe pkgs.playerctl;
  brightnessctl = lib.getExe pkgs.brightnessctl;
  jq = lib.getExe pkgs.jq;

  msi = "Microstep MSI MAG321CQR KA3H071804955";

  # ── Theming ───────────────────────────────────────────────────────
  theme-name = "Tokyonight-Dark";
  icon-theme-name = "Papirus-Dark";
  cursor-theme = "phinger-cursors-dark";
  cursor-size = "24";

  # ── Fonts ─────────────────────────────────────────────────────────
  fonts = [
    pkgs.nerd-fonts.caskaydia-mono
    pkgs.noto-fonts-color-emoji
  ];
in
{
  imports = [ wlib.wrapperModules.niri ];

  # Use my fork with on-output window rule support
  config.package = lib.mkForce inputs.niri.packages.${pkgs.stdenv.hostPlatform.system}.niri;
  config."v2-settings" = true;

  # ── Theming — baked into the derivation via postBuild ─────────────
  config.drv.nativeBuildInputs = [ pkgs.dconf ];
  config.drv.postBuild = ''
    # Fontconfig — point at bundled fonts so the demo works without system fonts
    mkdir -p $out/fontconfig
    cat > $out/fontconfig/fonts.conf <<'FCEOF'
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>/run/current-system/sw/share/X11/fonts</dir>
      <dir>~/.local/share/fonts</dir>
      <dir>~/.fonts</dir>
      ${lib.concatMapStringsSep "\n  " (f: "<dir>${f}/share/fonts</dir>") fonts}
      <include ignore_missing="yes">/etc/fonts/fonts.conf</include>
    </fontconfig>
    FCEOF

    # GTK settings
    mkdir -p $out/xdg/gtk-3.0 $out/xdg/gtk-4.0
    cat > $out/xdg/gtk-3.0/settings.ini <<'GTKEOF'
    [Settings]
    gtk-theme-name = ${theme-name}
    gtk-icon-theme-name = ${icon-theme-name}
    gtk-cursor-theme-name = ${cursor-theme}
    gtk-cursor-theme-size = ${cursor-size}
    GTKEOF
    cp $out/xdg/gtk-3.0/settings.ini $out/xdg/gtk-4.0/settings.ini

    # dconf compiled database (dconf compile expects a directory of keyfiles)
    mkdir -p $out/dconf $TMPDIR/dconf-keyfiles
    cat > $TMPDIR/dconf-keyfiles/defaults <<'DCONFEOF'
    [org/gnome/desktop/interface]
    gtk-theme='${theme-name}'
    icon-theme='${icon-theme-name}'
    color-scheme='prefer-dark'
    cursor-theme='${cursor-theme}'
    cursor-size=24

    [org/gnome/desktop/background]
    color-shading-type='solid'
    picture-options='zoom'
    DCONFEOF
    dconf compile $out/dconf/db $TMPDIR/dconf-keyfiles

    cat > $out/dconf/profile <<PROFILEEOF
    user-db:user
    file-db:$out/dconf/db
    PROFILEEOF
  '';

  config.env = {
    GTK_THEME = theme-name;
    XCURSOR_THEME = cursor-theme;
    XCURSOR_SIZE = cursor-size;
    QT_QPA_PLATFORMTHEME = "gtk3";
    XDG_CONFIG_DIRS = "${placeholder "out"}/xdg";
    DCONF_PROFILE = "${placeholder "out"}/dconf/profile";
    FONTCONFIG_FILE = "${placeholder "out"}/fontconfig/fonts.conf";
  };

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
    {
      data = [
        "XDG_DATA_DIRS"
        ":"
        (lib.concatStringsSep ":" [
          "${pkgs.tokyonight-gtk-theme}/share"
          "${pkgs.papirus-icon-theme}/share"
          "${pkgs.phinger-cursors}/share"
          "${pkgs.glib}/share"
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
        numlock = emptyNode;
      };
      touchpad = {
        tap = emptyNode;
        natural-scroll = emptyNode;
      };
      mouse = { };
      trackpoint = {
        accel-speed = -0.25;
        accel-profile = "flat";
      };
      touch = {
        map-to-output = "eDP-1";
      };
      disable-power-key-handling = emptyNode;
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
        position = _: {
          props = {
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
        position = _: {
          props = {
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
        position = _: {
          props = {
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
      xcursor-theme = cursor-theme;
      xcursor-size = lib.strings.toInt cursor-size;
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
        off = emptyNode;
      };

      border = {
        width = 2;
        active-color = "#00C0A3";
        inactive-color = "#292e42";
      };

      shadow = {
        on = emptyNode;
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
      skip-at-startup = emptyNode;
      hide-not-bound = emptyNode;
    };

    prefer-no-csd = emptyNode;

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
        show-hotkey-overlay = emptyNode;
      };

      "Mod+Return" = _: {
        props.hotkey-overlay-title = "Open a Terminal: kitty";
        content.spawn = kittyBin;
      };
      "Mod+Shift+Return" = _: {
        props.hotkey-overlay-title = "Open Terminal Here";
        content.spawn = toString (
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
      "Mod+D" = _: {
        props.hotkey-overlay-title = "Run an Application";
        content.spawn = [
          noctaliaBin
          "ipc"
          "call"
          "launcher"
          "toggle"
        ];
      };
      "Mod+Alt+V" = _: {
        props.hotkey-overlay-title = "Clipboard History";
        content.spawn = [
          noctaliaBin
          "ipc"
          "call"
          "launcher"
          "clipboard"
        ];
      };
      "Super+Alt+L" = _: {
        props.hotkey-overlay-title = "Lock the Screen";
        content.spawn = [
          noctaliaBin
          "ipc"
          "call"
          "lockScreen"
          "lock"
        ];
      };

      # Volume
      "XF86AudioRaiseVolume" = _: {
        props.allow-when-locked = true;
        content.spawn = [
          wpctl
          "set-volume"
          "@DEFAULT_AUDIO_SINK@"
          "5%+"
        ];
      };
      "XF86AudioLowerVolume" = _: {
        props.allow-when-locked = true;
        content.spawn = [
          wpctl
          "set-volume"
          "@DEFAULT_AUDIO_SINK@"
          "5%-"
        ];
      };
      "XF86AudioMute" = _: {
        props.allow-when-locked = true;
        content.spawn = [
          wpctl
          "set-mute"
          "@DEFAULT_AUDIO_SINK@"
          "toggle"
        ];
      };
      "XF86AudioMicMute" = _: {
        props.allow-when-locked = true;
        content.spawn = [
          wpctl
          "set-mute"
          "@DEFAULT_AUDIO_SOURCE@"
          "toggle"
        ];
      };

      # Media
      "XF86AudioPlay" = _: {
        props.allow-when-locked = true;
        content.spawn-sh = "${playerctl} play-pause";
      };
      "XF86AudioStop" = _: {
        props.allow-when-locked = true;
        content.spawn-sh = "${playerctl} stop";
      };
      "XF86AudioPrev" = _: {
        props.allow-when-locked = true;
        content.spawn-sh = "${playerctl} previous";
      };
      "XF86AudioNext" = _: {
        props.allow-when-locked = true;
        content.spawn-sh = "${playerctl} next";
      };

      # Brightness
      "XF86MonBrightnessUp" = _: {
        props.allow-when-locked = true;
        content.spawn = [
          brightnessctl
          "set"
          "5%+"
        ];
      };
      "XF86MonBrightnessDown" = _: {
        props.allow-when-locked = true;
        content.spawn = [
          brightnessctl
          "set"
          "5%-"
        ];
      };

      # Overview
      "Mod+O" = _: {
        props.repeat = false;
        content.toggle-overview = emptyNode;
      };

      # Window management
      "Mod+Q" = _: {
        props.repeat = false;
        content.close-window = emptyNode;
      };

      "Mod+H".focus-column-left = emptyNode;
      "Mod+J".focus-window-or-workspace-down = emptyNode;
      "Mod+K".focus-window-or-workspace-up = emptyNode;
      "Mod+L".focus-column-right = emptyNode;

      "Mod+Shift+H".move-column-left = emptyNode;
      "Mod+Shift+J".move-window-down-or-to-workspace-down = emptyNode;
      "Mod+Shift+K".move-window-up-or-to-workspace-up = emptyNode;
      "Mod+Shift+L".move-column-right = emptyNode;

      "Mod+Home".focus-column-first = emptyNode;
      "Mod+End".focus-column-last = emptyNode;
      "Mod+Ctrl+Home".move-column-to-first = emptyNode;
      "Mod+Ctrl+End".move-column-to-last = emptyNode;

      "Mod+Ctrl+H".focus-monitor-left = emptyNode;
      "Mod+Ctrl+J".focus-monitor-down = emptyNode;
      "Mod+Ctrl+K".focus-monitor-up = emptyNode;
      "Mod+Ctrl+L".focus-monitor-right = emptyNode;

      "Mod+Shift+Ctrl+H".move-column-to-monitor-left = emptyNode;
      "Mod+Shift+Ctrl+J".move-column-to-monitor-down = emptyNode;
      "Mod+Shift+Ctrl+K".move-column-to-monitor-up = emptyNode;
      "Mod+Shift+Ctrl+L".move-column-to-monitor-right = emptyNode;

      "Mod+U".focus-workspace-down = emptyNode;
      "Mod+I".focus-workspace-up = emptyNode;
      "Mod+Ctrl+U".move-column-to-workspace-down = emptyNode;
      "Mod+Ctrl+I".move-column-to-workspace-up = emptyNode;

      "Mod+Shift+U".move-workspace-down = emptyNode;
      "Mod+Shift+I".move-workspace-up = emptyNode;

      # Mouse wheel workspace switching
      "Mod+WheelScrollDown" = _: {
        props.cooldown-ms = 150;
        content.focus-workspace-down = emptyNode;
      };
      "Mod+WheelScrollUp" = _: {
        props.cooldown-ms = 150;
        content.focus-workspace-up = emptyNode;
      };
      "Mod+Ctrl+WheelScrollDown" = _: {
        props.cooldown-ms = 150;
        content.move-column-to-workspace-down = emptyNode;
      };
      "Mod+Ctrl+WheelScrollUp" = _: {
        props.cooldown-ms = 150;
        content.move-column-to-workspace-up = emptyNode;
      };

      "Mod+WheelScrollRight".focus-column-right = emptyNode;
      "Mod+WheelScrollLeft".focus-column-left = emptyNode;
      "Mod+Ctrl+WheelScrollRight".move-column-right = emptyNode;
      "Mod+Ctrl+WheelScrollLeft".move-column-left = emptyNode;

      "Mod+Shift+WheelScrollDown".focus-column-right = emptyNode;
      "Mod+Shift+WheelScrollUp".focus-column-left = emptyNode;
      "Mod+Ctrl+Shift+WheelScrollDown".move-column-right = emptyNode;
      "Mod+Ctrl+Shift+WheelScrollUp".move-column-left = emptyNode;

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
      "Mod+BracketLeft".consume-or-expel-window-left = emptyNode;
      "Mod+BracketRight".consume-or-expel-window-right = emptyNode;
      "Mod+Comma".consume-window-into-column = emptyNode;
      "Mod+Period".expel-window-from-column = emptyNode;

      # Sizing
      "Mod+R".switch-preset-column-width = emptyNode;
      "Mod+Shift+R".switch-preset-window-height = emptyNode;
      "Mod+Ctrl+R".reset-window-height = emptyNode;
      "Mod+F".maximize-column = emptyNode;
      "Mod+Shift+F".fullscreen-window = emptyNode;
      "Mod+Ctrl+F".expand-column-to-available-width = emptyNode;

      "Mod+C".center-column = emptyNode;
      "Mod+Ctrl+C".center-visible-columns = emptyNode;

      "Mod+Minus".set-column-width = "-10%";
      "Mod+Equal".set-column-width = "+10%";
      "Mod+Shift+Minus".set-window-height = "-10%";
      "Mod+Shift+Equal".set-window-height = "+10%";

      # Floating / tabbed
      "Mod+V".toggle-window-floating = emptyNode;
      "Mod+Shift+V".switch-focus-between-floating-and-tiling = emptyNode;
      "Mod+W".toggle-column-tabbed-display = emptyNode;

      # Screenshots
      "Print".screenshot = emptyNode;
      "Ctrl+Print".screenshot-screen = emptyNode;
      "Alt+Print".screenshot-window = emptyNode;

      # Session
      "Mod+Escape" = _: {
        props.allow-inhibiting = false;
        content.toggle-keyboard-shortcuts-inhibit = emptyNode;
      };
      "Mod+Shift+E".quit = emptyNode;
      "Ctrl+Alt+Delete".quit = emptyNode;
      "Mod+Shift+P".power-off-monitors = emptyNode;
    };
  };
}
