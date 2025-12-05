{
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [
    pkgs.swayidle

    pkgs.swaybg
    pkgs.swaycwd

    pkgs.libnotify

    pkgs.playerctl

    pkgs.wl-clipboard
    pkgs.wl-clip-persist

    pkgs.grim
    pkgs.slurp

    pkgs.phinger-cursors

    pkgs.pulseaudio
    pkgs.pavucontrol
    pkgs.jq
    pkgs.xdg-utils

    pkgs.tokyonight-gtk-theme
    pkgs.glib

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

  programs.sway.enable = true;

  programs.fish.enable = true;

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  security.pam.services.swaylock = {
    enableGnomeKeyring = true;
  };

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
    config.common.default = [
      "wlr"
      "gtk"
    ];
  };

  programs.xwayland.enable = true;
}
