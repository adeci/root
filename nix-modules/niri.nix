{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  dotpkgs = import ../dotpkgs {
    inherit pkgs;
    wrappers = inputs.adeci-wrappers;
    nixvim = inputs.nixvim;
  };
  backgroundImage = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/adeci/wallpapers/main/tokyo-night/tokyo-night_nix.png";
    sha256 = "sha256-W5GaKCOiV2S3NuORGrRaoOE2x9X6gUS+wYf7cQkw9CY=";
  };
in
{
  environment.systemPackages = [

    # Terminal Emulator
    dotpkgs.kitty

    # File Explorer
    pkgs.nautilus

    # XWayland
    pkgs.xwayland-satellite

    # Wallpaper
    pkgs.swaybg

    # Notifications
    pkgs.libnotify
    dotpkgs.mako

    # Media/audio
    pkgs.playerctl
    pkgs.pulseaudio
    pkgs.pavucontrol
    #dotpkgs.swayosd

    # Clipboard
    pkgs.wl-clipboard
    pkgs.wl-clip-persist

    # Launcher & lock
    dotpkgs.fuzzel
    dotpkgs.swaylock

    # Brightness
    pkgs.brightnessctl

    # Cursors & themes
    pkgs.phinger-cursors
    pkgs.tokyonight-gtk-theme
    pkgs.glib

    # Utilities
    pkgs.jq
    pkgs.xdg-utils
    pkgs.nmgui

  ];

  fonts.packages = with pkgs; [
    nerd-fonts.caskaydia-mono
    noto-fonts-color-emoji
  ];

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };

  programs.niri = {
    enable = true;
    package = dotpkgs.niri;
  };

  # gnome-keyring is enabled by programs.niri module, but we need PAM integration
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.swaylock.enableGnomeKeyring = true;

  environment.sessionVariables = {
    XCURSOR_THEME = "phinger-cursors-dark";
    XCURSOR_SIZE = "24";
    GTK_THEME = "Tokyonight-Dark";
    QT_QPA_PLATFORMTHEME = "gtk2";
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/gcr/ssh"; # gcr from gnome-keyring
  };

  programs.dconf = {
    enable = true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            gtk-theme = "Tokyonight-Dark";
            color-scheme = "prefer-dark";
            cursor-theme = "phinger-cursors-dark";
            cursor-size = lib.gvariant.mkInt32 24;
          };
          "org/gnome/desktop/background" = {
            color-shading-type = "solid";
            picture-options = "zoom";
            prefer-dark-theme = true;
          };
        };
      }
    ];
  };

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
  };

  # Systemd user services for niri session
  # Starting here rather than with Niri's spawn-at-startup
  systemd.user.services = {

    # Update environment and restart portals when niri starts
    niri-session-env = {
      description = "Update systemd environment for niri session";
      after = [ "niri.service" ];
      requisite = [ "niri.service" ];
      partOf = [ "graphical-session.target" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = pkgs.writeShellScript "niri-session-env" ''
          # Import environment variables into systemd user session
          ${pkgs.systemd}/bin/systemctl --user import-environment WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP
          ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd WAYLAND_DISPLAY DISPLAY XDG_CURRENT_DESKTOP

          # Restart portal services to pick up new environment
          ${pkgs.systemd}/bin/systemctl --user restart xdg-desktop-portal.service xdg-desktop-portal-gtk.service || true
        '';
      };
      wantedBy = [ "niri.service" ];
    };

    # mako = {
    #   description = "Mako notification daemon";
    #   partOf = [ "graphical-session.target" ];
    #   after = [ "graphical-session.target" ];
    #   requisite = [ "graphical-session.target" ];
    #   serviceConfig = {
    #     ExecStart = "${dotpkgs.mako}/bin/mako";
    #     Restart = "on-failure";
    #     RestartSec = 1;
    #   };
    #   wantedBy = [ "niri.service" ];
    # };
    #
    # swayosd = {
    #   description = "SwayOSD server";
    #   partOf = [ "graphical-session.target" ];
    #   after = [ "graphical-session.target" ];
    #   requisite = [ "graphical-session.target" ];
    #   serviceConfig = {
    #     ExecStart = "${dotpkgs.swayosd}/bin/swayosd-server";
    #     Restart = "on-failure";
    #     RestartSec = 1;
    #   };
    #   wantedBy = [ "niri.service" ];
    # };

    swaybg = {
      description = "Swaybg wallpaper";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      requisite = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.swaybg}/bin/swaybg -i ${backgroundImage} -m fill";
        Restart = "on-failure";
        RestartSec = 1;
      };
      wantedBy = [ "niri.service" ];
    };

    polkit-gnome = {
      description = "Polkit GNOME authentication agent";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      requisite = [ "graphical-session.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "on-failure";
        RestartSec = 1;
      };
      wantedBy = [ "niri.service" ];
    };
  };
}
