# Tokyo Night GTK theme, Papirus icons, phinger cursors, dark mode defaults.
{ lib, pkgs, ... }:
let
  theme-name = "Tokyonight-Dark";
  icon-theme-name = "Papirus-Dark";

  gtksettings = ''
    [Settings]
    gtk-theme-name = ${theme-name}
    gtk-icon-theme-name = ${icon-theme-name}
  '';
in
{
  environment.systemPackages = [
    pkgs.tokyonight-gtk-theme
    pkgs.papirus-icon-theme
    pkgs.phinger-cursors
    pkgs.glib
  ];

  environment.etc = {
    "xdg/gtk-3.0/settings.ini".text = gtksettings;
    "xdg/gtk-4.0/settings.ini".text = gtksettings;
  };

  environment.sessionVariables = {
    XCURSOR_THEME = "phinger-cursors-dark";
    XCURSOR_SIZE = "24";
    GTK_THEME = theme-name;
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  programs.dconf = {
    enable = lib.mkDefault true;
    profiles.user.databases = [
      {
        settings = {
          "org/gnome/desktop/interface" = {
            gtk-theme = theme-name;
            icon-theme = icon-theme-name;
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
}
