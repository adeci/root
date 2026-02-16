{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  dotpkgs = import ../dotpkgs { inherit pkgs inputs; };
in
{
  environment.systemPackages = [

    # Terminal Emulator
    dotpkgs.kitty.wrapper

    # File Explorer
    pkgs.nautilus

    # XWayland
    pkgs.xwayland-satellite

    # Notifications
    pkgs.libnotify

    # Media/audio
    pkgs.playerctl
    pkgs.pulseaudio
    pkgs.pavucontrol

    # Clipboard
    pkgs.wl-clipboard
    pkgs.wl-clip-persist

    # Brightness
    pkgs.brightnessctl

    # Cursors, icons & themes
    pkgs.phinger-cursors
    pkgs.adwaita-icon-theme
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

  programs.niri.enable = true;

  # gnome-keyring service is enabled by programs.niri, but PAM unlock is separate
  security.pam.services.login.enableGnomeKeyring = true;

  environment.sessionVariables = {
    XCURSOR_THEME = "phinger-cursors-dark";
    XCURSOR_SIZE = "24";
    GTK_THEME = "Tokyonight-Dark";
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  # dconf.enable already set by programs.niri — just need custom values
  programs.dconf.profiles.user.databases = [
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

  # Polkit agent (programs.niri enables the backend, but not a GUI agent)
  systemd.user.services.polkit-gnome = {
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
}
