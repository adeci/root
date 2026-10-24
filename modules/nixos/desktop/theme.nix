{ lib, pkgs, ... }:
let
  gtk = "adw-gtk3-dark";
  icons = "Papirus-Dark";
  cursor = "phinger-cursors-dark";
  cursorSize = 24;
in
{
  environment.systemPackages = [
    pkgs.adw-gtk3
    pkgs.papirus-icon-theme
    pkgs.phinger-cursors
  ];

  environment.sessionVariables = {
    XCURSOR_THEME = cursor;
    XCURSOR_SIZE = toString cursorSize;
    GTK_THEME = gtk;
    QT_QPA_PLATFORMTHEME = "gtk3";
  };

  programs.dconf = {
    enable = lib.mkDefault true;
    profiles.user.databases = [
      {
        settings."org/gnome/desktop/interface" = {
          gtk-theme = gtk;
          icon-theme = icons;
          color-scheme = "prefer-dark";
          cursor-theme = cursor;
          cursor-size = lib.gvariant.mkInt32 cursorSize;
        };
      }
    ];
  };
}
